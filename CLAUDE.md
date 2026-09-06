# TNT Core

This repository owns the staking and service contracts, their indexer, and generated Rust bindings.
Read the relevant source before changing a protocol boundary; copied contract trees are not the architecture.
Start contract work at [Tangle](src/Tangle.sol), its [shared state](src/core/Base.sol), and the [facet router](src/facets/FacetRouterBase.sol).
Preserve upgrade authorization, storage compatibility, share accounting, and event contracts consumed by the indexer.
Financial logic requires meaningful fuzz or invariant tests as well as the affected user flow.

## Checks and generated artifacts

Use [foundry.toml](foundry.toml) and [contract CI](.github/workflows/foundry.yml) for supported build and test profiles.
The `local_build` profile excludes tests; a passing build does not prove contract correctness.
Use the `fast` profile for local correctness tests with normal constructor semantics.
Check deployable sizes with the production-codegen profile described in CI.

For indexer changes, inspect [its scripts](indexer/package.json) and regenerate types when the schema or event contract changes.
For binding changes, read [xtask](xtask/README.md) and [binding guidance](bindings/README.md).
Regenerate bindings from the intended contract revision and retain their source-revision evidence.
Do not hand-edit generated bindings or substitute a moving revision for release provenance.

Before deployment, read the [deployment runbook](docs/DEPLOYMENT_RUNBOOK.md), the relevant network configuration, and [blueprint upgrade guidance](docs/UPGRADING_BLUEPRINTS.md).
Verify the target network, contract addresses, signer authority, and rollback or upgrade procedure before broadcasting.
