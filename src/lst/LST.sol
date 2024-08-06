// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract LST is ERC20 {
    IERC20 public token;

    constructor(address _token) ERC20("Liquid Staking Token", "LST") {
        token = IERC20(_token);
    }

    function deposit(uint256 _amount) public {
        // Amount must be greater than zero
        require(_amount > 0, "amount cannot be 0");

        // Transfer MyToken to contract
        token.transferFrom(msg.sender, address(this), _amount);

        // Mint LST to sender
        _mint(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        // Burn LST from sender
        _burn(msg.sender, _amount);

        // Transfer MyTokens from this contract to the sender
        token.transfer(msg.sender, _amount);
    }
}
