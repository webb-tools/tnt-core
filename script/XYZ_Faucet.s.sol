// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { StakingXYZ } from "../test/helpers/StakingXYZ.sol";
import { XYZAdapter } from "../test/helpers/XYZAdapter.sol";
import { Registry } from "core/lst/registry/Registry.sol";

import { Factory } from "core/lst/factory/Factory.sol";
import { TokenFaucet } from "../test/helpers/Faucet.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract XYZ_Faucet is Script {
    bytes32 private constant salt = bytes32(uint256(1));

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);

        address tokenAddress = vm.envAddress("TOKEN");
        ERC20 token = ERC20(tokenAddress);
        uint256 seedAmount = vm.envUint("SEED_AMOUNT");
        uint256 cooldown = vm.envUint("COOLDOWN");
        uint256 requestAmount = vm.envUint("REQUEST_AMOUNT");

        address me = vm.addr(privKey);
        console2.log("privKey", privKey);
        console2.log("me", me);
        console2.log("balance", token.balanceOf(me));

        cooldown = cooldown != 0 ? cooldown : 1 days;
        requestAmount = requestAmount != 0 ? requestAmount : 1000 ether;

        address faucet = address(new TokenFaucet{ salt: salt }(token, requestAmount, cooldown));
        token.transfer(faucet, seedAmount);

        console2.log("Faucet: ", faucet);
    }
}
