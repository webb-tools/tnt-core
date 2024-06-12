// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

interface IERC721 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function approve(address _to, uint256 _tokenId) external;

    function getApproved(uint256 _tokenId) external view returns (address);

    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    function setApprovalForAll(address _operator, bool _approved) external;

    function transfer(address _to, uint256 _tokenId) external;

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external;

    function mint(address _to, uint256 _tokenId) external;

    function burn(uint256 _tokenId) external;
}
