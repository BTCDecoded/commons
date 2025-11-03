# Test Plan: Suite-by-Suite, Inside-Out

This plan validates the system from the most foundational layer outward, running one suite at a time and fixing issues before advancing.

## Phase 0 — Baseline
- Pin toolchain via `rust-toolchain.toml` per repo (auto-detected by workflows).
- **Note**: Repos are standalone (not workspace members). Commands do not use `-p` package flags.
- Sanity per repo:
  - `cargo check`
  - `cargo test --no-run`

## Phase 1 — consensus-proof (L2)
1) Unit tests
- `cargo test --all-features --lib --tests` (no `-p` flag, repo is standalone)
- Fix order: constants → types → economic → pow → transaction → block → script → segwit/taproot.

2) Property tests
- `cargo test --test property_*` (no `-p` flag)
- Stabilize seeds; document bounds.

3) Kani proofs (subset)
- `cargo kani --features verify`
- Start with: subsidy, tx structure, PoW target.

4) Integration tests (L2 only)
- `cargo test --test integration_*` (no `-p` flag)
- Provide realistic header chains where needed.

5) Optional perf smoke
- `cargo bench -- benches::*` (no `-p` flag)

## Phase 2 — protocol-engine (L3)
1) All tests
- `cargo test --all-features` (no `-p` flag)
- Validate FeatureRegistry activation; validation rules flow to L2.

2) Variant coverage
- Run with: BitcoinV1, Testnet3, Regtest contexts; verify expected accept/reject.

## Phase 3 — reference-node (L4)
1) Storage
- `cargo test -- tests::storage_*` (no `-p` flag)

2) Network protocol (no sockets)
- `cargo test -- tests::network_*` (no `-p` flag)

3) RPC (added)
- `cargo test -- tests::rpc_*` (no `-p` flag)
- Check routing, error codes, and response shapes; feature flags reflected.

4) Node orchestration
- `cargo test -- tests::node_*` (no `-p` flag)

5) QUIC smoke (feature-gated)
- `cargo test --features quinn -- --ignored` (no `-p` flag)

## Phase 4 — developer-sdk
1) Build + unit tests
- `cargo test --all-features` (no `-p` flag)

2) CLI/examples
- `cargo test -- tests::cli_*` (no `-p` flag)

## Phase 5 — governance-app
1) Unit/integration
- `cargo test --all-features` (no `-p` flag)

2) Container build (local)
- `docker build -t governance-app:dev .`

## Cross-phase checks
- Ensure version pins match `commons/versions.toml`.
- Deterministic build per repo:
  - `cargo build --release --locked` (twice); compare hashes.
- Local set build and manifest:
  - `commons/tools/build_release_set.sh --base /path/to/checkouts --manifest ./out`

## Issue triage loop
- Run suite → capture failures → fix minimal scope → re-run same suite → log outcome.
- Advance only when current suite is green or documented.
- Record status in `TEST_STATUS.md` at each repo root.

## Execution order (summary)
- L2 unit → L2 property → L2 Kani → L2 integration → L3 all → L4 storage → L4 network → L4 RPC → L4 node → dev-sdk → governance-app.
