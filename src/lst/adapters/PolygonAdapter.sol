// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

uint256 constant VERSION = 1;

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";
import { ILiquifier } from "core/lst/liquifier/ILiquifier.sol";
import {
    IPolygonStakeManager,
    IPolygonValidatorShares,
    IPolygonStakingNFT,
    DelegatorUnbond
} from "core/lst/adapters/interfaces/IPolygon.sol";

// Matic exchange rate precision
uint256 constant EXCHANGE_RATE_PRECISION = 100; // For Validator ID < 8
uint256 constant EXCHANGE_RATE_PRECISION_HIGH = 10 ** 29; // For Validator ID >= 8
uint256 constant WITHDRAW_DELAY = 80; // 80 epochs, epoch length can vary on average between 200-300 Ethereum L1 blocks

IPolygonStakeManager constant POLYGON_STAKEMANAGER = IPolygonStakeManager(address(0x5e3Ef299fDDf15eAa0432E6e66473ace8c13D908));
ERC20 constant POL = ERC20(address(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0));

// Old validator owners
// If validators changed their "owner" we must have a special case to fetch the
// correct validator shares contract for their new owner.
// This fixes issue where liquifiers are currently tied to "owner" instead of "validatorId"
address constant BOUNTYBLOK_OLD = 0x055BD801cA712b4ddf67db8BC23FB6C8510D52b9;
address constant BOUNTYBLOK_NEW = 0x1BE946281214Afa0200725917B46EaeCb4b7dBE1;

// Polygon validators with a `validatorId` less than 8 are foundation validators
// These are special case validators that don't have slashing enabled and still operate
// On the old precision for the ValidatorShares contract.
function getExchangePrecision(uint256 validatorId) pure returns (uint256) {
    if (validatorId < 8) {
        return EXCHANGE_RATE_PRECISION;
    } else {
        return EXCHANGE_RATE_PRECISION_HIGH;
    }
}

