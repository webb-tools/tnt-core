// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/access/Ownable.sol";
import "core/services/metrics/IMetricComputation.sol";

/// @title MetricsSystem
/// @notice This contract manages a system for tracking and analyzing metrics for various blueprints and operators
contract MetricsSystem is Ownable {
    struct Metric {
        string name;
        uint8 decimals;
        bool isActive;
    }

    struct MetricValue {
        uint256 value;
        uint256 timestamp;
    }

    struct DerivedMetric {
        string name;
        bool isActive;
        uint256[] sourceMetricIndices;
        IMetricComputation computationContract;
    }

    /// @notice Mapping of blueprint IDs to their metrics
    mapping(bytes32 => Metric[]) public blueprintMetrics;

    /// @notice Mapping of blueprint IDs to their derived metrics
    mapping(bytes32 => DerivedMetric[]) public blueprintDerivedMetrics;

    /// @notice Mapping of blueprint IDs to operator addresses to metric indices to metric value histories
    mapping(bytes32 => mapping(address => mapping(uint256 => MetricValue[]))) public operatorMetrics;

    /// @notice Mapping of blueprint IDs to operator addresses to derived metric indices to the latest derived metric value
    mapping(bytes32 => mapping(address => mapping(uint256 => MetricValue))) public operatorDerivedMetrics;

    uint256 public constant MAX_HISTORY = 100; // Maximum number of historical values to store

    event MetricAdded(bytes32 indexed blueprintId, uint256 indexed metricIndex, string name, uint8 decimals);
    event MetricRemoved(bytes32 indexed blueprintId, uint256 indexed metricIndex);
    event DerivedMetricAdded(
        bytes32 indexed blueprintId,
        uint256 indexed derivedMetricIndex,
        string name,
        uint256[] sourceMetricIndices,
        address computationContract
    );
    event DerivedMetricRemoved(bytes32 indexed blueprintId, uint256 indexed derivedMetricIndex);
    event MetricReported(bytes32 indexed blueprintId, address indexed operator, uint256 indexed metricIndex, uint256 value);
    event DerivedMetricUpdated(
        bytes32 indexed blueprintId, address indexed operator, uint256 indexed derivedMetricIndex, uint256 value
    );

    /// @notice Adds a new metric to a blueprint
    /// @param blueprintId The unique identifier of the blueprint
    /// @param name The name of the metric
    /// @param decimals The number of decimal places for the metric
    function addMetric(bytes32 blueprintId, string memory name, uint8 decimals) external onlyOwner {
        uint256 metricIndex = blueprintMetrics[blueprintId].length;
        blueprintMetrics[blueprintId].push(Metric(name, decimals, true));
        emit MetricAdded(blueprintId, metricIndex, name, decimals);
    }

    /// @notice Removes a metric from a blueprint by setting it as inactive
    /// @param blueprintId The unique identifier of the blueprint
    /// @param metricIndex The index of the metric to be removed
    function removeMetric(bytes32 blueprintId, uint256 metricIndex) external onlyOwner {
        require(metricIndex < blueprintMetrics[blueprintId].length, "Invalid metric index");
        blueprintMetrics[blueprintId][metricIndex].isActive = false;
        emit MetricRemoved(blueprintId, metricIndex);
    }

    /// @notice Adds a new derived metric to a blueprint
    /// @param blueprintId The unique identifier of the blueprint
    /// @param name The name of the derived metric
    /// @param sourceMetricIndices The indices of the source metrics used to calculate this derived metric
    /// @param computationContractAddress The address of the contract that computes this derived metric
    function addDerivedMetric(
        bytes32 blueprintId,
        string memory name,
        uint256[] memory sourceMetricIndices,
        address computationContractAddress
    )
        external
        onlyOwner
    {
        uint256 derivedMetricIndex = blueprintDerivedMetrics[blueprintId].length;
        blueprintDerivedMetrics[blueprintId].push(
            DerivedMetric(name, true, sourceMetricIndices, IMetricComputation(computationContractAddress))
        );
        emit DerivedMetricAdded(blueprintId, derivedMetricIndex, name, sourceMetricIndices, computationContractAddress);
    }

    /// @notice Removes a derived metric from a blueprint by setting it as inactive
    /// @param blueprintId The unique identifier of the blueprint
    /// @param derivedMetricIndex The index of the derived metric to be removed
    function removeDerivedMetric(bytes32 blueprintId, uint256 derivedMetricIndex) external onlyOwner {
        require(derivedMetricIndex < blueprintDerivedMetrics[blueprintId].length, "Invalid derived metric index");
        blueprintDerivedMetrics[blueprintId][derivedMetricIndex].isActive = false;
        emit DerivedMetricRemoved(blueprintId, derivedMetricIndex);
    }

    /// @notice Reports a metric value for a specific blueprint and operator
    /// @param blueprintId The unique identifier of the blueprint
    /// @param metricIndex The index of the metric being reported
    /// @param value The value of the metric being reported
    function reportMetric(bytes32 blueprintId, uint256 metricIndex, uint256 value) external {
        require(metricIndex < blueprintMetrics[blueprintId].length, "Invalid metric index");
        require(blueprintMetrics[blueprintId][metricIndex].isActive, "Metric is not active");

        MetricValue[] storage history = operatorMetrics[blueprintId][msg.sender][metricIndex];
        if (history.length == MAX_HISTORY) {
            for (uint256 i = 0; i < MAX_HISTORY - 1; i++) {
                history[i] = history[i + 1];
            }
            history[MAX_HISTORY - 1] = MetricValue(value, block.timestamp);
        } else {
            history.push(MetricValue(value, block.timestamp));
        }

        emit MetricReported(blueprintId, msg.sender, metricIndex, value);
    }

    /// @notice Computes and updates a derived metric for a specific blueprint and operator
    /// @param blueprintId The unique identifier of the blueprint
    /// @param operator The address of the operator
    /// @param derivedMetricIndex The index of the derived metric to compute
    function computeDerivedMetric(bytes32 blueprintId, address operator, uint256 derivedMetricIndex) external {
        require(derivedMetricIndex < blueprintDerivedMetrics[blueprintId].length, "Invalid derived metric index");
        require(blueprintDerivedMetrics[blueprintId][derivedMetricIndex].isActive, "Derived metric is not active");

        DerivedMetric storage derivedMetric = blueprintDerivedMetrics[blueprintId][derivedMetricIndex];
        uint256[] memory sourceMetrics = derivedMetric.sourceMetricIndices;

        // Count total values across all source metrics
        uint256 totalValues = 0;
        for (uint256 i = 0; i < sourceMetrics.length; i++) {
            totalValues += operatorMetrics[blueprintId][operator][sourceMetrics[i]].length;
        }

        // Create arrays to hold all values and timestamps
        uint256[] memory values = new uint256[](totalValues);
        uint256[] memory timestamps = new uint256[](totalValues);
        uint256 valueIndex = 0;

        // Populate values and timestamps arrays
        for (uint256 i = 0; i < sourceMetrics.length; i++) {
            MetricValue[] storage history = operatorMetrics[blueprintId][operator][sourceMetrics[i]];
            for (uint256 j = 0; j < history.length; j++) {
                values[valueIndex] = history[j].value;
                timestamps[valueIndex] = history[j].timestamp;
                valueIndex++;
            }
        }

        // Compute the derived metric
        uint256 result = IMetricComputation(derivedMetric.computationContract).compute(values, timestamps);

        // Store the result
        operatorDerivedMetrics[blueprintId][operator][derivedMetricIndex] =
            MetricValue({ value: result, timestamp: block.timestamp });

        emit DerivedMetricUpdated(blueprintId, operator, derivedMetricIndex, result);
    }

    /// @notice Retrieves a specific metric for a blueprint
    /// @param blueprintId The unique identifier of the blueprint
    /// @param metricIndex The index of the metric
    /// @return The Metric struct containing the metric details
    function getMetric(bytes32 blueprintId, uint256 metricIndex) external view returns (Metric memory) {
        require(metricIndex < blueprintMetrics[blueprintId].length, "Invalid metric index");
        return blueprintMetrics[blueprintId][metricIndex];
    }

    /// @notice Retrieves a specific derived metric for a blueprint
    /// @param blueprintId The unique identifier of the blueprint
    /// @param derivedMetricIndex The index of the derived metric
    /// @return The DerivedMetric struct containing the derived metric details
    function getDerivedMetric(bytes32 blueprintId, uint256 derivedMetricIndex) external view returns (DerivedMetric memory) {
        require(derivedMetricIndex < blueprintDerivedMetrics[blueprintId].length, "Invalid derived metric index");
        return blueprintDerivedMetrics[blueprintId][derivedMetricIndex];
    }

    /// @notice Retrieves the metric value history for a specific operator and blueprint
    /// @param blueprintId The unique identifier of the blueprint
    /// @param operator The address of the operator
    /// @param metricIndex The index of the metric
    /// @return An array of MetricValue structs containing the value history
    function getOperatorMetricHistory(
        bytes32 blueprintId,
        address operator,
        uint256 metricIndex
    )
        external
        view
        returns (MetricValue[] memory)
    {
        return operatorMetrics[blueprintId][operator][metricIndex];
    }

    /// @notice Retrieves the latest derived metric value for a specific operator and blueprint
    /// @param blueprintId The unique identifier of the blueprint
    /// @param operator The address of the operator
    /// @param derivedMetricIndex The index of the derived metric
    /// @return The MetricValue struct containing the latest derived value and timestamp
    function getOperatorDerivedMetric(
        bytes32 blueprintId,
        address operator,
        uint256 derivedMetricIndex
    )
        external
        view
        returns (MetricValue memory)
    {
        return operatorDerivedMetrics[blueprintId][operator][derivedMetricIndex];
    }
}
