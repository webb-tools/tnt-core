// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
    /// @dev address(keccak256(pallet_services::Config::PalletId::to_account_id())[0:20])
    address public constant ROOT_CHAIN = 0x6d6f646c70792F73727663730000000000000000;

    /// @dev Only root chain can call this function
    /// @notice This function can only be called by the root chain
    modifier onlyFromRootChain() {
        require(msg.sender == ROOT_CHAIN, "RootChain: Only root chain can call this function");
        _;
    }
}
