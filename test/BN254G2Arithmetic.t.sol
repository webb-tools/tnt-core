// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { BN254 } from "../src/libraries/BN254.sol";
import { Types } from "../src/libraries/Types.sol";

/// Exposes the internal G2 operations for fixed-vector regression tests.
contract BN254G2ArithmeticHarness {
    function add(
        Types.BN254G2Point memory a,
        Types.BN254G2Point memory b
    )
        external
        pure
        returns (Types.BN254G2Point memory)
    {
        return BN254.addG2(a, b);
    }

    function double(Types.BN254G2Point memory point) external pure returns (Types.BN254G2Point memory) {
        return BN254.doubleG2(point);
    }
}

/// Arkworks vectors use `Fq2(c0, c1) = real + imaginary * i`.
/// EIP-197 calldata stores the same points as [imaginary, real].
contract BN254G2ArithmeticTest is Test {
    BN254G2ArithmeticHarness internal harness;

    function setUp() public {
        harness = new BN254G2ArithmeticHarness();
    }

    function test_double_generator_matches_arkworks() public view {
        Types.BN254G2Point memory result = harness.double(_generator());
        _assertTwoG2(result);
    }

    function test_add_generator_and_double_matches_arkworks_threeG2() public view {
        Types.BN254G2Point memory result = harness.add(_generator(), _twoG2());
        _assertThreeG2(result);
    }

    function test_add_two_operator_keys_matches_arkworks_twoSignerAggregate() public view {
        Types.BN254G2Point memory result = harness.add(_generator(), _generator());
        _assertTwoG2(result);
    }

    function test_add_three_operator_keys_matches_arkworks_sixG2() public view {
        Types.BN254G2Point memory result = harness.add(_threeG2(), _threeG2());
        _assertSixG2(result);
    }

    function _generator() internal pure returns (Types.BN254G2Point memory) {
        return Types.BN254G2Point(
            [
                11_559_732_032_986_387_107_991_004_021_392_285_783_925_812_861_821_192_530_917_403_151_452_391_805_634,
                10_857_046_999_023_057_135_944_570_762_232_829_481_370_756_359_578_518_086_990_519_993_285_655_852_781
            ],
            [
                4_082_367_875_863_433_681_332_203_403_145_435_568_316_851_327_593_401_208_105_741_076_214_120_093_531,
                8_495_653_923_123_431_417_604_973_247_489_272_438_418_190_587_263_600_148_770_280_649_306_958_101_930
            ]
        );
    }

    function _twoG2() internal pure returns (Types.BN254G2Point memory) {
        return Types.BN254G2Point(
            [
                14_583_779_054_894_525_174_450_323_658_765_874_724_019_480_979_794_335_525_732_096_752_006_891_875_705,
                18_029_695_676_650_738_226_693_292_988_307_914_797_657_423_701_064_905_010_927_197_838_374_790_804_409
            ],
            [
                11_474_861_747_383_700_316_476_719_153_975_578_001_603_231_366_361_248_090_558_603_872_215_261_634_898,
                2_140_229_616_977_736_810_657_479_771_656_733_941_598_412_651_537_078_903_776_637_920_509_952_744_750
            ]
        );
    }

    function _threeG2() internal pure returns (Types.BN254G2Point memory) {
        return Types.BN254G2Point(
            [
                7_273_165_102_799_931_111_715_871_471_550_377_909_735_733_521_218_303_035_754_523_677_688_038_059_653,
                2_725_019_753_478_801_796_453_339_367_788_033_689_375_851_816_420_509_565_303_521_482_350_756_874_229
            ],
            [
                957_874_124_722_006_818_841_961_785_324_909_313_781_880_061_366_718_538_693_995_380_805_373_202_866,
                2_512_659_008_974_376_214_222_774_206_987_427_162_027_254_181_373_325_676_825_515_531_566_330_959_255
            ]
        );
    }

    function _sixG2() internal pure returns (Types.BN254G2Point memory) {
        return Types.BN254G2Point(
            [
                12_345_624_066_896_925_082_600_651_626_583_520_268_054_356_403_305_150_512_393_106_955_803_260_718,
                10_191_129_150_170_504_690_859_455_063_377_241_352_678_147_020_731_325_090_942_140_630_855_943_625_622
            ],
            [
                13_790_151_551_682_513_054_696_583_104_432_356_791_070_435_696_840_691_503_641_536_676_885_931_241_944,
                16_727_484_375_212_017_249_697_795_760_885_267_597_317_766_655_549_468_217_180_521_378_213_906_474_374
            ]
        );
    }

    function _assertTwoG2(Types.BN254G2Point memory point) internal pure {
        assertEq(
            point.x[0],
            14_583_779_054_894_525_174_450_323_658_765_874_724_019_480_979_794_335_525_732_096_752_006_891_875_705,
            "2G2 x[0]"
        );
        assertEq(
            point.x[1],
            18_029_695_676_650_738_226_693_292_988_307_914_797_657_423_701_064_905_010_927_197_838_374_790_804_409,
            "2G2 x[1]"
        );
        assertEq(
            point.y[0],
            11_474_861_747_383_700_316_476_719_153_975_578_001_603_231_366_361_248_090_558_603_872_215_261_634_898,
            "2G2 y[0]"
        );
        assertEq(
            point.y[1],
            2_140_229_616_977_736_810_657_479_771_656_733_941_598_412_651_537_078_903_776_637_920_509_952_744_750,
            "2G2 y[1]"
        );
    }

    function _assertThreeG2(Types.BN254G2Point memory point) internal pure {
        assertEq(
            point.x[0],
            7_273_165_102_799_931_111_715_871_471_550_377_909_735_733_521_218_303_035_754_523_677_688_038_059_653,
            "3G2 x[0]"
        );
        assertEq(
            point.x[1],
            2_725_019_753_478_801_796_453_339_367_788_033_689_375_851_816_420_509_565_303_521_482_350_756_874_229,
            "3G2 x[1]"
        );
        assertEq(
            point.y[0],
            957_874_124_722_006_818_841_961_785_324_909_313_781_880_061_366_718_538_693_995_380_805_373_202_866,
            "3G2 y[0]"
        );
        assertEq(
            point.y[1],
            2_512_659_008_974_376_214_222_774_206_987_427_162_027_254_181_373_325_676_825_515_531_566_330_959_255,
            "3G2 y[1]"
        );
    }

    function _assertSixG2(Types.BN254G2Point memory point) internal pure {
        assertEq(
            point.x[0],
            12_345_624_066_896_925_082_600_651_626_583_520_268_054_356_403_303_305_150_512_393_106_955_803_260_718,
            "6G2 x[0]"
        );
        assertEq(
            point.x[1],
            10_191_129_150_170_504_690_859_455_063_377_241_352_678_147_020_731_325_090_942_140_630_855_943_625_622,
            "6G2 x[1]"
        );
        assertEq(
            point.y[0],
            13_790_151_551_682_513_054_696_583_104_432_356_791_070_435_696_840_691_503_641_536_676_885_931_241_944,
            "6G2 y[0]"
        );
        assertEq(
            point.y[1],
            16_727_484_375_212_017_249_697_795_760_885_267_597_317_766_655_549_468_217_180_521_378_213_906_474_374,
            "6G2 y[1]"
        );
    }
}
