// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Liquifier, Adapter } from "core/lst/liquifier/Liquifier.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Registry } from "core/lst/registry/Registry.sol";

// solhint-disable func-name-mixedcase
// solhint-disable no-empty-blocks

contract LiquifierHarness is Liquifier {
    constructor(address _registry, address _unlocks) Liquifier(_registry, _unlocks) { }

    function exposed_registry() public view returns (Registry) {
        return _registry();
    }

    function exposed_unlocks() public view returns (Unlocks) {
        return _unlocks();
    }
}
