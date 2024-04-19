// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract PermittedCaller {
    address public permitted;

    constructor() {
        permitted = msg.sender;
    }

    modifier onlyPermittedCaller() {
        require(msg.sender == permitted, "Only permitted caller can call this function");
        _;
    }
}

contract RootChainEnabled {
    address public ROOT_CHAIN;

    constructor() {
        ROOT_CHAIN = address(0x01);
    }

    modifier onlyFromRootChain() {
        require(msg.sender == ROOT_CHAIN, "Only root chain can call this function");
        _;
    }
}