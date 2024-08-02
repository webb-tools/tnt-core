// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @dev Created by the service blueprint designer (gadget developer)
contract RegistrationHook {
    function onRegister(bytes calldata registrationInputs) public payable virtual returns (bool) {
        return true;
    }
}
