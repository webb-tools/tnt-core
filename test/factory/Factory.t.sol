// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test, stdError } from "forge-std/Test.sol";

import { Factory } from "core/lst/factory/Factory.sol";
import { Tenderizer } from "core/lst/tenderizer/Tenderizer.sol";
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
    address private tenderizer = address(new Tenderizer(registry, unlocks));

    function setUp() public {
        vm.mockCall(registry, abi.encodeCall(Registry.tenderizer, ()), abi.encode(tenderizer));
        vm.mockCall(registry, abi.encodeCall(Registry.unlocks, ()), abi.encode(unlocks));
        factory = new Factory(registry);
    }

    function test_InitialStorage() public {
        assertEq(factory.registry(), registry, "registry not set");
        assertEq(factory.tenderizerImpl(), address(tenderizer), "tenderizer not set");
    }

    function test_NewTenderizer() public {
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(adapter));
        vm.mockCall(adapter, abi.encodeCall(Adapter.isValidator, (validator)), abi.encode(true));
        vm.mockCall(registry, abi.encodeCall(Registry.registerTenderizer, (asset, validator, tenderizer)), "");
        vm.expectCall(registry, abi.encodeCall(Registry.adapter, (asset)));

        address payable newTenderizer = payable(factory.newTenderizer(asset, validator));
        assertEq(newTenderizer, 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac, "tenderizer not created with correct address");
        assertEq(Tenderizer(newTenderizer).asset(), asset, "asset not set");
        assertEq(Tenderizer(newTenderizer).validator(), validator, "validator not set");
    }

    function test_NewTenderizer_RevertIfNoAdapter() public {
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(address(0)));

        vm.expectCall(registry, abi.encodeCall(Registry.adapter, (asset)));
        vm.expectRevert(abi.encodeWithSelector(Factory.InvalidAsset.selector, asset));
        factory.newTenderizer(asset, validator);
    }

    function test_NewTenderizer_RevertIfNotValidator() public {
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(adapter));
        vm.mockCall(adapter, abi.encodeCall(Adapter.isValidator, (validator)), abi.encode(false));

        vm.expectCall(registry, abi.encodeCall(Registry.adapter, (asset)));
        vm.expectCall(adapter, abi.encodeCall(Adapter.isValidator, (validator)));
        vm.expectRevert(abi.encodeWithSelector(Factory.NotValidator.selector, validator));
        factory.newTenderizer(asset, validator);
    }
}
