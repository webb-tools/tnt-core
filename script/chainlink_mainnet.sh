#!/bin/bash

source .env

# Set up environment variables
# address = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

export LINK_TOKEN=0x514910771AF9Ca656af840dff83E8264EcF986CA
export STAKING_CONTRACT=0x3feB1e09b4bb0E7f0387CeE092a52e85797ab889


deploy_logs=$(forge script script/Liquifie_Deploy.s.sol:Liquifie_Deploy \
--private-key $PRIVATE_KEY  \
--rpc-url ${TENDERLY_VIRTUAL_TESTNET_RPC} \
--etherscan-api-key $TENDERLY_ACCESS_KEY \
--verify \
--verifier-url ${TENDERLY_VERIFIER_URL} \
--broadcast --slow -vvvv)

# Extract registry and factory addresses from logs using grep with regex
export REGISTRY=$(echo "$deploy_logs" | awk '/Registry Proxy:  /' | grep -o '0x[0-9a-fA-F]*')
export FACTORY=$(echo "$deploy_logs" | awk '/Factory:  /' | grep -o '0x[0-9a-fA-F]*')

echo "Registry Proxy Address: $REGISTRY"
echo "Factory Address: $FACTORY"
# # Set up environment varifbles for the next script
export TOKEN=$LINK_TOKEN
export ASSET=$TOKEN

# Deploy adapter 
adapter_logs=$(forge script script/Adapter_Deploy.s.sol:Adapter_Deploy \
--private-key $PRIVATE_KEY  \
--rpc-url ${TENDERLY_VIRTUAL_TESTNET_RPC} \
--etherscan-api-key $TENDERLY_ACCESS_KEY \
--verify \
--verifier-url ${TENDERLY_VERIFIER_URL} \
--broadcast --slow -vvvv)

# Extract Liquifier address from logs
ADAPTER=$(echo "$adapter_logs" | awk '/Adapter Address:  /' | grep -o '0x[0-9a-fA-F]*')

echo "Adapter Address: $ADAPTER"

# Deploy Liquifier using Factory and capture logs
liquifier_logs=$(forge script script/XYZ_Liquifier.s.sol:XYZ_Liquifier \
--private-key $PRIVATE_KEY  \
--rpc-url ${TENDERLY_VIRTUAL_TESTNET_RPC} \
--etherscan-api-key $TENDERLY_ACCESS_KEY \
--verify \
--verifier-url ${TENDERLY_VERIFIER_URL} \
--broadcast --slow -vvvv)

# Extract Liquifier address from logs
LIQUIFIER=$(echo "$liquifier_logs" | awk '/Token Liquifier Address:  /' | grep -o '0x[0-9a-fA-F]*')

echo "Liquifier Address: $LIQUIFIER"

# Set up environment variables for the next script
export LIQUIFIER

