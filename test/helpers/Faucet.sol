// SPDX-License-Identifier: UNLICENSED

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Owned } from "solmate/auth/Owned.sol";

pragma solidity >=0.8.19;

contract TokenFaucet is Owned {
    ERC20 public token;
    uint256 public amount; // Amount of tokens to be distributed
    uint256 public cooldownTime; // Rate limiting cooldown in seconds
    mapping(address => uint256) public lastAccessTime; // Last time an address requested tokens

    event Distributed(address indexed receiver, uint256 amount);

    constructor(ERC20 _token, uint256 _amount, uint256 _cooldownTime) Owned(msg.sender) {
        token = _token;
        amount = _amount;
        cooldownTime = _cooldownTime;
    }

    /**
     * @dev Function for users to request tokens from the faucet.
     */
    function requestgTokens() external {
        require(lastAccessTime[msg.sender] + cooldownTime < block.timestamp, "Cooldown not over yet");

        require(token.balanceOf(address(this)) >= amount, "Not enough tokens in the faucet");

        lastAccessTime[msg.sender] = block.timestamp;

        token.transfer(msg.sender, amount);
        emit Distributed(msg.sender, amount);
    }

    /**
     * @dev Function to update the amount of tokens to be distributed.
     * @param _amount New amount to be distributed.
     */
    function setAmount(uint256 _amount) external onlyOwner {
        amount = _amount;
    }

    /**
     * @dev Function to update the cooldown time for rate limiting.
     * @param _cooldownTime New cooldown time in seconds.
     */
    function setCooldownTime(uint256 _cooldownTime) external onlyOwner {
        cooldownTime = _cooldownTime;
    }

    /**
     * @dev Function for the owner to withdraw any excess tokens.
     * @param _amount Amount of tokens to withdraw.
     */
    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(token.balanceOf(address(this)) >= _amount, "Not enough tokens in the faucet");
        token.transfer(msg.sender, _amount);
    }
}
