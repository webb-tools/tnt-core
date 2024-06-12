// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test, stdError } from "forge-std/Test.sol";

import { IERC20Metadata } from "core/lst/interfaces/IERC20.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";
import { Renderer } from "core/lst/unlocks/Renderer.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { LiquifierImmutableArgs } from "core/lst/liquifier/LiquifierBase.sol";
import { Unlocks, Metadata } from "core/lst/unlocks/Unlocks.sol";

// solhint-disable func-name-mixedcase
contract UnlockTest is Test {
    Unlocks private unlocks;
    address private receiver = vm.addr(1);
    address private asset = vm.addr(2);
    address private registry = vm.addr(3);
    address private renderer = vm.addr(4);
    address private impostor = vm.addr(5);
    address private validator = vm.addr(6);
    address private adapter = vm.addr(7);

    function setUp() public {
        unlocks = new Unlocks(registry, renderer);
        vm.etch(adapter, bytes("code"));
    }

    function test_Metadata() public {
        assertEq(unlocks.name(), "TangleUnlocks");
        assertEq(unlocks.symbol(), "UNLOCK");
    }

    function testFuzz_createUnlock_Success(address owner, uint256 lockId) public {
        lockId = bound(lockId, 0, type(uint96).max);
        vm.assume(owner != address(0) && owner != registry && !_isContract(owner));
        uint256 balanceBefore = unlocks.balanceOf(owner);

        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));
        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        uint256 tokenId = unlocks.createUnlock(owner, lockId);

        (address liquifier, uint256 decodedLockIndex) = _decodeTokenId(tokenId);
        assertEq(decodedLockIndex, lockId);
        assertEq(address(uint160(liquifier)), address(this), "decoded address should be the test address");
        assertEq(unlocks.balanceOf(owner), balanceBefore + 1, "user balance should increase by 1");
        assertEq(unlocks.ownerOf(tokenId), owner, "owner should be the owner");
    }

    function test_createUnlock_RevertIfNotLiquifier() public {
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(false));

        vm.expectRevert(abi.encodeWithSelector(Unlocks.NotLiquifier.selector, address(this)));
        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        unlocks.createUnlock(receiver, 1);
    }

    function test_createUnlock_RevertIfTooLargeId() public {
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));

        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        vm.expectRevert(abi.encodeWithSelector(Unlocks.InvalidID.selector));
        unlocks.createUnlock(receiver, 1 << 96);
    }

    function testFuzz_useUnlock_Success(address owner, uint256 lockId) public {
        lockId = bound(lockId, 0, type(uint96).max);
        vm.assume(owner != address(0) && owner != registry && !_isContract(owner));
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));
        uint256 tokenId = unlocks.createUnlock(owner, lockId);
        uint256 balanceBefore = unlocks.balanceOf(owner);

        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        unlocks.useUnlock(owner, lockId);

        assertEq(unlocks.balanceOf(owner), balanceBefore - 1, "user balance should decrease by 1");
        vm.expectRevert("NOT_MINTED");

        unlocks.ownerOf(tokenId);
    }

    function test_useUnlock_RevertIfNotLiquifier() public {
        uint256 lockId = 1;
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));
        unlocks.createUnlock(receiver, lockId);

        vm.expectRevert(abi.encodeWithSelector(Unlocks.NotLiquifier.selector, address(this)));

        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(false));

        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        unlocks.useUnlock(receiver, lockId);
    }

    function test_useUnlock_RevertIfNotOwnerOf() public {
        uint256 lockId = 1;
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));
        unlocks.createUnlock(receiver, lockId);

        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        vm.expectRevert(abi.encodeWithSelector(Unlocks.NotOwnerOf.selector, lockId, receiver, impostor));
        unlocks.useUnlock(impostor, lockId);
    }

    function test_useUnlock_RevertIfTooLargeId() public {
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));
        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));

        vm.expectRevert(abi.encodeWithSelector(Unlocks.InvalidID.selector));
        unlocks.useUnlock(receiver, 1 << 96);
    }

    function test_tokenURI_Success() public {
        uint256 lockId = 1;
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))), abi.encode(true));
        vm.expectCall(registry, abi.encodeCall(Registry.isLiquifier, (address(this))));
        uint256 tokenId = unlocks.createUnlock(receiver, lockId);

        vm.mockCall(renderer, abi.encodeCall(Renderer.json, (tokenId)), abi.encode("token uri"));
        vm.expectCall(renderer, abi.encodeCall(Renderer.json, (tokenId)));
        string memory expURI = unlocks.tokenURI(tokenId);
        assertEq(expURI, "token uri");
    }

    function test_tokenURI_RevertIfIdDoesntExist() public {
        vm.expectRevert("NOT_MINTED");
        unlocks.tokenURI(1);
    }

    function test_getMetadata() public {
        address liquifier = address(this);
        // create an unlock
        uint256 lockId = 1337;
        vm.mockCall(registry, abi.encodeCall(Registry.isLiquifier, (liquifier)), abi.encode(true));
        uint256 tokenId = unlocks.createUnlock(msg.sender, lockId);

        vm.mockCall(liquifier, abi.encodeCall(LiquifierImmutableArgs.adapter, ()), abi.encode((adapter)));
        vm.mockCall(adapter, abi.encodeCall(Adapter.currentTime, ()), abi.encode((block.number + 50)));
        vm.mockCall(adapter, abi.encodeCall(Adapter.unlockTime, ()), abi.encode((100)));

        vm.mockCall(liquifier, abi.encodeCall(Liquifier.previewWithdraw, (lockId)), abi.encode((1 ether)));
        vm.mockCall(liquifier, abi.encodeCall(Liquifier.unlockMaturity, (lockId)), abi.encode((block.number + 100)));
        vm.mockCall(liquifier, abi.encodeCall(LiquifierImmutableArgs.validator, ()), abi.encode((validator)));
        vm.mockCall(liquifier, abi.encodeCall(LiquifierImmutableArgs.asset, ()), abi.encode((asset)));
        vm.mockCall(asset, abi.encodeCall(IERC20Metadata.symbol, ()), abi.encode(("TEST")));
        vm.mockCall(asset, abi.encodeCall(IERC20Metadata.name, ()), abi.encode(("Test Token")));
        // get meta data

        Metadata memory d = unlocks.getMetadata(tokenId);

        assertEq(d.unlockId, lockId);
        assertEq(d.amount, 1 ether);
        assertEq(d.maturity, block.number + 100);
        assertEq(d.progress, 50);
        assertEq(d.symbol, "TEST");
        assertEq(d.name, "Test Token");
        assertEq(d.validator, validator);
    }

    // helpers
    function _decodeTokenId(uint256 tokenId) internal pure virtual returns (address liquifier, uint96 id) {
        return (address(bytes20(bytes32(tokenId))), uint96(bytes12(bytes32(tokenId) << 160)));
    }

    function _encodeTokenId(address liquifier, uint96 id) internal pure virtual returns (uint256) {
        return uint256(bytes32(abi.encodePacked(liquifier, id)));
    }

    function _isContract(address addr) internal view returns (bool) {
        return addr.code.length != 0;
    }
}
