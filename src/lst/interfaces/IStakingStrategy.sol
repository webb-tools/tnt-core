// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "core/lst/interfaces/IStrategy.sol";

interface IStakingStrategy is IStrategy {
    function migrate(bytes calldata data) external;
}
