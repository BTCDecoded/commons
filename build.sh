#!/bin/bash
#
# Unified Build Script for BTCDecoded Ecosystem
# Builds all repositories in dependency order
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
MODE="${1:-dev}"
ARTIFACTS_DIR="${SCRIPT_DIR}/artifacts"
TARGET_DIR="target/release"

# Repository configuration
declare -A REPOS
REPOS[consensus-proof]="library"
REPOS[protocol-engine]="library|consensus-proof"
REPOS[reference-node]="binary|protocol-engine,consensus-proof"
REPOS[developer-sdk]="binary"
REPOS[governance-app]="binary|developer-sdk"

# Dependency graph
declare -A DEPS
DEPS[consensus-proof]=""
DEPS[protocol-engine]="consensus-proof"
DEPS[reference-node]="protocol-engine consensus-proof"
DEPS[developer-sdk]=""
DEPS[governance-app]="developer-sdk"

# Binary names
declare -A BINARIES
BINARIES[consensus-proof]=""
BINARIES[protocol-engine]=""
BINARIES[reference-node]="reference-node"
BINARIES[developer-sdk]="bllvm-keygen bllvm-sign bllvm-verify"
BINARIES[governance-app]="governance-app key-manager test-content-hash test-content-hash-standalone"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_rust_toolchain() {
    log_info "Checking Rust toolchain..."
    
    if ! command -v rustc &> /dev/null; then
        log_error "Rust is not installed. Please install Rust 1.70+ from https://rustup.rs"
        exit 1
    fi
    
    RUST_VERSION=$(rustc --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    RUST_MAJOR=$(echo "$RUST_VERSION" | cut -d. -f1)
    RUST_MINOR=$(echo "$RUST_VERSION" | cut -d. -f2)
    
    if [ "$RUST_MAJOR" -lt 1 ] || ([ "$RUST_MAJOR" -eq 1 ] && [ "$RUST_MINOR" -lt 70 ]); then
        log_error "Rust 1.70+ required. Found: $RUST_VERSION"
        exit 1
    fi
    
    log_success "Rust toolchain OK: $(rustc --version)"
}

check_repo_exists() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    
    if [ ! -d "$repo_path" ]; then
        log_error "Repository not found: $repo_path"
        log_info "Please clone: git clone https://github.com/BTCDecoded/${repo}.git"
        return 1
    fi
    
    if [ ! -f "${repo_path}/Cargo.toml" ]; then
        log_error "Invalid repository: $repo_path (no Cargo.toml found)"
        return 1
    fi
    
    return 0
}

check_all_repos() {
    log_info "Checking all repositories..."
    
    local missing=0
    for repo in "${!REPOS[@]}"; do
        if ! check_repo_exists "$repo"; then
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "Missing $missing repository(ies). Please clone all required repos."
        exit 1
    fi
    
    log_success "All repositories found"
}

build_repo() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    
    log_info "Building ${repo}..."
    
    pushd "$repo_path" > /dev/null
    
    # Switch dependency mode if needed
    if [ "$MODE" == "release" ]; then
        log_info "Switching to git dependencies for release mode"
        # This would require modifying Cargo.toml - for now, assume local paths work
        # In a real implementation, we'd patch Cargo.toml or use git dependencies
    fi
    
    # Build
    if ! cargo build --release 2>&1 | tee "/tmp/${repo}-build.log"; then
        log_error "Build failed for ${repo}"
        popd > /dev/null
        return 1
    fi
    
    popd > /dev/null
    log_success "Built ${repo}"
    return 0
}

collect_binaries() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    local binaries="${BINARIES[$repo]}"
    
    if [ -z "$binaries" ]; then
        log_info "No binaries for ${repo} (library only)"
        return 0
    fi
    
    mkdir -p "${ARTIFACTS_DIR}/binaries"
    
    for binary in $binaries; do
        local bin_path="${repo_path}/${TARGET_DIR}/${binary}"
        if [ -f "$bin_path" ]; then
            cp "$bin_path" "${ARTIFACTS_DIR}/binaries/"
            log_success "Collected binary: ${binary}"
        else
            log_warn "Binary not found: ${bin_path}"
        fi
    done
}

topological_sort() {
    # Simple topological sort for dependency order
    local sorted=()
    local visited=()
    
    visit() {
        local repo=$1
        
        if [[ " ${visited[@]} " =~ " ${repo} " ]]; then
            return
        fi
        
        # Visit dependencies first
        local deps="${DEPS[$repo]}"
        if [ -n "$deps" ]; then
            for dep in $deps; do
                visit "$dep"
            done
        fi
        
        visited+=("$repo")
        sorted+=("$repo")
    }
    
    for repo in "${!REPOS[@]}"; do
        visit "$repo"
    done
    
    echo "${sorted[@]}"
}

main() {
    log_info "Bitcoin Commons BLLVM Unified Build System"
    log_info "Mode: ${MODE}"
    echo ""
    
    # Setup
    check_rust_toolchain
    check_all_repos
    mkdir -p "$ARTIFACTS_DIR"
    
    # Get build order
    local build_order
    build_order=($(topological_sort))
    
    log_info "Build order: ${build_order[*]}"
    echo ""
    
    # Build in order
    local failed=0
    for repo in "${build_order[@]}"; do
        if ! build_repo "$repo"; then
            failed=$((failed + 1))
            log_error "Build failed, stopping"
            break
        fi
        
        collect_binaries "$repo"
        echo ""
    done
    
    # Summary
    if [ $failed -eq 0 ]; then
        log_success "All repositories built successfully!"
        log_info "Binaries collected in: ${ARTIFACTS_DIR}/binaries"
    else
        log_error "Build completed with $failed failure(s)"
        exit 1
    fi
}

# Run main
main "$@"

