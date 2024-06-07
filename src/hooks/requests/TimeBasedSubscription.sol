// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "core/hooks/RequestHook.sol";

contract TimeBasedSubscriptionRequestHook is RequestHookBase {
    uint256 public price;
    uint256 public duration;

    mapping(uint256 => uint256) public paidAmountForSubscription;
    mapping(uint256 => uint256) public expirationOfSubscription;

    error ExpiredSubscription();
    error InsufficientPayment(uint256 price, uint256 paid);

    function setPrice(uint256 _price) public {
        price = _price;
    }

    function setDuration(uint256 _duration) public {
        duration = _duration;
    }

    /// We want to charge `price` for `duration` blocks.
    function extendService(uint256 serviceId, uint256 _duration) public payable {
        // Check if the payment is sufficient.
        if (msg.value != price) {
            revert InsufficientPayment(price, msg.value);
        } else {
            paidAmountForSubscription[serviceId] += msg.value;
        }

        // Extend the service subscription.
        if (expirationOfSubscription[serviceId] < block.number) {
            expirationOfSubscription[serviceId] = block.number + _duration;
        } else {
            expirationOfSubscription[serviceId] += _duration;
        }
    }

    function topUpSubscription(uint256 serviceId) public payable {
        paidAmountForSubscription[serviceId] += msg.value;
    }

    function requestService(uint256 serviceId) public payable override returns (bool) {
        if (msg.value < price) {
            revert InsufficientPayment(price, msg.value);
        }

        paidAmountForSubscription[serviceId] += msg.value;
        expirationOfSubscription[serviceId] = block.number + 10_000;

        return true;
    }

    function onJobCall(uint256 serviceId, uint8 jobId, bytes memory inputs) public view override returns (bool) {
        if (block.number >= expirationOfSubscription[serviceId]) {
            revert ExpiredSubscription();
        }

        return true;
    }
}
