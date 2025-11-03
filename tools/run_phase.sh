#!/bin/bash
# Run a phase of suites in order
# Usage: run_phase.sh --base /path/to/checkouts --phase L2|L3|L4|SDK|GA

set -euo pipefail

BASE=""
PHASE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$BASE" || -z "$PHASE" ]]; then
  echo "--base and --phase required" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$PHASE" in
  L2)
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/consensus-proof" --suite cp-unit
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/consensus-proof" --suite cp-prop || true
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/consensus-proof" --suite cp-kani || true
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/consensus-proof" --suite cp-int || true ;;
  L3)
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/protocol-engine" --suite pe-all ;;
  L4)
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/reference-node" --suite rn-storage
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/reference-node" --suite rn-network
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/reference-node" --suite rn-rpc
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/reference-node" --suite rn-node
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/reference-node" --suite rn-quic || true ;;
  SDK)
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/developer-sdk" --suite ds-all ;;
  GA)
    "$ROOT_DIR/run_suite.sh" --repo "$BASE/governance-app" --suite ga-all ;;
  *) echo "Unknown phase: $PHASE" >&2; exit 2 ;;
esac

echo "Phase $PHASE completed."
