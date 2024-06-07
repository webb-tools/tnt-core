// SPDX-License-Identifier: MIT
//
//  _____              _           _
// |_   _|            | |         (_)
//   | | ___ _ __   __| | ___ _ __ _ _______
//   | |/ _ \ '_ \ / _` |/ _ \ '__| |_  / _ \
//   | |  __/ | | | (_| |  __/ |  | |/ /  __/
//   \_/\___|_| |_|\__,_|\___|_|  |_/___\___|
//
// Copyright (c) Tenderize Labs Ltd

// solhint-disable no-console

pragma solidity >=0.8.19;

import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Tenderizer } from "core/lst/tenderizer/Tenderizer.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { FACTORY_ROLE } from "core/lst/registry/Roles.sol";
import { Renderer } from "core/lst/unlocks/Renderer.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Factory } from "core/lst/factory/Factory.sol";

struct TenderizerFixture {
    Registry registry_impl;
    Registry registry;
    Renderer renderer_impl;
    Renderer renderer;
    Unlocks unlocks;
    Tenderizer tenderizer;
    Factory factory;
}

function tenderizerFixture() returns (TenderizerFixture memory) {
    bytes32 salt = bytes32(uint256(1));

    Registry registry = new Registry{ salt: salt }();
    address registryProxy = address(new ERC1967Proxy{ salt: salt }(address(registry), ""));

    Renderer renderer = new Renderer{ salt: salt }();
    ERC1967Proxy rendererProxy = new ERC1967Proxy{ salt: salt }(address(renderer), abi.encodeCall(renderer.initialize, ()));
    Unlocks unlocks = new Unlocks{ salt: salt }(address(registryProxy), address(rendererProxy));

    Tenderizer tenderizer = new Tenderizer{ salt: salt }(registryProxy, address(unlocks));

    Registry(registryProxy).initialize(address(tenderizer), address(unlocks));

    Factory factory = new Factory{ salt: salt }(address(registryProxy));

    Registry(registryProxy).grantRole(FACTORY_ROLE, address(factory));

    return TenderizerFixture({
        registry_impl: registry,
        registry: Registry(registryProxy),
        renderer_impl: renderer,
        renderer: Renderer(address(rendererProxy)),
        unlocks: unlocks,
        tenderizer: tenderizer,
        factory: factory
    });
}
