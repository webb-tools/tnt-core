// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMetricComputation {
    function compute(uint256[] memory values, uint256[] memory timestamps) external view returns (uint256);
}
