// SPDX-FileCopyrightText: 2021 Tenderize <info@tenderize.me>

// SPDX-License-Identifier: MIT

// solhint-disable func-name-mixedcase

pragma solidity >=0.8.19;

struct DelegatorUnbond {
    uint256 shares;
    uint256 withdrawEpoch;
}

interface IPolygonStakeManager {
    function getValidatorId(address user) external view returns (uint256);
    function getValidatorContract(uint256 validatorId) external view returns (address);
    function epoch() external view returns (uint256);
    function delegatedAmount(uint256 validatorId) external view returns (uint256);
}

interface IPolygonValidatorShares {
    function owner() external view returns (address);

    function restake() external;

    function buyVoucher(uint256 _amount, uint256 _minSharesToMint) external returns (uint256 amount);

    function sellVoucher_new(uint256 claimAmount, uint256 maximumSharesToBurn) external;

    function unstakeClaimTokens_new(uint256 unbondNonce) external;

    function exchangeRate() external view returns (uint256);

    function validatorId() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function unbondNonces(address) external view returns (uint256);

    function withdrawExchangeRate() external view returns (uint256);

    function unbonds_new(address, uint256) external view returns (DelegatorUnbond memory);

    function totalSupply() external view returns (uint256);
}

interface IPolygonStakingNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
}
