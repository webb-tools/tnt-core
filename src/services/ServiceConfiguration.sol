// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "core/services/MetricsRegistry.sol";

/// @title Service Configuration Contract
/// @notice This contract handles the configuration of Quality of Service parameters for services
contract ServiceConfiguration {
    MetricsRegistry public metricsRegistry;

    /// @dev Struct to store QoS thresholds for a service
    struct QoSThresholds {
        uint256 minHeartbeatSuccess;   // Minimum required heartbeat success rate in basis points (0-10000)
        uint256 minTaskSuccess;        // Minimum required task success rate in basis points (0-10000)
        uint256 maxResponseTime;       // Maximum allowed response time in seconds
    }

    /// @dev Mapping of service ID to its QoS thresholds
    mapping(bytes32 => QoSThresholds) public serviceThresholds;

    /// @dev Event emitted when QoS thresholds are set for a service
    event QoSThresholdsSet(bytes32 indexed serviceId, uint256 minHeartbeatSuccess, uint256 minTaskSuccess, uint256 maxResponseTime);

    /// @notice Constructor to set the address of the MetricsRegistry contract
    /// @param _metricsRegistry Address of the deployed MetricsRegistry contract
    constructor(address _metricsRegistry) {
        metricsRegistry = MetricsRegistry(_metricsRegistry);
    }

    /// @notice Set QoS thresholds for a service
    /// @param serviceId Unique identifier of the service
    /// @param minHeartbeatSuccess Minimum required heartbeat success rate in basis points (0-10000)
    /// @param minTaskSuccess Minimum required task success rate in basis points (0-10000)
    /// @param maxResponseTime Maximum allowed response time in seconds
    function setQoSThresholds(
        bytes32 serviceId,
        uint256 minHeartbeatSuccess,
        uint256 minTaskSuccess,
        uint256 maxResponseTime
    ) external {
        // TODO: Add access control to limit who can set thresholds
        serviceThresholds[serviceId] = QoSThresholds(minHeartbeatSuccess, minTaskSuccess, maxResponseTime);
        emit QoSThresholdsSet(serviceId, minHeartbeatSuccess, minTaskSuccess, maxResponseTime);
    }

    /// @notice Get QoS thresholds for a service
    /// @param serviceId Unique identifier of the service
    /// @return QoSThresholds struct containing the thresholds
    function getQoSThresholds(bytes32 serviceId) external view returns (QoSThresholds memory) {
        return serviceThresholds[serviceId];
    }
}