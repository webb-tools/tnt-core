// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "core/ServiceManager.sol";

//
contract DfnsCggmp21ThresholdSignatureService is ServiceManagerBase, PermittedCaller {
    uint8 constant DKG_TASK_JOB_ID = 0;
    uint8 constant SIGNATURE_TASK_JOB_ID = 1;

    error InvalidThreshold(uint8 threshold, uint8 numParticipants);

    function createDKGTask(uint256 serviceId, uint8 t) public onlyPermittedCaller {
        if (t < getServiceParticipants(serviceId).length) {
            revert InvalidThreshold(t, uint8(getServiceParticipants(serviceId).length));
        }

        bytes memory inputs = abi.encode(t);
        submitJobToRuntime(DKG_TASK_JOB_ID, inputs);
    }

    function createSignatureTask() public onlyPermittedCaller {
        submitJobToRuntime(SIGNATURE_TASK_JOB_ID, "");
    }

    function submitMisbehavior(uint256 callId, bytes memory misbehavior) public {
        submitMisbehaviorToRuntime(callId, misbehavior);
    }
}
