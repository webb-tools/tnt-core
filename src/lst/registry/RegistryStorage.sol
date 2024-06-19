// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

contract RegistryStorage {
    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.registry.storage.location")) - 1;

    struct Protocol {
        address adapter;
        uint96 fee;
    }

    struct Storage {
        address liquifier;
        address unlocks;
        address treasury;
        mapping(address => Protocol) protocols;
        mapping(address asset => mapping(address validator => address liquifier)) liquifiers;
    }

    function _loadStorage() internal pure returns (Storage storage $) {
        uint256 slot = STORAGE;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := slot
        }
    }
}
