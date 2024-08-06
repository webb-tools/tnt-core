// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Metrics Precompile Contract
/// @notice This contract interacts with the Tangle blockchain's runtime to fetch metrics data
interface MetricsPrecompile {
    /// @notice Fetch the job creation time from the Tangle blockchain
    /// @param jobId Unique identifier of the job
    /// @return Timestamp of when the job was created
    function getJobCreationTime(bytes32 jobId) external view returns (uint256);

    /// @notice Fetch the job execution submission time from the Tangle blockchain
    /// @param jobId Unique identifier of the job
    /// @return Timestamp of when the job execution was submitted
    function getJobExecutionSubmissionTime(bytes32 jobId) external view returns (uint256);

    /// @notice Fetch the job execution verification time from the Tangle blockchain
    /// @param jobId Unique identifier of the job
    /// @return Timestamp of when the job execution was verified
    function getJobExecutionVerificationTime(bytes32 jobId) external view returns (uint256);

    /// @notice Fetch the address of the operator who submitted the job execution
    /// @param jobId Unique identifier of the job
    /// @return Address of the operator who submitted the job execution
    function getJobExecutionSubmitter(bytes32 jobId) external view returns (address);

    /// @notice Fetch the number of failed job executions
    /// @param jobId Unique identifier of the job
    /// @return Number of failed job executions
    function getFailedJobExecutions(bytes32 jobId) external view returns (uint256);

    /// @notice Check if a service meets its QoS standards
    /// @param serviceId Unique identifier of the service
    /// @return Boolean indicating whether the service meets its QoS standards
    function checkImOnline(bytes32 serviceId) external view returns (bool);
}
