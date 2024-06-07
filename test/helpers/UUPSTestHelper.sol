// SPDX-License-Identifier: MIT
//
//  _____              _           _
// |_   _|            | |         (_)
//   | | ___ _ __   __| | ___ _ __ _ _______
//   | |/ _ \ '_ \ / _` |/ _ \ '__| |_  / _ \
//   | |  __/ | | | (_| |  __/ |  | |/ /  __/
//   \_/\___|_| |_|\__,_|\___|_|  |_/___\___|
//
// Copyright (c) Tenderize Labs Ltd

pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ClonesUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// solhint-disable func-name-mixedcase

contract UpgradeableContract is Initializable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // solhint-disable no-empty-blocks
    function initialize() public initializer { }
    function _authorizeUpgrade(address) internal override { }
}

contract UUPSTestHelper is Test {
    ERC1967Proxy internal proxy;
    address internal owner = vm.addr(1);
    address internal nonAuthorized = vm.addr(2);

    UpgradeableContract internal currentVersion;
    bytes internal data; // initialize data for proxy
    bytes32 internal constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    constructor(address _currentVersion, bytes memory _data) {
        currentVersion = UpgradeableContract(_currentVersion);
        data = _data;
    }

    function setUp() public {
        vm.startPrank(owner);
        // currentVersion = new UpgradeableContract();
        proxy = new ERC1967Proxy(address(currentVersion), data);
        vm.stopPrank();
    }

    function test_implInitializerDisabled() public {
        vm.startPrank(owner);
        vm.expectRevert("Initializable: contract is already initialized");
        // solhint-disable-next-line avoid-low-level-calls
        address(currentVersion).call(data);
        vm.stopPrank();
    }

    function test_implInitializerDisabledAfterUpgrade() public {
        vm.startPrank(owner);
        UpgradeableContract nextVersion = new UpgradeableContract();
        UpgradeableContract(address(proxy)).upgradeTo(address(nextVersion));
        vm.expectRevert("Initializable: contract is already initialized");
        nextVersion.initialize();
        vm.stopPrank();
    }

    function test_unauthorizedUpgradeAttack() public {
        vm.startPrank(nonAuthorized);

        UpgradeableContract nextVersion = new UpgradeableContract();
        ERC1967Proxy proxy2 = new ERC1967Proxy(address(currentVersion), "");

        vm.expectRevert("Function must be called through delegatecall");
        currentVersion.upgradeTo(address(nextVersion));

        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(proxy2).delegatecall(abi.encodeCall(UUPSUpgradeable.upgradeTo, address(nextVersion)));
        assertTrue(success);

        address implClone = ClonesUpgradeable.clone(address(currentVersion));
        vm.expectRevert("Function must be called through active proxy");
        UpgradeableContract(implClone).upgradeTo(address(nextVersion));

        vm.stopPrank();
    }

    function test_upgradeTo() public {
        vm.startPrank(owner);
        UpgradeableContract nextVersion = new UpgradeableContract();

        bytes32 proxySlotBefore = vm.load(address(proxy), IMPL_SLOT);
        assertEq(proxySlotBefore, bytes32(uint256(uint160(address(currentVersion)))));

        UpgradeableContract(address(proxy)).upgradeTo(address(nextVersion));

        bytes32 proxySlotAfter = vm.load(address(proxy), IMPL_SLOT);
        assertEq(proxySlotAfter, bytes32(uint256(uint160(address(nextVersion)))));
    }

    function test_proxyImplSlot() public {
        bytes32 proxySlot = vm.load(address(proxy), IMPL_SLOT);
        assertEq(proxySlot, bytes32(uint256(uint160(address(currentVersion)))));
    }
}
