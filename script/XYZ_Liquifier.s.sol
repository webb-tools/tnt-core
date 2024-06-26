// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { Factory } from "core/lst/factory/Factory.sol";

contract XYZ_Liquifier is Script {
    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);

        address factoryAddress = vm.envAddress("FACTORY");
        Factory factory = Factory(factoryAddress);

        address tokenAddress = vm.envAddress("TOKEN");
        address validatorAddress = vm.addr(5);

        address newLiquifier = factory.newLiquifier(tokenAddress, validatorAddress);
        console2.log("LPT Liquifier Address: ", newLiquifier);

        vm.stopBroadcast();
    }
}
