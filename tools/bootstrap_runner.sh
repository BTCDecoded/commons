#!/bin/bash
# Bootstrap a self-hosted runner with required toolchains
# Usage: sudo ./bootstrap_runner.sh [--rust] [--docker] [--kani] [--ghcr USER TOKEN]

set -euo pipefail

INSTALL_RUST=0
INSTALL_DOCKER=0
INSTALL_KANI=0
GHCR_USER=""
GHCR_TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rust) INSTALL_RUST=1; shift ;;
    --docker) INSTALL_DOCKER=1; shift ;;
    --kani) INSTALL_KANI=1; shift ;;
    --ghcr) GHCR_USER="$2"; GHCR_TOKEN="$3"; shift 3 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ $INSTALL_RUST -eq 1 ]]; then
  echo "Installing Rust toolchain..."
  curl https://sh.rustup.rs -sSf | sh -s -- -y
fi

if [[ $INSTALL_DOCKER -eq 1 ]]; then
  echo "Installing Docker..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker "${SUDO_USER:-$(whoami)}"
fi

if [[ $INSTALL_KANI -eq 1 ]]; then
  echo "Installing Kani..."
  su - "${SUDO_USER:-$(whoami)}" -c "curl -fsSL https://model-checking.github.io/kani/install.sh | sh -s -- -y"
fi

if [[ -n "$GHCR_USER" && -n "$GHCR_TOKEN" ]]; then
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
fi

echo "Bootstrap complete. Reboot may be required for docker group permissions."
