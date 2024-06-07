// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "core/hooks/RegistrationHook.sol";

struct PublicKey {
    bytes publicKey;
    bytes PoK;
}

/// @dev Bls381PublicKeyRegistration contract is a registration hook that requires operators to register public keys.
/// @dev The public key is a 48-byte array and the proof of knowledge (PoK) is a 96-byte array.
/// @dev The public key and PoK are concatenated together and passed as the registration inputs.
///
/// @notice This is particularly useful for silent MPC protocols, where customers can request services
/// without needing participants to run a setup phase apriori. We accomplish this by requiring
/// operators to register their public keys and PoKs before they can participate in the service.
contract Bls381PublicKeyRegistration is RegistrationHook {
    mapping(address => uint256) public accountToPublicKey;
    PublicKey[] publicKeys;

    error InvalidPoK();

    constructor() {
        publicKeys.push(PublicKey({publicKey: "", PoK: ""}));
    }

    function getPublicKey(uint256 index) public view returns (bytes memory) {
        return publicKeys[index].publicKey;
    }

    function getPublicKeys() public view returns (PublicKey[] memory) {
        // Return the public keys except the 1st index
        PublicKey[] memory keys = new PublicKey[](publicKeys.length - 1);
        for (uint256 i = 1; i < publicKeys.length; i++) {
            keys[i - 1] = publicKeys[i];
        }

        return keys;
    }

    function verifyPoK(bytes memory publicKey, bytes memory proof) internal returns (bool) {
        return true;
    }

    function onRegister(bytes calldata registrationInputs) public payable override returns (bool) {
        bytes memory publicKey = registrationInputs[:48];
        bytes memory proof = registrationInputs[48:];

        if (!verifyPoK(publicKey, proof)) {
            revert InvalidPoK();
        }

        if (accountToPublicKey[msg.sender] != 0) {
            return false;
        }

        accountToPublicKey[msg.sender] = publicKeys.length;
        publicKeys.push(PublicKey({publicKey: publicKey, PoK: proof}));

        return true;
    }
}
