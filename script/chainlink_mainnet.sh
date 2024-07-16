#!/bin/bash
set -x

forge build

curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","id":67,"method":"anvil_setCode","params": ["0x4e59b44847b379578588920ca78fbf26c0b4956c","0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"]}' 127.0.0.1:8545

source .env
# address = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export REGISTRY=0x1C5ffc48077AbdFC8EbbE605Ab011Eb3b218B054
export FACTORY=0x25D20120328cc35afe3da930eC1295048CCd9d3b

# forge script script/Liquifie_Deploy.s.sol:Liquifie_Deploy --rpc-url ${MAINNET_RPC} --broadcast --private-key $PRIVATE_KEY -vvvv 
# --verifier-url $MAINNET_RPC/verify/etherscan

# Registry Implementation:  0x0A65d94635EE2F1573258980b40B3Fe48aC762bC
# Registry Proxy:  0x1C5ffc48077AbdFC8EbbE605Ab011Eb3b218B054
# Renderer Implementation:  0xC561771B32Ec35e7019B0306A789e5e3e6D2c3e4
# Renderer Proxy:  0x10b1F8AD54492E0CFb877E87520a60FCa0914447
# Unlocks:  0x46B6F4F05D6DB8Cb493C94479B60060531C8c87D
# Liquifier Implementation:  0x6997285deF9363D37C5eBBC04542078B21f7cE6a
# Factory:  0x25D20120328cc35afe3da930eC1295048CCd9d3b

Deploy Livepeer
Parameters
export NAME="Livepeer"
export SYMBOL="LPT"
export BASE_APR="280000"
export UNLOCK_TIME="604800"
export TOTAL_SUPPLY="30000000000000000000000000"
export ID=0
forge script script/XYZ_Deploy.s.sol:XYZ_Deploy  --rpc-url ${MAINNET_RPC}  --broadcast --private-key $PRIVATE_KEY -vvvv


#   MY ADDRESS IS
#   0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
#   LPT Token:  0x0BC472c881dc7b305Ab0dd03Bb390B52f37Cd617
#   LPT Staking : 0x98EC38B997e543c4FCd26Ce02d792c1f1F6ad5eA
#   LPT Adapter:  0x7198960C0B1e91f5E9a031507De58A4AE73B2404


# # Deploy Graph 
# export NAME="The Graph"
# export SYMBOL="GRT"
# export BASE_APR="170000"
# export UNLOCK_TIME="2419200"
# export TOTAL_SUPPLY="10000000000000000000000000000"
# export ID=1
# forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv

# # Deploy Polygon 
# export NAME="Polygon"
# export SYMBOL="POL"
# export BASE_APR="110000"
# export UNLOCK_TIME="201600"
# export TOTAL_SUPPLY="10000000000000000000000000000"
# export ID=2
# forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv


# read -r -d '' _ </dev/tty
# echo "Closing Down Anvil"
# pkill -9 anvil