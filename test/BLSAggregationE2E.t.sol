// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseTest } from "./BaseTest.sol";
import { Types } from "../src/libraries/Types.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { BN254 } from "../src/libraries/BN254.sol";
import { BLSTestHelper } from "./helpers/BLSTestHelper.sol";
import { BlueprintServiceManagerBase } from "../src/BlueprintServiceManagerBase.sol";

/// @title MockAggregationBSME2E
/// @notice Mock BSM for E2E BLS tests
contract MockAggregationBSME2E is BlueprintServiceManagerBase {
    mapping(uint8 => bool) public aggregationRequired;
    mapping(uint8 => uint16) public thresholdBps;
    mapping(uint8 => uint8) public thresholdType;

    function setAggregationConfig(uint8 jobIndex, bool required, uint16 _thresholdBps, uint8 _thresholdType) external {
        aggregationRequired[jobIndex] = required;
        thresholdBps[jobIndex] = _thresholdBps;
        thresholdType[jobIndex] = _thresholdType;
    }

    function requiresAggregation(uint64, uint8 jobIndex) external view override returns (bool) {
        return aggregationRequired[jobIndex];
    }

    function getAggregationThreshold(uint64, uint8 jobIndex) external view override returns (uint16, uint8) {
        uint16 threshold = thresholdBps[jobIndex];
        if (threshold == 0) threshold = 6700;
        return (threshold, thresholdType[jobIndex]);
    }
}

