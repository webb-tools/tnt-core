// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test, stdError } from "forge-std/Test.sol";
import { TestHelpers } from "test/helpers/Helpers.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { IERC20, IERC20Metadata } from "core/lst/interfaces/IERC20.sol";
import { Adapter, LiquifierHarness } from "test/liquifier/Liquifier.harness.sol";
import { AdapterDelegateCall } from "core/lst/adapters/Adapter.sol";
import { LiquifierEvents } from "core/lst/liquifier/LiquifierBase.sol";
import { StaticCallFailed } from "core/lst/utils/StaticCall.sol";
import { TgToken } from "core/lst/liquidtoken/TgToken.sol";
import { Unlocks } from "core/lst/unlocks/Unlocks.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { ClonesWithImmutableArgs } from "clones/ClonesWithImmutableArgs.sol";
import { addressToString } from "core/lst/utils/Utils.sol";

contract LiquifierSetup is Test, TestHelpers {
    using ClonesWithImmutableArgs for address;

    uint256 internal constant MAX_UINT = type(uint256).max;
    uint256 internal MAX_UINT_SQRT = sqrt(MAX_UINT - 1);

    uint256 internal constant MAX_FEE = 0.005e6;

    address internal asset = vm.addr(1);
    address internal staking = vm.addr(2);

    LiquifierHarness internal liquifier;
    address internal registry = vm.addr(3);
    address internal adapter = vm.addr(4);
    address internal unlocks = vm.addr(5);

    address internal account1 = vm.addr(6);
    address internal account2 = vm.addr(7);

    address internal validator = vm.addr(8);
    address internal treasury = vm.addr(9);

    bytes internal constant ERROR_MESSAGE = "ADAPTER_CALL_FAILED";

    string internal symbol = "FOO";

    function setUp() public {
        vm.etch(registry, bytes("code"));
        vm.etch(adapter, bytes("code"));
        vm.etch(asset, bytes("code"));
        vm.etch(staking, bytes("code"));
        vm.etch(unlocks, bytes("code"));
        // Setup global mock responses
        vm.mockCall(registry, abi.encodeCall(Registry.adapter, (asset)), abi.encode(adapter));
        vm.mockCall(registry, abi.encodeCall(Registry.fee, (asset)), abi.encode(0.05 ether));
        vm.mockCall(registry, abi.encodeCall(Registry.treasury, ()), abi.encode(treasury));
        vm.mockCall(asset, abi.encodeCall(IERC20Metadata.symbol, ()), abi.encode(symbol));

        liquifier =
            LiquifierHarness(payable(address(new LiquifierHarness(registry, unlocks)).clone(abi.encodePacked(asset, validator))));
    }
}

