// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test, stdError } from "forge-std/Test.sol";

import { Factory } from "core/lst/factory/Factory.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

// solhint-disable func-name-mixedcase
contract FactoryTest is Test {
    Factory private factory;

    address private unlocks = vm.addr(2);
    address private adapter = vm.addr(3);
    address private asset = vm.addr(4);
    address private validator = vm.addr(5);
    address private registry = vm.addr(6);
    address private liquifier = address(new Liquifier(registry, unlocks));

    function setUp() public {
        vm.mockCall(registry, abi.encodeCall(Registry.liquifier, ()), abi.encode(liquifier));
        vm.mockCall(registry, abi.encodeCall(Registry.unlocks, ()), abi.encode(unlocks));
        factory = new Factory(registry);
    }

    function test_InitialStorage() public {
        assertEq(factory.registry(), registry, "registry not set");
        assertEq(factory.liquifierImpl(), address(liquifier), "liquifier not set");
    }

    function test_NewLiquifier() public {
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(adapter));
        vm.mockCall(adapter, abi.encodeCall(Adapter.isValidator, (validator)), abi.encode(true));
        vm.mockCall(registry, abi.encodeCall(Registry.registerLiquifier, (asset, validator, liquifier)), "");
        vm.expectCall(registry, abi.encodeCall(Registry.adapter, (asset)));

        address payable newLiquifier = payable(factory.newLiquifier(asset, validator));
        assertEq(newLiquifier, 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac, "liquifier not created with correct address");
        assertEq(Liquifier(newLiquifier).asset(), asset, "asset not set");
        assertEq(Liquifier(newLiquifier).validator(), validator, "validator not set");
    }

    function test_NewLiquifier_RevertIfNoAdapter() public {
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(address(0)));

        vm.expectCall(registry, abi.encodeCall(Registry.adapter, (asset)));
        vm.expectRevert(abi.encodeWithSelector(Factory.InvalidAsset.selector, asset));
        factory.newLiquifier(asset, validator);
    }

    function test_NewLiquifier_RevertIfNotValidator() public {
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(adapter));
        vm.mockCall(adapter, abi.encodeCall(Adapter.isValidator, (validator)), abi.encode(false));

        vm.expectCall(registry, abi.encodeCall(Registry.adapter, (asset)));
        vm.expectCall(adapter, abi.encodeCall(Adapter.isValidator, (validator)));
        vm.expectRevert(abi.encodeWithSelector(Factory.NotValidator.selector, validator));
        factory.newLiquifier(asset, validator);
    }
}
