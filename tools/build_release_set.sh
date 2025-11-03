#!/bin/bash
# Build a release set locally based on commons/versions.toml
# Usage: build_release_set.sh --base /path/to/checkouts [--gov-source] [--gov-docker] [--manifest /path/to/out/dir]

set -euo pipefail

BASE=""
GOV_SOURCE=0
GOV_DOCKER=0
MANIFEST_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --gov-source) GOV_SOURCE=1; shift ;;
    --gov-docker) GOV_DOCKER=1; shift ;;
    --manifest) MANIFEST_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$BASE" ]]; then
  echo "--base /path/to/checkouts required (contains consensus-proof/, protocol-engine/, reference-node/, developer-sdk/, governance-app/)" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERS_FILE="$ROOT_DIR/versions.toml"

if [[ ! -f "$VERS_FILE" ]]; then echo "versions.toml not found: $VERS_FILE" >&2; exit 2; fi

CP_TAG=$(grep -E '^consensus-proof' "$VERS_FILE" | awk -F '="' '{print $2}' | tr -d '"')
PE_TAG=$(grep -E '^protocol-engine' "$VERS_FILE" | awk -F '="' '{print $2}' | tr -d '"')
RN_TAG=$(grep -E '^reference-node' "$VERS_FILE" | awk -F '="' '{print $2}' | tr -d '"')
DS_TAG=$(grep -E '^developer-sdk' "$VERS_FILE" | awk -F '="' '{print $2}' | tr -d '"')
GA_TAG=$(grep -E '^governance-app' "$VERS_FILE" | awk -F '="' '{print $2}' | tr -d '"')

echo "Release set:"
echo "  consensus-proof: $CP_TAG"
echo "  protocol-engine : $PE_TAG"
echo "  reference-node  : $RN_TAG"
echo "  developer-sdk   : $DS_TAG"
echo "  governance-app  : $GA_TAG"

git_checkout() {
  local dir="$1"; local tag="$2"
  ( cd "$dir" && git fetch --tags && git checkout "$tag" )
}

build_repo() {
  local name="$1"; local tag="$2"
  local dir="$BASE/$name"
  if [[ ! -d "$dir/.git" ]]; then
    echo "Missing git repo: $dir" >&2; exit 2
  fi
  echo "=== Building $name@$tag ==="
  git_checkout "$dir" "$tag"
  "$ROOT_DIR/tools/det_build.sh" --repo "$dir"
}

build_governance_source() {
  local dir="$BASE/governance-app"
  echo "=== Building governance-app from source @$GA_TAG ==="
  git_checkout "$dir" "$GA_TAG"
  ( cd "$dir" && cargo build --locked --release )
  ( cd "$dir" && ( sha256sum target/release/* 2>/dev/null || true ) > SHA256SUMS )
}

build_governance_docker() {
  local dir="$BASE/governance-app"
  echo "=== Building governance-app Docker image @$GA_TAG ==="
  git_checkout "$dir" "$GA_TAG"
  local tag="$GA_TAG"
  local image="ghcr.io/$(basename "$(dirname "$ROOT_DIR")")/governance-app:${tag}"
  ( cd "$dir" && docker build -t "$image" . )
  echo "$image" > "$dir/IMAGE_TAG.txt"
}

# L2 → L3 → L4 → dev-sdk
build_repo consensus-proof "$CP_TAG"
build_repo protocol-engine "$PE_TAG"
build_repo reference-node "$RN_TAG"
build_repo developer-sdk "$DS_TAG"

# Governance-app (optional)
if [[ $GOV_SOURCE -eq 1 ]]; then
  build_governance_source
fi
if [[ $GOV_DOCKER -eq 1 ]]; then
  build_governance_docker
fi

# Optional manifest
if [[ -n "$MANIFEST_DIR" ]]; then
  mkdir -p "$MANIFEST_DIR"
  MANIFEST_PATH="$MANIFEST_DIR/MANIFEST.json"
  echo "{" > "$MANIFEST_PATH"
  for name in consensus-proof protocol-engine reference-node developer-sdk; do
    dir="$BASE/$name"
    if [[ -f "$dir/SHA256SUMS" ]]; then
      sums=$(python3 - <<'PY'
import json,sys
p=sys.argv[1]
with open(p,'r') as f:
  entries=[line.strip().split() for line in f if line.strip()]
print(json.dumps({e[1]: e[0] for e in entries if len(e)>=2}))
PY
 "$dir/SHA256SUMS")
      echo "  \"$name\": { \"hashes\": $sums }," >> "$MANIFEST_PATH"
    fi
  done
  # governance-app image
  if [[ -f "$BASE/governance-app/IMAGE_TAG.txt" ]]; then
    img=$(cat "$BASE/governance-app/IMAGE_TAG.txt")
    echo "  \"governance-app\": { \"image\": \"$img\" }" >> "$MANIFEST_PATH"
  else
    # trim trailing comma if present
    sed -i 's/},$/}/' "$MANIFEST_PATH" || true
  fi
  echo "}" >> "$MANIFEST_PATH"
  echo "Manifest: $MANIFEST_PATH"
fi

echo "Done. See SHA256SUMS in each repo and optional MANIFEST.json."
