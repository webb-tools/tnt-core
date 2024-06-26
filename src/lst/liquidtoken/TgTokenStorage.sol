// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

abstract contract TgTokenStorage {
    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.tgToken.storage.location")) - 1;

    struct Storage {
        uint256 _totalShares;
        uint256 _totalSupply;
        mapping(address => uint256) shares;
        mapping(address => mapping(address => uint256)) allowance;
        mapping(address => uint256) nonces;
    }

    function _loadStorage() internal pure returns (Storage storage $) {
        uint256 slot = STORAGE;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := slot
        }
    }
}
