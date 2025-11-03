#!/bin/bash
# Deterministic build wrapper for a Rust repo
# Usage: det_build.sh --repo /path/to/repo [--features "..."] [--package name]

set -euo pipefail

REPO=""
FEATURES=""
PACKAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --features) FEATURES="$2"; shift 2 ;;
    --package) PACKAGE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$REPO" ]]; then echo "--repo required" >&2; exit 2; fi
cd "$REPO"

# Use repo toolchain if present
if [[ -f rust-toolchain.toml ]]; then
  echo "Using rust-toolchain.toml"
fi

export RUSTFLAGS="-C debuginfo=0 -C link-arg=-s"
PKG_ARG=""; if [[ -n "$PACKAGE" ]]; then PKG_ARG="-p $PACKAGE"; fi
FEAT_ARG=""; if [[ -n "$FEATURES" ]]; then FEAT_ARG="--features $FEATURES"; fi

cargo build --locked --release $PKG_ARG $FEAT_ARG

# Hash outputs
( find target/release -maxdepth 1 -type f -executable -print0 | xargs -0 sha256sum || true ) > SHA256SUMS
sha256sum Cargo.lock >> SHA256SUMS || true

echo "Build complete. Hashes in: $REPO/SHA256SUMS"
