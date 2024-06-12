// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IERC20 } from "core/lst/interfaces/IERC20.sol";
import { TgTokenStorage } from "core/lst/liquidtoken/TgTokenStorage.sol";

/// @notice Non-standard ERC20 + EIP-2612 implementation.
/// @author Liquifie
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @dev Do not mint shares without updating the total supply without being unaware of the consequences (see
/// `_mintShares` and `_burnShares`).

abstract contract TgToken is TgTokenStorage, IERC20 {
    using FixedPointMathLib for uint256;

    error ZeroAmount();
    error InvalidSignature();
    error PermitDeadlineExpired(uint256 expiryTimestamp, uint256 currentTimestamp);

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint8 private constant DECIMALS = 18;

    /**
     * @notice Returns the number of decimals
     * @return Number of decimals
     */
    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Returns the name of the tgToken
     * @return Name of the tgToken
     */
    function name() external view virtual returns (string memory);

    /**
     * @notice Returns the symbol of the tgToken
     * @return Symbol of the tgToken
     */
    function symbol() external view virtual returns (string memory);

    /**
     * @notice converts shares to assets
     * @param shares Amount of shares to convert
     * @return Amount of assets representing the shares
     */
    function convertToAssets(uint256 shares) public view returns (uint256) {
        Storage storage $ = _loadStorage();

        uint256 _totalShares = $._totalShares; // Saves an extra SLOAD if slot is non-zero
        return _totalShares == 0 ? shares : shares.mulDivDown($._totalSupply, _totalShares);
    }

    /**
     * @notice converts assets to shares
     * @param assets Amount of assets to convert
     * @return Amount of shares representing the assets
     */
    function convertToShares(uint256 assets) public view returns (uint256) {
        Storage storage $ = _loadStorage();

        uint256 _totalSupply = $._totalSupply; // Saves an extra SLOAD if slot is non-zero
        return _totalSupply == 0 ? assets : assets.mulDivDown($._totalShares, _totalSupply);
    }

    /**
     * @notice Returns the tgToken balance of an account
     * @param account address to get balance of
     * @return Balance of account
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return convertToAssets(_loadStorage().shares[account]);
    }

    /**
     * @notice Returns the total supply of the tgToken
     * @return Total supply of the tgToken
     */
    function totalSupply() public view virtual returns (uint256) {
        Storage storage $ = _loadStorage();
        return $._totalSupply;
    }

    /**
     * @notice returns the EIP-2612 permit nonce for an address
     * @param owner address to get nonce for
     */
    function nonces(address owner) external view returns (uint256) {
        Storage storage $ = _loadStorage();
        return $.nonces[owner];
    }

    /**
     * @notice Approve an address to spend your tokens
     * @param spender address to approve
     * @param amount amount of tokens to approve
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        Storage storage $ = _loadStorage();
        $.allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    /**
     * @notice Transfer tokens to another address
     * @param to address to transfer tokens to
     * @param amount amount of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        Storage storage $ = _loadStorage();
        uint256 shares = convertToShares(amount);
        // underflows if insufficient balance
        $.shares[msg.sender] -= shares;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            $.shares[to] += shares;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    /**
     * @notice Returns the previously approved amount by an address for a spender
     * @param owner address that approved spending
     * @param spender address allowed to spend tokens
     * @return Amount approved for spending
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        Storage storage $ = _loadStorage();
        return $.allowance[owner][spender];
    }

    /**
     * @notice Transfer tokens from one address to another
     * @param from address to transfer tokens from
     * @param to address to transfer tokens to
     * @param amount amount of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        Storage storage $ = _loadStorage();
        uint256 allowed = $.allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) {
            $.allowance[from][msg.sender] = allowed - amount;
        }

        uint256 shares = convertToShares(amount);

        $.shares[from] -= shares;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            $.shares[to] += shares;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /**
     * @notice EIP-2612 Permit function. For more details, see https://eips.ethereum.org/EIPS/eip-2612
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        virtual
    {
        if (deadline < block.timestamp) revert PermitDeadlineExpired(deadline, block.timestamp);

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _loadStorage().nonces[owner]++, deadline))
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0) || recoveredAddress != owner) revert InvalidSignature();

            _loadStorage().allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(TgToken(address(this)).name())),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function _setTotalSupply(uint256 supply) internal virtual {
        Storage storage $ = _loadStorage();
        $._totalSupply = supply;
    }

    function _mint(address to, uint256 assets) internal virtual returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if ((shares = convertToShares(assets)) == 0) return shares;

        Storage storage $ = _loadStorage();
        $._totalSupply += assets;
        $._totalShares += shares;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            $.shares[to] += shares;
        }
    }

    function _burn(address from, uint256 assets) internal virtual {
        uint256 shares;

        if (assets == 0) revert ZeroAmount();
        // Revert when calculated shares equals 0
        // Require to try and burn at least one share if the
        // amount of assets being burnt isn't at least one share.
        if ((shares = convertToShares(assets)) == 0) revert ZeroAmount();

        Storage storage $ = _loadStorage();
        $._totalSupply -= assets;
        $.shares[from] -= shares;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            $._totalShares -= shares;
        }
    }
}
