// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Permissions.sol";

contract ServiceQuerier {
    address SERVICE_PRECOMPILE = address(0x02);

    function getServiceParticipants(uint256 serviceId) internal returns (address[] memory) {
        (bool success, bytes memory data) = SERVICE_PRECOMPILE.delegatecall(
            abi.encodeWithSignature("getServiceParticipants(uint256)", serviceId)
        );
        require(success, "Failed to get service participants");
        return abi.decode(data, (address[]));
    }
}