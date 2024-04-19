// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// Created by the service blueprint designer (gadget developer)
contract RegistrationHook {
    function onRegister(bytes calldata registrationInputs) public payable returns (bool) {
        return true;
    }
}
