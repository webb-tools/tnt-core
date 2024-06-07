// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { Factory } from "core/lst/factory/Factory.sol";
import {
    LivepeerAdapter,
    LPT,
    LIVEPEER_BONDING,
    LIVEPEER_ROUNDS,
    UNI_POOL,
    TWAP_INTERVAL,
    WETH
} from "core/lst/adapters/LivepeerAdapter.sol";
import { Tenderizer, TenderizerEvents } from "core/lst/tenderizer/Tenderizer.sol";
import { Unlocks, Metadata } from "core/lst/unlocks/Unlocks.sol";
import { TWAP } from "core/lst/utils/TWAP.sol";
import { ILivepeerBondingManager, ILivepeerRoundsManager } from "core/lst/adapters/interfaces/ILivepeer.sol";
import { ERC721Receiver } from "core/lst/utils/ERC721Receiver.sol";
import { IQuoter } from "core/lst/adapters/interfaces/IUniswap_Quoter.sol";
import { TenderizerFixture, tenderizerFixture } from "./Fixture.sol";

ILivepeerBonding constant BONDING = ILivepeerBonding(address(LIVEPEER_BONDING));
ILivepeerRounds constant ROUNDS = ILivepeerRounds(address(LIVEPEER_ROUNDS));
address constant MINTER = 0xc20DE37170B45774e6CD3d2304017fc962f27252;
address constant TICKET_BROKER = 0xa8bB618B1520E284046F3dFc448851A1Ff26e41B;

address constant UNI_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

address constant ORCHESTRATOR_1 = 0xf4e8Ef0763BCB2B1aF693F5970a00050a6aC7E1B;

uint256 constant roundLength = 6377; // round length in blocks
uint256 constant unlockRounds = 7; // unlock time in rounds

interface IMinter {
    function depositETH() external payable returns (bool);
    function currentMintableTokens() external view returns (uint256);
}

interface ILivepeerBonding is ILivepeerBondingManager {
    function updateTranscoderWithFees(address transcoder, uint256 amount, uint256 round) external;

    function getTranscoder(address _transcoder)
        external
        view
        returns (
            uint256 lastRewardRound,
            uint256 rewardCut,
            uint256 feeShare,
            uint256 lastActiveStakeUpdateRound,
            uint256 activationRound,
            uint256 deactivationRound,
            uint256 activeCumulativeRewards,
            uint256 cumulativeRewards,
            uint256 cumulativeFees,
            uint256 lastFeeRound
        );

    function transcoderTotalStake(address _transcoder) external view returns (uint256);

    function currentRoundTotalActiveStake() external view returns (uint256);

    function reward() external;

    function getTranscoderEarningsPoolForRound(
        address _transcoder,
        uint256 _round
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256);
}

interface ILivepeerRounds is ILivepeerRoundsManager {
    function initializeRound() external;
}

