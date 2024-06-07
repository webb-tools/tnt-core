// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "core/hooks/RequestHook.sol";

contract SimpleSubscriptionRequestHook is RequestHookBase {
    uint256 public price;

    mapping(uint256 => uint256) public paidAmountForSubscription;

    error InsufficientPayment(uint256 price, uint256 paid);
    error InsufficientFunds(uint256 required, uint256 available);

    function setPrice(uint256 _price) public {
        price = _price;
    }

    function topUpSubscription(uint256 serviceId) public payable {
        paidAmountForSubscription[serviceId] += msg.value;
    }

    function requestService(uint256 serviceId) public payable override returns (bool) {
        if (msg.value < price) {
            revert InsufficientPayment(price, msg.value);
        }

        paidAmountForSubscription[serviceId] += msg.value;

        return true;
    }

    function onJobCall(uint256 serviceId, uint8 jobId, bytes memory inputs) public override returns (bool) {
        if (jobId == 0) {
            // Take 1 token unit from the subscription
            if (paidAmountForSubscription[serviceId] < 1 ether) {
                revert InsufficientFunds(1 ether, paidAmountForSubscription[serviceId]);
            }
            paidAmountForSubscription[serviceId] -= 1 ether;
        } else if (jobId == 1) {
            // Take 0.1 token units from the subscription
            if (paidAmountForSubscription[serviceId] < 0.1 ether) {
                revert InsufficientFunds(0.1 ether, paidAmountForSubscription[serviceId]);
            }
            paidAmountForSubscription[serviceId] -= 0.1 ether;
        } else {
            revert("Invalid job ID");
        }
    }
}
