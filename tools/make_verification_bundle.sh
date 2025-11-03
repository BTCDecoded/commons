#!/bin/bash
# Create verification bundle for the consensus-proof repo and optionally timestamp it
# Usage:
#   make_verification_bundle.sh --repo /path/to/consensus-proof [--out /path/to/outdir] [--no-kani]
# Environment alternatives:
#   CP_REPO=/path/to/consensus-proof OUT_DIR=/path/to/outdir NO_KANI=1 ./make_verification_bundle.sh

set -euo pipefail

# Defaults
CP_REPO_DEFAULT="${CP_REPO:-}"
OUT_DIR_DEFAULT="${OUT_DIR:-}"
RUN_KANI_DEFAULT=1
if [[ "${NO_KANI:-}" == "1" ]]; then RUN_KANI_DEFAULT=0; fi

print_usage() {
  echo "Usage: $0 --repo /path/to/consensus-proof [--out /path/to/outdir] [--no-kani]" >&2
}

CP_REPO="${CP_REPO_DEFAULT}"
OUT_DIR="${OUT_DIR_DEFAULT}"
RUN_KANI=${RUN_KANI_DEFAULT}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      CP_REPO="$2"; shift 2 ;;
    --out)
      OUT_DIR="$2"; shift 2 ;;
    --no-kani)
      RUN_KANI=0; shift ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage
      exit 2 ;;
  esac
done

if [[ -z "${CP_REPO}" ]]; then
  echo "Error: --repo /path/to/consensus-proof is required (or CP_REPO env)." >&2
  exit 2
fi

if [[ ! -d "${CP_REPO}" ]]; then
  echo "Error: repo path not found: ${CP_REPO}" >&2
  exit 2
fi

if [[ -z "${OUT_DIR}" ]]; then
  OUT_DIR="${CP_REPO%/}/verify-artifacts"
fi

mkdir -p "${OUT_DIR}"
BUNDLE_DIR="${OUT_DIR}"
BUNDLE_PATH="${CP_REPO%/}/verify-artifacts.tar.gz"

echo "=== Verification Bundle ==="
echo "Repo: ${CP_REPO}"
echo "Out:  ${OUT_DIR}"
echo "Kani: ${RUN_KANI}"  

# Run tests
echo "=== Running tests (consensus-proof) ==="
( cd "${CP_REPO}" && cargo test --all-features ) | tee "${OUT_DIR}/tests.log"

# Kani (optional and best-effort)
if [[ ${RUN_KANI} -eq 1 ]]; then
  if command -v cargo-kani >/dev/null 2>&1 || command -v kani >/dev/null 2>&1; then
    echo "=== Running Kani proofs (consensus-proof) ==="
    # Allow non-zero to avoid hard failing local runs when some harnesses are WIP
    ( cd "${CP_REPO}" && cargo kani --features verify ) | tee "${OUT_DIR}/kani.log" || true
  else
    echo "Kani not installed; skipping model checking (install: https://model-checking.github.io/kani/)" | tee "${OUT_DIR}/kani.log"
  fi
else
  echo "Kani disabled via --no-kani" | tee "${OUT_DIR}/kani.log"
fi

# Collect metadata
( cd "${CP_REPO}" && cargo metadata --format-version=1 ) > "${OUT_DIR}/cargo_metadata.json" || true

# Bundle artifacts
echo "=== Creating bundle ==="
# Normalize path to repo root to avoid nesting absolute paths inside the archive
(
  cd "${CP_REPO}" \
  && tar -czf "${BUNDLE_PATH}" "$(realpath --relative-to="${CP_REPO}" "${BUNDLE_DIR}")"
)

# SHA256
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${BUNDLE_PATH}" | tee "${BUNDLE_PATH}.sha256"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "${BUNDLE_PATH}" | tee "${BUNDLE_PATH}.sha256"
else
  echo "Warning: no sha256 tool available; skipping hash file" >&2
fi

# Optional OpenTimestamps
if command -v ots >/dev/null 2>&1; then
  echo "=== OpenTimestamps stamping ==="
  ots stamp "${BUNDLE_PATH}"
  echo "Stamped: ${BUNDLE_PATH}.ots"
else
  echo "OpenTimestamps (ots) not installed; skipping timestamp."
fi

echo "Done. Bundle: ${BUNDLE_PATH}"
