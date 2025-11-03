# Test Vectors (Central)

Directory structure for shared fixtures used across repos:

- headers/
  - mainnet/*.json
  - testnet/*.json
  - regtest/*.json
- blocks/
  - mainnet/*.bin
- txs/
  - valid/*.hex
  - invalid/*.hex
- rpc-golden/
  - getblockchaininfo/*.json
  - getnetworkinfo/*.json

## Usage
- Reference these fixtures from tests; do not embed large literals in code.
- Version fixtures alongside `commons/versions.toml` release set.
