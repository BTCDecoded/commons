# Build Policy (Org-Level)

## Separation of Concerns
- **commons**: Orchestration, policies, reusable workflows, shared tools, version topology.
- **consensus-proof (L2)**: Consensus math + formal verification; publishes libraries and verification bundles.
- **protocol-engine (L3)**: Protocol abstraction; depends on L2; publishes library.
- **reference-node (L4)**: Node infra; depends on L2 & L3; publishes binaries.

## Build Order
1. consensus-proof → verify (tests + optional Kani)
2. protocol-engine → build lib
3. reference-node → build binaries

## Version Topology
- Authoritative map: `commons/versions.toml` (tags per repo).
- Orchestrator reads this file to pin repos.

## Workflows
- Reusable: `.github/workflows/verify_consensus.yml`, `build_lib.yml`.
- Orchestrator: `.github/workflows/release_orchestrator.yml`.

## Deterministic Builds
- Each repo maintains `rust-toolchain.toml`.
- Builds use `--locked` and fixed toolchain.
- Hash artifacts with `SHA256SUMS`.

## Attestation
- Verification bundles produced by L2 (tests + kani + logs).
- Attestations stored in governance repo (or commons/attestations/).
