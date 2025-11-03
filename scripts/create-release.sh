#!/bin/bash
#
# Create a unified release for BTCDecoded ecosystem
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${COMMONS_DIR}/artifacts"

VERSION_TAG="${1:-}"
if [ -z "$VERSION_TAG" ]; then
    echo "Usage: $0 <version-tag>"
    echo "Example: $0 v0.1.0"
    exit 1
fi

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

create_release_notes() {
    local notes_file="${ARTIFACTS_DIR}/RELEASE_NOTES.md"
    
    cat > "$notes_file" <<EOF
# BTCDecoded Release ${VERSION_TAG}

Release date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Components

This release includes the following components:

- **consensus-proof** - Direct mathematical implementation of Bitcoin consensus rules
- **protocol-engine** - Bitcoin protocol abstraction layer
- **reference-node** - Minimal Bitcoin node implementation
- **developer-sdk** - Governance infrastructure and CLI tools
- **governance-app** - GitHub App for cryptographic governance enforcement

## Binaries Included

- \`reference-node\` - Bitcoin reference node
- \`bllvm-keygen\` - Key generation tool
- \`bllvm-sign\` - Message signing tool
- \`bllvm-verify\` - Signature verification tool
- \`governance-app\` - Governance application server
- \`key-manager\` - Key management utility
- \`test-content-hash\` - Content hash testing tool
- \`test-content-hash-standalone\` - Standalone content hash test

## Installation

Extract the archive and place binaries in your PATH:

\`\`\`bash
tar -xzf bitcoin-commons-bllvm-*.tar.gz
sudo mv binaries/* /usr/local/bin/
\`\`\`

## Verification

Verify checksums:

\`\`\`bash
sha256sum -c SHA256SUMS
\`\`\`

## Documentation

For more information, visit:
- https://github.com/BTCDecoded
- https://btcdecoded.org

## License

MIT License - see individual repository LICENSE files for details.
EOF

    log_success "Created release notes: ${notes_file}"
}

main() {
    log_info "Creating release for tag: ${VERSION_TAG}"
    
    if [ ! -d "$ARTIFACTS_DIR" ] || [ ! -d "${ARTIFACTS_DIR}/binaries" ]; then
        log_info "Artifacts directory not found. Running collect-artifacts.sh..."
        "${SCRIPT_DIR}/collect-artifacts.sh"
    fi
    
    create_release_notes
    
    log_success "Release created for ${VERSION_TAG}"
    log_info "Release artifacts: ${ARTIFACTS_DIR}"
}

main "$@"

