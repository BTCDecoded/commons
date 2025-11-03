# BTCDecoded Build System Documentation

## Overview

The BTCDecoded build system provides unified orchestration for building, testing, and releasing the multi-repository BTCDecoded ecosystem.

## Architecture

### Dependency Graph

```
consensus-proof (no dependencies)
    ↓
protocol-engine
    ↓
reference-node

developer-sdk (no dependencies)
    ↓
governance-app
```

### Build Order

1. **consensus-proof** - Foundation library (builds in parallel with developer-sdk)
2. **developer-sdk** - Standalone CLI tools (builds in parallel with consensus-proof)
3. **protocol-engine** - Protocol abstraction (depends on consensus-proof)
4. **reference-node** - Full node (depends on protocol-engine + consensus-proof)
5. **governance-app** - Governance app (depends on developer-sdk)

## Usage

### Local Development Build

```bash
# Ensure all repos are cloned in parent directory
cd commons

# Build all repos using local path dependencies
./build.sh --mode dev
```

### Release Build

```bash
# Build all repos using git dependencies
./build.sh --mode release
```

### Using Reusable Workflows

Other repositories can call reusable workflows from `commons`:

```yaml
# In reference-node/.github/workflows/build.yml
name: Build

on: [push, pull_request]

jobs:
  build:
    uses: BTCDecoded/commons/.github/workflows/build-single.yml@main
    with:
      repo-name: reference-node
      required-deps: consensus-proof,protocol-engine
    secrets: inherit
```

## Scripts

### `build.sh`

Main unified build script that:
- Checks Rust toolchain (requires 1.70+)
- Verifies all repositories are present
- Builds repos in dependency order
- Collects binaries to `artifacts/binaries/`

**Usage:**
```bash
./build.sh [--mode dev|release]
```

### `scripts/setup-build-env.sh`

Sets up build environment by cloning/updating all repositories.

**Usage:**
```bash
./scripts/setup-build-env.sh [--tag <version-tag>]
```

### `scripts/collect-artifacts.sh`

Collects all built binaries into release archives with checksums.

**Usage:**
```bash
./scripts/collect-artifacts.sh [platform]
```

### `scripts/create-release.sh`

Creates a unified release package with release notes.

**Usage:**
```bash
./scripts/create-release.sh <version-tag>
```

### `scripts/verify-versions.sh`

Verifies version compatibility across repositories.

**Usage:**
```bash
./scripts/verify-versions.sh [repo-name]
```

## Version Coordination

The `versions.toml` file tracks compatible versions:

```toml
[versions]
consensus-proof = { version = "0.1.0", git_tag = "v0.1.0", ... }
protocol-engine = { version = "0.1.0", requires = ["consensus-proof=0.1.0"], ... }
```

## GitHub Actions Workflows

### `build-all.yml` (Reusable)

Builds all repositories in dependency order.

**Inputs:**
- `mode`: Build mode (`dev` or `release`)

### `build-single.yml` (Reusable)

Builds a single repository with its dependencies.

**Inputs:**
- `repo-name`: Repository to build
- `required-deps`: Comma-separated dependency list

### `release.yml` (Reusable)

Creates a unified release with all binaries.

**Inputs:**
- `version_tag`: Version tag (e.g., `v0.1.0`)

### `verify-versions.yml` (Reusable)

Verifies version compatibility.

**Inputs:**
- `repo-name`: Optional repository name (empty for all)

## Docker Builds

Use `docker-compose.build.yml` for containerized builds:

```bash
docker-compose -f docker-compose.build.yml build
```

This builds all components in dependency order using Docker.

## Artifacts

Built binaries are collected in `artifacts/binaries/`:

- `reference-node` - Bitcoin reference node
- `bllvm-keygen`, `bllvm-sign`, `bllvm-verify` - SDK tools
- `governance-app`, `key-manager`, `test-content-hash*` - Governance tools

Release archives include:
- `bitcoin-commons-bllvm-<platform>.tar.gz` - Tar archive
- `bitcoin-commons-bllvm-<platform>.zip` - Zip archive
- `SHA256SUMS` - Checksums for all binaries

## Troubleshooting

### Build Failures

1. Check Rust version: `rustc --version` (requires 1.70+)
2. Verify all repos are cloned
3. Check dependency versions in `versions.toml`
4. Review build logs in `/tmp/<repo>-build.log`

### Missing Binaries

- Libraries (consensus-proof, protocol-engine) don't produce binaries
- Only reference-node, developer-sdk, and governance-app produce binaries
- Check `target/release/` in each repo after build

### Version Mismatches

Run `./scripts/verify-versions.sh` to check compatibility.

## Future Improvements

- [ ] TOML parser for better version.toml parsing
- [ ] Support for cross-compilation
- [ ] Automated dependency version updates
- [ ] Integration with governance-app for version validation
- [ ] Support for feature flags per repo