// solhint-disable func-name-mixedcase
contract LiquifierTest is LiquifierSetup, LiquifierEvents {
    function test_Name() public {
        vm.expectCall(asset, abi.encodeCall(IERC20Metadata.symbol, ()));
        assertEq(liquifier.name(), string.concat("liquid ", symbol, "-", addressToString(validator)), "invalid name");
    }

    function test_Symbol() public {
        vm.expectCall(asset, abi.encodeCall(IERC20Metadata.symbol, ()));
        assertEq(liquifier.symbol(), string.concat("tg", symbol, "-", addressToString(validator)), "invalid name");
    }

    function test_InitialVaules() public {
        assertEq(address(liquifier.asset()), asset, "invalid asset");
        assertEq(address(liquifier.validator()), validator, "invalid validator");
        assertEq(address(liquifier.exposed_registry()), registry, "invalid registry");
        assertEq(address(liquifier.exposed_unlocks()), unlocks, "invalid unlocks");
        assertEq(address(liquifier.adapter()), adapter, "invalid adapter");
    }

    function test_PreviewDeposit() public {
        uint256 amountIn = 100 ether;
        uint256 amountOut = 99.5 ether;
        vm.mockCall(adapter, abi.encodeCall(Adapter.previewDeposit, (validator, amountIn)), abi.encode(amountOut));
        vm.expectCall(adapter, abi.encodeCall(Adapter.previewDeposit, (validator, amountIn)));
        assertEq(liquifier.previewDeposit(amountIn), amountOut);
    }

    function test_PreviewDeposit_RevertIfAdapterReverts() public {
        vm.mockCallRevert(adapter, abi.encodeCall(Adapter.previewDeposit, (validator, 1 ether)), ERROR_MESSAGE);
        vm.expectRevert(
            abi.encodeWithSelector(
                StaticCallFailed.selector, address(liquifier), abi.encodeCall(liquifier._previewDeposit, (1 ether)), ""
            )
        );
        liquifier.previewDeposit(1 ether);
    }

    function test_UnlockMaturity() public {
        uint256 unlockID = 1;
        uint256 unlockTime = block.timestamp;
        vm.mockCall(adapter, abi.encodeCall(Adapter.unlockMaturity, (unlockID)), abi.encode(unlockTime));
        vm.expectCall(adapter, abi.encodeCall(Adapter.unlockMaturity, (unlockID)));
        assertEq(liquifier.unlockMaturity(unlockID), unlockTime);
    }

    function test_PreviewWithdraw() public {
        uint256 amount = 1 ether;
        uint256 unlockID = 1;
        vm.mockCall(adapter, abi.encodeCall(Adapter.previewWithdraw, (unlockID)), abi.encode(amount));
        vm.expectCall(adapter, abi.encodeCall(Adapter.previewWithdraw, (unlockID)));
        assertEq(liquifier.previewWithdraw(unlockID), amount);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, MAX_UINT_SQRT);
        _deposit(account1, amount, 0);
        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, amount)), abi.encode(amount));

        vm.prank(account1);
        vm.expectCall(adapter, abi.encodeCall(Adapter.rebase, (validator, amount)));
        vm.expectCall(address(liquifier), abi.encodeCall(TgToken.transfer, (account2, amount)));
        liquifier.transfer(account2, amount);
    }

    function testFuzz_TransferFrom(uint256 amount) public {
        amount = bound(amount, 1, MAX_UINT_SQRT);
        _deposit(account1, amount, 0);

        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, amount)), abi.encode(amount));
        vm.expectCall(adapter, abi.encodeCall(Adapter.rebase, (validator, amount)));
        vm.expectCall(address(liquifier), abi.encodeCall(TgToken.transferFrom, (account1, account2, amount)));
        vm.prank(account1);
        liquifier.approve(account2, amount);
        vm.prank(account2);
        liquifier.transferFrom(account1, account2, amount);
    }

    function testFuzz_Deposit(uint256 amountIn, uint256 amountOut) public {
        amountIn = bound(amountIn, 1, MAX_UINT_SQRT);
        amountOut = bound(amountOut, 1, MAX_UINT_SQRT);

        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, 0)), abi.encode(0));
        vm.mockCall(asset, abi.encodeCall(IERC20.transferFrom, (account1, address(liquifier), amountIn)), abi.encode(true));
        vm.mockCall(adapter, abi.encodeCall(Adapter.stake, (validator, amountIn)), abi.encode(amountOut));
        vm.expectCall(adapter, abi.encodeCall(Adapter.rebase, (validator, 0)));
        vm.expectCall(asset, abi.encodeCall(IERC20.transferFrom, (account1, address(liquifier), amountIn)));
        vm.expectCall(adapter, abi.encodeCall(Adapter.stake, (validator, amountIn)));
        vm.prank(account1);

        vm.expectEmit(true, true, true, true);
        emit Deposit(account1, account2, amountIn, amountOut);
        uint256 actualAssets = liquifier.deposit(account2, amountIn);

        assertEq(actualAssets, amountOut, "invalid return value");
        assertEq(liquifier.balanceOf(address(account2)), amountOut, "mint failed");
    }

    function test_Deposit_RevertIfStakeReverts() public {
        uint256 depositAmount = 100 ether;
        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, 0)), abi.encode(0));
        vm.mockCall(adapter, abi.encodeCall(Adapter.previewDeposit, (validator, depositAmount)), abi.encode(depositAmount));
        vm.mockCallRevert(
            adapter,
            abi.encodeCall(Adapter.stake, (validator, depositAmount)),
            abi.encodeWithSignature("Error(string)", ERROR_MESSAGE)
        );
        vm.expectRevert(abi.encodeWithSelector(AdapterDelegateCall.AdapterDelegateCallFailed.selector, ERROR_MESSAGE));
        liquifier.deposit(account1, depositAmount);
    }

    function test_Deposit_RevertIfZeroAmount() public {
        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, 0)), abi.encode(0));
        vm.mockCall(adapter, abi.encodeCall(Adapter.stake, (validator, 0)), abi.encode(0));
        vm.expectRevert(TgToken.ZeroAmount.selector);
        liquifier.deposit(account1, 0);
    }

    function test_Deposit_RevertIfAssetTransferFails() public {
        uint256 depositAmount = 100 ether;
        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, 0)), abi.encode(0));
        vm.mockCall(adapter, abi.encodeCall(Adapter.previewDeposit, (validator, depositAmount)), abi.encode(depositAmount));
        vm.mockCall(asset, abi.encodeCall(IERC20.transferFrom, (account1, address(liquifier), depositAmount)), abi.encode(false));
        vm.prank(account1);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        liquifier.deposit(account1, depositAmount);
    }

    function testFuzz_Unlock(uint256 amount) public {
        uint256 depositAmount = 100 ether;
        uint256 unlockID = 1;
        amount = bound(amount, 1, depositAmount);

        _unlockPreReq(account1, depositAmount, amount, unlockID);

        vm.expectCall(adapter, abi.encodeCall(Adapter.rebase, (validator, depositAmount)));
        vm.expectCall(adapter, abi.encodeCall(Adapter.unstake, (validator, amount)));
        vm.expectCall(unlocks, abi.encodeCall(Unlocks.createUnlock, (account1, unlockID)));
        vm.expectEmit(true, true, true, true);
        emit Unlock(account1, amount, unlockID);
        vm.prank(account1);
        uint256 returnedUnlockID = liquifier.unlock(amount);

        assertEq(returnedUnlockID, unlockID, "invalid return value");
        assertEq(liquifier.balanceOf(account1), depositAmount - amount, "burn failed");
    }

    function test_Unlock_RevertIfAdapterCallReverts() public {
        uint256 depositAmount = 100 ether;
        uint256 unlockAmount = 10 ether;
        _unlockPreReq(account1, depositAmount, unlockAmount, 1);

        vm.mockCallRevert(
            adapter,
            abi.encodeCall(Adapter.unstake, (validator, unlockAmount)),
            abi.encodeWithSignature("Error(string)", ERROR_MESSAGE)
        );

        vm.prank(account1);
        vm.expectRevert(abi.encodeWithSelector(AdapterDelegateCall.AdapterDelegateCallFailed.selector, ERROR_MESSAGE));
        liquifier.unlock(unlockAmount);
    }

    function test_unlock_RevertIfCreateUnlockFails() public {
        uint256 depositAmount = 100 ether;
        uint256 unlockAmount = 10 ether;
        uint256 unlockID = 1;
        _unlockPreReq(account1, depositAmount, unlockAmount, unlockID);

        vm.mockCall(adapter, abi.encodeCall(Adapter.unstake, (validator, unlockAmount)), abi.encode(unlockID));
        vm.mockCallRevert(
            unlocks,
            abi.encodeCall(Unlocks.createUnlock, (account1, unlockID)),
            abi.encodeWithSignature("Error(string)", ERROR_MESSAGE)
        );

        vm.prank(account1);
        vm.expectRevert(ERROR_MESSAGE);
        liquifier.unlock(unlockAmount);
    }

    function test_Unlock_RevertIfZeroAmount() public {
        _unlockPreReq(account1, 1 ether, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(TgToken.ZeroAmount.selector));
        liquifier.unlock(0);
    }

    function test_Unlock_RevertIfNotEnoughLiquidTokens() public {
        uint256 depositAmount = 100 ether;
        uint256 unlockAmount = depositAmount + 1;

        _unlockPreReq(account1, depositAmount, unlockAmount, 0);

        vm.prank(account1);
        vm.expectRevert(stdError.arithmeticError);
        liquifier.unlock(unlockAmount);
    }

    function testFuzz_Withdraw(uint256 amount) public {
        uint256 depositAmount = 100 ether;
        uint256 unlockID = 1;
        amount = bound(amount, 1, depositAmount);

        vm.mockCall(unlocks, abi.encodeCall(Unlocks.useUnlock, (account1, unlockID)), "");
        vm.mockCall(adapter, abi.encodeCall(Adapter.withdraw, (validator, unlockID)), abi.encode(amount));

        vm.expectCall(unlocks, abi.encodeCall(Unlocks.useUnlock, (account1, unlockID)));
        vm.expectCall(asset, abi.encodeCall(IERC20.transfer, (account2, amount)));
        vm.expectEmit(true, true, true, true);
        emit Withdraw(account2, amount, unlockID);
        vm.prank(account1);
        uint256 returnedAssets = liquifier.withdraw(account2, unlockID);

        assertEq(returnedAssets, amount, "invalid return value");
    }

    function test_Withdraw_RevertIfAdapterCallReverts() public {
        uint256 unlockID = 1;
        vm.mockCall(unlocks, abi.encodeCall(Unlocks.useUnlock, (account1, unlockID)), "");
        vm.mockCallRevert(
            adapter,
            abi.encodeCall(Adapter.withdraw, (validator, unlockID)),
            abi.encodeWithSignature("Error(string)", ERROR_MESSAGE)
        );

        vm.expectRevert(abi.encodeWithSelector(AdapterDelegateCall.AdapterDelegateCallFailed.selector, ERROR_MESSAGE));
        liquifier.withdraw(account1, unlockID);
    }

    function test_Withdraw_RevertIfUseUnlockFails() public {
        uint256 unlockID = 1;
        // Calls to mocked addresses may revert if there is no code on the address.
        // To circumvent this, use the etch cheatcode if the mocked address has no code.
        // From https://book.getfoundry.sh/cheatcodes/mock-call
        vm.etch(unlocks, "0");
        vm.mockCallRevert(
            unlocks,
            abi.encodeCall(Unlocks.useUnlock, (account1, unlockID)),
            abi.encodeWithSignature("Error(string)", ERROR_MESSAGE)
        );

        vm.prank(account1);
        vm.expectRevert(ERROR_MESSAGE);
        liquifier.withdraw(account2, unlockID);
    }

    function testFuzz_Rebase_Positive(uint256 depositSeed, uint256 rewards, uint256 feeRate) public {
        uint256 deposit1 = rand(depositSeed, 0, 1, MAX_UINT_SQRT / 4);
        uint256 deposit2 = rand(depositSeed, 1, 1, MAX_UINT_SQRT / 4);
        uint256 totalDeposit = deposit1 + deposit2;
        // new stake can at most double
        // newStake >>> totalShares causes larger errors in calculations
        rewards = bound(rewards, 0, 2 * totalDeposit);
        feeRate = bound(feeRate, 0, 2 ether);
        uint256 newStake = totalDeposit + rewards;

        _deposit(account1, deposit1, 0);
        _deposit(account2, deposit2, deposit1);

        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, totalDeposit)), abi.encode(newStake));
        vm.mockCall(registry, abi.encodeCall(Registry.fee, (asset)), abi.encode(feeRate));

        uint256 cappedFeeRate = feeRate > MAX_FEE ? MAX_FEE : feeRate;
        uint256 expFees = ((newStake - totalDeposit) * cappedFeeRate) / 1e6;

        vm.expectEmit(true, true, true, true);
        emit Rebase(totalDeposit, newStake);
        liquifier.rebase();

        assertLt(absDiff(liquifier.totalSupply(), newStake), 5, "invalid totalSupply");
        assertLt(
            absDiff(liquifier.balanceOf(account1), (newStake - expFees) * deposit1 / totalDeposit), 5, "invalid account1 balance"
        );
        assertLt(
            absDiff(liquifier.balanceOf(account2), (newStake - expFees) * deposit2 / totalDeposit), 5, "invalid account2 balance"
        );
        assertLt(absDiff(liquifier.balanceOf(address(treasury)), expFees), 5, "invalid fees minted");
    }

    function testFuzz_Rebase_Negative(uint256 depositSeed, uint256 slash) public {
        uint256 deposit1 = rand(depositSeed, 0, 1, MAX_UINT_SQRT / 4);
        uint256 deposit2 = rand(depositSeed, 1, 1, MAX_UINT_SQRT / 4);
        uint256 totalDeposit = deposit1 + deposit2;
        slash = bound(slash, 0, totalDeposit);
        uint256 newStake = totalDeposit - slash;

        _deposit(account1, deposit1, 0);
        _deposit(account2, deposit2, deposit1);

        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, totalDeposit)), abi.encode(newStake));
        vm.mockCall(registry, abi.encodeCall(Registry.fee, (asset)), abi.encode(0.01 ether));

        vm.expectEmit(true, true, true, true);
        emit Rebase(totalDeposit, newStake);
        liquifier.rebase();

        assertEq(liquifier.totalSupply(), newStake, "invalid totalSupply");
        assertEq(liquifier.balanceOf(account1), (newStake * deposit1) / totalDeposit, "invalid account1 balance");
        assertEq(liquifier.balanceOf(account2), (newStake * deposit2) / totalDeposit, "invalid account2 balance");
    }

    function test_Rebase_Neutral() public {
        uint256 deposit1 = 1 ether;
        uint256 deposit2 = 2 ether;
        uint256 totalDeposit = deposit1 + deposit2;

        _deposit(account1, deposit1, 0);
        _deposit(account2, deposit2, deposit1);

        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, totalDeposit)), abi.encode(totalDeposit));
        vm.mockCall(registry, abi.encodeCall(Registry.fee, (asset)), abi.encode(0.01 ether));

        vm.expectEmit(true, true, true, true);
        emit Rebase(totalDeposit, totalDeposit);
        liquifier.rebase();

        assertEq(liquifier.totalSupply(), totalDeposit, "invalid totalSupply");
        assertEq(liquifier.balanceOf(account1), deposit1, "invalid account1 balance");
        assertEq(liquifier.balanceOf(account2), deposit2, "invalid account2 balance");
    }

    function _deposit(address account, uint256 amount, uint256 totalPreviousDeposits) internal {
        vm.mockCall(adapter, abi.encodeCall(Adapter.previewDeposit, (validator, amount)), abi.encode(amount));
        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, totalPreviousDeposits)), abi.encode(totalPreviousDeposits));
        vm.mockCall(adapter, abi.encodeCall(Adapter.stake, (validator, amount)), abi.encode(amount));

        vm.prank(account);
        liquifier.deposit(account, amount);
    }

    function _unlockPreReq(address account, uint256 depositAmount, uint256 unlockAmount, uint256 unlockID) internal {
        _deposit(account, depositAmount, 0);

        vm.mockCall(adapter, abi.encodeCall(Adapter.unstake, (validator, unlockAmount)), abi.encode(unlockID));
        vm.mockCall(unlocks, abi.encodeCall(Unlocks.createUnlock, (account1, unlockID)), abi.encode(unlockID));
        vm.mockCall(adapter, abi.encodeCall(Adapter.rebase, (validator, depositAmount)), abi.encode(depositAmount));
    }
}
