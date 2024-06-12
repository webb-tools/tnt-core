// SPDX-License-Identifier: UNLICENSED

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { Adapter } from "core/lst/adapters/Adapter.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { Renderer } from "core/lst/unlocks/Renderer.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

pragma solidity >=0.8.19;

// solhint-disable quotes

/// @title Unlocks
/// @notice ERC721 contract for unlock tokens
/// @dev Creates an NFT for staked tokens pending unlock. Each Unlock has an amount and a maturity date.

struct Metadata {
    uint256 amount;
    uint256 maturity;
    uint256 progress;
    uint256 unlockId;
    string symbol;
    string name;
    address validator;
}

contract Unlocks is ERC721 {
    Registry private immutable registry;
    Renderer private immutable renderer;

    error NotOwnerOf(uint256 tokenId, address owner, address sender);
    error NotLiquifier(address sender);
    error InvalidID();

    modifier isValidLiquifier(address sender) {
        _isValidLiquifier(sender);
        _;
    }

    constructor(address _registry, address _renderer) ERC721("TangleUnlocks", "UNLOCK") {
        registry = Registry(_registry);
        renderer = Renderer(_renderer);
    }

    /**
     * @notice Creates a new unlock token
     * @dev Only callable by a Liquifier
     * @param receiver Address of the receiver
     * @param unlockId ID of the unlock
     * @return tokenId ID of the created token
     */
    function createUnlock(
        address receiver,
        uint256 unlockId
    )
        external
        virtual
        isValidLiquifier(msg.sender)
        returns (uint256 tokenId)
    {
        if (unlockId >= 1 << 96) revert InvalidID();
        tokenId = _encodeTokenId(msg.sender, uint96(unlockId));
        _safeMint(receiver, tokenId);
    }

    /**
     * @notice Burns an unlock token
     * @dev Only callable by a Liquifier
     * @param owner Owner of the token
     * @param unlockId ID of the unlock
     */
    function useUnlock(address owner, uint256 unlockId) external virtual isValidLiquifier(msg.sender) {
        if (unlockId >= 1 << 96) revert InvalidID();
        uint256 tokenId = _encodeTokenId(msg.sender, uint96(unlockId));
        if (ownerOf(tokenId) != owner) revert NotOwnerOf(unlockId, ownerOf(tokenId), owner);
        _burn(tokenId);
    }

    /**
     * @notice Returns the tokenURI of an unlock token
     * @param tokenId ID of the unlock token
     * @return tokenURI of the unlock token
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "non-existent token");
        return renderer.json(tokenId);
    }

    /**
     * @notice Returns the metadata of an unlock token
     * @param tokenId ID of the unlock token
     * @return metadata of the unlock token
     */
    function getMetadata(uint256 tokenId) external view returns (Metadata memory metadata) {
        (address payable liquifier, uint96 unlockId) = _decodeTokenId(tokenId);
        address asset = Liquifier(liquifier).asset();

        Adapter adapter = Liquifier(liquifier).adapter();
        uint256 maturity = Liquifier(liquifier).unlockMaturity(unlockId);
        uint256 currentTime = adapter.currentTime();

        return Metadata({
            amount: Liquifier(liquifier).previewWithdraw(unlockId),
            maturity: maturity,
            progress: maturity > currentTime
                ? 100 - FixedPointMathLib.mulDivUp((maturity - currentTime), 100, adapter.unlockTime())
                : 100,
            unlockId: unlockId,
            symbol: ERC20(asset).symbol(),
            name: ERC20(asset).name(),
            validator: Liquifier(liquifier).validator()
        });
    }

    function _isValidLiquifier(address sender) internal view virtual {
        if (!registry.isLiquifier(sender)) revert NotLiquifier(sender);
    }

    function _encodeTokenId(address liquifier, uint96 unlockId) internal pure virtual returns (uint256) {
        return uint256(bytes32(abi.encodePacked(liquifier, unlockId)));
    }

    function _decodeTokenId(uint256 tokenId) internal pure virtual returns (address payable liquifier, uint96 unlockId) {
        bytes32 a = bytes32(tokenId);
        (liquifier, unlockId) = (payable(address(bytes20(a))), uint96(bytes12(a << 160)));
    }
}
