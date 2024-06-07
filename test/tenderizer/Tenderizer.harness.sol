// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Tenderizer, Adapter } from "core/lst/tenderizer/Tenderizer.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Registry } from "core/lst/registry/Registry.sol";

// solhint-disable func-name-mixedcase
// solhint-disable no-empty-blocks

contract TenderizerHarness is Tenderizer {
    constructor(address _registry, address _unlocks) Tenderizer(_registry, _unlocks) { }

    function exposed_registry() public view returns (Registry) {
        return _registry();
    }

    function exposed_unlocks() public view returns (Unlocks) {
        return _unlocks();
    }
}