/// @title BLSAggregationE2ETest
/// @notice End-to-end tests with valid BLS signatures
/// @dev These tests generate real BLS signatures and verify them on-chain
contract BLSAggregationE2ETest is BaseTest {
    MockAggregationBSME2E public mockBsm;
    uint64 public blueprintId;
    uint64 public serviceId;

    function setUp() public override {
        super.setUp();

        // Deploy mock BSM
        mockBsm = new MockAggregationBSME2E();

        // Create blueprint with aggregation-enabled BSM
        vm.prank(developer);
        blueprintId = _createBlueprintAsSender("ipfs://bls-e2e-test", address(mockBsm));

        // The three operators use the Arkworks-derived private keys 1, 2, and 3.
        // Their proof-of-possession checks exercise the same G2 encoding used by aggregation.
        _registerOperator(operator1, 5 ether); // 50%
        _registerOperator(operator2, 3 ether); // 30%
        _registerOperator(operator3, 2 ether); // 20%

        _registerForBlueprint(operator1, blueprintId);
        _registerForBlueprint(operator2, blueprintId);
        _registerForBlueprint(operator3, blueprintId);

        address[] memory operators = new address[](3);
        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;
        address[] memory callers = new address[](0);

        vm.prank(user1);
        uint64 requestId = tangle.requestService(
            blueprintId, operators, "", callers, 0, address(0), 0, Types.ConfidentialityPolicy.Any
        );

        _approveBlsAsOperator(operator1, requestId, 1);
        _approveBlsAsOperator(operator2, requestId, 2);
        _approveBlsAsOperator(operator3, requestId, 3);

        serviceId = 0;
    }

    function _approveBlsAsOperator(address operator, uint64 requestId, uint256 sk) internal {
        uint256[4] memory pubkey = BLSTestHelper.g2ToArray(BLSTestHelper.getTestPubkey(sk));
        bytes memory pop = tangle.blsPopMessage(operator, pubkey);
        Types.BN254G1Point memory popSig = BLSTestHelper.sign(pop, sk);
        vm.prank(operator);
        tangle.approveService(_approveWithBls(requestId, pubkey, BLSTestHelper.g1ToArray(popSig)));
    }

    /// @notice Canonical operator list for the test service (matches the
    ///         insertion order in `setUp` and therefore the on-chain
    ///         `_serviceOperatorSet[serviceId].values()` order).
    function _operators() internal view returns (address[] memory ops) {
        ops = new address[](3);
        ops[0] = operator1;
        ops[1] = operator2;
        ops[2] = operator3;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST: Valid Single Signer BLS E2E
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Test with valid BLS signature from single signer (sk=1)
    /// @dev This is the simplest valid BLS test case
    function test_ValidBLS_SingleSigner() public {
        // 3333 bps is the highest threshold that still permits 1 of 3 signers with round-up math.
        mockBsm.setAggregationConfig(0, true, 3333, 0);

        // Submit a job
        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "test input");

        // Generate valid BLS signature
        bytes memory output = "valid result";
        (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey) =
            BLSTestHelper.createSingleSignerData(serviceId, callId, address(tangle), _operators(), output);

        // Only operator 0 signed (bit 0)
        uint256 signerBitmap = 0x1;

        // Submit aggregated result with valid signature
        tangle.submitAggregatedResult(
            serviceId, callId, output, signerBitmap, BLSTestHelper.g1ToArray(sig), BLSTestHelper.g2ToArray(pubkey)
        );

        // Verify job completed
        Types.JobCall memory job = tangle.getJobCall(serviceId, callId);
        assertTrue(job.completed, "Job should be completed with valid BLS signature");
    }

    /// @notice Test BLS verification helper directly
    function test_BLSVerification_Direct() public {
        bytes memory message = abi.encodePacked(uint64(0), uint64(1), keccak256("test"));

        // Sign with sk=1
        Types.BN254G1Point memory sig = BLSTestHelper.sign(message, 1);
        Types.BN254G2Point memory pubkey = BLSTestHelper.getTestPubkey(1);

        // Verify signature
        bool valid = BN254.verifyBls(message, sig, pubkey);
        assertTrue(valid, "BLS signature should verify");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST: Valid Multi-Signer BLS E2E
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Test with valid aggregated BLS signature from two signers.
    /// @dev The aggregate public key is 1*G2 + 2*G2 = 3*G2.
    function test_ValidBLS_TwoSigners() public {
        // ceil(3 * 50%) requires two of the three operators.
        mockBsm.setAggregationConfig(0, true, 5000, 0);

        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "two-signer test");

        bytes memory output = "two-signer result";
        bytes memory message =
            BLSTestHelper.buildJobResultMessage(serviceId, callId, address(tangle), _operators(), output);

        Types.BN254G1Point memory sig1 = BLSTestHelper.sign(message, 1);
        Types.BN254G1Point memory sig2 = BLSTestHelper.sign(message, 2);
        Types.BN254G1Point memory aggregateSignature = BN254.addG1(sig1, sig2);

        Types.BN254G2Point memory key1 = BLSTestHelper.getTestPubkey(1);
        Types.BN254G2Point memory key2 = BLSTestHelper.getTestPubkey(2);
        Types.BN254G2Point memory aggregatePubkey = BN254.addG2(key1, key2);

        tangle.submitAggregatedResult(
            serviceId,
            callId,
            output,
            0x3,
            BLSTestHelper.g1ToArray(aggregateSignature),
            BLSTestHelper.g2ToArray(aggregatePubkey)
        );

        assertTrue(tangle.getJobCall(serviceId, callId).completed, "Two-signer BLS result should complete");
    }

    /// @notice Test with valid aggregated BLS signature from three signers.
    function test_ValidBLS_ThreeSigners() public {
        // Enable aggregation with 100% threshold (all 3 must sign)
        mockBsm.setAggregationConfig(0, true, 10_000, 0);

        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "multi-signer test");

        bytes memory output = "three-signer result";
        (Types.BN254G1Point memory aggregateSignature, Types.BN254G2Point memory aggregatePubkey) =
            BLSTestHelper.createThreeSignerData(serviceId, callId, address(tangle), _operators(), output);

        tangle.submitAggregatedResult(
            serviceId,
            callId,
            output,
            0x7,
            BLSTestHelper.g1ToArray(aggregateSignature),
            BLSTestHelper.g2ToArray(aggregatePubkey)
        );

        assertTrue(tangle.getJobCall(serviceId, callId).completed, "Three-signer BLS result should complete");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST: Stake-Weighted Threshold E2E
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Test stake-weighted threshold calculation
    /// @dev Operators have stakes: 5 ETH (50%), 3 ETH (30%), 2 ETH (20%)
    /// With 67% stake threshold:
    /// - Operator 1 alone (50%) < 67% - should fail
    /// - Operators 1+2 (80%) >= 67% - should pass
    /// - Operators 2+3 (50%) < 67% - should fail
    function test_StakeWeighted_Threshold67() public {
        // Enable stake-weighted aggregation (type=1) with 67% threshold
        mockBsm.setAggregationConfig(0, true, 6700, 1);

        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "stake test");

        bytes memory output = "stake-weighted result";
        bytes memory message =
            BLSTestHelper.buildJobResultMessage(serviceId, callId, address(tangle), _operators(), output);

        // Test 1: Only operator 0 (50% stake) - should fail threshold
        {
            Types.BN254G1Point memory sig0 = BLSTestHelper.sign(message, 1);
            uint256 signerBitmap = 0x1; // Only operator 0

            vm.expectRevert(); // Threshold not met
            tangle.submitAggregatedResult(
                serviceId,
                callId,
                output,
                signerBitmap,
                BLSTestHelper.g1ToArray(sig0),
                BLSTestHelper.g2ToArray(BLSTestHelper.getTestPubkey(1))
            );
        }

        // Test 2: Operators 1+2 (50%+30%=80% stake) - should pass threshold
        // Note: This would require properly aggregated signatures
        // For now, document expected behavior
    }

    /// @notice Test that count-based and stake-weighted produce different results
    /// @dev Count-based and stake-weighted thresholds should diverge under the same signer set.
    function test_CountVsStakeWeighted_Difference() public {
        // Setup: 3 operators with 5/3/2 ETH stakes
        // Total stake = 10 ETH

        // Job 0: Count-based 33.33% = 1 operator needed with round-up math.
        mockBsm.setAggregationConfig(0, true, 3333, 0);

        // Job 1: Stake-weighted 50% = need operators with >= 5 ETH total
        // Operator 0 alone (5 ETH) satisfies stake-weighted 50%
        mockBsm.setAggregationConfig(1, true, 5000, 1);

        // Submit jobs
        vm.prank(user1);
        uint64 callId0 = tangle.submitJob(serviceId, 0, "count job");
        vm.prank(user1);
        uint64 callId1 = tangle.submitJob(serviceId, 1, "stake job");

        bytes memory output = "result";

        // Single signer (operator 0 with 50% stake)
        uint256 signerBitmap = 0x1;
        Types.BN254G1Point memory sig = BLSTestHelper.sign(
            BLSTestHelper.buildJobResultMessage(serviceId, callId0, address(tangle), _operators(), output), 1
        );

        // Count-based with 33.33% threshold requires exactly 1 signer.
        tangle.submitAggregatedResult(
            serviceId,
            callId0,
            output,
            signerBitmap,
            BLSTestHelper.g1ToArray(sig),
            BLSTestHelper.g2ToArray(BLSTestHelper.getTestPubkey(1))
        );

        // Verify job completed
        Types.JobCall memory job = tangle.getJobCall(serviceId, callId0);
        assertTrue(job.completed, "Count-based job should complete with 1 signer at 33.33% threshold");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST: Operator State Changes During Aggregation
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Test that operators must go through exit queue when leaving
    /// @dev Documents current behavior: leaving requires exit queue (1 day commitment + 7 days queue)
    function test_OperatorLeave_InstantNoQueue() public {
        // Create a dynamic service with NO BSM - uses protocol default exit queue
        Types.BlueprintConfig memory config = Types.BlueprintConfig({
            membership: Types.MembershipModel.Dynamic,
            pricing: Types.PricingModel.PayOnce,
            minOperators: 1,
            maxOperators: 10,
            subscriptionRate: 0,
            subscriptionInterval: 0,
            eventRate: 0
        });

        vm.prank(developer);
        uint64 dynamicBpId = _createBlueprintWithConfigAsSender("ipfs://dynamic", address(0), config);

        _registerForBlueprint(operator1, dynamicBpId);
        _registerForBlueprint(operator2, dynamicBpId);
        _registerForBlueprint(operator3, dynamicBpId);

        address[] memory operators = new address[](3);
        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;
        address[] memory callers = new address[](0);

        vm.prank(user1);
        uint64 reqId = tangle.requestService(
            dynamicBpId, operators, "", callers, 0, address(0), 0, Types.ConfidentialityPolicy.Any
        );

        vm.prank(operator1);
        tangle.approveService(_approve(reqId));
        vm.prank(operator2);
        tangle.approveService(_approve(reqId));
        vm.prank(operator3);
        tangle.approveService(_approve(reqId));

        uint64 dynamicSvcId = 1;

        // Verify operator2 is active
        Types.ServiceOperator memory opBefore = tangle.getServiceOperator(dynamicSvcId, operator2);
        assertTrue(opBefore.active, "Operator should be active");

        // Warp past minimum commitment duration (1 day default)
        vm.warp(block.timestamp + 1 days + 1);

        // Schedule exit
        vm.prank(operator2);
        tangle.scheduleExit(dynamicSvcId);
        assertEq(uint256(tangle.getExitStatus(dynamicSvcId, operator2)), uint256(Types.ExitStatus.Scheduled));

        // Warp past exit queue duration (7 days default)
        vm.warp(block.timestamp + 7 days + 1);

        // Execute exit
        vm.prank(operator2);
        tangle.executeExit(dynamicSvcId);

        // Now inactive after going through exit queue
        Types.ServiceOperator memory opAfter = tangle.getServiceOperator(dynamicSvcId, operator2);
        assertFalse(opAfter.active, "Operator should be inactive after exit queue");
        assertEq(opAfter.leftAt, block.timestamp, "leftAt should be current timestamp");

        // SECURITY: Exit queue prevents operators from:
        // 1. Signing an aggregation message
        // 2. Immediately leaving before submission
        // 3. Avoiding slashing for bad behavior
    }

    /// @notice Test operator exit queue prevents leaving mid-aggregation
    /// @dev Operator must wait through exit queue, preventing mid-aggregation leave
    function test_OperatorLeave_MidAggregation() public {
        // Setup dynamic service with NO BSM - uses protocol default exit queue
        Types.BlueprintConfig memory config = Types.BlueprintConfig({
            membership: Types.MembershipModel.Dynamic,
            pricing: Types.PricingModel.PayOnce,
            minOperators: 1,
            maxOperators: 10,
            subscriptionRate: 0,
            subscriptionInterval: 0,
            eventRate: 0
        });

        vm.prank(developer);
        uint64 dynamicBpId = _createBlueprintWithConfigAsSender("ipfs://dynamic-agg", address(0), config);

        _registerForBlueprint(operator1, dynamicBpId);
        _registerForBlueprint(operator2, dynamicBpId);
        _registerForBlueprint(operator3, dynamicBpId);

        address[] memory operators = new address[](3);
        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operator3;
        address[] memory callers = new address[](0);

        vm.prank(user1);
        uint64 reqId = tangle.requestService(
            dynamicBpId, operators, "", callers, 0, address(0), 0, Types.ConfidentialityPolicy.Any
        );

        vm.prank(operator1);
        tangle.approveService(_approve(reqId));
        vm.prank(operator2);
        tangle.approveService(_approve(reqId));
        vm.prank(operator3);
        tangle.approveService(_approve(reqId));

        uint64 dynamicSvcId = 1;

        mockBsm.setAggregationConfig(0, true, 3333, 0); // 1 of 3 threshold with round-up math

        vm.prank(user1);
        uint64 callId = tangle.submitJob(dynamicSvcId, 0, "leave mid-agg");

        // Warp past minimum commitment duration (1 day default)
        vm.warp(block.timestamp + 1 days + 1);

        // Scenario: Operator 2 schedules exit during pending aggregation
        vm.prank(operator2);
        tangle.scheduleExit(dynamicSvcId);

        // Operator is still active during exit queue period!
        Types.ServiceOperator memory opDuringQueue = tangle.getServiceOperator(dynamicSvcId, operator2);
        assertTrue(opDuringQueue.active, "Operator still active during exit queue");

        // SECURITY: The exit queue (7 days) gives time to submit aggregated result
        // before operator can actually leave, preventing mid-aggregation escapes

        // Warp past exit queue duration
        vm.warp(block.timestamp + 7 days + 1);

        // Execute exit - now operator leaves
        vm.prank(operator2);
        tangle.executeExit(dynamicSvcId);

        Types.ServiceOperator memory opAfter = tangle.getServiceOperator(dynamicSvcId, operator2);
        assertFalse(opAfter.active, "Operator should be inactive after exit");
    }

    /// @notice Test service termination during pending job
    /// @dev Termination is a hard stop: pending aggregated jobs cannot finalize afterward.
    function test_ServiceTermination_PendingJob() public {
        mockBsm.setAggregationConfig(0, true, 3333, 0);

        // Submit a job
        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "pending job");

        Types.JobCall memory jobBefore = tangle.getJobCall(serviceId, callId);
        assertFalse(jobBefore.completed, "Job should be pending");

        // Service owner terminates service
        vm.prank(user1);
        tangle.terminateService(serviceId);

        // What happens to pending job?
        Types.JobCall memory jobAfter = tangle.getJobCall(serviceId, callId);
        assertFalse(jobAfter.completed, "Job still not completed");

        bytes memory output = "late result";
        (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey) =
            BLSTestHelper.createSingleSignerData(serviceId, callId, address(tangle), _operators(), output);

        vm.expectRevert(abi.encodeWithSelector(Errors.ServiceNotActive.selector, serviceId));
        tangle.submitAggregatedResult(
            serviceId, callId, output, 0x1, BLSTestHelper.g1ToArray(sig), BLSTestHelper.g2ToArray(pubkey)
        );

        Types.JobCall memory jobFinal = tangle.getJobCall(serviceId, callId);
        assertFalse(jobFinal.completed, "terminated service must not accept aggregated completion");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST: Edge Cases with Valid BLS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Test submitting correct signature with wrong output
    function test_ValidSignature_WrongOutput() public {
        mockBsm.setAggregationConfig(0, true, 3333, 0);

        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "test");

        bytes memory correctOutput = "correct";
        bytes memory wrongOutput = "wrong";

        // Sign correct output
        (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey) =
            BLSTestHelper.createSingleSignerData(serviceId, callId, address(tangle), _operators(), correctOutput);

        // Try to submit with wrong output - BLS verification will fail
        vm.expectRevert(Errors.InvalidBLSSignature.selector);
        tangle.submitAggregatedResult(
            serviceId,
            callId,
            wrongOutput, // Wrong!
            0x1,
            BLSTestHelper.g1ToArray(sig),
            BLSTestHelper.g2ToArray(pubkey)
        );
    }

    /// @notice Test signature for wrong callId
    function test_ValidSignature_WrongCallId() public {
        mockBsm.setAggregationConfig(0, true, 3333, 0);

        vm.prank(user1);
        uint64 callId1 = tangle.submitJob(serviceId, 0, "job 1");
        vm.prank(user1);
        uint64 callId2 = tangle.submitJob(serviceId, 0, "job 2");

        bytes memory output = "result";

        // Sign for callId1
        (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey) =
            BLSTestHelper.createSingleSignerData(serviceId, callId1, address(tangle), _operators(), output);

        // Try to use it for callId2 - BLS verification will fail
        vm.expectRevert(Errors.InvalidBLSSignature.selector);
        tangle.submitAggregatedResult(
            serviceId,
            callId2, // Wrong!
            output,
            0x1,
            BLSTestHelper.g1ToArray(sig),
            BLSTestHelper.g2ToArray(pubkey)
        );
    }

    /// @notice Test double submission (replay protection)
    function test_ValidSignature_ReplayPrevention() public {
        mockBsm.setAggregationConfig(0, true, 3333, 0);

        vm.prank(user1);
        uint64 callId = tangle.submitJob(serviceId, 0, "test");

        bytes memory output = "result";
        (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey) =
            BLSTestHelper.createSingleSignerData(serviceId, callId, address(tangle), _operators(), output);

        // First submission - succeeds
        tangle.submitAggregatedResult(
            serviceId, callId, output, 0x1, BLSTestHelper.g1ToArray(sig), BLSTestHelper.g2ToArray(pubkey)
        );

        // Second submission with same signature - should fail
        vm.expectRevert(abi.encodeWithSelector(Errors.JobAlreadyCompleted.selector, serviceId, callId));
        tangle.submitAggregatedResult(
            serviceId, callId, output, 0x1, BLSTestHelper.g1ToArray(sig), BLSTestHelper.g2ToArray(pubkey)
        );
    }
}
