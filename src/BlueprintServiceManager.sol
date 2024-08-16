// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "core/Permissions.sol";

/**
 * @title BlueprintServiceManager
 * @dev This contract acts as a manager for the lifecycle of a Blueprint Instance,
 * facilitating various stages such as registration, service requests, job execution,
 * and job result handling. It is designed to be used by the service blueprint designer
 * (gadget developer) and integrates with the RootChain for permissioned operations.
 * Each function serves as a hook for different lifecycle events, and reverting any
 * of these functions interrupts the process flow.
 */
contract BlueprintServiceManager is RootChainEnabled {
    /**
     * @dev Hook for service operator registration. Called when a service operator
     * attempts to register with the blueprint.
     * @param operator The operator's details.
     * @param registrationInputs Inputs required for registration.
     */
    function onRegister(bytes calldata operator, bytes calldata registrationInputs) public payable virtual onlyFromRootChain { }

    /**
     * @dev Hook for service instance requests. Called when a user requests a service
     * instance from the blueprint.
     * @param serviceId The ID of the requested service.
     * @param operators The operators involved in the service.
     * @param requestInputs Inputs required for the service request.
     */
    function onRequest(
        uint64 serviceId,
        bytes[] calldata operators,
        bytes calldata requestInputs
    )
        public
        payable
        virtual
        onlyFromRootChain
    { }

    /**
     * @dev Hook for job calls on the service. Called when a job is executed within
     * the service context.
     * @param serviceId The ID of the service where the job is called.
     * @param job The job identifier.
     * @param jobCallId A unique ID for the job call.
     * @param inputs Inputs required for the job execution.
     */
    function onJobCall(
        uint64 serviceId,
        uint8 job,
        uint64 jobCallId,
        bytes calldata inputs
    )
        public
        payable
        virtual
        onlyFromRootChain
    { }

    /**
     * @dev Hook for handling job call results. Called when operators send the result
     * of a job execution.
     * @param serviceId The ID of the service related to the job.
     * @param job The job identifier.
     * @param jobCallId The unique ID for the job call.
     * @param participant The participant (operator) sending the result.
     * @param inputs Inputs used for the job execution.
     * @param outputs Outputs resulting from the job execution.
     */
    function onJobCallResult(
        uint64 serviceId,
        uint8 job,
        uint64 jobCallId,
        bytes calldata participant,
        bytes calldata inputs,
        bytes calldata outputs
    )
        public
        virtual
        onlyFromRootChain
    { }

    /**
     * @dev Verifies the result of a job call. This function is used to validate the
     * outputs of a job execution against the expected results.
     * @param serviceId The ID of the service related to the job.
     * @param job The job identifier.
     * @param jobCallId The unique ID for the job call.
     * @param participant The participant (operator) whose result is being verified.
     * @param inputs Inputs used for the job execution.
     * @param outputs Outputs resulting from the job execution.
     * @return bool Returns true if the job call result is verified successfully,
     * otherwise false.
     */
    function verifyJobCallResult(
        uint64 serviceId,
        uint8 job,
        uint64 jobCallId,
        bytes calldata participant,
        bytes calldata inputs,
        bytes calldata outputs
    )
        public
        view
        virtual
        onlyFromRootChain
        returns (bool)
    { }
}
