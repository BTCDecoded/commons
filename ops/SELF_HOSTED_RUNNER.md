# Self-Hosted Runner Setup

## Runner Installation
1. Provision a Linux host (x86_64 recommended).
2. Install dependencies: Rust toolchain, Docker (optional), systemd.
3. Follow GitHub Actions self-hosted runner setup for the `governance-app` repository.

## Governance App Deploy Workflow
- Add the workflow from `commons/templates/governance-app/.github/workflows/deploy.yml` to the governance-app repo.
- It listens for `repository_dispatch` with type `deploy` and:
  - Builds from source and restarts a systemd service, or
  - Pulls a provided Docker image and restarts a container.

## Triggering Deploys
- The org orchestrator (`commons/.github/workflows/release_orchestrator.yml`) sends a `repository_dispatch` to `governance-app` with payload:
  ```json
  { "tag": "v0.1.0", "image": "ghcr.io/<org>/governance-app:<ref>" }
  ```
- Ensure `ORG_PAT` (or default `GITHUB_TOKEN`) has permissions to dispatch events to `governance-app`.

## Systemd (from source) Example
```
[Unit]
Description=Governance App
After=network.target

[Service]
User=governance
WorkingDirectory=/opt/governance-app
ExecStart=/opt/governance-app/target/release/governance-app
Restart=always
RestartSec=5
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
```

## Docker (container) Example
```
docker run -d --name governance-app --restart=always -p 8080:8080 ghcr.io/<org>/governance-app:stable
```
