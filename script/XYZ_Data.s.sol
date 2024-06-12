// SPDX-License-Identifier: UNLICENSED

// solhint-disable no-console

pragma solidity >=0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { StakingXYZ } from "../test/helpers/StakingXYZ.sol";
import { XYZAdapter } from "../test/helpers/XYZAdapter.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { Factory } from "core/lst/factory/Factory.sol";

contract XYZ_Data is Script {
    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);
        Liquifier t = Liquifier(payable(address(0x61F9f8De77D9AA02432F4014DC1Ed4311372Ce71)));
        MockERC20 e = MockERC20(0x9623063377AD1B27544C965cCd7342f7EA7e88C7);
        e.approve(address(t), e.balanceOf(0x3F717b0F5270311C011A48d46ca7A67F7e37c015) / 2);
        uint256 am =
            t.deposit(0x3F717b0F5270311C011A48d46ca7A67F7e37c015, e.balanceOf(0x3F717b0F5270311C011A48d46ca7A67F7e37c015) / 2);
    }
}
