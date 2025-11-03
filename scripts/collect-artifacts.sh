#!/bin/bash
#
# Collect all built binaries into release artifacts
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$COMMONS_DIR")"
ARTIFACTS_DIR="${COMMONS_DIR}/artifacts"
BINARIES_DIR="${ARTIFACTS_DIR}/binaries"
TARGET_DIR="target/release"

# Binary mapping
declare -A REPO_BINARIES
REPO_BINARIES[reference-node]="reference-node"
REPO_BINARIES[developer-sdk]="bllvm-keygen bllvm-sign bllvm-verify"
REPO_BINARIES[governance-app]="governance-app key-manager test-content-hash test-content-hash-standalone"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warn() {
    echo "[WARN] $1"
}

collect_repo_binaries() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    local binaries="${REPO_BINARIES[$repo]:-}"
    
    if [ -z "$binaries" ]; then
        return 0  # No binaries for this repo
    fi
    
    for binary in $binaries; do
        local bin_path="${repo_path}/${TARGET_DIR}/${binary}"
        
        if [ -f "$bin_path" ]; then
            cp "$bin_path" "${BINARIES_DIR}/"
            log_success "Collected: ${binary}"
        else
            log_warn "Binary not found: ${bin_path}"
        fi
    done
}

generate_checksums() {
    log_info "Generating checksums..."
    
    pushd "$BINARIES_DIR" > /dev/null
    
    if command -v sha256sum &> /dev/null; then
        sha256sum * > "${ARTIFACTS_DIR}/SHA256SUMS" 2>/dev/null || true
        log_success "Generated SHA256SUMS"
    elif command -v shasum &> /dev/null; then
        shasum -a 256 * > "${ARTIFACTS_DIR}/SHA256SUMS" 2>/dev/null || true
        log_success "Generated SHA256SUMS"
    else
        log_warn "No checksum tool found (sha256sum or shasum)"
    fi
    
    popd > /dev/null
}

create_archives() {
    log_info "Creating release archives..."
    
    local platform="${1:-linux-x86_64}"
    local archive_name="bitcoin-commons-bllvm-${platform}"
    
    pushd "$ARTIFACTS_DIR" > /dev/null
    
    # Create tar.gz
    if [ -d "binaries" ] && [ "$(ls -A binaries)" ]; then
        tar -czf "${archive_name}.tar.gz" binaries/ SHA256SUMS 2>/dev/null || true
        log_success "Created: ${archive_name}.tar.gz"
        
        # Create zip (if zip available)
        if command -v zip &> /dev/null; then
            zip -r "${archive_name}.zip" binaries/ SHA256SUMS 2>/dev/null || true
            log_success "Created: ${archive_name}.zip"
        fi
    fi
    
    popd > /dev/null
}

main() {
    log_info "Collecting artifacts..."
    
    mkdir -p "$BINARIES_DIR"
    
    # Collect binaries from each repo
    for repo in reference-node developer-sdk governance-app; do
        collect_repo_binaries "$repo"
    done
    
    # Generate checksums
    if [ "$(ls -A ${BINARIES_DIR})" ]; then
        generate_checksums
        create_archives "${2:-linux-x86_64}"
        log_success "Artifacts collected in: ${ARTIFACTS_DIR}"
    else
        log_warn "No binaries found to collect"
    fi
}

main "$@"

