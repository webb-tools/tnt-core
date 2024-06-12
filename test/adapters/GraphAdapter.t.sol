// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";
import { GraphAdapter, GRAPH_STAKING, GRAPH_EPOCHS, GRT } from "core/lst/adapters/GraphAdapter.sol";
import { IERC20 } from "core/lst/interfaces/IERC20.sol";
import { IGraphStaking, IGraphEpochManager } from "core/lst/adapters/interfaces/IGraph.sol";
import { TestHelpers } from "test/helpers/Helpers.sol";

// solhint-disable func-name-mixedcase

contract GraphAdapterTest is Test, GraphAdapter, TestHelpers {
    address private staking = address(GRAPH_STAKING);
    address private epochs = address(GRAPH_EPOCHS);
    address private token = address(GRT);

    address private validator = vm.addr(1);

    uint256 private constant DELEGATION_TAX = 5000;
    uint256 private constant MAX_PPM = 1_000_000;
    uint256 private constant THAWING_PERIOD = 201_600;

    uint256 private constant MAX_UINT = type(uint256).max;
    uint256 private MAX_UINT_SQRT = sqrt(MAX_UINT - 1);

    function setUp() public {
        vm.etch(staking, bytes("code"));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationTaxPercentage, ()), abi.encode(DELEGATION_TAX));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.thawingPeriod, ()), abi.encode(THAWING_PERIOD));
    }

    function testFuzz_PreviewDeposit(uint256 amount) public {
        amount = bound(amount, 1, 10e32);

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, 1 ether, 1 ether));
        uint256 am = amount - amount * DELEGATION_TAX / MAX_PPM;
        uint256 shares = am * 1 ether / 1 ether;
        uint256 ev = shares * (1 ether + am) / (1 ether + shares);
        assertEq(this.previewDeposit(validator, amount), ev);
    }

    function testFuzz_UnlockMaturity(uint256 lastEpochUnlockedAt, uint256 userEpoch) public {
        uint256 unlockId = 1;
        uint256 currentEpoch = 2;
        userEpoch = bound(userEpoch, 0, currentEpoch);
        vm.roll(rand(1, 1, 1, MAX_UINT_SQRT));

        lastEpochUnlockedAt = bound(lastEpochUnlockedAt, block.number - THAWING_PERIOD, block.number);

        Storage storage $ = _loadStorage();
        $.currentEpoch = currentEpoch;
        $.unlocks[unlockId].epoch = userEpoch;
        $.lastEpochUnlockedAt = lastEpochUnlockedAt;

        vm.expectCall(staking, abi.encodeCall(IGraphStaking.thawingPeriod, ()));

        if (userEpoch == currentEpoch) {
            assertEq(this.unlockMaturity(unlockId), $.lastEpochUnlockedAt + 2 * THAWING_PERIOD, "invalid when yet to process");
        }
        if (userEpoch == currentEpoch - 1) {
            assertEq(this.unlockMaturity(unlockId), $.lastEpochUnlockedAt + THAWING_PERIOD, "invalid when processing");
        }
        if (userEpoch < currentEpoch - 1) assertEq(this.unlockMaturity(unlockId), 0, "invalid when processed");
    }

    function testFuzz_PreviewWithdraw(uint256 unlockShares, uint256 epochAmount, uint256 epochTotalShares) public {
        uint256 unlockID = 1;
        uint256 unlockEpoch = 1;
        vm.assume(epochTotalShares > 0);
        unlockShares = bound(unlockShares, 0, MAX_UINT_SQRT);
        epochAmount = bound(epochAmount, 0, MAX_UINT_SQRT);
        Storage storage $ = _loadStorage();
        $.unlocks[unlockID].shares = unlockShares;
        $.unlocks[unlockID].epoch = unlockEpoch;
        $.epochs[unlockEpoch].amount = epochAmount;
        $.epochs[unlockEpoch].totalShares = epochTotalShares;
        assertEq(this.previewWithdraw(unlockID), unlockShares * epochAmount / epochTotalShares);
    }

    function testFuzz_Stake(uint256 amount) public {
        amount = bound(amount, 1, 10e32);
        vm.mockCall(token, abi.encodeCall(IERC20.approve, (staking, amount)), abi.encode(true));
        uint256 am = amount - amount * DELEGATION_TAX / MAX_PPM;
        uint256 shares = am * 1 ether / 1 ether;
        uint256 ev = shares * (1 ether + am) / (1 ether + shares);
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegate, (validator, amount)), abi.encode(shares));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, 1 ether, 1 ether));
        vm.expectCall(token, abi.encodeCall(IERC20.approve, (staking, amount)));
        vm.expectCall(staking, abi.encodeCall(IGraphStaking.delegate, (validator, amount)));
        uint256 staked = this.stake(validator, amount);
        assertEq(staked, ev, "invalid staked amount");
    }

    function test_Stake_RevertIfApproveFails() public {
        vm.mockCall(token, abi.encodeCall(IERC20.approve, (address(staking), 1 ether)), abi.encode(false));

        vm.expectRevert("APPROVE_FAILED");
        this.stake(validator, 1 ether);
    }

    function testFuzz_Unstake_WithoutProcessing(uint256 amount, uint256 epochAmount, uint256 epochShares) public {
        vm.roll(1);
        uint256 epoch = 1;
        uint256 lastUnlockID = 0;

        amount = bound(amount, 1, MAX_UINT_SQRT);
        epochShares = bound(epochShares, 0, MAX_UINT_SQRT);
        epochAmount = bound(epochAmount, 0, MAX_UINT_SQRT);

        // prevent unlock processing by setting the mocked value for `Delegation.tokensLockedUntil` to `block.number + 1`
        vm.mockCall(
            staking,
            abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))),
            abi.encode(10 ether, 1 ether, block.number + 1)
        );

        vm.mockCall(epochs, abi.encodeCall(IGraphEpochManager.currentEpoch, ()), abi.encode(epoch));

        Storage storage $ = _loadStorage();
        $.currentEpoch = epoch;
        $.epochs[epoch].amount = epochAmount;
        $.epochs[epoch].totalShares = epochShares;
        $.lastUnlockID = lastUnlockID;

        uint256 unlockID = this.unstake(validator, amount);

        uint256 expShares = epochAmount == 0 ? amount : amount * epochShares / epochAmount;
        assertEq(unlockID, lastUnlockID + 1, "invalid unlock ID returned");
        assertEq($.epochs[epoch].amount, epochAmount + amount, "invalid epoch amount");
        assertEq($.epochs[epoch].totalShares, epochShares + expShares, "invalid epoch shares");
        assertEq($.unlocks[unlockID].shares, expShares, "invalid unlock shrares");
        assertEq($.unlocks[unlockID].epoch, 1, "invalid unlock epoch");
        assertEq($.lastUnlockID, lastUnlockID + 1, "invalid nextUnlockID");
        assertEq($.currentEpoch, epoch, "invalid epoch");
    }

    function testFuzz_Unstake(uint256 amount, uint256 stakedAmount, uint256 stakedShares) public {
        stakedAmount = bound(stakedAmount, 1 ether, 10e32);
        amount = bound(amount, 1, stakedAmount);
        stakedShares = bound(stakedShares, 1 ether, 10e32);
        uint256 epoch = 1;
        uint256 lastUnlockID = 1;

        Storage storage $ = _loadStorage();
        $.currentEpoch = epoch;
        $.lastUnlockID = lastUnlockID;

        // No unlock processing (del.tokensLockedUntil = 0)
        // and currentEpoch.amount != 0 since we undelegate `amount`
        // => undelegate currentEpoch.amount
        // For this test epoch shares are 1:1 to epoch amounts

        vm.mockCall(
            staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, stakedAmount, stakedShares)
        );

        vm.mockCall(
            staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))), abi.encode(stakedShares, 0, 0)
        );
        vm.mockCall(epochs, abi.encodeCall(IGraphEpochManager.currentEpoch, ()), abi.encode(epoch));
        uint256 expUndelegateShares = amount * stakedShares / stakedAmount;
        vm.mockCall(
            staking, abi.encodeCall(IGraphStaking.undelegate, (validator, expUndelegateShares)), abi.encode(expUndelegateShares)
        );
        vm.expectCall(staking, abi.encodeCall(IGraphStaking.undelegate, (validator, expUndelegateShares)));
        this.unstake(validator, amount);
        assertEq($.currentEpoch, epoch + 1, "invalid epoch");
        assertEq($.lastEpochUnlockedAt, block.number, "invalid lastEpochUnlockedAt");
        assertEq($.unlocks[lastUnlockID + 1].shares, amount, "invalid unlock shares");
        assertEq($.unlocks[lastUnlockID + 1].epoch, epoch, "invalid unlock epoch");
        assertEq($.epochs[epoch].amount, amount, "invalid epoch amount");
        assertEq($.epochs[epoch].totalShares, amount, "invalid epoch shares");
    }

    function test_Withdraw_LastTwoEpochsEmpty() public {
        uint256 amount = 1 ether;
        // should neither call `undelegate` nor `withdrawDelegation`
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))), abi.encode(amount, 0, 0));

        Storage storage $ = _loadStorage();
        uint256 epoch = 2;
        $.currentEpoch = epoch;
        this.withdraw(validator, 0);
        assertEq($.currentEpoch, epoch, "invalid epoch");
        assertEq($.lastEpochUnlockedAt, 0, "invalid lastEpochUnlockedAt");
    }

    function test_Withdraw_PreviousEpochEmpty() public {
        uint256 amount = 1 ether;

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, amount, amount));
        // should call `undelegate` but not `withdrawDelegation`
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))), abi.encode(amount, 0, 0));

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.undelegate, (validator, amount)), abi.encode(0));

        Storage storage $ = _loadStorage();
        // set unlock id 0 for epoch 0
        $.unlocks[0].shares = amount;
        $.epochs[0].totalShares = amount;
        $.epochs[0].amount = amount;

        uint256 epoch = 2;
        $.currentEpoch = epoch;
        $.epochs[epoch].amount = amount;
        $.epochs[epoch].totalShares = amount;

        vm.expectCall(staking, abi.encodeCall(IGraphStaking.undelegate, (validator, amount)));
        this.withdraw(validator, 0);
        assertEq($.currentEpoch, epoch + 1, "invalid epoch");
        assertEq($.lastEpochUnlockedAt, block.number, "invalid lastEpochUnlockedAt");
        assertEq($.epochs[0].amount, 0, "invalid unlock epoch amount");
        assertEq($.epochs[0].totalShares, 0, "invalid unlock epoch shares");
        assertEq($.epochs[epoch - 1].amount, 0, "invalid previous epoch amount");
    }

    function test_ProcessWithdraw() public {
        uint256 amount = 1 ether;

        uint256 tokensLocked = 1 ether;
        uint256 currentBlock = 100;
        vm.roll(currentBlock);
        uint256 tokensLockedUntil = rand(1, 1, 0, currentBlock - 1);
        vm.mockCall(
            staking,
            abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))),
            abi.encode(10 ether, tokensLocked, tokensLockedUntil)
        );
        vm.mockCall(epochs, abi.encodeCall(IGraphEpochManager.currentEpoch, ()), abi.encode(tokensLockedUntil));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, validator), abi.encode(0, 0, 0, 0, 10 ether, 10 ether));

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.undelegate, (validator, amount)), abi.encode(0));

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.withdrawDelegated, (validator, address(0))), abi.encode(tokensLocked));

        uint256 epoch = 1;
        _loadStorage().currentEpoch = epoch;

        vm.expectCall(staking, abi.encodeCall(IGraphStaking.withdrawDelegated, (validator, address(0))));
        uint256 unlockID = this.unstake(validator, amount);

        Storage storage $ = _loadStorage();

        assertEq($.currentEpoch, epoch, "invalid epoch");
        assertEq($.unlocks[unlockID].shares, amount, "invalid unlock shares");
        assertEq($.unlocks[unlockID].epoch, epoch, "invalid unlock epoch");
        assertEq($.epochs[epoch].amount, amount, "invalid epoch amount");
        assertEq($.epochs[epoch].totalShares, amount, "invalid epoch shares");
    }

    function testFuzz_Withdraw_WithoutProcessing(uint256 unlockShares, uint256 epochAmount, uint256 epochShares) public {
        uint256 unlockID = 1;
        uint256 unlockEpoch = 10;
        epochShares = bound(epochShares, 1, MAX_UINT_SQRT);
        unlockShares = bound(unlockShares, 1, epochShares);
        epochAmount = bound(epochAmount, 1, MAX_UINT_SQRT);

        // unlock processing
        vm.mockCall(
            staking,
            abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))),
            abi.encode(10 ether, 1 ether, unlockEpoch)
        );
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, 10 ether, 10 ether));
        vm.mockCall(epochs, abi.encodeCall(IGraphEpochManager.currentEpoch, ()), abi.encode(unlockEpoch - 1));
        Storage storage $ = _loadStorage();
        $.unlocks[unlockID].epoch = unlockEpoch;
        $.currentEpoch = unlockEpoch + 2;
        $.unlocks[unlockID].shares = unlockShares;
        $.epochs[unlockEpoch].totalShares = epochShares;
        $.epochs[unlockEpoch].amount = epochAmount;

        uint256 returnedAmount = this.withdraw(validator, unlockID);

        uint256 expAmount = unlockShares * epochAmount / epochShares;
        assertEq(returnedAmount, expAmount, "invalid return value");
        assertEq($.epochs[unlockEpoch].totalShares, epochShares - unlockShares, "invalid epoch shares");
        assertEq($.epochs[unlockEpoch].amount, epochAmount - expAmount, "invalid epoch shares");
        assertEq($.unlocks[unlockID].epoch, 0, "unlock not deleted");
        assertEq($.unlocks[unlockID].shares, 0, "unlock not deleted");

        if ($.epochs[unlockEpoch].amount == 0) {
            assertEq($.epochs[unlockEpoch].totalShares, 0, "epoch not deleted");
        }
    }

    function test_Withdraw_RevertIfPending() public {
        uint256 unlockID = 1;
        uint256 currentEpoch = 100;
        uint256 unlockEpoch = 101;

        // unlock processing
        vm.mockCall(
            staking,
            abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))),
            abi.encode(10 ether, 1 ether, unlockEpoch)
        );
        vm.mockCall(epochs, abi.encodeCall(IGraphEpochManager.currentEpoch, ()), abi.encode(currentEpoch));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, validator), abi.encode(0, 0, 0, 0, 10 ether, 10 ether));

        Storage storage $ = _loadStorage();
        $.unlocks[unlockID].epoch = unlockEpoch;
        $.currentEpoch = currentEpoch;

        vm.expectRevert(WithdrawPending.selector);
        this.withdraw(validator, unlockID);
    }

    function testFuzz_Rebase_Positive(uint256 startStake, uint256 reward) public {
        startStake = bound(startStake, 1, MAX_UINT_SQRT);
        reward = bound(reward, 1, MAX_UINT_SQRT);

        // percentage of startStake that is epochs[currentEpoch].amount
        uint256 currentEpochRatio = 0.33 ether;
        uint256 currentEpochAmountStart = startStake * currentEpochRatio / 1 ether;

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))), abi.encode(1, 1 ether, 0));
        vm.mockCall(
            staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, startStake + reward, 1)
        );

        Storage storage $ = _loadStorage();
        uint256 currentEpoch = 1;
        $.currentEpoch = currentEpoch;
        $.epochs[currentEpoch].amount = currentEpochAmountStart;

        vm.expectCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))));
        vm.expectCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)));
        uint256 newStake = this.rebase(validator, startStake - currentEpochAmountStart);

        uint256 rewardForUnlocks = reward * currentEpochAmountStart / startStake;
        uint256 rewardForStake = reward - rewardForUnlocks;
        assertEq(newStake, startStake + rewardForStake - currentEpochAmountStart, "invalid new stake");
        assertEq($.epochs[currentEpoch].amount, currentEpochAmountStart + rewardForUnlocks, "invalid current epoch amount");
        assertEq($.epochs[currentEpoch - 1].amount, 1 ether, "invalid previous epoch amount");
    }

    function test_Rebase_NoChangeInStake() public {
        uint256 currentEpoch = 1;
        uint256 staked = 10 ether;
        uint256 currentEpochRatio = 0.33 ether;
        uint256 currentEpochAmount = staked * currentEpochRatio / 1 ether;

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))), abi.encode(1, 0, 0));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, staked, 1));

        Storage storage $ = _loadStorage();
        $.currentEpoch = currentEpoch;
        $.epochs[currentEpoch].amount = currentEpochAmount;

        // TODO: Assert below call not made after https://github.com/foundry-rs/foundry/issues/4513
        // vm.expectCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))));
        vm.expectCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)));
        uint256 newStake = this.rebase(validator, staked - currentEpochAmount);
        assertEq(newStake, staked - currentEpochAmount, "invalid new stake");
    }

    function test_Rebase_NoChangeInStake_ForceRebase() public {
        uint256 currentEpoch = 1;
        uint256 staked = 10 ether;
        uint256 currentEpochRatio = 0.33 ether;
        uint256 currentEpochAmount = staked * currentEpochRatio / 1 ether;

        vm.mockCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))), abi.encode(1, 0, 0));
        vm.mockCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)), abi.encode(0, 0, 0, 0, staked, 1));

        Storage storage $ = _loadStorage();
        $.currentEpoch = currentEpoch;
        $.epochs[currentEpoch].amount = currentEpochAmount;

        vm.expectCall(staking, abi.encodeCall(IGraphStaking.delegationPools, (validator)));
        vm.expectCall(staking, abi.encodeCall(IGraphStaking.getDelegation, (validator, address(this))));
        uint256 newStake = this.rebase(validator, staked - currentEpochAmount);
        assertEq(newStake, staked - currentEpochAmount, "invalid new stake");
    }
}
