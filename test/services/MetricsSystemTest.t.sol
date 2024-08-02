// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "core/services/MetricsRegistry.sol";
import "core/services/ServiceConfiguration.sol";
import "core/services/MetricsAggregator.sol";

contract MetricsSystemTest is Test {
    MetricsRegistry public registry;
    ServiceConfiguration public configuration;
    MetricsAggregator public aggregator;

    address public blueprintDeveloper = address(1);
    address public operator1 = address(2);
    address public operator2 = address(3);

    bytes32 public constant SERVICE_ID = keccak256("TestService");

    function setUp() public {
        vm.startPrank(blueprintDeveloper);
        
        registry = new MetricsRegistry();
        configuration = new ServiceConfiguration(address(registry));
        aggregator = new MetricsAggregator(address(registry), address(configuration));
        
        // Transfer ownership to blueprintDeveloper
        registry.transferOwnership(blueprintDeveloper);
        
        vm.stopPrank();
    }

    function testBlueprintDeveloperSetup() public {
        vm.startPrank(blueprintDeveloper);

        // Register metrics
        registry.registerMetric(SERVICE_ID, "heartbeat", "heartbeat", 60);
        registry.registerMetric(SERVICE_ID, "taskSuccess", "task", 300);
        registry.registerMetric(SERVICE_ID, "responseTime", "custom", 60);

        // Set QoS thresholds
        configuration.setQoSThresholds(SERVICE_ID, 9500, 9800, 100);

        // Initialize metrics
        aggregator.initializeMetrics(SERVICE_ID);

        vm.stopPrank();

        // Verify metrics registration
        MetricsRegistry.Metric[] memory metrics = registry.getServiceMetrics(SERVICE_ID);
        assertEq(metrics.length, 3);
        assertEq(metrics[0].name, "heartbeat");
        assertEq(metrics[1].name, "taskSuccess");
        assertEq(metrics[2].name, "responseTime");

        // Verify QoS thresholds
        ServiceConfiguration.QoSThresholds memory thresholds = configuration.getQoSThresholds(SERVICE_ID);
        assertEq(thresholds.minHeartbeatSuccess, 9500);
        assertEq(thresholds.minTaskSuccess, 9800);
        assertEq(thresholds.maxResponseTime, 100);
    }

    function testOperatorReporting() public {
        // Set up the service first
        testBlueprintDeveloperSetup();

        vm.startPrank(operator1);

        // Report metrics
        aggregator.reportMetric(SERVICE_ID, "heartbeat", 1);
        aggregator.reportMetric(SERVICE_ID, "taskSuccess", 1);
        aggregator.reportMetric(SERVICE_ID, "responseTime", 50);

        vm.stopPrank();

        // Verify aggregated metrics
        MetricsAggregator.AggregatedMetrics memory metrics = aggregator.getAggregatedMetrics(SERVICE_ID);
        assertEq(metrics.heartbeatSuccessRate, 10000);
        assertEq(metrics.taskSuccessRate, 10000);
        assertEq(metrics.averageResponseTime, 50);
    }

    function testMultipleOperatorReporting() public {
        // Set up the service first
        testBlueprintDeveloperSetup();

        // Operator 1 reports
        vm.prank(operator1);
        aggregator.reportMetric(SERVICE_ID, "heartbeat", 1);
        aggregator.reportMetric(SERVICE_ID, "taskSuccess", 1);
        aggregator.reportMetric(SERVICE_ID, "responseTime", 50);

        // Operator 2 reports
        vm.prank(operator2);
        aggregator.reportMetric(SERVICE_ID, "heartbeat", 1);
        aggregator.reportMetric(SERVICE_ID, "taskSuccess", 0);
        aggregator.reportMetric(SERVICE_ID, "responseTime", 150);

        // Verify aggregated metrics
        MetricsAggregator.AggregatedMetrics memory metrics = aggregator.getAggregatedMetrics(SERVICE_ID);
        assertEq(metrics.heartbeatSuccessRate, 10000);
        assertEq(metrics.taskSuccessRate, 5000);
        assertEq(metrics.averageResponseTime, 100);
    }

    function testMovingAverageCalculation() public {
        // Set up the service first
        testBlueprintDeveloperSetup();

        vm.startPrank(operator1);

        // Report metrics multiple times
        for (uint i = 0; i < 10; i++) {
            aggregator.reportMetric(SERVICE_ID, "heartbeat", 1);
            aggregator.reportMetric(SERVICE_ID, "taskSuccess", i % 2 == 0 ? 1 : 0);
            aggregator.reportMetric(SERVICE_ID, "responseTime", 50 + i * 10);
        }

        vm.stopPrank();

        // Verify aggregated metrics
        MetricsAggregator.AggregatedMetrics memory metrics = aggregator.getAggregatedMetrics(SERVICE_ID);
        assertEq(metrics.heartbeatSuccessRate, 10000);
        assertEq(metrics.taskSuccessRate, 5000);
        assertEq(metrics.averageResponseTime, 95);
    }

    function testQoSCheck() public {
        // Set up the service first
        testBlueprintDeveloperSetup();

        // Report good metrics
        vm.prank(operator1);
        aggregator.reportMetric(SERVICE_ID, "heartbeat", 1);
        aggregator.reportMetric(SERVICE_ID, "taskSuccess", 1);
        aggregator.reportMetric(SERVICE_ID, "responseTime", 50);

        // Check QoS (should pass)
        bool meetsQoS = aggregator.checkQoS(SERVICE_ID);
        assertTrue(meetsQoS);

        // Report bad metrics
        vm.prank(operator2);
        aggregator.reportMetric(SERVICE_ID, "heartbeat", 0);
        aggregator.reportMetric(SERVICE_ID, "taskSuccess", 0);
        aggregator.reportMetric(SERVICE_ID, "responseTime", 200);

        // Check QoS again (should fail)
        meetsQoS = aggregator.checkQoS(SERVICE_ID);
        assertFalse(meetsQoS);
    }

    function testUnauthorizedMetricRegistration() public {
        vm.prank(operator1);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.registerMetric(SERVICE_ID, "unauthorizedMetric", "custom", 60);
    }

    function testReportingUnregisteredMetric() public {
        vm.prank(operator1);
        vm.expectRevert("Metric not registered for this service");
        aggregator.reportMetric(SERVICE_ID, "unregisteredMetric", 1);
    }
}