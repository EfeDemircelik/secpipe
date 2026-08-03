# DevSecOps Container Security Pipeline

A single CLI that chains Hadolint, Trivy, Syft, Grype, Cosign, and Kyverno into one config-driven pipeline — linting, building, scanning, signing, and enforcing policy on container images from the Dockerfile all the way to Kubernetes admission.

## Overview

This project automates container image security end-to-end. Instead of running each scanner separately, `pipeline.sh` wraps all of them behind one CLI: choose which stages to run with flags, and the pipeline handles validation, execution order, logging, and per-run reports for you.

## Features

- **Dockerfile linting** (Hadolint) and **misconfiguration scanning** (Trivy config)
- **Image build** and **registry push**
- **SBOM generation** (Syft), with **SBOM-based vulnerability scanning** (Grype) and **direct image vulnerability scanning** (Trivy image)
- **Image signing and verification** (Cosign)
- **Kubernetes admission enforcement** (Kyverno) — block unsigned images at the cluster gate
- Timestamped, per-run reports (`reports/<run-id>/`) plus a full combined log
- Defaults overridable per-project via a config file, no code changes needed
- One-command dependency installer

## How It Works

The pipeline is three files:

| File | Role |
|---|---|
| `pipeline.sh` | Entry point — validates flag combinations, sets up the run, executes the selected stages in order |
| `scripts/pipeline-cli.sh` | Library: parses CLI flags into state (doesn't run anything itself) |
| `scripts/lib.sh` | Library: the actual per-tool functions (`hadolint_scan`, `docker_build_image`, `cosign_sign_image`, etc.) |

Regardless of which flags you pass, stages always run in this order, skipping anything you didn't select:

```
hadolint → trivy-config → build → syft → grype → trivy-image → push
  → cosign-sign → cosign-verify → cosign-tree → apply-policy
  → check-kyverno → kyverno-test
```

## Prerequisites

- Docker, Hadolint, Trivy, Syft, Grype, and Cosign, all on `PATH`
- `kubectl`/`helm` configured against a cluster with Kyverno installed, for the Kubernetes-related operations
- A Cosign key pair for signing/verification (`cosign generate-key-pair`)

All of the above can be installed in one shot with `installation-script.sh`.

## Installation

```bash
./installation-script.sh
```

By default this installs everything (Docker, Hadolint, Trivy, Syft, Grype, Cosign, k3s, Helm, Kyverno) and scaffolds the project folders. Each flag **disables** its corresponding install — e.g. `--skip-docker` skips installing Docker, `--skip-kubernetes` skips k3s/Helm/Kyverno together. Run `./installation-script.sh --skip-kubernetes`, for example, if you already have your own cluster and only want the scanning/signing tools.

## Quick Start

```bash
# Lint a Dockerfile
./pipeline.sh --hadolint

# Build and scan, without publishing anywhere
./pipeline.sh --build --syft --grype --trivy-image --image my-app:dev

# Full pipeline: lint, build, scan, push, sign, verify
./pipeline.sh \
  --hadolint --trivy-config \
  --build --syft --grype --trivy-image \
  --push --sign --verify \
  --image registry.example.com/my-app:1.0.0

# Enforce signatures at admission time
./pipeline.sh --apply-policy -p require-cosign-signature.yaml
./pipeline.sh --kyverno-test --image registry.example.com/my-app:1.0.0
```

See `./pipeline.sh -h` for the full options reference and more examples.

## Project Structure

```
devsecops-pipeline/
├── pipeline.sh
├── config/
│   └── pipeline.conf      # optional — overrides defaults
├── keys/
│   ├── cosign.key
│   └── cosign.pub
├── policies/
│   └── *.yaml              # Kyverno ClusterPolicy files
├── reports/
│   └── <run-id>/            # created automatically per run
└── scripts/
    ├── lib.sh
    ├── installation-script.sh
    └── pipeline-cli.sh

```

## Configuration

Defaults (severity thresholds, key paths, SBOM format, etc.) live in `lib.sh`. To override them per-project without touching the script, create `config/pipeline.conf` — it's sourced automatically if present:

```bash
# config/pipeline.conf
TRIVY_SEVERITY="CRITICAL"
GRYPE_FAIL_ON="critical"
HADOLINT_FAILURE_THRESHOLD="warning"
```

## Roadmap

- Package the pipeline as a `.deb` for easier installation
- Compare Trivy and Grype findings automatically — the two use different vulnerability databases and can flag different CVEs for the same image; a script reconciling `trivy-image.json` and `grype-result.json` by CVE ID would surface what each tool catches that the other misses
- Broader output analysis across all stages, not just Trivy/Grype, in one combined summary
- Expand the Kyverno/Kubernetes policy set beyond signature enforcement (e.g. SBOM attestation checks, resource policies)
