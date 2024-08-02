// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "core/services/MetricsRegistry.sol";
import "core/services/ServiceConfiguration.sol";

/// @title Metrics Aggregator Contract
/// @notice This contract handles the reporting and aggregation of metrics for services
contract MetricsAggregator {
    MetricsRegistry public metricsRegistry;
    ServiceConfiguration public serviceConfiguration;

    /// @dev Struct to store aggregated metrics for a service
    struct AggregatedMetrics {
        uint256 lastHeartbeat;
        uint256 heartbeatSuccessRate;
        uint256 taskSuccessRate;
        uint256 averageResponseTime;
        uint256 lastUpdateTime;
    }

    /// @dev Mapping of service ID to its aggregated metrics
    mapping(bytes32 => AggregatedMetrics) public aggregatedMetrics;

    /// @dev Mapping of service ID to operator to last report time
    mapping(bytes32 => mapping(address => uint256)) public lastReportTime;

    /// @dev Event emitted when metrics are reported
    event MetricsReported(bytes32 indexed serviceId, address indexed operator, string metricName, uint256 value);

    /// @dev Event emitted when aggregated metrics are updated
    event AggregatedMetricsUpdated(bytes32 indexed serviceId, uint256 heartbeatSuccessRate, uint256 taskSuccessRate, uint256 averageResponseTime);

    /// @notice Constructor to set the addresses of the MetricsRegistry and ServiceConfiguration contracts
    /// @param _metricsRegistry Address of the deployed MetricsRegistry contract
    /// @param _serviceConfiguration Address of the deployed ServiceConfiguration contract
    constructor(address _metricsRegistry, address _serviceConfiguration) {
        metricsRegistry = MetricsRegistry(_metricsRegistry);
        serviceConfiguration = ServiceConfiguration(_serviceConfiguration);
    }

    function initializeMetrics(bytes32 serviceId) external {
        AggregatedMetrics storage metrics = aggregatedMetrics[serviceId];
        metrics.heartbeatSuccessRate = 10000;
        metrics.taskSuccessRate = 10000;
        metrics.averageResponseTime = 0;
        metrics.lastUpdateTime = block.timestamp;
    }

    /// @notice Report a metric for a service
    /// @param serviceId Unique identifier of the service
    /// @param metricName Name of the metric being reported
    /// @param value Value of the metric
    function reportMetric(bytes32 serviceId, string memory metricName, uint256 value) external {
        // TODO: Add access control to limit who can report metrics (only registered operators)
        MetricsRegistry.Metric[] memory metrics = metricsRegistry.getServiceMetrics(serviceId);
        bool metricFound = false;
        
        for (uint i = 0; i < metrics.length; i++) {
            if (keccak256(bytes(metrics[i].name)) == keccak256(bytes(metricName))) {
                metricFound = true;
                break;
            }
        }
        
        require(metricFound, "Metric not registered for this service");

        emit MetricsReported(serviceId, msg.sender, metricName, value);

        // Update last report time for the operator
        lastReportTime[serviceId][msg.sender] = block.timestamp;

        // Update aggregated metrics
        updateAggregatedMetrics(serviceId, metricName, value);
    }

    /// @notice Update aggregated metrics for a service
    /// @param serviceId Unique identifier of the service
    /// @param metricName Name of the metric being updated
    /// @param value Value of the metric
    function updateAggregatedMetrics(bytes32 serviceId, string memory metricName, uint256 value) internal {
        AggregatedMetrics storage metrics = aggregatedMetrics[serviceId];

        if (keccak256(bytes(metricName)) == keccak256(bytes("heartbeat"))) {
            metrics.lastHeartbeat = block.timestamp;
            metrics.heartbeatSuccessRate = (metrics.heartbeatSuccessRate * 9 + value * 10000) / 10;
        } else if (keccak256(bytes(metricName)) == keccak256(bytes("taskSuccess"))) {
            metrics.taskSuccessRate = (metrics.taskSuccessRate * 9 + value * 10000) / 10;
        } else if (keccak256(bytes(metricName)) == keccak256(bytes("responseTime"))) {
            metrics.averageResponseTime = (metrics.averageResponseTime * 9 + value) / 10;
        }

        metrics.lastUpdateTime = block.timestamp;

        emit AggregatedMetricsUpdated(serviceId, metrics.heartbeatSuccessRate, metrics.taskSuccessRate, metrics.averageResponseTime);
    }

    /// @notice Check if a service meets its QoS standards
    /// @param serviceId Unique identifier of the service
    /// @return Boolean indicating whether the service meets its QoS standards
    function checkQoS(bytes32 serviceId) external view returns (bool) {
        AggregatedMetrics memory metrics = aggregatedMetrics[serviceId];
        ServiceConfiguration.QoSThresholds memory thresholds = serviceConfiguration.getQoSThresholds(serviceId);

        return (
            metrics.heartbeatSuccessRate >= thresholds.minHeartbeatSuccess &&
            metrics.taskSuccessRate >= thresholds.minTaskSuccess &&
            metrics.averageResponseTime <= thresholds.maxResponseTime
        );
    }

    /// @notice Get the aggregated metrics for a service
    /// @param serviceId Unique identifier of the service
    /// @return AggregatedMetrics struct containing the metrics
    function getAggregatedMetrics(bytes32 serviceId) external view returns (AggregatedMetrics memory) {
        return aggregatedMetrics[serviceId];
    }
}
