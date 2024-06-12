// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { PolygonAdapter, POL } from "core/lst/adapters/PolygonAdapter.sol";
import { Liquifier } from "core/lst/liquifier/ILiquifier.sol";
import { Registry } from "core/lst/registry/Registry.sol";

address constant VALIDATOR_OLD = 0x055BD801cA712b4ddf67db8BC23FB6C8510D52b9;
address constant VALIDATOR_NEW = 0x1BE946281214Afa0200725917B46EaeCb4b7dBE1;
address payable constant LIQUIFIER = payable(0xa536981111f0C1e510150c544D8762Ae8e9bEbd3);
address constant REGISTRY = 0xa7cA8732Be369CaEaE8C230537Fc8EF82a3387EE;
address constant GOVERNOR = 0x5542b58080FEE48dBE6f38ec0135cE9011519d96;

contract Polygon_Advisory_Fix_1 is Test {
    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"));
    }

    function test_rebase_fails() public {
        Liquifier liquifier = Liquifier(LIQUIFIER);
        vm.expectRevert();
        liquifier.rebase();
    }

    function test_fixed_adapter() public {
        address adapter = address(new PolygonAdapter());
        Registry registry = Registry(REGISTRY);
        Liquifier liquifier = Liquifier(LIQUIFIER);
        vm.prank(GOVERNOR);
        registry.registerAdapter(address(POL), adapter);
        liquifier.rebase();
    }
}
