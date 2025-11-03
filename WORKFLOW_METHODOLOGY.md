# BTCDecoded Workflow Methodology (Org-Wide)

This document defines a consistent, reproducible, and secure workflow model applied across all repositories. It separates orchestration (commons) from tier-specific logic and runs entirely on self-hosted Linux x64 runners.

## Core Principles
- **Single Source of Truth for Versions**: `commons/versions.toml` pins tags per repo for a release set.
- **Reusable Workflows**: Repos call commons workflows via `workflow_call` to ensure consistency.
- **Self-Hosted Only**: All CI runs on `[self-hosted, linux, x64]` runners.
- **Deterministic Builds**: `--locked` builds, rust-toolchain per repo, artifact hashing.
- **Security Gates**: Consensus verification (tests + optional Kani) precedes builds downstream.
- **Clear Ordering**: L2 (consensus-proof) → L3 (protocol-engine) → L4 (reference-node) → developer-sdk → governance-app.

## Roles & Separation
- **commons**: orchestration, version topology, reusable workflows, tooling, policy docs.
- **consensus-proof (L2)**: consensus math + formal verification; libraries & verification bundles.
- **protocol-engine (L3)**: abstraction; depends on L2; library.
- **reference-node (L4)**: infra; depends on L2/L3; binaries.
- **developer-sdk**: SDK; depends on L4; library/binaries as applicable.
- **governance-app**: service; Docker image or source build; deploy via self-hosted runner.

## Required Files
- `commons/versions.toml`: authoritative tags
- Repos: `rust-toolchain.toml` (auto-detected by workflows), minimal wrapper workflows (or none, using commons directly)
- **Note**: Repos are standalone (not workspace members). Test commands must not use `-p` package flags.

## Reusable Workflows (commons)
- `commons/.github/workflows/verify_consensus.yml`
  - Inputs: `repo`, `ref`, `kani` (bool)
  - Runs tests and optional Kani
  - Self-hosted
- `commons/.github/workflows/build_lib.yml`
  - Inputs: `repo`, `ref`, `package`, `features`, `verify_deterministic` (optional)
  - Deterministic build, hashes artifacts
  - Optional deterministic verification (rebuild + compare hashes)
  - Self-hosted (prefers `rust` label)
- `commons/.github/workflows/build_docker.yml`
  - Inputs: `repo`, `ref`, `tag`, `image_name`, `push`
  - Builds Docker image, optional push
  - Self-hosted
- `commons/.github/workflows/release_orchestrator.yml`
  - Reads `versions.toml` and sequences all builds
  - Sends `repository_dispatch` deploy to governance-app

## Runner Policy
- All jobs run on self-hosted Linux x64 runners.
- Optional labels (`rust`, `docker`, `kani`) optimize job assignment but aren't required.
- Workflows handle installation as fallback if labeled runners unavailable.
- Repos should restrict Actions to self-hosted in settings; optional enforcement via org policy.

## Deterministic Builds
- Per-repo `rust-toolchain.toml` defines toolchain
- Workflows auto-detect toolchain via `dtolnay/rust-toolchain` action (no explicit override)
- Use `cargo build --locked --release`
- Hash outputs to `SHA256SUMS`
- Optional deterministic verification: rebuild and compare hashes (via `verify_deterministic` input in `build_lib.yml`)

## Local (No-CI) Tooling
- `commons/tools/build_release_set.sh` — sequence local builds from local clones; optional governance-app source/docker; optional `MANIFEST.json` aggregation
- `commons/tools/det_build.sh` — deterministic build wrapper
- `commons/tools/make_verification_bundle.sh` — generate consensus-proof verification bundle; optional OpenTimestamps

## Governance & Deploys
- Deploy signal: commons orchestrator emits `repository_dispatch: deploy` to governance-app with payload `{ tag, image }`
- governance-app repo includes a listener workflow to act on the signal (build source or pull container; restart service)

## Minimal Per-Repo Wrapper (Optional)
- Repos can include thin wrappers that call commons workflows for local triggers; preferred approach is to run orchestration from commons only.

## Naming & Conventions
- Workflow names: `verify`, `build`, `docker`, `release_orchestrator`
- Artifacts: `SHA256SUMS`, optional `MANIFEST.json` at set level
- Tags: match `versions.toml`

## Applying Org-Wide
1. Keep `versions.toml` authoritative and up-to-date.
2. Use `release_orchestrator.yml` for tagged release sets only.
3. Restrict runners to `[self-hosted, linux, x64]` in all repos.
4. Prefer commons workflows; remove divergent per-repo CI logic.
5. Record hashes and (optional) OTS receipts alongside releases/attestations.
