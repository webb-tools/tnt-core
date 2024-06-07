// SPDX-License-Identifier: MIT
//
//  _____              _           _
// |_   _|            | |         (_)
//   | | ___ _ __   __| | ___ _ __ _ _______
//   | |/ _ \ '_ \ / _` |/ _ \ '__| |_  / _ \
//   | |  __/ | | | (_| |  __/ |  | |/ /  __/
//   \_/\___|_| |_|\__,_|\___|_|  |_/___\___|
//
// Copyright (c) Tenderize Labs Ltd

pragma solidity >=0.8.19;

contract RegistryStorage {
    uint256 private constant STORAGE = uint256(keccak256("xyz.tenderize.registry.storage.location")) - 1;

    struct Protocol {
        address adapter;
        uint96 fee;
    }

    struct Storage {
        address tenderizer;
        address unlocks;
        address treasury;
        mapping(address => Protocol) protocols;
        mapping(address asset => mapping(address validator => address tenderizer)) tenderizers;
    }

    function _loadStorage() internal pure returns (Storage storage $) {
        uint256 slot = STORAGE;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := slot
        }
    }
}
