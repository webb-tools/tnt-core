# tnt-core

This repo contains interfaces and abstractions for using Tangle's restaking infrastructure for the creation of new
service blueprints. The service blueprint is a set of smart contracts that define the rules of the service and allow the gadget developer to customize the service to their needs, how it is used, how it is paid for, and how it is managed.


## Liquifier - Liquid Native Staking

The Liquifier protocol enables **liquid native staking**, each validator on a network can have its own permissionless
liquid staking vault and ERC20 token for itself and its delegators. It is designed to be fully credibly neutral and
autonomous, while enabling more flexibility to users when staking.

Based off of [https://github.com/Tenderize/staking](Tenderize)

## Getting Started

## Usage

Here's a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
forge clean
```

### Compile

Compile the contracts:

```sh
forge build
```

### Coverage

Get a test coverage report:

```sh
forge coverage
```

### Deploy

For full deploy flow check out the [deploy document](./script/DEPLOY.md).

#### Deploy Liquid Staking and deposit LPT tokens 

The `deploy_liquid_staking.sh` script is used to automate the deployment of the Liquifier protocol components to a local Anvil instance. This script simplifies the deployment process by setting up the necessary environment variables and executing the required deployment commands.

#### Usage

To use the `deploy_liquid_staking.sh` script, follow these steps:

1. **Start Anvil**: Open a terminal and start Anvil by running:
    ```sh
    anvil
    ```
   Leave this terminal open and let `anvil` run.

2. **Run the Script**: In a separate terminal, navigate to the directory containing the `deploy_liquid_staking.sh` script and execute it:
    ```sh
    ./script/deploy_liquid_staking.sh
    ```

The `deploy_liquid_staking.sh` script performs the following steps:

- **Deploy Registry and Factories**: Deploys the registry and factory contracts to the Anvil instance.
- **Deploy the LPT Token**: Sets the token parameters and deploys the token contract.
- **Liquid Stake the Tokens**: Deposits teh LPT tokens into the Liquifier contract, which returns tgLPT tokens 

Deploy Liquifier to Anvil:

```sh
$ forge script script/Liquifie_Deploy.s.sol:Liquifie_Deploy --fork-url http://localhost:8545 \
 --broadcast --private-key $PRIVATE_KEY
```

Deploy an Adapter to Anvil:

```sh
forge script script/Adapter_Deploy.s.sol:Adapter_Deploy  --fork-url http://localhost:8545 \
 --broadcast --private-key $PRIVATE_KEY
```

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting tutorial](https://book.getfoundry.sh/tutorials/solidity-scripting.html).

### Format

Format the contracts:

```sh
forge fmt
```

### Gas Usage

Get a gas report:

```sh
forge test --gas-report
```

### Lint

Lint the contracts:

```sh
yarn lint
```

### Test

Run the tests:

```sh
forge test
```

## Modules

- [Liquifier](): Liquid staking vault and rebasing ERC20 token
- [Unlocks](): ERC721 NFTs representing unstaked assets in their unstaking period
- [Adapter](): Interfaces for interacting with Adapters containing external protocol specific logic
- [Registry](): Registry and Role-Based access control
- [Factory](): Factory for deploying new Liquifiers for validators

### ERC1967 Storage

Liquifier contracts use [ERC1967](https://eips.ethereum.org/EIPS/eip-1967) storage slots. Each contract has its own
storage space defined as a `struct` stored at a defined location to avoid storage collisions. Storage slots are
addressed with a dollar sign, `$`, to improve readability when storage is accessed.

### Registry

The Registry keeps track of entities within the protocol. It is used to update things like `Adapter` for an asset, or
the fee for an asset. It also uses Role-based access control to manage roles. It is deployed as an ERC1967 UUPS.

### Liquifier

#### Adapter interactions

A `Liquifier` is a generic contract for Liquid Staking. Protocol specific logic is implemented in an `Adapter`. An
`Adapter` is essentially a contract that works similar to a library.

Each function on the `Adapter` is called by the `Liquifier` using `delegatecall`, meaning the logic of the `Adapter` is
executed in context of the `Liquifier`. An `Adapter` can have its own storage space, which is stored on the
`Liquifier` contract, but can only be managed by the `Adapter`.

For view functions a workaround is used by marking the `internal` functions on the `Liquifier` that interact with the
`Adapter` as `public` instead. Then creating a separate `external view` function that wraps a call to these functions in
a `staticcall` to the `Liquifier` itself.

#### Clones with immutable args

Liquifiers are deployes as lightweight clones (proxies) with immutable argumants to avoid initialization logic and save
gas. Immutable arguments are appended to the clone's bytecode at creation time, and appended to the calldata on a
delegatecall to the proxy. The implementation can then read and deserialize these arguments from the calldata.

#### LiquidToken

`Liquifier` inherits the `TGToken` contract, which is a rebasing ERC20 token. Its supply always equals the amount staked
in the underlying protocol for a validator and its delegators. Rebasing changes the total supply depending on whether
the validator earned rewards or got slashed.

### Unlocks

`Unlocks` is a ERC-721 NFT contract that represent staked assets in their unstaking period, meaning they have been
unstaked by their owner. Each unlock has an amount and a maturity date at which the amount can be withdrawn, this burns
the NFT. `Unlocks` is not upgradeable. All assets on the same network use the same `Unlocks` contract.

Only a valid `Liquifier` contract can create or destroy Unlocks, which is checked by the `Unlocks` contract through the
`Registry`.

#### Renderer

The Renderer is a UUPS (ERC1967) upgradeable proxy contract that contains logic to how these NFTs and their JSON
metadata should be rendered by front-end applications, this data does not affect the value represented by the NFT in any
way.

### Sequence Diagrams

#### Deposit

![deposit](./diagrams/deposit.png)

#### Unlock

![unlock](./diagrams/unlock.png)

#### Withdraw

![withdraw](./diagrams/withdraw.png)

#### Rebase

![rebase](./diagrams/rebase.png)



# Deployment of Chainlink adapter

Deployed Contracts on Tenderly:
- Registry Proxy Address: 0x1C5ffc48077AbdFC8EbbE605Ab011Eb3b218B054
- Factory Address: 0x25D20120328cc35afe3da930eC1295048CCd9d3b
- Adapter Address: 0xD60b939004eD587Cc753E6e4C8044af7adBb1a49
- Liquifier Address: 0x2871DafDB3b0047D06bBdb42f865DeD2514Dd9b0
- LINK Token Address: 0x514910771AF9Ca656af840dff83E8264EcF986CA

First, configure the .env file with the following fields:

```
TENDERLY_VIRTUAL_TESTNET_RPC=
TENDERLY_VERIFIER_URL=$TENDERLY_VIRTUAL_TESTNET_RPC/verify/etherscan
TENDERLY_ACCESS_KEY=
```

You can reset the state of the blockchain by running:

```sh
./script/snapshot_and_revert.sh 
```

Then you can deploy Chainlink-related contracts:

```sh
./script/chainlink_mainnet.sh 
```

This will log all the deployed contract addresses to the terminal.

Finally, you can run a script to start staking LINK:

```sh
./script/stake_link.sh
```


# Deployment Instructions

Follow these steps to deploy and set up the registry, factories, and token.

### 1. Run `anvil`

Open a terminal and run the following command:

```bash
anvil
```

Leave this terminal open and let `anvil` run.

### 2. Deploy the Registry and Factories

In a separate terminal, set the private key environment variable and deploy the registry and factories:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

forge script script/Liquifie_Deploy.s.sol:Liquifie_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv
```

### 3. Set Environment Variables

After the deployment completes, you will receive the `REGISTRY` and `FACTORY` addresses. Set these addresses as environment variables:

```bash
export REGISTRY=0xa7cA8732Be369CaEaE8C230537Fc8EF82a3387EE
export FACTORY=0xF09b219D86Ff3b533FC72148a21a948Ac48216CA
```

### 4. Deploy a Token

Set the token parameters and deploy the token:

```bash
export NAME="Livepeer"
export SYMBOL="LPT"
export BASE_APR="280000"
export UNLOCK_TIME="604800"
export TOTAL_SUPPLY="30000000000000000000000000"
export ID=0

forge script script/XYZ_Deploy.s.sol:XYZ_Deploy --fork-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv
```

### 5. Retrieve Deployed Contract Addresses

After deploying the token, you will get the following contract addresses:

```plaintext
LPT Token: 0x0BC472c881dc7b305Ab0dd03Bb390B52f37Cd617
LPT Staking: 0x98EC38B997e543c4FCd26Ce02d792c1f1F6ad5eA
LPT Adapter: 0x7198960C0B1e91f5E9a031507De58A4AE73B2404
```

### 6. Stake the Tokens

Now you can stake the tokens using the provided addresses.

If you encounter any issues or need further assistance, please refer to the official documentation or contact support.


