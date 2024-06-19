// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { StakingXYZ } from "../test/helpers/StakingXYZ.sol";
import { XYZAdapter } from "../test/helpers/XYZAdapter.sol";
import { Registry } from "core/lst/registry/Registry.sol";

import { Factory } from "core/lst/factory/Factory.sol";

uint256 constant VERSION = 1;

contract XYZ_Deploy is Script {
    bytes32 private constant salt = bytes32(VERSION);

    function run() public {
        address registry = vm.envAddress("REGISTRY");

        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");

        uint256 unlockTime = vm.envUint("UNLOCK_TIME");
        uint256 baseAPR = vm.envUint("BASE_APR");
        uint256 totalSupply = vm.envUint("TOTAL_SUPPLY");

        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);
        address me = vm.addr(privKey);

        MockERC20 XYZ = new MockERC20{ salt: salt }(name, symbol, 18);
        console2.log(string.concat(symbol, " Token: "), address(XYZ));
        // mint supply
        XYZ.mint(me, totalSupply);
        StakingXYZ stakingXYZ = new StakingXYZ{ salt: salt }(address(XYZ), unlockTime, baseAPR);
        console2.log(string.concat(symbol, " Staking: "), address(stakingXYZ));
        XYZAdapter adapter = new XYZAdapter{ salt: salt }(address(stakingXYZ), address(XYZ));
        console2.log(string.concat(symbol, " Adapter: "), address(adapter));
        // Register XYZ adapter
        Registry(registry).registerAdapter(address(XYZ), address(adapter));
    }
}