contract LivepeerForkTest is Test, TenderizerEvents, ERC721Receiver {
    TenderizerFixture fixture;
    LivepeerAdapter adapter;

    event NewTenderizer(address indexed asset, address indexed validator, address tenderizer);

    function mintLPT(address account, uint256 amount) public {
        vm.prank(MINTER);
        MockERC20(address(LPT)).mint(account, amount);
    }

    function setUp() public {
        bytes32 salt = bytes32(uint256(1));
        vm.createSelectFork(vm.envString("ARBITRUM_RPC"));
        fixture = tenderizerFixture();
        adapter = new LivepeerAdapter{ salt: salt }();
        fixture.registry.registerAdapter(address(LPT), address(adapter));
    }

    function test_registry_AdapterRegistered() public {
        assertEq(fixture.registry.adapter(address(LPT)), address(adapter), "adapter not registered");
    }

    function test_adapter_unlockTime() public {
        assertEq(adapter.unlockTime(), roundLength * unlockRounds, "unlock time incorrect");
    }

    function test_adapter_currentTime() public {
        assertEq(adapter.currentTime(), block.number, "current time incorrect");
    }

    function test_adapter_isValidator() public {
        assertTrue(adapter.isValidator(ORCHESTRATOR_1), "isValidator true incorrect");
        assertFalse(adapter.isValidator(makeAddr("NOT_ORCHESTRATOR")), "isValidator false incorrect");
    }

    function test_adapter_previewDeposit() public {
        assertEq(adapter.previewDeposit(ORCHESTRATOR_1, 10 ether), 10 ether, "previewDeposit incorrect");
    }

    function test_factory_newTenderizer() public {
        // Revert with inactive orchestrator
        address inactiveOrchestrator = makeAddr("INACTIVE_ORCHESTRATOR");
        vm.expectRevert(abi.encodeWithSelector(Factory.NotValidator.selector, (inactiveOrchestrator)));
        fixture.factory.newTenderizer(address(LPT), inactiveOrchestrator);

        // Deploy tenderizer
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: false });
        emit NewTenderizer(address(LPT), ORCHESTRATOR_1, address(0x0));
        fixture.factory.newTenderizer(address(LPT), ORCHESTRATOR_1);
    }

    function test_deposit() public {
        uint256 depositAmount = 10 ether;

        // Deploy tenderizer
        Tenderizer tenderizer = Tenderizer(payable(fixture.factory.newTenderizer(address(LPT), ORCHESTRATOR_1)));

        uint256 currentStake = BONDING.pendingStake(address(this), type(uint256).max);

        // Deposit
        mintLPT(address(this), depositAmount);
        LPT.approve(address(tenderizer), depositAmount);

        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit Deposit(address(this), address(this), depositAmount, depositAmount);
        tenderizer.deposit(address(this), depositAmount);

        (uint256 bondedAmount,,,,,,) = BONDING.getDelegator(address(tenderizer));

        assertEq(tenderizer.totalSupply(), depositAmount, "total supply");
        assertEq(tenderizer.balanceOf(address(this)), depositAmount, "balance of");
        assertEq(bondedAmount, currentStake + depositAmount, "Bonded amount");
        assertEq(BONDING.pendingStake(address(tenderizer), type(uint256).max), currentStake + depositAmount, "pending stake");
    }

    function test_unstake_withdraw() public {
        uint256 depositAmount = 10 ether;
        uint256 unstakeAmount = 5 ether;
        Tenderizer tenderizer = Tenderizer(payable(fixture.factory.newTenderizer(address(LPT), ORCHESTRATOR_1)));
        mintLPT(address(this), depositAmount);
        LPT.approve(address(tenderizer), depositAmount);
        tenderizer.deposit(address(this), depositAmount);

        // Livepeer only allows unbonding from when the next round starts
        // That's when added stake becomes active
        // So we have to roll `roundLength` and initialize the round
        // (roll to exact round start)
        uint256 currentRoundStartBlock = ROUNDS.currentRoundStartBlock();
        vm.roll(currentRoundStartBlock + roundLength);
        ROUNDS.initializeRound();

        vm.expectEmit();
        emit Unlock(address(this), unstakeAmount, 0);
        uint256 unlockID = tenderizer.unlock(unstakeAmount);
        (uint256 bondedAmount,,,,,,) = BONDING.getDelegator(address(tenderizer));
        assertEq(bondedAmount, depositAmount - unstakeAmount, "Bonded amount");
        assertEq(BONDING.pendingStake(address(tenderizer), type(uint256).max), depositAmount - unstakeAmount, "pending stake");

        {
            (uint256 amount,) = BONDING.getDelegatorUnbondingLock(address(tenderizer), unlockID);
            assertEq(amount, unstakeAmount, "unstake amount");
        }

        assertEq(unlockID, 0, "unlock ID");
        currentRoundStartBlock = ROUNDS.currentRoundStartBlock();
        uint256 blocksRemainingInCurrentRound = roundLength - (block.number - currentRoundStartBlock);

        assertEq(
            tenderizer.unlockMaturity(unlockID),
            block.number + roundLength * (unlockRounds - 1) + blocksRemainingInCurrentRound,
            "unlock maturity"
        );

        uint256 tokenId = uint256(bytes32(abi.encodePacked(address(tenderizer), unlockID)));
        Metadata memory metadata = fixture.unlocks.getMetadata(tokenId);

        assertEq(metadata.amount, unstakeAmount, "metadata amount");
        assertEq(metadata.progress, 0, "metadata progress");
        assertEq(
            metadata.maturity, block.number + roundLength * (unlockRounds - 1) + blocksRemainingInCurrentRound, "metadata maturity"
        );
        assertEq(metadata.unlockId, unlockID, "metadata unlock ID");
        assertEq(metadata.validator, ORCHESTRATOR_1, "metadata validator");

        // Roll to 50% unlock progress
        vm.roll(currentRoundStartBlock + roundLength * (unlockRounds / 2) + roundLength / 2);
        ROUNDS.initializeRound();
        metadata = fixture.unlocks.getMetadata(tokenId);
        // rounding error
        assertEq(metadata.progress, 49, "metadata progress 50%");

        // Roll to 100% progress and withdraw
        uint256 lptBalBeforeWithdraw = LPT.balanceOf(address(this));
        vm.roll(block.number + unlockRounds * roundLength);
        ROUNDS.initializeRound();

        vm.expectEmit();
        emit Withdraw(address(this), unstakeAmount, unlockID);
        uint256 withdrawn = tenderizer.withdraw(address(this), unlockID);

        assertEq(withdrawn, unstakeAmount);
        // Check Livepeer's unbonding lock is deleted
        {
            (uint256 amount, uint256 withdrawRound) = BONDING.getDelegatorUnbondingLock(address(tenderizer), unlockID);
            assertEq(amount, 0, "unstake amount zero");
            assertEq(withdrawRound, 0, "withdraw round zero");
        }
        // Check Tenderize Unlock is deleted
        vm.expectRevert("NOT_MINTED");
        fixture.unlocks.ownerOf(tokenId);
        // Check LPT balance
        assertEq(LPT.balanceOf(address(this)), lptBalBeforeWithdraw + unstakeAmount, "LPT balance");
    }

    function test_rebase() public {
        uint256 depositAmount = 100_000 ether;
        Tenderizer tenderizer = Tenderizer(payable(fixture.factory.newTenderizer(address(LPT), ORCHESTRATOR_1)));
        mintLPT(address(this), depositAmount);
        LPT.approve(address(tenderizer), depositAmount);
        tenderizer.deposit(address(this), depositAmount);

        // Initialize next round to make stake active
        uint256 currentRoundStartBlock = ROUNDS.currentRoundStartBlock();
        vm.roll(currentRoundStartBlock + roundLength);
        ROUNDS.initializeRound();

        // Add fees - check eth fees only rebase
        uint256 fees = 0.1 ether + 1;
        updateTenderizerFees(address(tenderizer), fees);
        // account for rounding error of 1 wei
        fees = BONDING.pendingFees(address(tenderizer), 0);
        assertEq(fees, 0.1 ether, "pending fees");
        uint256 quotedOut = IQuoter(UNI_QUOTER).quoteExactInputSingle(address(WETH), address(LPT), 3000, fees, 0);
        // vm.expectEmit();
        // emit Rebase(100_000 ether, 100_000 ether + quotedOut);
        currentRoundStartBlock = ROUNDS.currentRoundStartBlock();
        vm.roll(currentRoundStartBlock + roundLength);
        ROUNDS.initializeRound();
        Tenderizer(tenderizer).rebase();
        assertEq(tenderizer.totalSupply(), depositAmount + quotedOut, "total supply fees only");
        (uint256 bondedAmount,,,,,,) = BONDING.getDelegator(address(tenderizer));
        assertEq(bondedAmount, depositAmount + quotedOut, "Bonded amount fees only");

        // Initialize next round
        // Check LPT rewards only rebase
        currentRoundStartBlock = ROUNDS.currentRoundStartBlock();
        vm.roll(currentRoundStartBlock + roundLength);
        ROUNDS.initializeRound();

        (uint256 lastRewardRound,,,,,,,,,) = BONDING.getTranscoder(ORCHESTRATOR_1);
        (,,, uint256 crfBefore,) = BONDING.getTranscoderEarningsPoolForRound(ORCHESTRATOR_1, lastRewardRound);

        // call reward
        vm.prank(ORCHESTRATOR_1);
        BONDING.reward();
        Tenderizer(tenderizer).rebase();
        uint256 round = ROUNDS.currentRound();
        (,,, uint256 crfAfter,) = BONDING.getTranscoderEarningsPoolForRound(ORCHESTRATOR_1, round);
        uint256 expStake = bondedAmount * crfAfter / crfBefore;
        assertEq(tenderizer.totalSupply(), expStake, "total supply rewards only");

        // Initialize next round
        currentRoundStartBlock = ROUNDS.currentRoundStartBlock();
        vm.roll(currentRoundStartBlock + roundLength);
        ROUNDS.initializeRound();
        crfBefore = crfAfter;

        // Add Eth Fees
        fees = 0.1 ether + 1;
        updateTenderizerFees(address(tenderizer), fees);
        fees = BONDING.pendingFees(address(tenderizer), 0);
        quotedOut = IQuoter(UNI_QUOTER).quoteExactInputSingle(address(WETH), address(LPT), 3000, fees, 0);

        // Call reward
        vm.prank(ORCHESTRATOR_1);
        BONDING.reward();
        round = ROUNDS.currentRound();
        (,,, crfAfter,) = BONDING.getTranscoderEarningsPoolForRound(ORCHESTRATOR_1, round);
        expStake = expStake * (crfAfter * 1e27 / crfBefore) / 1e27 + quotedOut - 1;
        Tenderizer(tenderizer).rebase();
        assertEq(
            tenderizer.totalSupply(), BONDING.pendingStake(address(tenderizer), type(uint256).max), "total supply vs pending stake"
        );
        assertEq(tenderizer.totalSupply(), expStake, "total supply rewards & fees");
    }

    function updateTenderizerFees(address tenderizer, uint256 amount) internal {
        address orchestrator = Tenderizer(payable(tenderizer)).validator();
        uint256 round = ROUNDS.currentRound();

        // get tenderizer stake share of delegation pool
        // and orchestrator's fee cut
        (,, uint256 feeShare,,,,,,,) = BONDING.getTranscoder(orchestrator);
        uint256 orchStake = BONDING.transcoderTotalStake(orchestrator);
        uint256 tenderizerStake = BONDING.pendingStake(tenderizer, round);

        uint256 fees = amount * (orchStake * 1e6 / feeShare) / tenderizerStake;
        vm.prank(TICKET_BROKER);
        BONDING.updateTranscoderWithFees(orchestrator, fees, round);
        vm.prank(MINTER);
        IMinter(MINTER).depositETH{ value: fees }();
    }
}
