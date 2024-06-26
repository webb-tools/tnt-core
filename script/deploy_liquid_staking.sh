#!/bin/bash
# set -x
# nohup bash -c "anvil --chain-id 1337 &" >/dev/null 2>&1 && sleep 5

#!/bin/bash

# Set up environment variables
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deploy contracts and capture logs
deploy_logs=$(forge script script/Liquifie_Deploy.s.sol:Liquifie_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv)

# Extract registry and factory addresses from logs using grep with regex
REGISTRY=$(echo "$deploy_logs" | awk '/Registry Proxy:  /' | grep -o '0x[0-9a-fA-F]*')
FACTORY=$(echo "$deploy_logs" | awk '/Factory:  /' | grep -o '0x[0-9a-fA-F]*')

echo "Registry Proxy Address: $REGISTRY"
echo "Factory Address: $FACTORY"

# Set up environment variables for the next script
export REGISTRY
export FACTORY
export NAME="Livepeer"
export SYMBOL="LPT"
export BASE_APR="280000"
export UNLOCK_TIME="604800"
export TOTAL_SUPPLY="30000000000000000000000000"
export TOKEN_AMOUNT="100000000000000000000"  # 100 tokens with 18 decimals

# Deploy XYZ token, staking contract, and adapter and capture logs
xyz_deploy_logs=$(forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv)

# Extract LPT token and staking contract addresses from logs using grep and sed
LPT_TOKEN=$(echo "$xyz_deploy_logs" | awk '/LPT Token:  /' | grep -o '0x[0-9a-fA-F]*')
STAKING_CONTRACT=$(echo "$xyz_deploy_logs" | awk '/LPT Staking:  /' | grep -o '0x[0-9a-fA-F]*')

echo "LPT Token Address: $LPT_TOKEN"
echo "Staking Contract Address: $STAKING_CONTRACT"

# Set up environment varifbles for the next script
export TOKEN=$LPT_TOKEN

# Deploy Liquifier using Factory and capture logs
liquifier_logs=$(forge script script/XYZ_Liquifier.s.sol:XYZ_Liquifier --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv)
# Extract Liquifier address from logs
LIQUIFIER=$(echo "$liquifier_logs" | awk '/LPT Liquifier Address:  /' | grep -o '0x[0-9a-fA-F]*')

echo "Liquifier Address: $LIQUIFIER"

# Set up environment variables for the next script
export LIQUIFIER

# Stake 100 LPT tokens and capture logs
liquifier_logs=$(forge script script/XYZ_Stake.s.sol:XYZ_Stake --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv)

echo "$liquifier_logs"