#!/bin/bash
set -x

forge build

curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","id":67,"method":"anvil_setCode","params": ["0x4e59b44847b379578588920ca78fbf26c0b4956c","0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"]}' 127.0.0.1:8545

source .env

# Deterministic
export REGISTRY=0x6232894e592F104FB561c1Fb59a52ea01ee7D867
export FACTORY=0x62536191D4EB10D4CA5909D60232593A1b40BE10

# forge script script/Tenderize_Deploy.s.sol:Tenderize_Deploy --rpc-url ${ARBITRUM_GOERLI_RPC} --broadcast --private-key $PRIVATE_KEY -vvvv


# Deploy Livepeer
# Parameters
export NAME="Livepeer"
export SYMBOL="LPT"
export BASE_APR="280000"
export UNLOCK_TIME="604800"
export TOTAL_SUPPLY="30000000000000000000000000"
export ID=0
forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --rpc-url ${ARBITRUM_GOERLI_RPC} --broadcast --private-key $PRIVATE_KEY -vvvv

# Deploy Graph 
export NAME="The Graph"
export SYMBOL="GRT"
export BASE_APR="170000"
export UNLOCK_TIME="2419200"
export TOTAL_SUPPLY="10000000000000000000000000000"
export ID=1
forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --rpc-url ${ARBITRUM_GOERLI_RPC} --broadcast --private-key $PRIVATE_KEY -vvvv

# Deploy Polygon 
export NAME="Polygon"
export SYMBOL="POL"
export BASE_APR="110000"
export UNLOCK_TIME="201600"
export TOTAL_SUPPLY="10000000000000000000000000000"
export ID=2
forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --rpc-url ${ARBITRUM_GOERLI_RPC} --broadcast --private-key $PRIVATE_KEY -vvvv

