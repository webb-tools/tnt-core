// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ClonesUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { Renderer } from "core/lst/unlocks/Renderer.sol";
import { Unlocks, Metadata } from "core/lst/unlocks/Unlocks.sol";
import { Base64 } from "core/lst/unlocks/Base64.sol";
import { UUPSTestHelper } from "test/helpers/UUPSTestHelper.sol";

// solhint-disable quotes
// solhint-disable func-name-mixedcase
// solhint-disable avoid-low-level-calls
// solhint-disable no-empty-blocks

contract RendererV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    function json(uint256 /*id*/ ) external pure returns (string memory) {
        return "test json response";
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner { }
}

contract RendererUpgradeTest is UUPSTestHelper {
    constructor() UUPSTestHelper(address(new RendererV1()), abi.encodeCall(Renderer.initialize, ())) { }

    function test_upgradeTo_RevertIfNotOwner() public {
        vm.startPrank(nonAuthorized);

        Renderer rendererV2 = new Renderer();

        vm.expectRevert("Ownable: caller is not the owner");
        RendererV1(address(proxy)).upgradeTo(address(rendererV2));
        vm.stopPrank();
    }
}

contract RendererTest is Test {
    ERC1967Proxy private proxy;
    address private owner = vm.addr(1);
    address private nonAuthorized = vm.addr(2);
    address private liquifier = vm.addr(3);
    address private validator = vm.addr(4);
    uint256 private id = 1;
    Metadata private metadata =
        Metadata({ amount: 100, maturity: 1000, progress: 100, unlockId: id, symbol: "GRT", name: "Graph", validator: validator });
    RendererV1 private rendererV1;

    bytes32 internal constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    function setUp() public {
        vm.startPrank(owner);
        rendererV1 = new RendererV1();
        bytes memory data = abi.encodeWithSignature("initialize()");
        proxy = new ERC1967Proxy(address(rendererV1), data);
        vm.stopPrank();
    }

    function test_V1Json() public {
        string memory json = RendererV1(address(proxy)).json(1);
        assertEq(json, "test json response");
    }

    function test_V2Json() public {
        vm.startPrank(owner);
        Renderer rendererV2 = new Renderer();
        RendererV1(address(proxy)).upgradeTo(address(rendererV2));
        vm.stopPrank();
        vm.mockCall(address(this), abi.encodeCall(Unlocks.getMetadata, (id)), abi.encode(metadata));
        vm.expectCall(address(this), abi.encodeCall(Unlocks.getMetadata, (id)));
        string memory data = Renderer(address(proxy)).json(id);
        string memory encodedJson = substring(data, 29, bytes(data).length);

        assertEq(
            string(Base64.decode(encodedJson)),
            // solhint-disable-next-line max-line-length
            '{"name": "TangleLock", "description": "TangleLock from https://tangle.tools represents ERC20 tokens during the unbonding period, thus making them tradable. Owning a TangleLock token makes the owner eligible to claim the tokens at the end of the unbonding period.", "image": "data:image/svg+xml;base64,<svg width="290" height="500" viewBox="0 0 290 500" xmlns="http://www.w3.org/2000/svg" xmlns:xlink=\'http://www.w3.org/1999/xlink\'>PHJlY3Qgd2lkdGg9JzI5MHB4JyBoZWlnaHQ9JzUwMHB4JyBmaWxsPScjMDAwMDAwJy8+PHRleHQgeD0nMTAnIHk9JzIwJz5HUlQ8L3RleHQ+PHRleHQgeD0iMTAiIHk9IjQwIj4xMDA8L3RleHQ+PHRleHQgeD0iMTAiIHk9IjYwIj4xMDAwPC90ZXh0Pjx0ZXh0IHg9IjEwIiB5PSI4MCI+MTwvdGV4dD48L3N2Zz4=","attributes":[{"trait_type": "maturity", "value":1000},{"trait_type": "amount", "value":100},{"trait_type": "token", "value":"Graph"},{"trait_type": "symbol", "value":"GRT"}]}'
        );
    }

    function substring(string memory str, uint256 startIndex, uint256 endIndex) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}
