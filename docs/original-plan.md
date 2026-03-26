# Standalone Multi-Pack Spec Kit Project

## Summary

Build this as a **published GitHub project that acts as a multi-pack hub**, not a single extension repo. Recommended repo name: **`spec-kit-foundry`**
Alternatives: `spec-kit-fleet`, `spec-kit-workshop`

V1 model:
- the repo root is an **all-in-one installable bundle**
- individual packs live under `packs/`
- each pack is itself a valid Spec Kit extension payload
- “presets” are modeled as **template/memory-only packs**, so they can use the same install mechanism as command packs

This gives you both:
- **pick only what you need**
- **install everything in one click**

## Repo Layout

Use this structure:

```text
spec-kit-foundry/
├── extension.yml                # root "all-in-one" bundle, installable from repo root
├── README.md
├── commands/                    # generated/assembled for the all-in-one bundle
├── memory/                      # generated/assembled for the all-in-one bundle
├── templates/                   # generated/assembled for the all-in-one bundle
├── agents/                      # optional prebuilt agent variants later
├── packs/
│   ├── peer/
│   │   ├── extension.yml
│   │   ├── commands/
│   │   ├── memory/
│   │   └── templates/
│   ├── gates/
│   │   ├── extension.yml
│   │   ├── memory/
│   │   └── templates/
│   ├── preset-zen/
│   │   ├── extension.yml
│   │   ├── memory/
│   │   └── templates/
│   └── preset-strict/
│       ├── extension.yml
│       ├── memory/
│       └── templates/
├── shared/
│   ├── providers/
│   │   └── codex/
│   ├── prompts/
│   └── schemas/
├── scripts/
│   ├── validate-pack.sh
│   ├── build-pack.sh
│   └── build-all.sh
└── .github/workflows/release.yml
```

Rules:
- root bundle is the **aggregate pack**
- every directory under `packs/` must be independently installable with `--dev`
- root bundle is generated from selected packs and committed so repo-root install works

## Install Model

### All-in-one install
Supported from repo root:

```bash
specify extension add foundry --from https://github.com/<org>/spec-kit-foundry/archive/refs/tags/v1.0.0.zip
specify extension add --dev /path/to/spec-kit-foundry
```

### Individual pack install
Local dev uses pack subdirs:

```bash
specify extension add peer --dev /path/to/spec-kit-foundry/packs/peer
specify extension add preset-zen --dev /path/to/spec-kit-foundry/packs/preset-zen
```

Remote per-pack install should use **release assets**, not the repo archive, because GitHub archive ZIPs expose the whole repo root:

```bash
specify extension add peer --from https://github.com/<org>/spec-kit-foundry/releases/download/v1.0.0/peer.zip
specify extension add preset-zen --from https://github.com/<org>/spec-kit-foundry/releases/download/v1.0.0/preset-zen.zip
```

## Pack Design

### 1. `peer` pack
Purpose: adversarial review + orchestrated execution
Commands:
- `/speckit.peer.review <artifact>`
- `/speckit.peer.execute`

V1 provider model:
- provider abstraction exists now
- Codex adapter is implemented first
- Copilot/Gemini adapters are reserved in config, not implemented yet

### 2. `gates` pack
Purpose: optional workflow nudges and hook-based guidance
Contents:
- optional `before_*` / `after_*` hook definitions
- review-readiness memory files
- small template add-ons for command-first flow

### 3. `preset-*` packs
Purpose: opinionated memory/template bundles
Examples:
- `preset-zen`
- `preset-strict`

These do **not** need commands. They install as extensions that provide only:
- memory
- templates
- optional hook suggestions

### 4. `foundry` root bundle
Purpose: install everything conveniently
Includes:
- `peer`
- `gates`
- one default preset, or all presets if you want a true kitchen-sink bundle

## Important Interfaces

Each pack must expose a standard manifest:
- `extension.yml`
- `provides.commands`
- `provides.memory`
- `provides.templates`
- optional `hooks`

Add a repo-level pack index for build/release tooling:

```yaml
packs:
  - id: peer
    type: commands
    path: packs/peer
  - id: gates
    type: workflow
    path: packs/gates
  - id: preset-zen
    type: preset
    path: packs/preset-zen
```

Add a provider config schema for packs that need orchestration:

```yaml
default_provider: codex
providers:
  codex: { enabled: true }
  copilot: { enabled: false }
  gemini: { enabled: false }
```

## Release and Publishing

GitHub Actions release job should:
1. validate every pack directory
2. build the root aggregate bundle
3. zip each pack as its own installable artifact
4. zip the root bundle
5. publish tag assets:
- `foundry.zip`
- `peer.zip`
- `gates.zip`
- `preset-zen.zip`
- `preset-strict.zip`

The README should document:
- root install
- per-pack install
- `--dev` local workflows
- which packs are commands vs presets vs workflow helpers

## Test Plan

Validate these scenarios:

1. Root install from `--dev /path/to/spec-kit-foundry` installs the aggregate bundle cleanly.
2. Root install from tagged GitHub archive ZIP works as the all-in-one path.
3. Each `packs/*` directory installs cleanly with `--dev`.
4. Each release asset ZIP installs as the named pack.
5. `peer` commands appear and work after install.
6. Preset packs install only memory/templates and do not conflict with command packs.
7. Aggregate build contains the expected union of files and no filename collisions.
8. Unsupported providers fail clearly while keeping Codex functional.

## Assumptions

- Current install UX reliably supports **one installable payload per ZIP root**, so per-pack remote installs use release assets.
- A “preset” is treated as an extension pack that ships templates/memory, which keeps the project compatible with today’s extension install model.
- Recommended naming:
  - repo: `spec-kit-foundry`
  - aggregate pack: `foundry`
  - command pack: `peer`
  - workflow pack: `gates`
- If Spec Kit later adds first-class multi-pack repo selection from one archive, this layout can adopt it without restructuring the repo.
