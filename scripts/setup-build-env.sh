#!/bin/bash
#
# Setup build environment by checking out all required repositories
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMONS_DIR="$(dirname "$SCRIPT_DIR")"
# Use PARENT_DIR from environment if set (e.g., in GitHub Actions), otherwise calculate from script location
PARENT_DIR="${PARENT_DIR:-$(dirname "$COMMONS_DIR")}"

# Configuration
ORG="BTCDecoded"
TAG="${1:-}"
REPOS=("bllvm-consensus" "bllvm-protocol" "bllvm-node" "bllvm" "bllvm-sdk" "governance-app")

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

clone_or_update_repo() {
    local repo=$1
    local repo_path="${PARENT_DIR}/${repo}"
    
    if [ -d "$repo_path" ]; then
        log_info "Repository exists: ${repo}"
        pushd "$repo_path" > /dev/null
        
        # Always fetch latest changes first
        log_info "Fetching latest changes..."
        git fetch origin
        git fetch --tags
        
        # Update if tag specified
        if [ -n "$TAG" ]; then
            log_info "Checking out tag: ${TAG}"
            # Try to checkout tag, but if it doesn't exist or is outdated, use main
            if git rev-parse --verify "$TAG" >/dev/null 2>&1; then
                git checkout "$TAG"
                # For Phase 1 prerelease, always use latest main to get bug fixes
                # TODO: In Phase 2, use exact tag versions for deterministic builds
                log_info "Tag ${TAG} found, but using latest main for Phase 1 prerelease (bug fixes)"
                git checkout main 2>/dev/null || git checkout master 2>/dev/null
                git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
            else
                log_info "Tag ${TAG} not found in ${repo}, using latest main..."
                git checkout main 2>/dev/null || git checkout master 2>/dev/null
                git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
            fi
        else
            # Update to latest
            git checkout main 2>/dev/null || git checkout master 2>/dev/null
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        fi
        
        popd > /dev/null
        log_success "Repository ready: ${repo}"
    else
        log_info "Cloning repository: ${repo}"
        
        local repo_url="https://github.com/${ORG}/${repo}.git"
        
        pushd "$PARENT_DIR" > /dev/null
        
        if ! git clone "$repo_url" "$repo"; then
            log_error "Failed to clone ${repo}"
            popd > /dev/null
            return 1
        fi
        
        if [ -n "$TAG" ]; then
            pushd "$repo" > /dev/null
            git fetch origin
            git fetch --tags
            # For Phase 1 prerelease, always use latest main to get bug fixes
            # TODO: In Phase 2, use exact tag versions for deterministic builds
            log_info "Using latest main for Phase 1 prerelease (includes bug fixes like test removals)"
                git checkout main 2>/dev/null || git checkout master 2>/dev/null
                git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
            popd > /dev/null
        fi
        
        popd > /dev/null
        log_success "Cloned repository: ${repo}"
    fi
    
    return 0
}

main() {
    log_info "Setting up build environment"
    
    if [ -n "$TAG" ]; then
        log_info "Target tag: ${TAG}"
    else
        log_info "Using latest from main/master branches"
    fi
    
    mkdir -p "$PARENT_DIR"
    
    local failed=0
    for repo in "${REPOS[@]}"; do
        if ! clone_or_update_repo "$repo"; then
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log_success "Build environment ready!"
        log_info "Repositories located in: ${PARENT_DIR}"
    else
        log_error "Setup completed with ${failed} failure(s)"
        exit 1
    fi
}

main "$@"

