// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "core/lst/interfaces/IStaking.sol";

interface IOperatorStaking is IStaking {
    function getRemovedPrincipal(address _staker) external view returns (uint256);
}
