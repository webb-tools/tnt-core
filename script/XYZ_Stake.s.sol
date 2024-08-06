// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { StakingXYZ } from "../test/helpers/StakingXYZ.sol";
import { XYZAdapter } from "../test/helpers/XYZAdapter.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { Registry } from "core/lst/registry/Registry.sol";

contract XYZ_Stake is Script {
    function run() public {
        // Get private key from environment
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        // Start broadcasting transactions using the private key
        vm.startBroadcast(privKey);

        // Get LPT token address from environment
        address tokenAddress = vm.envAddress("TOKEN");
        ERC20 token = ERC20(tokenAddress);

        // Get Liquifier contract address from environment
        address liquifierAddress = vm.envAddress("LIQUIFIER");
        Liquifier liquifier = Liquifier(payable(liquifierAddress));

        // Get sender's address
        address sender = vm.addr(privKey);

        // Log initial balances
        console2.log("Initial LPT Token balance", token.balanceOf(sender));
        console2.log("Initial tgLPT Token balance", liquifier.balanceOf(sender));

        // Approve Liquifier contract to spend 1000 LPT tokens
        uint256 depositAmount = 1000 * (10 ** uint256(token.decimals())); // 1000 LPT tokens
        token.approve(address(liquifier), depositAmount);

        // Deposit LPT tokens into Liquifier
        uint256 receivedAmount = liquifier.deposit(sender, depositAmount);
        console2.log("Deposited LPT Tokens", receivedAmount);

        // Log updated balances after deposit
        console2.log("Updated LPT Token balance", token.balanceOf(sender));
        console2.log("Updated tgLPT Token balance", liquifier.balanceOf(sender));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
