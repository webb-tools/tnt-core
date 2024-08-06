// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "core/services/MetricsSystem.sol";
import "core/services/metrics/IMetricComputation.sol";

contract MockComputation is IMetricComputation {
    function compute(uint256[] memory values, uint256[] memory) external pure override returns (uint256) {
        require(values.length > 0, "No values provided");
        uint256 sum = 0;
        uint256 count = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] != 0) {
                sum += values[i];
                count++;
            }
        }
        return count > 0 ? sum / count : 0;
    }
}

contract MetricsSystemTest is Test {
    MetricsSystem public metricsSystem;
    MockComputation public mockComputation;

    bytes32 public constant BLUEPRINT_ID = keccak256("TestBlueprint");
    address public constant OPERATOR = address(0x1234);

    function setUp() public {
        metricsSystem = new MetricsSystem();
        mockComputation = new MockComputation();
    }

    function testAddMetric() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 2);
        MetricsSystem.Metric memory metric = metricsSystem.getMetric(BLUEPRINT_ID, 0);
        assertEq(metric.name, "TestMetric");
        assertEq(metric.decimals, 2);
        assertTrue(metric.isActive);
    }

    function testRemoveMetric() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 2);
        metricsSystem.removeMetric(BLUEPRINT_ID, 0);
        MetricsSystem.Metric memory metric = metricsSystem.getMetric(BLUEPRINT_ID, 0);
        assertFalse(metric.isActive);
    }

    function testAddDerivedMetric() public {
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "DerivedMetric", sourceIndices, address(mockComputation));
        MetricsSystem.DerivedMetric memory derivedMetric = metricsSystem.getDerivedMetric(BLUEPRINT_ID, 0);
        assertEq(derivedMetric.name, "DerivedMetric");
        assertTrue(derivedMetric.isActive);
        assertEq(derivedMetric.sourceMetricIndices.length, 1);
        assertEq(derivedMetric.sourceMetricIndices[0], 0);
        assertEq(address(derivedMetric.computationContract), address(mockComputation));
    }

    function testRemoveDerivedMetric() public {
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "DerivedMetric", sourceIndices, address(mockComputation));
        metricsSystem.removeDerivedMetric(BLUEPRINT_ID, 0);
        MetricsSystem.DerivedMetric memory derivedMetric = metricsSystem.getDerivedMetric(BLUEPRINT_ID, 0);
        assertFalse(derivedMetric.isActive);
    }

    function testReportMetric() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 2);
        vm.prank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100);
        MetricsSystem.MetricValue[] memory history = metricsSystem.getOperatorMetricHistory(BLUEPRINT_ID, OPERATOR, 0);
        assertEq(history.length, 1);
        assertEq(history[0].value, 100);
    }

    function testComputeDerivedMetric() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric", 2);
        uint256[] memory sourceIndices = new uint256[](1);
        sourceIndices[0] = 0;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "DerivedMetric", sourceIndices, address(mockComputation));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 200);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 300);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        assertEq(derivedValue.value, 200); // Average of 100, 200, 300
    }

    function testReportMultipleMetrics() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric1", 2);
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric2", 2);

        vm.startPrank(OPERATOR);
        for (uint256 i = 0; i < 5; i++) {
            metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100 + i * 10);
            metricsSystem.reportMetric(BLUEPRINT_ID, 1, 200 + i * 20);
        }
        vm.stopPrank();

        MetricsSystem.MetricValue[] memory history1 = metricsSystem.getOperatorMetricHistory(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue[] memory history2 = metricsSystem.getOperatorMetricHistory(BLUEPRINT_ID, OPERATOR, 1);

        assertEq(history1.length, 5);
        assertEq(history2.length, 5);
        assertEq(history1[4].value, 140);
        assertEq(history2[4].value, 280);
    }

    function testComputeDerivedMetricWithMultipleSources() public {
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric1", 2);
        metricsSystem.addMetric(BLUEPRINT_ID, "TestMetric2", 2);

        uint256[] memory sourceIndices = new uint256[](2);
        sourceIndices[0] = 0;
        sourceIndices[1] = 1;
        metricsSystem.addDerivedMetric(BLUEPRINT_ID, "DerivedMetric", sourceIndices, address(mockComputation));

        vm.startPrank(OPERATOR);
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100);
        metricsSystem.reportMetric(BLUEPRINT_ID, 1, 200);
        vm.stopPrank();

        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        MetricsSystem.MetricValue memory derivedValue = metricsSystem.getOperatorDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
        assertEq(derivedValue.value, 150); // Average of 100 and 200
    }

    function testFailReportInvalidMetric() public {
        vm.expectRevert("Invalid metric");
        metricsSystem.reportMetric(BLUEPRINT_ID, 0, 100);
    }

    function testFailComputeInvalidDerivedMetric() public {
        vm.expectRevert("Invalid derived metric");
        metricsSystem.computeDerivedMetric(BLUEPRINT_ID, OPERATOR, 0);
    }
}
