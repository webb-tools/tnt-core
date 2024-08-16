// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "core/Permissions.sol";

/// @dev Created by the service blueprint designer (gadget developer)
contract BlueprintServiceManager is RootChainEnabled {
    function onRegister(bytes calldata operator, bytes calldata registrationInputs) public payable virtual onlyFromRootChain { }

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
    {
        return true;
    }
}
