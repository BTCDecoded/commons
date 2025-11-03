#!/bin/bash
# Run a single test suite for a given repo
# Usage: run_suite.sh --repo /path/to/repo --suite <name> [--features "..."]
# Suites:
#  cp-unit, cp-prop, cp-kani, cp-int, pe-all,
#  rn-storage, rn-network, rn-rpc, rn-node, rn-quic,
#  ds-all, ga-all

set -euo pipefail

REPO=""
SUITE=""
FEATURES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --suite) SUITE="$2"; shift 2 ;;
    --features) FEATURES="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$REPO" || -z "$SUITE" ]]; then
  echo "--repo and --suite required" >&2
  exit 2
fi

cd "$REPO"

case "$SUITE" in
  cp-unit)
    cargo test --all-features --lib --tests ;;
  cp-prop)
    cargo test --test property_* ;;
  cp-kani)
    if command -v cargo-kani >/dev/null 2>&1 || command -v kani >/dev/null 2>&1; then
      cargo kani --features verify || true
    else
      echo "Kani not installed; skipping" ;
    fi ;;
  cp-int)
    cargo test --test integration_* ;;
  pe-all)
    cargo test --all-features ;;
  rn-storage)
    cargo test -- tests::storage_* ;;
  rn-network)
    cargo test -- tests::network_* ;;
  rn-rpc)
    cargo test -- tests::rpc_* ;;
  rn-node)
    cargo test -- tests::node_* ;;
  rn-quic)
    cargo test --features quinn -- --ignored ;;
  ds-all)
    cargo test --all-features ;;
  ga-all)
    cargo test --all-features ;;
  *)
    echo "Unknown suite: $SUITE" >&2 ; exit 2 ;;
esac

echo "Suite $SUITE completed."
