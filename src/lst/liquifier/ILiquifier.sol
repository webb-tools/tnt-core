// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

import { IERC20 } from "core/lst/interfaces/IERC20.sol";
import { Liquifier } from "core/lst/liquifier/Liquifier.sol";

/**
 * @title ILiquifier
 * @author Tangle Labs
 * @notice This interface can be used by external sources to interfact with a Liquifier.
 * @dev Contains only the necessary API
 */
interface ILiquifier is IERC20 {
    function asset() external view returns (IERC20);
    function validator() external view returns (address);
    function deposit(address receiver, uint256 assets) external returns (uint256);
    function unlock(uint256 assets) external returns (uint256 unlockID);
    function withdraw(address receiver, uint256 unlockID) external returns (uint256 amount);
    function rebase() external;
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewWithdraw(uint256 unlockID) external view returns (uint256);
    function unlockMaturity(uint256 unlockID) external view returns (uint256);
}