contract PolygonAdapter is Adapter {
    using SafeTransferLib for ERC20;

    struct Storage {
        uint256 validatorId;
    }

    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.polygon.adapter.storage.location")) - 1;

    function _loadStorage() internal pure returns (Storage storage $) {
        uint256 slot = STORAGE;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := slot
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(Adapter).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function isValidator(address validator) public view returns (bool) {
        // Validator must have a validator shares contract
        // This will revert if the address does not own its StakeNFT
        // Which could lead to unexpected behaviour if used by external contracts
        return address(_getValidatorSharesContract(getValidatorId(validator))) != address(0);
    }

    function previewDeposit(address validator, uint256 assets) external view returns (uint256) {
        uint256 validatorId = getValidatorId(validator);
        uint256 delegatedAmount = IPolygonStakeManager(POLYGON_STAKEMANAGER).delegatedAmount(validatorId);
        IPolygonValidatorShares validatorShares = _getValidatorSharesContract(validatorId);
        uint256 totalShares = validatorShares.totalSupply();
        uint256 prec = getExchangePrecision(getValidatorId(validator));
        uint256 fxRate_0 = prec * delegatedAmount / totalShares;
        uint256 sharesToMint = assets * prec / fxRate_0;
        uint256 amountToTransfer = sharesToMint * fxRate_0 / prec;
        uint256 fxRate_1 = prec * (delegatedAmount + amountToTransfer) / (totalShares + sharesToMint);
        return sharesToMint * fxRate_1 / prec;
    }

    function previewWithdraw(uint256 unlockID) external view returns (uint256 amount) {
        // get validator for caller (Liquifier through delegate call)
        address validator = _getValidatorAddress();
        // get the validator shares contract for validator
        uint256 validatorId = getValidatorId(validator);
        IPolygonValidatorShares validatorShares = _getValidatorSharesContract(validatorId);

        DelegatorUnbond memory unbond = validatorShares.unbonds_new(address(this), unlockID);
        // calculate amount of tokens to withdraw by converting shares back into amount
        // See https://github.com/maticnetwork/contracts/blob/main/contracts/staking/validatorShare/ValidatorShare.sol#L281-L282
        amount = unbond.shares * validatorShares.withdrawExchangeRate() / getExchangePrecision(validatorId);
    }

    function unlockMaturity(uint256 unlockID) external view returns (uint256) {
        // Note that this returns the unlockMaturity as a Polygon epoch number in the future
        // It's fairly hard to predict the number of blocks between checkpoints
        // While we could use an historical average, it's better to just return the epoch number for now
        // consumers of this method can still convert it into a block or timestamp if they choose to
        DelegatorUnbond memory u =
            _getValidatorSharesContract(getValidatorId(_getValidatorAddress())).unbonds_new(address(this), unlockID);
        return u.withdrawEpoch + WITHDRAW_DELAY;
    }

    function unlockTime() external pure override returns (uint256) {
        return WITHDRAW_DELAY;
    }

    function currentTime() external view override returns (uint256) {
        return POLYGON_STAKEMANAGER.epoch();
    }

    function stake(address validator, uint256 amount) external override returns (uint256) {
        // approve tokens
        POL.safeApprove(address(POLYGON_STAKEMANAGER), amount);

        uint256 validatorId = getValidatorId(validator);
        IPolygonValidatorShares validatorShares = _getValidatorSharesContract(validatorId);

        // calculate minimum amount of voucher shares to mint
        // adjust for integer truncation upon division
        uint256 precision = getExchangePrecision(validatorId);
        uint256 fxRate = validatorShares.exchangeRate();
        uint256 min = amount * precision / fxRate - 1;

        // Mint voucher shares
        return validatorShares.buyVoucher(amount, min);
    }

    function unstake(address validator, uint256 amount) external override returns (uint256 unlockID) {
        uint256 validatorId = getValidatorId(validator);
        IPolygonValidatorShares validatorShares = _getValidatorSharesContract(validatorId);

        uint256 precision = getExchangePrecision(validatorId);
        uint256 fxRate = validatorShares.exchangeRate();

        // Unbond tokens
        // calculate max amount of validator shares to burn
        uint256 max = amount * precision / fxRate + 1;
        validatorShares.sellVoucher_new(amount, max);

        return validatorShares.unbondNonces(address(this));
    }

    function withdraw(address validator, uint256 unlockID) external override returns (uint256 amount) {
        uint256 validatorId = getValidatorId(validator);
        IPolygonValidatorShares validatorShares = _getValidatorSharesContract(validatorId);

        DelegatorUnbond memory unbond = validatorShares.unbonds_new(address(this), unlockID);
        // foundation validators (id < 8) don't have slashing enabled
        // see https://github1s.com/maticnetwork/contracts/blob/main/contracts/staking/validatorShare/ValidatorShare.sol#L89-L95
        uint256 fxRate = validatorId >= 8 ? validatorShares.withdrawExchangeRate() : EXCHANGE_RATE_PRECISION;
        amount = unbond.shares * fxRate / getExchangePrecision(validatorId);

        validatorShares.unstakeClaimTokens_new(unlockID);
    }

    function rebase(address validator, uint256 currentStake) external returns (uint256 newStake) {
        // Special case code to fix validators that have changed owner
        if (validator == BOUNTYBLOK_OLD) {
            validator = BOUNTYBLOK_NEW;
        }

        Storage storage $ = _loadStorage();
        uint256 validatorId = getValidatorId(validator);
        if ($.validatorId == 0) {
            $.validatorId = validatorId;
        }
        IPolygonValidatorShares validatorShares = _getValidatorSharesContract(validatorId);

        // This call will revert if there are no rewards
        // In which case we don't throw, just return the current staked amount.
        // solhint-disable-next-line no-empty-blocks
        try validatorShares.restake() { }
        catch {
            return currentStake;
        }

        // Read new stake
        uint256 shares = validatorShares.balanceOf(address(this));
        uint256 precision = getExchangePrecision(validatorId);
        uint256 fxRate = validatorShares.exchangeRate();
        newStake = shares * fxRate / precision;
    }

    function _getValidatorAddress() internal view returns (address) {
        Storage storage $ = _loadStorage();
        uint256 id = $.validatorId;
        return id != 0 ? IPolygonStakingNFT(address(POLYGON_STAKEMANAGER)).ownerOf(id) : ILiquifier(address(this)).validator();
    }

    function getValidatorId(address validator) public view returns (uint256) {
        // This will revert if validator is not valid
        Storage storage $ = _loadStorage();
        uint256 id = $.validatorId;
        return id != 0 ? id : POLYGON_STAKEMANAGER.getValidatorId(validator);
    }
}

function _getValidatorSharesContract(uint256 validatorId) view returns (IPolygonValidatorShares) {
    return IPolygonValidatorShares(POLYGON_STAKEMANAGER.getValidatorContract(validatorId));
}
