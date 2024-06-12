# Liquifier Deployments

## Deploying To Anvil

Liquifier uses `CREATE2` to deploy contracts. Forge expects this contract to be deterministically deployed at
`0x4e59b44847b379578588920ca78fbf26c0b4956c`.

Anvil by default doesn't have the `CREATE2` proxy deployed. Instead, `anvil_setCode` can be used as a workaround.

```sh
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","id":67,"method":"anvil_setCode","params": ["0x4e59b44847b379578588920ca78fbf26c0b4956c","0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"]}' 127.0.0.1:8545
```

As a sanity check you can run `cast code "0x4e59b44847b379578588920ca78fbf26c0b4956c" --rpc-url http://127.0.0.1:8545`
to see if this was succesful.

## Deploy Liquifier

The Liquifier Factory and all associated components need to be deployed only once per network by setting the vars in
`.env` and running:

```sh
source .env
forge script script/Liquifie_Deploy.s.sol --broadcast --rpc-url $GOERLI_RPC_URL --verify
```

This script will execute following calls:

1. Deploy Registry (without initialization)
   - Deploy `Registry` implementation
   - Deploy `ERC1967` UUPS Proxy
2. Deploy `Unlocks`
   - Deploy `Renderer` Implementation
   - Deploy `Renderer` `ERC1967` UUPS Proxy
   - Deploy `Unlocks` contract
3. Deploy `Liquifier` Implementation
4. Initialize `Registry` with `Liquifier` implementation address and `Unlocks` address as arguments
5. Deploy `Factory` with `Registry` address as argument
   - Set `FACTORY_ROLE` on `Registry` for `Factory`

## Deploy New Adapter

We can deploy adapters for each supported protocol on a network using:

```sh
forge script deploy/2_Adapter.s.sol --broadcast --rpc-url $GOERLI_RPC_URL --verify
```

1. Deploy `Adapter` Implementation
2. Set `Adapter` address on `Registry`
