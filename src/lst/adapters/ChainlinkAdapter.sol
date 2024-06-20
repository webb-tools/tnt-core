// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

uint256 constant VERSION = 1;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { Adapter } from "core/lst/adapters/Adapter.sol";
import { Staking } from "chainlink-staking/Staking.sol";
import { IERC165 } from "core/lst/interfaces/IERC165.sol";

ERC20 constant LINK = ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
Staking constant CHAINLINK_STAKING = Staking(0x3feB1e09b4bb0E7f0387CeE092a52e85797ab889);

contract ChainlinkAdapter is Adapter {
    using SafeTransferLib for ERC20;

    struct Storage {
        uint256 lastRebaseTimestamp;
    }

    uint256 private constant STORAGE = uint256(keccak256("xyz.liquifier.chainlink.adapter.storage.location")) - 1;

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

    function previewDeposit(address, /*validator*/ uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function previewWithdraw(uint256) external pure returns (uint256 amount) {
        // In Chainlink, we don't have individual unlock IDs. 
        // Instead, we'll return the total staked amount.
        return CHAINLINK_STAKING.getStake(address(this));
    }

    function unlockMaturity(uint256) external view returns (uint256 maturity) {
        // Chainlink doesn't have a concept of unlock maturity.
        // We'll return the current time plus the unbonding period.
        (, uint256 endTimestamp) = CHAINLINK_STAKING.getRewardTimestamps();
        return endTimestamp;
    }

    function unlockTime() external view override returns (uint256) {
        // Return the time left until the end of the staking period
        (, uint256 endTimestamp) = CHAINLINK_STAKING.getRewardTimestamps();
        return endTimestamp > block.timestamp ? endTimestamp - block.timestamp : 0;
    }

    function currentTime() external view override returns (uint256) {
        return block.timestamp;
    }

    function stake(address validator, uint256 amount) public returns (uint256) {
        LINK.safeApprove(address(CHAINLINK_STAKING), amount);
        CHAINLINK_STAKING.onTokenTransfer(address(this), amount, "");
        return amount;
    }

    function unstake(address, /*validator*/ uint256 amount) external returns (uint256) {
        // Chainlink doesn't support partial unstaking, so we ignore the amount
        // and unstake everything
        CHAINLINK_STAKING.unstake();
        return CHAINLINK_STAKING.getStake(address(this));
    }

    function withdraw(address, /*validator*/ uint256) external returns (uint256 amount) {
        // Chainlink automatically withdraws when unstaking, so this function is empty
        return 0;
    }

    function rebase(address validator, uint256 currentStake) external returns (uint256 newStake) {
        Storage storage $ = _loadStorage();
        if (block.timestamp - $.lastRebaseTimestamp < 1 days) {
            return currentStake;
        }

        $.lastRebaseTimestamp = block.timestamp;

        // Claim rewards (if any)
        uint256 baseReward = CHAINLINK_STAKING.getBaseReward(address(this));
        uint256 delegationReward = CHAINLINK_STAKING.getDelegationReward(address(this));
        
        if (baseReward + delegationReward > 0) {
            // Note: In the actual Chainlink staking contract, there might be a separate
            // function to claim rewards. This is a placeholder.
            // CHAINLINK_STAKING.claimRewards();

            // Restake rewards
            stake(validator, baseReward + delegationReward);
        }

        // Read new stake
        newStake = CHAINLINK_STAKING.getStake(address(this));
    }

    function isValidator(address validator) public view override returns (bool) {
        return CHAINLINK_STAKING.isOperator(validator);
    }
}