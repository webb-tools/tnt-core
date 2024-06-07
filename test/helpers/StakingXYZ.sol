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

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

pragma solidity >=0.8.19;

contract StakingXYZ {
    address private immutable token;
    uint256 public nextRewardTimeStamp;

    uint256 public immutable APR;
    uint256 public constant APR_PRECISION = 1e6;
    uint256 public constant SECONDS_IN_A_YEAR = 31_536_000;

    uint256 public immutable unlockTime;

    struct Unlock {
        uint256 amount;
        uint256 maturity;
    }

    mapping(address => uint256) public staked;
    mapping(address => uint256) public lastClaimed;
    mapping(address => mapping(uint256 => Unlock)) public unlocks;
    mapping(address => uint256) public unlockCount;

    constructor(address _token, uint256 _unlockTime, uint256 _baseAPR) {
        token = _token;
        unlockTime = _unlockTime;
        APR = _baseAPR;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "amount must be greater than 0");
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        if (staked[msg.sender] == 0) {
            lastClaimed[msg.sender] = block.timestamp;
        }
        staked[msg.sender] = staked[msg.sender] + amount;
    }

    function unstake(uint256 amount) external returns (uint256 unlockID) {
        staked[msg.sender] -= amount;
        unlockID = unlockCount[msg.sender]++;
        unlocks[msg.sender][unlockID] = Unlock(amount, block.timestamp + unlockTime);
    }

    function withdraw(uint256 id) external returns (uint256) {
        Unlock memory unlock = unlocks[msg.sender][id];
        require(unlock.maturity <= block.timestamp, "unlock time not reached");
        delete unlocks[msg.sender][id];
        ERC20(token).transfer(msg.sender, unlock.amount);
        return unlock.amount;
    }

    function claimrewards() external {
        if (block.timestamp == lastClaimed[msg.sender]) return;

        uint256 timeDiff = block.timestamp - lastClaimed[msg.sender];
        uint256 extraAPR = block.number % APR;
        uint256 reward = (staked[msg.sender] * (APR + extraAPR) * timeDiff) / SECONDS_IN_A_YEAR / APR_PRECISION;

        if (reward > 0) {
            staked[msg.sender] = staked[msg.sender] + reward;
            lastClaimed[msg.sender] = block.timestamp;
            MockERC20(token).mint(address(this), reward);
        }
    }
}
