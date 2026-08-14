// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BN254 } from "../../src/libraries/BN254.sol";
import { Types } from "../../src/libraries/Types.sol";

/// @title BLSTestHelper
/// @notice Helper contract for generating valid BLS test data
/// @dev Uses precomputed G2 points for test private keys.
///      The vectors come from ark-bn254 0.4.0 and use EIP-197's
///      [imaginary, real] encoding at the contract boundary.
///
/// BN254 BLS scheme:
/// - Private key `sk` is a scalar in F_r
/// - Public key `pk = sk * G2` (G2 point)
/// - Signature `sig = sk * H(message)` (G1 point)
/// - Verify: e(sig, G2) = e(H(message), pk)
///
/// Test keys (precomputed with ark-bn254 0.4.0):
/// - sk=1: pk = G2 generator
/// - sk=2: pk = 2*G2 (precomputed below)
/// - sk=3: pk = 3*G2 (precomputed below)
library BLSTestHelper {
    // ═══════════════════════════════════════════════════════════════════════════
    // G2 GENERATOR (pk for sk=1)
    // ═══════════════════════════════════════════════════════════════════════════

    // G2 generator coordinates (same as BN254.sol)
    uint256 constant G2_X0 =
        11_559_732_032_986_387_107_991_004_021_392_285_783_925_812_861_821_192_530_917_403_151_452_391_805_634;
    uint256 constant G2_X1 =
        10_857_046_999_023_057_135_944_570_762_232_829_481_370_756_359_578_518_086_990_519_993_285_655_852_781;
    uint256 constant G2_Y0 =
        4_082_367_875_863_433_681_332_203_403_145_435_568_316_851_327_593_401_208_105_741_076_214_120_093_531;
    uint256 constant G2_Y1 =
        8_495_653_923_123_431_417_604_973_247_489_272_438_418_190_587_263_600_148_770_280_649_306_958_101_930;

    // ═══════════════════════════════════════════════════════════════════════════
    // PRECOMPUTED G2 POINTS (2*G2, 3*G2)
    // These were computed with Arkworks for the BN254 curve.
    // ═══════════════════════════════════════════════════════════════════════════

    // 2 * G2 (public key for sk=2)
    uint256 constant G2_2X_X0 =
        14_583_779_054_894_525_174_450_323_658_765_874_724_019_480_979_794_335_525_732_096_752_006_891_875_705;
    uint256 constant G2_2X_X1 =
        18_029_695_676_650_738_226_693_292_988_307_914_797_657_423_701_064_905_010_927_197_838_374_790_804_409;
    uint256 constant G2_2X_Y0 =
        11_474_861_747_383_700_316_476_719_153_975_578_001_603_231_366_361_248_090_558_603_872_215_261_634_898;
    uint256 constant G2_2X_Y1 =
        2_140_229_616_977_736_810_657_479_771_656_733_941_598_412_651_537_078_903_776_637_920_509_952_744_750;

    // 3 * G2 (public key for sk=3)
    uint256 constant G2_3X_X0 =
        7_273_165_102_799_931_111_715_871_471_550_377_909_735_733_521_218_303_035_754_523_677_688_038_059_653;
    uint256 constant G2_3X_X1 =
        2_725_019_753_478_801_796_453_339_367_788_033_689_375_851_816_420_509_565_303_521_482_350_756_874_229;
    uint256 constant G2_3X_Y0 =
        957_874_124_722_006_818_841_961_785_324_909_313_781_880_061_366_718_538_693_995_380_805_373_202_866;
    uint256 constant G2_3X_Y1 =
        2_512_659_008_974_376_214_222_774_206_987_427_162_027_254_181_373_325_676_825_515_531_566_330_959_255;

    // 6 * G2 (aggregate pubkey for sk=1+2+3)
    uint256 constant G2_6X_X0 =
        12_345_624_066_896_925_082_600_651_626_583_520_268_054_356_403_303_305_150_512_393_106_955_803_260_718;
    uint256 constant G2_6X_X1 =
        10_191_129_150_170_504_690_859_455_063_377_241_352_678_147_020_731_325_090_942_140_630_855_943_625_622;
    uint256 constant G2_6X_Y0 =
        13_790_151_551_682_513_054_696_583_104_432_356_791_070_435_696_840_691_503_641_536_676_885_931_241_944;
    uint256 constant G2_6X_Y1 =
        16_727_484_375_212_017_249_697_795_760_885_267_597_317_766_655_549_468_217_180_521_378_213_906_474_374;

    // ═══════════════════════════════════════════════════════════════════════════
    // PUBLIC KEY GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Get G2 public key for test private key index
    /// @param keyIndex 1, 2, or 3
    function getTestPubkey(uint256 keyIndex) internal pure returns (Types.BN254G2Point memory) {
        if (keyIndex == 1) {
            return Types.BN254G2Point([G2_X0, G2_X1], [G2_Y0, G2_Y1]);
        } else if (keyIndex == 2) {
            return Types.BN254G2Point([G2_2X_X0, G2_2X_X1], [G2_2X_Y0, G2_2X_Y1]);
        } else if (keyIndex == 3) {
            return Types.BN254G2Point([G2_3X_X0, G2_3X_X1], [G2_3X_Y0, G2_3X_Y1]);
        }
        revert("Invalid key index");
    }

    /// @notice Get aggregated pubkey for operators 1+2+3 (sk=6)
    function getAggregatedPubkey123() internal pure returns (Types.BN254G2Point memory) {
        return Types.BN254G2Point([G2_6X_X0, G2_6X_X1], [G2_6X_Y0, G2_6X_Y1]);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SIGNATURE GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Sign a message with test private key
    /// @dev sig = sk * H(message)
    /// @param message The message to sign
    /// @param privateKey The private key (1, 2, or 3 for tests)
    function sign(bytes memory message, uint256 privateKey) internal view returns (Types.BN254G1Point memory) {
        // Hash message to G1 point
        Types.BN254G1Point memory msgPoint = BN254.hashToG1(message);
        // Multiply by private key
        return BN254.scalarMulG1(msgPoint, privateKey);
    }

    /// @notice Create aggregated signature for multiple signers
    /// @param message The message all signers signed
    /// @param privateKeys Array of private keys
    function aggregateSignatures(
        bytes memory message,
        uint256[] memory privateKeys
    )
        internal
        view
        returns (Types.BN254G1Point memory aggSig)
    {
        require(privateKeys.length > 0, "No private keys");

        // First signature
        aggSig = sign(message, privateKeys[0]);

        // Add remaining signatures
        for (uint256 i = 1; i < privateKeys.length; i++) {
            Types.BN254G1Point memory sig = sign(message, privateKeys[i]);
            aggSig = BN254.addG1(aggSig, sig);
        }
    }

    /// @notice Build the message that operators sign for job results.
    /// @dev Message format MUST match `JobsAggregation._verifyAggregatedSignature`:
    ///        abi.encode(
    ///          "TANGLE_BLS_AGG_v1",
    ///          chainId,
    ///          tangleAddress,
    ///          serviceId,
    ///          callId,
    ///          keccak256(abi.encode(operators)),  // operator-set snapshot
    ///          keccak256(output)
    ///        )
    ///      for operator-collusion #2c — domain-separated message
    ///      bound to the operator-set snapshot so a swap-and-pop reorder
    ///      invalidates in-flight signatures.
    function buildJobResultMessage(
        uint64 serviceId,
        uint64 callId,
        address tangleAddress,
        address[] memory operators,
        bytes memory output
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(
            "TANGLE_BLS_AGG_v1",
            block.chainid,
            tangleAddress,
            serviceId,
            callId,
            keccak256(abi.encode(operators)),
            keccak256(output)
        );
    }

    /// @notice Legacy two-arg message builder retained for tests that don't go
    ///         through the actual on-chain aggregation path.
    function buildJobResultMessage(
        uint64 serviceId,
        uint64 callId,
        bytes memory output
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(serviceId, callId, keccak256(output));
    }

    /// @notice Create valid BLS data for a single signer (sk=1)
    /// @return sig The signature
    /// @return pubkey The public key (G2 generator)
    function createSingleSignerData(
        uint64 serviceId,
        uint64 callId,
        address tangleAddress,
        address[] memory operators,
        bytes memory output
    )
        internal
        view
        returns (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey)
    {
        bytes memory message = buildJobResultMessage(serviceId, callId, tangleAddress, operators, output);
        sig = sign(message, 1);
        pubkey = getTestPubkey(1);
    }

    /// @notice Legacy 3-arg overload retained for backwards-compatible tests.
    function createSingleSignerData(
        uint64 serviceId,
        uint64 callId,
        bytes memory output
    )
        internal
        view
        returns (Types.BN254G1Point memory sig, Types.BN254G2Point memory pubkey)
    {
        bytes memory message = buildJobResultMessage(serviceId, callId, output);
        sig = sign(message, 1);
        pubkey = getTestPubkey(1);
    }

    /// @notice Create valid BLS data for all 3 test signers
    function createThreeSignerData(
        uint64 serviceId,
        uint64 callId,
        address tangleAddress,
        address[] memory operators,
        bytes memory output
    )
        internal
        view
        returns (Types.BN254G1Point memory aggSig, Types.BN254G2Point memory aggPubkey)
    {
        bytes memory message = buildJobResultMessage(serviceId, callId, tangleAddress, operators, output);

        uint256[] memory privateKeys = new uint256[](3);
        privateKeys[0] = 1;
        privateKeys[1] = 2;
        privateKeys[2] = 3;

        aggSig = aggregateSignatures(message, privateKeys);
        aggPubkey = getAggregatedPubkey123();
    }

    /// @notice Convert G1 point to uint256[2] array for contract calls
    function g1ToArray(Types.BN254G1Point memory p) internal pure returns (uint256[2] memory) {
        return [p.x, p.y];
    }

    /// @notice Convert G2 point to uint256[4] array for contract calls
    function g2ToArray(Types.BN254G2Point memory p) internal pure returns (uint256[4] memory) {
        return [p.x[0], p.x[1], p.y[0], p.y[1]];
    }
}
