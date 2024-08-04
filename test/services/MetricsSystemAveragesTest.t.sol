// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "core/services/MetricsSystem.sol";
import "core/services/metrics/Averages.sol";

contract MetricsSystemAveragesTest is Test {
    MetricsSystem public metricsSystem;
    SimpleMovingAverage public sma;
    WeightedMovingAverage public wma;
    ExponentialMovingAverage public ema;

    bytes32 public constant BLUEPRINT_ID = keccak256("TestBlueprint");
    address public constant OPERATOR = address(0x1234);

    function setUp() public {
        metricsSystem = new MetricsSystem();
        sma = new SimpleMovingAverage(3); // 3-period SMA
        uint256[] memory weights = new uint256[](3);
        weights[0] = 1;
        weights[1] = 2;
        weights[2] = 3;
        wma = new WeightedMovingAverage(weights);
        ema = new ExponentialMovingAverage(500_000_000_000_000_000); // alpha = 0.5
    }

    function testSimpleMovingAverageSmall() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 2);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "SMA", sourceIndices, address(sma));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 200);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 300);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 400);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        assertEq(derivedValue.value, 300); // Average of 200, 300, 400
    }

    function testSimpleMovingAverageBig() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 18);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "SMA", sourceIndices, address(sma));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 200e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 300e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 400e18);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        assertEq(derivedValue.value, 300e18); // Average of 200e18, 300e18, 400e18
    }

    function testWeightedMovingAverageSmall() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 18);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "WMA", sourceIndices, address(wma));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 200e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 300e18);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        // Expected WMA: (100e18*1 + 200e18*2 + 300e18*3) / (1+2+3) = 233.33e18
        assertApproxEqAbs(derivedValue.value, 233_333_333_333_333_333_333, 1e15);
    }

    function testWeightedMovingAverageBig() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 18);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "WMA", sourceIndices, address(wma));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 200e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 300e18);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        // Expected WMA: (100e18*1 + 200e18*2 + 300e18*3) / (1+2+3) = 233.33e18
        assertApproxEqAbs(derivedValue.value, 233_333_333_333_333_333_333, 1e15);
    }

    function testExponentialMovingAverage() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 18);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "EMA", sourceIndices, address(ema));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 200e18);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 300e18);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);

        // Expected EMA after [100, 200, 300] with alpha 0.5 is 225
        uint256 expectedEMA = 225e18;
        assertApproxEqAbs(derivedValue.value, expectedEMA, 1e15); // Allow for small rounding errors
    }
}
