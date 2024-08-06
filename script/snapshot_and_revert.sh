#!/bin/bash

source .env

# Script to create a snapshot
# curl -X POST --data '{"jsonrpc":"2.0","method":"evm_snapshot","params":[],"id":1}' $TENDERLY_VIRTUAL_TESTNET_RPC
# {"id":1,"jsonrpc":"2.0","result":"0x6608bd282e04b8b4784a358d9436d0ce112b75deb9989330c9370c632211db32"}%                                                              

#!/bin/bash
# Script to restore to a snapshot
curl -X POST --data '{"jsonrpc":"2.0","method":"evm_revert","params":["0x6608bd282e04b8b4784a358d9436d0ce112b75deb9989330c9370c632211db32"],"id":1}' $TENDERLY_VIRTUAL_TESTNET_RPC
