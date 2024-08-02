// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/access/Ownable.sol";

/// @title Metrics Registry Contract
/// @notice This contract handles the registration of metrics for different services
contract MetricsRegistry is Ownable {
    /// @dev Struct to define a metric
    struct Metric {
        string name;
        string metricType; // "heartbeat", "task", or "custom"
        uint256 expectedInterval; // Expected interval between reports in seconds
    }

    /// @dev Mapping of service ID to its registered metrics
    mapping(bytes32 => Metric[]) public serviceMetrics;

    /// @dev Event emitted when a new metric is registered
    event MetricRegistered(bytes32 indexed serviceId, string name, string metricType, uint256 expectedInterval);

    /// @notice Register a new metric for a service
    /// @param serviceId Unique identifier of the service
    /// @param name Name of the metric
    /// @param metricType Type of the metric ("heartbeat", "task", or "custom")
    /// @param expectedInterval Expected interval between reports in seconds
    function registerMetric(
        bytes32 serviceId,
        string memory name,
        string memory metricType,
        uint256 expectedInterval
    ) external {
        // TODO: Add access control to limit who can register metrics
        Metric memory newMetric = Metric(name, metricType, expectedInterval);
        serviceMetrics[serviceId].push(newMetric);
        emit MetricRegistered(serviceId, name, metricType, expectedInterval);
    }

    /// @notice Get all metrics for a service
    /// @param serviceId Unique identifier of the service
    /// @return Array of Metric structs
    function getServiceMetrics(bytes32 serviceId) external view returns (Metric[] memory) {
        return serviceMetrics[serviceId];
    }
}