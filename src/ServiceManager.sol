// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Permissions.sol";
import "./Precompiles.sol";

/// @dev Created by the service blueprint designer (gadget developer)
/// @dev Deployed by the service requester (service instance creator)
contract ServiceManagerBase is RootChainEnabled, ServiceQuerier {
    address TASK_CREATION_PRECOMPILE = address(0x01);
    uint256 serviceId;
    
    function setServiceId(uint256 _serviceId) public onlyFromRootChain {
        serviceId = _serviceId;
    }

    function submitJobToRuntime(uint8 jobIndex, bytes memory inputs) internal {
        // Create a task
        (bool success, bytes memory data) = TASK_CREATION_PRECOMPILE.delegatecall(
            abi.encodeWithSignature("createTask(uint256,uint8,bytes)", serviceId, jobIndex, inputs)
        );
        require(success, "Task creation failed");
    }

    function submitJobResultToRuntime(uint256 callId, bytes memory result) internal {
        // Submit the result
        (bool success, bytes memory data) = TASK_CREATION_PRECOMPILE.delegatecall(
            abi.encodeWithSignature("submitTaskResult(uint256,bytes)", callId, result)
        );
        require(success, "Task result submission failed");
    }

    function submitMisbehaviorToRuntime(uint256 callId, bytes memory misbehavior) internal {
        // Submit the misbehavior
        (bool success, bytes memory data) = TASK_CREATION_PRECOMPILE.delegatecall(
            abi.encodeWithSignature("submitMisbehavior(uint256,bytes)", callId, misbehavior)
        );
        require(success, "Misbehavior submission failed");
    }
}
