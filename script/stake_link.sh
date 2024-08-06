#!/bin/bash

# Load environment variables
source .env

# Set up environment variables
# address = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

export TOKEN=0x514910771AF9Ca656af840dff83E8264EcF986CA
export LIQUIFIER=0x2871dafdb3b0047d06bbdb42f865ded2514dd9b0



# Execute the LINK_Stake script
forge script script/XYZ_Stake.s.sol:XYZ_Stake \
--private-key $PRIVATE_KEY  \
--rpc-url ${TENDERLY_VIRTUAL_TESTNET_RPC} \
--etherscan-api-key $TENDERLY_ACCESS_KEY \
--verify \
--verifier-url ${TENDERLY_VERIFIER_URL} \
--broadcast --slow -vvvv

echo "LINK staking completed. Check the logs above for details."