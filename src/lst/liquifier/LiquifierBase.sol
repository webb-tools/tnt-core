// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Clone } from "clones/Clone.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";

/// @title LiquifierImmutableArgs
/// @notice Immutable arguments for Liquifier
/// @dev Immutable arguments are appended to the proxy bytecode at deployment of a clone.
/// Arguments are appended to calldata when the proxy delegatecals to its implementation,
/// where these arguments can be read given their memory offset and length.

abstract contract LiquifierImmutableArgs is Clone {
    constructor(address _registry, address _unlocks) {
        registry = _registry;
        unlocks = _unlocks;
    }

    address private immutable registry;
    address private immutable unlocks;

    /**
     * @notice Returns the underlying asset
     * @return Address of the underlying asset
     */
    function asset() public pure returns (address) {
        return _getArgAddress(0); // start: 0 end: 19
    }

    /**
     * @notice Returns the validator
     * @return Address of the validator
     */
    function validator() public pure returns (address) {
        return _getArgAddress(20); // start: 20 end: 39
    }

    function adapter() public view returns (Adapter) {
        return Adapter(_registry().adapter(asset()));
    }

    function _registry() internal view returns (Registry) {
        return Registry(registry);
    }

    function _unlocks() internal view returns (Unlocks) {
        return Unlocks(unlocks);
    }
}

/// @title LiquifierEvents
/// @notice Events for Liquifier
abstract contract LiquifierEvents {
    event Deposit(address indexed sender, address indexed receiver, uint256 assetsIn, uint256 tgTokenOut);

    event Rebase(uint256 oldStake, uint256 newStake);

    event Unlock(address indexed receiver, uint256 assets, uint256 unlockID);

    event Withdraw(address indexed receiver, uint256 assets, uint256 unlockID);
}
