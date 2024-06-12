// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { ClonesWithImmutableArgs } from "clones/ClonesWithImmutableArgs.sol";

import { Adapter } from "core/lst/adapters/Adapter.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";

/**
 * @title Factory
 * @author Tangle Labs
 * @notice Factory for Liquifier contracts
 */
contract Factory {
    using ClonesWithImmutableArgs for address;

    error InvalidAsset(address asset);
    error NotValidator(address validator);

    address public immutable registry;
    address public immutable liquifierImpl;

    constructor(address _registry) {
        registry = _registry;
        liquifierImpl = Registry(_registry).liquifier();
    }

    /**
     * @notice Creates a new Liquifier
     * @param asset Address of the underlying asset
     * @param validator Address of the validator
     * @return liquifier Address of the created Liquifier
     */
    function newLiquifier(address asset, address validator) external returns (address liquifier) {
        Adapter adapter = Adapter(Registry(registry).adapter(asset));

        if (address(adapter) == address(0)) revert InvalidAsset(asset);
        if (!adapter.isValidator(validator)) revert NotValidator(validator);

        liquifier = address(liquifierImpl).clone(abi.encodePacked(asset, validator));

        // Reverts if caller is not a registered factory
        // Reverts if `validator` already has a registered `liquifier` for `asset`
        Registry(registry).registerLiquifier(asset, validator, liquifier);
    }
}
