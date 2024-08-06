// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "core/services/MetricsSystem.sol";
import "core/services/metrics/Averages.sol";

contract MetricsSystemAveragesTest is Test {
    MetricsSystem public metricsSystem;
    ExponentialMovingAverage public ema;
    ExponentialMovingAverage public emaFastResponse;
    ExponentialMovingAverage public emaSlowResponse;

    bytes32 public constant BLUEPRINT_ID = keccak256("TestBlueprint");
    address public constant OPERATOR = address(0x1234);

    function setUp() public {
        metricsSystem = new MetricsSystem();
        ema = new ExponentialMovingAverage(500_000_000_000_000_000); // alpha = 0.5
        emaFastResponse = new ExponentialMovingAverage(800_000_000_000_000_000); // alpha = 0.8
        emaSlowResponse = new ExponentialMovingAverage(200_000_000_000_000_000); // alpha = 0.2
    }

    function testBasicEMA() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 100e18;
        values[1] = 200e18;
        values[2] = 300e18;
        runEMATest(ema, values, 225e18, "Basic EMA");
    }

    function testFastResponseEMA() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 100e18;
        values[1] = 200e18;
        values[2] = 300e18;
        runEMATest(emaFastResponse, values, 276e18, "Fast Response EMA");
    }

    function testEMAWithConstantValues() public {
        uint256[] memory values = new uint256[](4);
        values[0] = 100e18;
        values[1] = 100e18;
        values[2] = 100e18;
        values[3] = 100e18;
        runEMATest(ema, values, 100e18, "EMA with Constant Values");
    }

    function testEMAWithDecreasingValues() public {
        uint256[] memory values = new uint256[](5);
        values[0] = 500e18;
        values[1] = 400e18;
        values[2] = 300e18;
        values[3] = 200e18;
        values[4] = 100e18;
        runEMATest(ema, values, 193.75e18, "EMA with Decreasing Values");
    }

    function testEMAWithIncreasingValues() public {
        uint256[] memory values = new uint256[](5);
        values[0] = 100e18;
        values[1] = 200e18;
        values[2] = 300e18;
        values[3] = 400e18;
        values[4] = 500e18;
        runEMATest(ema, values, 406.25e18, "EMA with Increasing Values");
    }

    function testEMAWithVolatileValues() public {
        uint256[] memory values = new uint256[](5);
        values[0] = 100e18;
        values[1] = 500e18;
        values[2] = 50e18;
        values[3] = 400e18;
        values[4] = 200e18;
        runEMATest(ema, values, 243.75e18, "EMA with Volatile Values");
    }

    function testSlowResponseEMA() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 100e18;
        values[1] = 200e18;
        values[2] = 300e18;
        runEMATest(emaSlowResponse, values, 156e18, "Slow Response EMA");
    }

    function testEMAWithSingleValue() public {
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        runEMATest(ema, values, 100e18, "EMA with Single Value");
    }

    function testEMAWithLargeValues() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1e40;
        values[1] = 2e40;
        values[2] = 3e40;
        runEMATest(ema, values, 2.25e40, "EMA with Large Values");
    }

    function testEMAWithSmallValues() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1e6;
        values[1] = 2e6;
        values[2] = 3e6;
        runEMATest(ema, values, 2.25e6, "EMA with Small Values");
    }

    function runEMATest(
        ExponentialMovingAverage emaContract,
        uint256[] memory values,
        uint256 expectedEMA,
        string memory testName
    )
        internal
    {
        metricsSystem.addMetric(BLUEPRINT_ID, testName, 18);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, testName, sourceIndices, address(emaContract));

        vm.startPrank(OPERATOR);
        for (uint256 i = 0; i < values.length; i++) {
            metricsSystem.reportMetric(BLUEPRINT_ID, 0, values[i]);
        }
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);

        assertApproxEqRel(derivedValue.value, expectedEMA, 1e15, string(abi.encodePacked("EMA test failed: ", testName))); // 0.1%
            // tolerance
    }
}
