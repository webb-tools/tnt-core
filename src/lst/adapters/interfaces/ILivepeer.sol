// SPDX-License-Identifier: MIT
//
//  _____              _           _
// |_   _|            | |         (_)
//   | | ___ _ __   __| | ___ _ __ _ _______
//   | |/ _ \ '_ \ / _` |/ _ \ '__| |_  / _ \
//   | |  __/ | | | (_| |  __/ |  | |/ /  __/
//   \_/\___|_| |_|\__,_|\___|_|  |_/___\___|
//
// Copyright (c) Tenderize Labs Ltd

pragma solidity >=0.8.19;

interface ILivepeerBondingManager {
    function bond(uint256 _amount, address _to) external;

    function unbond(uint256 _amount) external;

    function withdrawStake(uint256 _unbondingLockId) external;

    function withdrawFees(address payable, uint256) external;

    function pendingFees(address _delegator, uint256 _endRound) external view returns (uint256);

    function pendingStake(address _delegator, uint256 _endRound) external view returns (uint256);

    function getDelegator(address _delegator)
        external
        view
        returns (
            uint256 bondedAmount,
            uint256 fees,
            address delegateAddress,
            uint256 delegatedAmount,
            uint256 startRound,
            uint256 lastClaimRound,
            uint256 nextUnbondingLockId
        );

    function getDelegatorUnbondingLock(
        address _delegator,
        uint256 _unbondingLockId
    )
        external
        view
        returns (uint256 amount, uint256 withdrawRound);

    function isRegisteredTranscoder(address _transcoder) external view returns (bool);

    function unbondingPeriod() external view returns (uint256);
}

interface ILivepeerRoundsManager {
    function currentRound() external view returns (uint256);

    function currentRoundInitialized() external view returns (bool);

    function currentRoundStartBlock() external view returns (uint256);

    function roundLength() external view returns (uint256);
}
