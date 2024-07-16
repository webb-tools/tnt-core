#!/bin/bash
# set -x
# nohup bash -c "anvil --chain-id 1337 &" >/dev/null 2>&1 && sleep 5

# forge build

# curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","id":67,"method":"anvil_setCode","params": ["0x4e59b44847b379578588920ca78fbf26c0b4956c","0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"]}' 127.0.0.1:8545

# address = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export REGISTRY=0xa7cA8732Be369CaEaE8C230537Fc8EF82a3387EE
export FACTORY=0xF09b219D86Ff3b533FC72148a21a948Ac48216CA

# forge script script/Liquifie_Deploy.s.sol:Liquifie_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv
#   Registry Implementation:  0xC1Ae73A0dbC185048D9afe487BDbf1CCf3a513a0
#   Registry Proxy:  0xa7cA8732Be369CaEaE8C230537Fc8EF82a3387EE
#   Renderer Implementation:  0xe88d90F5742dd7E214f978178f63cc961F3D10F0
#   Renderer Proxy:  0x43c3dBEE4d6E884Dc2b81E9432EcEe29DD8E008D
#   Unlocks:  0xb98c7e67f63d198BD96574073AD5B3427a835796
#   Liquifier Implementation:  0x8ACd955Cb1073f018d0737708E258cCf3F6bA824
#   Factory:  0xF09b219D86Ff3b533FC72148a21a948Ac48216CA


# Deploy Livepeer
# Parameters
export NAME="Livepeer"
export SYMBOL="LPT"
export BASE_APR="280000"
export UNLOCK_TIME="604800"
export TOTAL_SUPPLY="30000000000000000000000000"
export ID=0
forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv


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