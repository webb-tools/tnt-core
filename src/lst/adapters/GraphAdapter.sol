// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

uint256 constant VERSION = 1;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Adapter } from "core/lst/adapters/Adapter.sol";
import { IGraphStaking, IGraphEpochManager } from "core/lst/adapters/interfaces/IGraph.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";

IGraphEpochManager constant GRAPH_EPOCHS = IGraphEpochManager(0x5A843145c43d328B9bB7a4401d94918f131bB281);
IGraphStaking constant GRAPH_STAKING = IGraphStaking(0x00669A4CF01450B64E8A2A20E9b1FCB71E61eF03);
ERC20 constant GRT = ERC20(0x9623063377AD1B27544C965cCd7342f7EA7e88C7);
uint256 constant MAX_PPM = 1e6;

contract GraphAdapter is Adapter {
    using SafeTransferLib for ERC20;

    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.graph.adapter.storage.location")) - 1;

    error WithdrawPending();

    struct Unlock {
        uint256 shares;
        uint256 epoch;
    }

    struct Epoch {
        uint256 amount;
        uint256 totalShares;
    }

    struct Storage {
        uint256 lastUnlockID;
        uint256 currentEpoch;
        uint256 lastEpochUnlockedAt;
        mapping(uint256 => Epoch) epochs;
        mapping(uint256 => Unlock) unlocks;
    }

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

    function previewDeposit(address validator, uint256 assets) external view override returns (uint256) {
        assets -= assets * GRAPH_STAKING.delegationTaxPercentage() / MAX_PPM;
        IGraphStaking.DelegationPool memory delPool = GRAPH_STAKING.delegationPools(validator);

        uint256 shares = delPool.tokens != 0 ? assets * delPool.shares / delPool.tokens : assets;
        return shares * (delPool.tokens + assets) / (delPool.shares + shares);
    }

    function previewWithdraw(uint256 unlockID) external view override returns (uint256) {
        Storage storage $ = _loadStorage();
        Unlock memory unlock = $.unlocks[unlockID];
        Epoch memory epoch = $.epochs[unlock.epoch];
        return unlock.shares * epoch.amount / epoch.totalShares;
    }

    function unlockMaturity(uint256 unlockID) external view override returns (uint256) {
        Storage storage $ = _loadStorage();
        Unlock memory unlock = $.unlocks[unlockID];
        uint256 THAWING_PERIOD = GRAPH_STAKING.thawingPeriod();
        // if userEpoch == currentEpoch, it is yet to unlock
        // => unlockBlock + thawingPeriod
        // if userEpoch == currentEpoch - 1, it is processing
        // => unlockBlock
        // if userEpoch < currentEpoch - 1, it has been processed
        // => 0
        uint256 unlockBlock = $.lastEpochUnlockedAt + THAWING_PERIOD;
        if (unlock.epoch == $.currentEpoch) {
            return THAWING_PERIOD + unlockBlock;
        } else if (unlock.epoch == $.currentEpoch - 1) {
            return unlockBlock;
        } else {
            return 0;
        }
    }

    function unlockTime() external view override returns (uint256) {
        return GRAPH_STAKING.thawingPeriod();
    }

    function currentTime() external view override returns (uint256) {
        return block.number;
    }

    function isValidator(address validator) public view override returns (bool) {
        return GRAPH_STAKING.hasStake(validator);
    }

    function stake(address validator, uint256 amount) external override returns (uint256) {
        GRT.safeApprove(address(GRAPH_STAKING), amount);
        uint256 delShares = GRAPH_STAKING.delegate(validator, amount);
        IGraphStaking.DelegationPool memory delPool = GRAPH_STAKING.delegationPools(validator);
        return delShares * delPool.tokens / delPool.shares;
    }

    function unstake(address validator, uint256 amount) external override returns (uint256 unlockID) {
        Storage storage $ = _loadStorage();
        Epoch memory e = $.epochs[$.currentEpoch];

        uint256 shares = e.amount == 0 ? amount : amount * e.totalShares / e.amount;

        e.amount += amount;
        e.totalShares += shares;
        $.epochs[$.currentEpoch] = e;

        unlockID = ++$.lastUnlockID;
        $.unlocks[unlockID] = Unlock({ shares: shares, epoch: $.currentEpoch });

        _processWithdrawals(validator);
    }

    function withdraw(address validator, uint256 unlockID) external override returns (uint256 amount) {
        _processWithdrawals(validator);
        Storage storage $ = _loadStorage();
        Unlock memory unlock = $.unlocks[unlockID];
        Epoch memory epoch = $.epochs[unlock.epoch];

        if (unlock.epoch >= $.currentEpoch - 1) revert WithdrawPending();

        if (unlock.shares == epoch.totalShares) {
            amount = epoch.amount;
            delete $.epochs[unlock.epoch];
        } else {
            amount = unlock.shares * epoch.amount / epoch.totalShares;
            epoch.amount -= amount;
            epoch.totalShares -= unlock.shares;
            $.epochs[unlock.epoch] = epoch;
        }

        delete $.unlocks[unlockID];
    }

    function rebase(address validator, uint256 currentStake) external override returns (uint256 newStake) {
        Storage storage $ = _loadStorage();
        uint256 currentEpochNum = $.currentEpoch;
        Epoch memory currentEpoch = $.epochs[currentEpochNum];
        IGraphStaking.DelegationPool memory delPool = GRAPH_STAKING.delegationPools(validator);

        newStake = currentStake;

        IGraphStaking.Delegation memory delegation = GRAPH_STAKING.getDelegation(validator, address(this));
        uint256 staked = delegation.shares * delPool.tokens / delPool.shares;

        // account for stake still to unstake
        uint256 oldStake = currentStake + currentEpoch.amount;

        // Last epoch amount should be synced with Delegation.tokensLocked
        if (currentEpochNum > 0) $.epochs[currentEpochNum - 1].amount = delegation.tokensLocked;

        if (staked > oldStake) {
            // handle rewards
            // To reduce long waiting periods we want to still reward users
            // for which their stake is still to be unlocked
            // because technically it is not unlocked from the Graph either
            // We do this by adding the rewards to the current epoch
            currentEpoch.amount += (staked - oldStake) * currentEpoch.amount / oldStake;
            $.epochs[currentEpochNum].amount = currentEpoch.amount;
        }

        // rewards is already accounted for in $.epochs[$.currentEpoch].amount
        newStake = staked - currentEpoch.amount;
    }

    function _processWithdrawals(address validator) internal {
        // process possible withdrawals before unstakes
        _processWithdraw(validator);
        _processUnstake(validator);
    }

    function _processUnstake(address validator) internal {
        IGraphStaking.Delegation memory del = GRAPH_STAKING.getDelegation(validator, address(this));
        // undelegation already ungoing: no-op
        if (del.tokensLockedUntil != 0) return;

        Storage storage $ = _loadStorage();
        uint256 currentEpochAmount = $.epochs[$.currentEpoch].amount;

        // if current epoch amount is non-zero
        // => progress epoch and undelegate from underlying
        // if current epoch is zero and previous epoch is non-zero
        // => only progress epoch, as withdrawal of last epoch is processed
        // => would return at del.tokensLockedUntil check if withdrawal is yet to process
        // if current and previous epoch are zero
        // => no-op - optimization, no need to progress epochs if last two are emtpy
        // => ie. no pending unlocks, no unlocks processing
        if (currentEpochAmount != 0) {
            ++$.currentEpoch;
            $.lastEpochUnlockedAt = block.number;

            // calculate shares to undelegate from The Graph
            IGraphStaking.DelegationPool memory delPool = GRAPH_STAKING.delegationPools(validator);
            uint256 undelegationShares = currentEpochAmount * delPool.shares / delPool.tokens;
            // account for possible rounding error
            undelegationShares = del.shares < undelegationShares ? del.shares : undelegationShares;

            // undelegate
            GRAPH_STAKING.undelegate(validator, undelegationShares);
        } else if ($.epochs[$.currentEpoch - 1].amount != 0) {
            ++$.currentEpoch;
            $.lastEpochUnlockedAt = block.number;
        }
    }

    function _processWithdraw(address validator) internal {
        // withdrawal isn't ready: no-op
        uint256 tokensLockedUntil = GRAPH_STAKING.getDelegation(validator, address(this)).tokensLockedUntil;
        if (tokensLockedUntil == 0 || tokensLockedUntil > GRAPH_EPOCHS.currentEpoch()) return;

        Storage storage $ = _loadStorage();

        // withdraw undelegated
        unchecked {
            // $.currentEpoch - 1 is safe as we only call this function after at least 1 _processUnstake
            // which increments $.currentEpoch, otherwise del.tokensLockedUntil would still be 0 and we would
            // not reach this branch
            $.epochs[$.currentEpoch - 1].amount = GRAPH_STAKING.withdrawDelegated(validator, address(0));
        }
    }
}
