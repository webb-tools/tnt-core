# echo "
# unknown_chain = { key = \"${TENDERLY_ACCESS_KEY}\", chain = 1, url = \"https://virtual.mainnet.rpc.tenderly.co/cfe3066a-1c36-4b2b-8af1-e3dd4cf99da9\" }" >> foundry.toml

# forge create Counter \
# --private-key $PRIVATE_KEY  \
# --rpc-url https://virtual.mainnet.rpc.tenderly.co/cfe3066a-1c36-4b2b-8af1-e3dd4cf99da9 \
# --etherscan-api-key $TENDERLY_ACCESS_KEY \
# --verify \
# --verifier-url https://virtual.mainnet.rpc.tenderly.co/cfe3066a-1c36-4b2b-8af1-e3dd4cf99da9/verify/etherscan


#!/bin/bash
# set -x
# nohup bash -c "anvil --chain-id 1337 &" >/dev/null 2>&1 && sleep 5

# !/bin/bash

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

# # Stake 100 LPT tokens and capture logs
# liquifier_logs=$(forge script script/XYZ_Stake.s.sol:XYZ_Stake --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv)

# echo "$liquifier_logs"

# forge verify-contract $LIQUIFIER \
# Liquifier \
# --etherscan-api-key $TENDERLY_ACCESS_KEY \
# --verifier-url $TENDERLY_VERIFIER_URL \
# --watch