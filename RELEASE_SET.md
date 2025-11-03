# Release Set

## Define a Set
Edit `versions.toml` with exact tags per repo:

```
[versions]
consensus-proof = "v0.1.0-locked"
protocol-engine  = "v0.1.0"
reference-node   = "v0.1.0"
```

## Orchestrate
Run the reusable orchestrator (GitHub Actions):
- Workflow: `commons/.github/workflows/release_orchestrator.yml`
- It verifies L2 and builds L3/L4 sequentially.

## Local (No CI)
Use tools:
- `commons/tools/build_release_set.sh` (clone tags, build in order, hash)
- `commons/tools/make_verification_bundle.sh` (L2 verification bundle)

## Artifacts
- Each repo uploads its own artifacts and `SHA256SUMS`.
- Collect hashes into a set manifest and timestamp with OpenTimestamps.
