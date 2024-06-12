// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { FACTORY_ROLE } from "core/lst/registry/Roles.sol";
import { Renderer } from "core/lst/unlocks/Renderer.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Factory } from "core/lst/factory/Factory.sol";

struct LiquifierFixture {
    Registry registry_impl;
    Registry registry;
    Renderer renderer_impl;
    Renderer renderer;
    Unlocks unlocks;
    Liquifier liquifier;
    Factory factory;
}

function liquifierFixture() returns (LiquifierFixture memory) {
    bytes32 salt = bytes32(uint256(1));

    Registry registry = new Registry{ salt: salt }();
    address registryProxy = address(new ERC1967Proxy{ salt: salt }(address(registry), ""));

    Renderer renderer = new Renderer{ salt: salt }();
    ERC1967Proxy rendererProxy = new ERC1967Proxy{ salt: salt }(address(renderer), abi.encodeCall(renderer.initialize, ()));
    Unlocks unlocks = new Unlocks{ salt: salt }(address(registryProxy), address(rendererProxy));

    Liquifier liquifier = new Liquifier{ salt: salt }(registryProxy, address(unlocks));

    Registry(registryProxy).initialize(address(liquifier), address(unlocks));

    Factory factory = new Factory{ salt: salt }(address(registryProxy));

    Registry(registryProxy).grantRole(FACTORY_ROLE, address(factory));

    return LiquifierFixture({
        registry_impl: registry,
        registry: Registry(registryProxy),
        renderer_impl: renderer,
        renderer: Renderer(address(rendererProxy)),
        unlocks: unlocks,
        liquifier: liquifier,
        factory: factory
    });
}
