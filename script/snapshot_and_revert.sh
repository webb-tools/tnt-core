#!/bin/bash

source .env

# Script to create a snapshot
# curl -X POST --data '{"jsonrpc":"2.0","method":"evm_snapshot","params":[],"id":1}' $TENDERLY_VIRTUAL_TESTNET_RPC
# {"id":1,"jsonrpc":"2.0","result":"0xa84c622c5e4f5b38238632d9df2120a59232f90d6a162ecf87f0e65a12823bca"}%                                                              

#!/bin/bash
# Script to restore to a snapshot
curl -X POST --data '{"jsonrpc":"2.0","method":"evm_revert","params":["0xa84c622c5e4f5b38238632d9df2120a59232f90d6a162ecf87f0e65a12823bca"],"id":1}' $TENDERLY_VIRTUAL_TESTNET_RPC
