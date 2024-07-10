// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "core/lst/interfaces/IVault.sol";

interface ICommunityVault is IVault {
    function claimRewards(uint256 _minRewards, address _rewardsReceiver) external;
}
