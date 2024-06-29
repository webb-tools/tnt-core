// SPDX-License-Identifier: UNLICENSED
// solhint-disable max-line-length
// solhint-disable func-name-mixedcase

pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";
import { ChainlinkAdapter, LINK, CHAINLINK_STAKING } from "core/lst/adapters/ChainlinkAdapter.sol";
import { IERC20 } from "core/lst/interfaces/IERC20.sol";
import { TestHelpers } from "test/helpers/Helpers.sol";

contract ChainlinkAdapterTest is Test, ChainlinkAdapter, TestHelpers {
    address private staking = address(CHAINLINK_STAKING);
    address private token = address(LINK);
    address private validator = vm.addr(1);

    function setUp() public {
        vm.etch(staking, bytes("code"));
    }

    function testFuzz_PreviewDeposit(uint256 amount) public {
        amount = bound(amount, 1, 10e32);
        assertEq(this.previewDeposit(validator, amount), amount);
    }
}
