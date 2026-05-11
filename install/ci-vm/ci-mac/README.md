# Mac CI runner — scaffolding (WP7 / community bonding)

**Status:** Scaffolding only. Full WP7 implementation lands in Week 11 (Aug 11–17, 2026).
This directory exists so the bonding-period verification work has a home and a future PR has a clear seam.

The Mac flow is **intentionally not** a 1-to-1 copy of `ci-linux` / `ci-windows`:

| Concern | Linux / Windows | Mac |
|---|---|---|
| Compute | GCE VMs, started per-test | GitHub Actions runner (hosted or self-hosted) |
| Bootstrap | GCE metadata + gcsfuse mount of `/repository` | No GCE metadata. Workflow uses `actions/checkout` + `actions/upload-artifact` |
| Status reporting | `curl http://metadata/.../reportURL` → POST to sample-platform | Workflow posts to a webhook URL passed in via repo secret |

Rationale: GCP does not offer macOS VMs; AWS EC2 Mac is ~$156/day minimum. GitHub Actions `macos-latest` is free for open source; a self-hosted runner is the no-cost fallback during GSoC and for extended testing.

## Verified during community bonding (2026-05-12)

Existing macOS binary at `~/ccextractor/mac/ccextractor` runs cleanly:

```
Version:          0.96.5
Git commit:       c6647a663b0cc06c9f8381af2690bf9d152d0d1c
Compilation date: 2026-04-21
```

So the existing `mac/build.command` script in the CCExtractor repo is the build entry point — the Mac CI runner just needs to invoke it.

## Self-hosted runner registration (one-time, on your Mac)

**Register against your fork** (`<your-user>/ccextractor`), not the upstream `CCExtractor/ccextractor`:
- You need repo admin to register a runner; you have it on your fork, not upstream.
- Self-hosted runners execute code from any PR that triggers a workflow. On a public upstream repo, that lets outside contributors run arbitrary code on your personal Mac. On your fork only PRs you open run, so the blast radius is contained.

Steps:

1. Your fork on GitHub → Settings → Actions → Runners → "New self-hosted runner" → macOS / ARM64.
2. Follow the displayed `./config.sh --url ... --token ...` commands in a working directory like `~/actions-runner/`.
3. When prompted for labels, add `macos,arm64,self-hosted` so workflows can target it via `runs-on: [self-hosted, macOS, ARM64]`.
4. Install as a service so it survives reboots: `./svc.sh install && ./svc.sh start`.
5. The runner shows as "Idle" in the GitHub UI when registered.

Note: the registration token is short-lived (~1 hour). Do not commit it anywhere.

When upstreaming in Week 11, propose `macos-latest` (GitHub-hosted) as the primary path for `CCExtractor/ccextractor`, with `repository_dispatch` for maintainer-triggered extended runs on a maintainer-owned Mac if they want one. Self-hosted on the upstream public repo is not recommended.

## Build dependencies (Homebrew)

CCExtractor's `mac/build.command` expects these formulae present:

```
brew install autoconf automake libtool pkg-config cmake \
             gpac tesseract leptonica ffmpeg utf8proc \
             rustup-init
rustup-init -y --default-toolchain stable
```

- `gpac`, `ffmpeg`, `tesseract`, `leptonica` are needed for the optional `OCR` and `-hardsubx` build flavors.
- `rustup-init` is required: CCExtractor links a Rust static lib (`libccx_rust.a`) built via cargo. MSRV is **1.87.0** (enforced by `mac/build.command`).

## Build invocation

Use the wrapper in this directory (`build.sh`) or call CCExtractor's own script directly:

```bash
cd ~/ccextractor/mac
./build.command            # baseline build
./build.command OCR        # with tesseract/leptonica OCR
./build.command OCR -hardsubx   # full feature set
./build.command -debug     # with -g + address sanitizer (matches WP1 -g requirement)
```

The output binary lands at `~/ccextractor/mac/ccextractor`.

## Files in this directory

- `README.md` — this file.
- `build.sh` — thin wrapper that invokes CCExtractor's `mac/build.command` with the canonical CI flags.
- `mac-tests.yml.example` — reference GitHub Actions workflow. Final home: `.github/workflows/mac-tests.yml` in the **CCExtractor/ccextractor** repo, not this repo. Kept here so the sample-platform PR shows the full Mac story in one place.

## Open questions for mentor review

1. **Hosted vs self-hosted as primary?** Proposal recommends hosted `macos-latest` for CI with self-hosted as backup. Confirm before Week 11.
2. **Result upload path.** Linux/Windows use gcsfuse-mounted GCS. For Mac the simplest path is `gsutil cp` from the workflow using a service-account JSON repo secret. Confirm this fits the existing sample-platform ingest model.
3. **Status webhook.** The Linux/Windows runCI scripts POST to a `reportURL` fetched from GCE metadata. The Mac workflow has no equivalent — needs a secret-provided URL. Confirm the sample-platform endpoint accepts unauthenticated progress POSTs (it appears to, via the `userAgent` check, but worth confirming).
