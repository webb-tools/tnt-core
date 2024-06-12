// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { Adapter, AdapterDelegateCall } from "core/lst/adapters/Adapter.sol";
import { Registry } from "core/lst/registry/Registry.sol";
import { LiquifierImmutableArgs, LiquifierEvents } from "core/lst/liquifier/LiquifierBase.sol";
import { TgToken } from "core/lst/liquidtoken/TgToken.sol";
import { Multicall } from "core/lst/utils/Multicall.sol";
import { SelfPermit } from "core/lst/utils/SelfPermit.sol";
import { _staticcall } from "core/lst/utils/StaticCall.sol";
import { addressToString } from "core/lst/utils/Utils.sol";

/**
 * @title Liquifier
 * @author Tangle Labs
 * @notice Liquid staking vault for native liquid staking
 * @dev Uses full type safety and unstructured storage
 */
contract Liquifier is LiquifierImmutableArgs, LiquifierEvents, TgToken, Multicall, SelfPermit {
    error InsufficientAssets();

    using AdapterDelegateCall for Adapter;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 private constant MAX_FEE = 0.005e6; // 0.5%
    uint256 private constant FEE_BASE = 1e6;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _registry, address _unlocks) LiquifierImmutableArgs(_registry, _unlocks) { }
    receive() external payable { }
    fallback() external payable { }

    // @inheritdoc TgToken
    function name() external view override returns (string memory) {
        return string.concat("liquid ", _baseSymbol());
    }

    // @inheritdoc TgToken
    function symbol() external view override returns (string memory) {
        return string.concat("tg", _baseSymbol());
    }

    // @inheritdoc TgToken
    function transfer(address to, uint256 amount) public override returns (bool) {
        _rebase();
        return TgToken.transfer(to, amount);
    }

    // @inheritdoc TgToken
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _rebase();
        return TgToken.transferFrom(from, to, amount);
    }

    /**
     * @notice Deposit assets to mint tgTokens
     * @param receiver address to mint tgTokens to
     * @param assets amount of assets to deposit
     */
    function deposit(address receiver, uint256 assets) external returns (uint256) {
        _rebase();

        // transfer tokens before minting (or ERC777's could re-enter)
        ERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);

        // stake assets
        uint256 staked = _stake(validator(), assets);

        // mint tokens to receiver
        uint256 shares;
        if ((shares = _mint(receiver, staked)) == 0) revert InsufficientAssets();

        uint256 tgTokenOut = convertToAssets(shares);
        emit Deposit(msg.sender, receiver, assets, tgTokenOut);

        return tgTokenOut;
    }

    /**
     * @notice Unlock tgTokens to withdraw assets at maturity
     * @param assets amount of assets to unlock
     * @return unlockID of the unlock
     */
    function unlock(uint256 assets) external returns (uint256 unlockID) {
        _rebase();

        // burn tgTokens before creating an `unlock`
        _burn(msg.sender, assets);

        // unlock assets and get unlockID
        unlockID = _unstake(validator(), assets);

        // create unlock of unlockID
        _unlocks().createUnlock(msg.sender, unlockID);

        // emit Unlock event
        emit Unlock(msg.sender, assets, unlockID);
    }

    /**
     * @notice Redeem an unlock to withdraw assets after maturity
     * @param receiver address to withdraw assets to
     * @param unlockID ID of the unlock to redeem
     * @return amount of assets withdrawn
     */
    function withdraw(address receiver, uint256 unlockID) external returns (uint256 amount) {
        // Redeem unlock if mature
        _unlocks().useUnlock(msg.sender, unlockID);

        // withdraw assets to send to `receiver`
        amount = _withdraw(validator(), unlockID);

        // transfer assets to `receiver`
        ERC20(asset()).safeTransfer(receiver, amount);

        // emit Withdraw event
        emit Withdraw(receiver, amount, unlockID);
    }

    /**
     * @notice Rebase tgToken supply
     * @dev Rebase can be called by anyone, is also forced to be called before any action or transfer
     */
    function rebase() external {
        _rebase();
    }

    function _rebase() internal {
        uint256 currentStake = totalSupply();
        uint256 newStake = _rebase(validator(), currentStake);

        if (newStake > currentStake) {
            unchecked {
                uint256 rewards = newStake - currentStake;
                uint256 fees = _calculateFees(rewards);
                _setTotalSupply(newStake - fees);
                // mint fees
                if (fees > 0) {
                    _mint(_registry().treasury(), fees);
                }
            }
        } else {
            _setTotalSupply(newStake);
        }

        // emit rebase event
        emit Rebase(currentStake, newStake);
    }

    function _calculateFees(uint256 rewards) internal view returns (uint256 fees) {
        uint256 fee = _registry().fee(asset());
        fee = fee > MAX_FEE ? MAX_FEE : fee;
        fees = rewards * fee / FEE_BASE;
    }

    function _baseSymbol() internal view returns (string memory) {
        return string.concat(ERC20(asset()).symbol(), "-", addressToString(validator()));
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        uint256 out = abi.decode(_staticcall(address(this), abi.encodeCall(this._previewDeposit, (assets))), (uint256));
        Storage storage $ = _loadStorage();
        uint256 _totalShares = $._totalShares; // Saves an extra SLOAD if slot is non-zero
        uint256 shares = convertToShares(out);
        return _totalShares == 0 ? out : shares * $._totalSupply / _totalShares;
    }

    function previewWithdraw(uint256 unlockID) external view returns (uint256) {
        return abi.decode(_staticcall(address(this), abi.encodeCall(this._previewWithdraw, (unlockID))), (uint256));
    }

    function unlockMaturity(uint256 unlockID) external view returns (uint256) {
        return abi.decode(_staticcall(address(this), abi.encodeCall(this._unlockMaturity, (unlockID))), (uint256));
    }

    // ===============================================================================================================
    // NOTE: These functions are marked `public` but considered `internal` (hence the `_` prefix).
    // This is because the compiler doesn't know whether there is a state change because of `delegatecall``
    // So for the external API (e.g. used by Unlocks.sol) we wrap these functions in `external` functions
    // using a `staticcall` to `this`.
    // This is a hacky workaround while better solidity features are being developed.
    function _previewDeposit(uint256 assets) public returns (uint256) {
        return abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().previewDeposit, (validator(), assets))), (uint256));
    }

    function _previewWithdraw(uint256 unlockID) public returns (uint256) {
        return abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().previewWithdraw, (unlockID))), (uint256));
    }

    function _unlockMaturity(uint256 unlockID) public returns (uint256) {
        return abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().unlockMaturity, (unlockID))), (uint256));
    }
    // ===============================================================================================================

    function _rebase(address validator, uint256 currentStake) internal returns (uint256 newStake) {
        newStake = abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().rebase, (validator, currentStake))), (uint256));
    }

    function _stake(address validator, uint256 amount) internal returns (uint256 staked) {
        staked = abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().stake, (validator, amount))), (uint256));
    }

    function _unstake(address validator, uint256 amount) internal returns (uint256 unlockID) {
        unlockID = abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().unstake, (validator, amount))), (uint256));
    }

    function _withdraw(address validator, uint256 unlockID) internal returns (uint256 withdrawAmount) {
        withdrawAmount = abi.decode(adapter()._delegatecall(abi.encodeCall(adapter().withdraw, (validator, unlockID))), (uint256));
    }
}
