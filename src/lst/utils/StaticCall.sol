// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.19;

error StaticCallFailed(address to, bytes data, string message);

function _staticcall(address target, bytes memory data) view returns (bytes memory) {
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returnData) = address(target).staticcall(data);

    if (!success) {
        if (returnData.length < 68) revert StaticCallFailed(address(target), data, "");
        assembly {
            returnData := add(returnData, 0x04)
        }
        revert StaticCallFailed(address(target), data, abi.decode(returnData, (string)));
    }

    return returnData;
}
