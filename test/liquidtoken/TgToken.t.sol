// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test, stdError } from "forge-std/Test.sol";
import { TestHelpers } from "test/helpers/Helpers.sol";
import { IERC20 } from "core/lst/interfaces/IERC20.sol";
import { TgToken } from "core/lst/liquidtoken/TgToken.sol";

// solhint-disable func-name-mixedcase
// solhint-disable no-empty-blocks

contract TokenSetup is TestHelpers, Test, TgToken {
    uint256 public MAX_UINT_SQRT = sqrt(type(uint256).max - 1);

    function name() public view override returns (string memory) { }

    function symbol() public view override returns (string memory) { }

    address public account1 = vm.addr(1);
    address public account2 = vm.addr(2);
    address public account3 = vm.addr(3);
}

// Inheriting TgTokenHarness only to get events
contract TgTokenTest is TokenSetup {
    function test_Metadata() public {
        assertEq(decimals(), uint8(18), "invalid decimals");
    }

    function testFuzz_ShareCalc(uint256 amount, uint256 totalShares, uint256 totalSupply) public {
        amount = bound(amount, 1, MAX_UINT_SQRT);
        totalShares = bound(totalShares, 1, MAX_UINT_SQRT);
        totalSupply = bound(totalSupply, 1, MAX_UINT_SQRT);

        assertEq(convertToShares(amount), amount, "invalid share conversion - no shares/supply");
        assertEq(convertToAssets(amount), amount, "invalid asset conversion - no shares/supply");

        Storage storage $ = _loadStorage();

        // non-zero supply and shares
        $._totalShares = totalShares;
        $._totalSupply = totalSupply;
        assertEq(convertToShares(amount), amount * totalShares / totalSupply, "invalid share conversion");
        assertEq(convertToAssets(amount), amount * totalSupply / totalShares, "invalid asset conversion");

        // zero supply
        $._totalSupply = 0;
        assertEq(convertToShares(amount), amount, "invalid share conversion - no shares");
        assertEq(convertToAssets(amount), 0, "invalid asset conversion - no shares/supply");

        // zero shares
        $._totalShares = 0;
        assertEq(convertToShares(amount), amount, "invalid share conversion - no shares");
        assertEq(convertToAssets(amount), amount, "invalid asset conversion - no shares");
    }

    function testFuzz_BalanceOf(uint256 shares, uint256 totalShares, uint256 totalSupply) public {
        shares = bound(shares, 1, MAX_UINT_SQRT / 2);
        totalShares = bound(shares, 1, MAX_UINT_SQRT / 2);
        totalSupply = bound(shares, 1, MAX_UINT_SQRT / 2);

        Storage storage $ = _loadStorage();
        $.shares[account1] = shares;
        $._totalSupply = totalSupply;
        $._totalShares = totalShares;

        assertEq(balanceOf(account1), shares * totalSupply / totalShares, "invalid balance");
        assertEq(balanceOf(account2), 0, "invalid balance - no tokens");
    }

    function testFuzz_Approve(uint256 amountSeed) public {
        uint256 amount1 = rand(amountSeed, 0, 0, MAX_UINT_SQRT);
        uint256 amount2 = rand(amountSeed, 1, 0, MAX_UINT_SQRT);

        // with no prior approval
        vm.expectEmit(true, true, true, true);
        emit Approval(account1, account2, amount1);

        vm.prank(account1);
        assertTrue(this.approve(account2, amount1), "invalid return value");
        assertEq(this.allowance(account1, account2), amount1, "invalid allowance");
        assertEq(this.allowance(account1, account3), 0, "invalid allowance other account");

        // with already exisitng approval
        vm.prank(account1);
        assertTrue(this.approve(account2, amount2), "invalid return value - exisiting approval");
        assertEq(this.allowance(account1, account2), amount2, "invalid allowance - exisiting approval");
    }

    function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT);
        transferAmount = bound(transferAmount, 0, mintAmount);

        _mint(account1, mintAmount);

        vm.prank(account1);
        assertTrue(this.transfer(account2, transferAmount), "invalid return value");
        assertEq(totalSupply(), mintAmount, "invalid supply");
        assertEq(balanceOf(account1), mintAmount - transferAmount, "invalid sender balance");
        assertEq(balanceOf(account2), transferAmount, "invalid receiver balance");
    }

    function testFuzz_Transfer_RevertIfNotEnoughBalance(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT - 1);
        transferAmount = bound(transferAmount, mintAmount + 1, MAX_UINT_SQRT);

        _mint(account1, mintAmount);

        vm.prank(account1);
        vm.expectRevert(stdError.arithmeticError);
        assertFalse(this.transfer(account2, transferAmount), "invalid return value");
    }

    function testFuzz_TransferFrom(uint256 mintAmount, uint256 approveAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT);
        approveAmount = bound(approveAmount, 1, mintAmount);
        transferAmount = bound(transferAmount, 1, approveAmount);

        _mint(account1, mintAmount);

        vm.prank(account1);
        this.approve(account2, approveAmount);

        vm.prank(account2);
        vm.expectEmit(true, true, true, true);
        emit Transfer(account1, account3, transferAmount);

        assertTrue(this.transferFrom(account1, account3, transferAmount), "invalid return value");
        assertEq(totalSupply(), mintAmount, "invalid supply");
        assertEq(balanceOf(account1), mintAmount - transferAmount, "invalid sender balance");
        assertEq(balanceOf(account2), 0, "invalid caller balance");
        assertEq(balanceOf(account3), transferAmount, "invalid receiver balance");

        assertEq(this.allowance(account1, account2), approveAmount - transferAmount, "invalid allowance");
    }

    function testFuzz_TransferFrom_InfiniteApproval(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT);
        transferAmount = bound(transferAmount, 1, mintAmount);

        _mint(account1, mintAmount);

        vm.prank(account1);
        this.approve(account2, type(uint256).max);
        vm.prank(account2);
        assertTrue(this.transferFrom(account1, account3, transferAmount), "invalid return value");
        assertEq(this.allowance(account1, account2), type(uint256).max, "invalid allowance");
    }

    function testFuzz_TransferFrom_RevertIfNotEnoughApproved(
        uint256 mintAmount,
        uint256 approveAmount,
        uint256 transferAmount
    )
        public
    {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT - 1);
        approveAmount = bound(approveAmount, 1, mintAmount);
        transferAmount = bound(transferAmount, approveAmount + 1, MAX_UINT_SQRT);

        _mint(account1, mintAmount);

        vm.prank(account1);
        this.approve(account2, approveAmount);

        vm.prank(account2);
        vm.expectRevert(stdError.arithmeticError);
        assertFalse(this.transferFrom(account1, account3, transferAmount), "invalid return value");
        assertEq(this.allowance(account1, account2), approveAmount, "invalid allowance");
    }

    function testFuzz_TransferFrom_RevertIfNotEnoughBalance(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT - 1);
        transferAmount = bound(transferAmount, mintAmount + 1, MAX_UINT_SQRT);

        _mint(account1, mintAmount);

        vm.prank(account1);
        this.approve(account2, transferAmount);

        vm.prank(account2);
        vm.expectRevert(stdError.arithmeticError);
        assertFalse(this.transferFrom(account1, account3, transferAmount), "invalid return value");
        assertEq(this.allowance(account1, account2), transferAmount, "invalid allowance");
    }

    function testFuzz_Permit(uint256 approveAmount) public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(vm, DOMAIN_SEPARATOR(), privateKey, owner, account2, approveAmount, 0, block.timestamp + 10_000);

        vm.expectEmit(true, true, true, true);
        emit Approval(owner, account2, approveAmount);
        this.permit(owner, account2, approveAmount, block.timestamp + 10_000, v, r, s);

        assertEq(this.allowance(owner, account2), approveAmount, "invalid allowance");
        assertEq(this.nonces(owner), 1, "invalid nonce");
    }

    function test_Permit_RevertIfInvalidSigner() public {
        uint256 privateKey = 0xBEEF;
        address signer = vm.addr(privateKey);
        uint256 amount = 10 ether;

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(vm, DOMAIN_SEPARATOR(), privateKey, signer, account2, amount, 0, block.timestamp + 10_000);

        vm.expectRevert(abi.encodeWithSelector(TgToken.InvalidSignature.selector));
        this.permit(account1, account2, amount, block.timestamp + 10_000, v, r, s);
    }

    function test_Permit_RevertIfInvalidDeadline() public {
        uint256 privateKey = 0xBEEF;
        address signer = vm.addr(privateKey);
        uint256 amount = 10 ether;

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(vm, DOMAIN_SEPARATOR(), privateKey, signer, account2, amount, 0, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(TgToken.InvalidSignature.selector));
        this.permit(signer, account2, amount, block.timestamp + 1, v, r, s);
    }

    function test_Permit_RevertIfDeadlineExpired() public {
        uint256 privateKey = 0xBEEF;
        address signer = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(vm, DOMAIN_SEPARATOR(), privateKey, signer, account2, 1 ether, 0, block.timestamp);

        vm.warp(block.timestamp + 1);
        vm.expectRevert(abi.encodeWithSelector(TgToken.InvalidSignature.selector));
        this.permit(signer, account2, 1 ether, block.timestamp, v, r, s);
    }

    function test_Permit_RevertIfInvalidNonce() public {
        uint256 privateKey = 0xBEEF;
        address signer = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(vm, DOMAIN_SEPARATOR(), privateKey, signer, account2, 1 ether, 1, block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(TgToken.InvalidSignature.selector));
        this.permit(signer, account2, 1 ether, block.timestamp, v, r, s);
    }

    function test_Permit_RevertIfReplayed() public {
        uint256 privateKey = 0xBEEF;
        address signer = vm.addr(privateKey);
        uint256 amount = 1 ether;

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(vm, DOMAIN_SEPARATOR(), privateKey, signer, account2, amount, 0, block.timestamp + 10_000);
        this.permit(signer, account2, amount, block.timestamp + 10_000, v, r, s);

        vm.expectRevert(abi.encodeWithSelector(TgToken.InvalidSignature.selector));
        this.permit(signer, account2, amount, block.timestamp + 10_000, v, r, s);
    }

    function test_SetTotalSupply(uint256 supply) public {
        _setTotalSupply(supply);
        assertEq(totalSupply(), supply);
    }

    function testFuzz_Mint(uint256 amountSeed) public {
        uint256 amount1 = rand(amountSeed, 0, 1, MAX_UINT_SQRT / 2);
        uint256 amount2 = rand(amountSeed, 1, 1, MAX_UINT_SQRT / 2);

        Storage storage $ = _loadStorage();

        _mint(account1, amount1);
        assertEq(balanceOf(account1), amount1, "invalid balance");
        assertEq(totalSupply(), amount1, "invalid supply");
        assertEq($.shares[account1], amount1, "invalid account1 shares");
        assertEq($._totalShares, amount1, "invalid total shares");
        assertEq($._totalSupply, amount1, "invalid total supply");

        _mint(account2, amount2);
        assertEq(balanceOf(account2), amount2, "invalid balance");
        assertEq(totalSupply(), amount1 + amount2, "invalid supply - second mint");
        assertEq($.shares[account2], amount2, "invalid account1 shares");
        assertEq($._totalShares, amount1 + amount2, "invalid total shares");
        assertEq($._totalSupply, amount1 + amount2, "invalid total supply");
    }

    function test_Mint_RevertsIfZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(TgToken.ZeroAmount.selector));
        _mint(account1, 0);
    }

    function test_Mint_AmountBelowFXRate() public {
        _mint(account1, 1 ether);
        Storage storage $ = _loadStorage();
        $._totalSupply = 2 ether;

        _mint(account2, 1);

        assertEq(balanceOf(account2), 0);
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT / 2);
        burnAmount = bound(burnAmount, 1, mintAmount);

        _mint(account1, mintAmount);
        _mint(account2, mintAmount);
        _burn(account1, burnAmount);

        Storage storage $ = _loadStorage();
        assertEq(balanceOf(account1), mintAmount - burnAmount, "invalid account1 balance");
        assertEq(balanceOf(account2), mintAmount, "invalid account2 balance");
        assertEq(totalSupply(), mintAmount * 2 - burnAmount, "invalid supply");
        assertEq($._totalShares, mintAmount * 2 - burnAmount, "invalid total shares");
        assertEq($._totalSupply, mintAmount * 2 - burnAmount, "invalid total supply");
    }

    function testFuzz_Burn_RevertIfNotEnoughBalance(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_UINT_SQRT / 2);
        burnAmount = bound(burnAmount, mintAmount + 1, MAX_UINT_SQRT);

        _mint(account1, mintAmount);
        vm.expectRevert(stdError.arithmeticError);
        _burn(account1, burnAmount);
    }

    function test_Burn_RevertIfZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(TgToken.ZeroAmount.selector));
        _burn(account1, 0);
    }

    function test_Burn_RevertIfZeroTotalSupply(uint256 amount, uint256 totalShares) public {
        amount = bound(amount, 1, MAX_UINT_SQRT);
        totalShares = bound(totalShares, 1, MAX_UINT_SQRT);
        Storage storage $ = _loadStorage();
        $._totalShares = totalShares;
        $._totalSupply = 0;

        vm.expectRevert();
        _burn(account1, amount);
    }

    function test_Burn_AmountBelowFXRate() public {
        _mint(account1, 1 ether);
        _mint(account2, 1 ether);
        Storage storage $ = _loadStorage();
        $._totalSupply = 4 ether;

        vm.expectRevert(TgToken.ZeroAmount.selector);
        _burn(account2, 1);
    }
}
