// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { FACTORY_ROLE } from "core/lst/registry/Roles.sol";
import { Renderer } from "core/lst/unlocks/Renderer.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Factory } from "core/lst/factory/Factory.sol";

uint256 constant VERSION = 1;

contract Liquifie_Deploy is Script {
    // Contracts are deployed deterministically.
    // e.g. `foo = new Foo{salt: salt}(constructorArgs)`
    // The presence of the salt argument tells forge to use https://github.com/Arachnid/deterministic-deployment-proxy
    bytes32 private constant salt = bytes32(VERSION);

    function run() public {
        string memory json_output;

        // Start broadcasting with private key from `.env` file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Registry (without initialization)
        // - Deploy Registry Implementation
        Registry registry = new Registry{ salt: salt }();
        vm.serializeAddress(json_output, "registry_implementation", address(registry));
        // - Deploy Registry UUPS Proxy
        address registryProxy = address(new ERC1967Proxy{ salt: salt }(address(registry), ""));
        vm.serializeAddress(json_output, "registry_proxy", registryProxy);
        console2.log("Registry Implementation: ", address(registry));
        console2.log("Registry Proxy: ", registryProxy);

        // 2. Deploy Unlocks
        // - Deploy Renderer Implementation
        Renderer renderer = new Renderer{ salt: salt }();
        vm.serializeAddress(json_output, "renderer_implementation", address(renderer));
        // - Deploy Renderer UUPS Proxy
        ERC1967Proxy rendererProxy = new ERC1967Proxy{ salt: salt }(address(renderer), abi.encodeCall(renderer.initialize, ()));
        vm.serializeAddress(json_output, "renderer_proxy", address(rendererProxy));
        // - Deploy Unlocks
        Unlocks unlocks = new Unlocks{ salt: salt }(address(registryProxy), address(rendererProxy));
        vm.serializeAddress(json_output, "unlocks", address(unlocks));
        console2.log("Renderer Implementation: ", address(renderer));
        console2.log("Renderer Proxy: ", address(rendererProxy));
        console2.log("Unlocks: ", address(unlocks));

        // 3. Deploy Liquifier Implementation
        Liquifier liquifier = new Liquifier{ salt: salt }(registryProxy, address(unlocks));
        vm.serializeAddress(json_output, "liquifier_implementation", address(liquifier));
        console2.log("Liquifier Implementation: ", address(liquifier));

        // 4. Initialize Registry
        Registry(registryProxy).initialize(address(liquifier), address(unlocks));

        // 5. Deploy Factory
        Factory factory = new Factory{ salt: salt }(address(registryProxy));
        vm.serializeAddress(json_output, "factory", address(factory));
        // - Grant Factory role to Factory
        Registry(registryProxy).grantRole(FACTORY_ROLE, address(factory));
        console2.log("Factory: ", address(factory));

        vm.stopBroadcast();

        // Write json_output to file
        // vm.writeJson(json_output, "deployments.json");
    }
}
