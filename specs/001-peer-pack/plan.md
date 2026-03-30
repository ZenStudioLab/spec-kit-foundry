# Implementation Plan: Spec Kit Peer Workflow Integration

**Branch**: `001-peer-pack` | **Date**: 2026-03-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-peer-pack/spec.md`

## Summary

Build the `peer` pack — a Spec Kit extension that adds adversarial review and orchestrated execution commands on top of the existing specify workflow. The pack provides `/speckit.peer.review <target>` in two modes: artifact mode for `spec`, `research`, `plan`, or `tasks`, and file-delegation mode that routes explicit file paths to `/plan-review`. It also provides `/speckit.peer.execute`, both backed by a provider-abstracted adapter layer with Codex as the v1 implementation. Review rounds are append-only Markdown files; provider session state is persisted in JSON for multi-turn continuity. The pack is independently installable with no sibling-pack runtime dependencies.

## Technical Context

**Language/Version**: Bash 5+ (scripts), YAML 1.2 (manifests/config), Markdown (command instruction files)
**Primary Dependencies**: Spec Kit (`specify` CLI), `/codex` skill (`~/.claude/skills/codex/scripts/ask_codex.sh` — external prerequisite, install from https://skills.sh/oil-oil/codex/codex), host-provided `/plan-review` skill or command for explicit file-path delegation mode
**Storage**: File-based — append-only Markdown review files, JSON provider-state, YAML peer config
**Testing**: `scripts/validate-pack.sh <pack-dir>`, manual install scenarios (including explicit file-path delegation to `/plan-review` with no peer-state writes); automated validation matrix covers the artifact/execute workflow, while delegated file-path review is validated as an explicit manual scenario alongside it: first-run state init (no review file, no `provider-state.json`), session reuse (`--session <id>` passed on round 2+), missing `.specify/peer.yml`, disabled provider, unimplemented provider, malformed `provider-state.json`, append-only integrity (no round overwritten), unknown-target rejection (target is neither an artifact keyword nor an existing file path)
**Target Platform**: Linux/macOS (wherever Spec Kit runs)
**Project Type**: Spec Kit extension pack (command pack)
**Performance Goals**: `validate-pack.sh` < 5 s (command-pack acceptance gate); command preflight checks < 500 ms; default max artifact input: 50 KB, configurable via `max_artifact_size_kb` in `peer.yml`; `build-all.sh` < 60 s (global CI context; informational only, not a command-pack acceptance gate)
**Constraints**:

*I/O Contract*: in review mode, adapter stdout may emit `session_id=<value>` and `output_path=<path>` metadata; absence of one or both lines is warning-only as long as the review file is written successfully. Human-readable output stays on stderr: errors use canonical format `[peer/<command>] ERROR: <ERROR_CODE>: <message>`, success summaries use `[peer/<command>]` prefix and include artifact name, round number, review file path, consensus status; verbose/debug output goes to stderr gated by `PEER_DEBUG=1` env var.

*Locking*: `/speckit.peer.review` instructs the provider to write review rounds directly to the review file and does not add an extra lock layer in v1. `/speckit.peer.execute` still uses guarded append semantics for code-review rounds written to `plan-review.md`.

*State & Recovery*: `provider-state.json` is written via temp file + atomic rename after consensus is read from the provider-written review file. Each provider/workflow entry includes `last_persisted_round: N`; the review command increments it after a normal provider-written round or a manually appended `PARSE_FAILURE` note. Unsupported/absent `version` values are backed up and reinitialized; unparseable JSON fails fast.

*Config Validation*: `CODEX_TIMEOUT_SECONDS`: integer 10–600, default 60, env var override — on timeout emit `PROVIDER_TIMEOUT` (exit 2), no retries in v1; `max_artifact_size_kb` in `peer.yml`: integer 1–10240, default 50 — invalid values fail with bounds message at startup; `peer.yml` includes `version: 1`; `provider-state.json` includes `"version": 1` — absent `version` treated as pre-v1: auto-backup as `<file>.bak.YYYYMMDDHHMMSS`, then re-create with instructions; no migration in v1.

*Provider Discovery*: Codex script discovery order: `CODEX_SKILL_PATH` env var → `~/.claude/skills/codex/scripts/ask_codex.sh` → fail with install URL; when `CODEX_SKILL_PATH` override is set, preflight verifies existence + readability + executable bit and emits `[peer/WARN] using CODEX_SKILL_PATH override: ~/...` (home segment redacted by default; full path only with `PEER_DEBUG=1`).

*Feature Resolution*: current working directory spec dir → explicit `--feature <id>` flag → fail with disambiguation prompt listing available spec directories.

*VCS Policy*: `provider-state.json` and `*.bak.*` files are runtime state and MUST be listed in `.gitignore`.

*Other*: no mandatory auto-hooks; review rounds are append-only (no overwrites); session reuse via `--session <id>` codex skill flag; unsupported provider adapters must fail clearly without affecting Codex; artifact mode input is restricted to `spec|research|plan|tasks`, while explicit existing file paths delegate to `/plan-review`; artifact content treated as opaque data in adapter prompts (structurally delimited, never interpolated as instructions).
**Scale/Scope**: Single extension pack consumed by individual developers; no server-side components

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pack Modularity** — The `peer` pack has a single clearly stated responsibility: adversarial review + orchestrated execution. All runtime behavior is self-contained in `packs/peer/`. The Codex adapter uses the external `/codex` skill (user-side prerequisite, not a sibling-pack import). Shared utilities (provider schemas) live in `shared/schemas/`. No sibling-pack runtime imports.
- [x] **II. Code Quality** — Command files are Markdown instruction templates (no line-limit concern). The `extension.yml` manifest will be < 100 lines. No runtime scripts authored in `packs/peer/` (the codex skill script is external); `scripts/validate-pack.sh` is a test/build-time script at the repository root, not part of the pack itself. All failure paths in the provider adapter logic must exit non-zero with actionable stderr messages (enforced in command file instructions).
- [x] **III. Test-First** — All 6 mandatory install/behavior cases are defined in spec.md (SC-003): root `--dev` install, per-pack `--dev` install, release ZIP install, peer commands functional, preset isolation (N/A — peer is a command pack, not a preset), provider error isolation. Plus: session reuse, all four artifact review types.
- [x] **IV. UX Consistency** — Commands follow `speckit.peer.review` and `speckit.peer.execute`. The `peer` pack is a command pack, not a preset, so commands are expected and correct. Error messages in command files must be actionable (state what failed, why, how to resolve).
- [x] **V. Performance** — File I/O is minimal (read/append markdown, read/write small JSON). Bounded performance risks: lock contention resolves within 5 retries × 200 ms (1 s total); provider timeout bounded by `CODEX_TIMEOUT_SECONDS` (default 60 s, max 600 s). No unbounded loops. Command-pack acceptance gates: `validate-pack.sh` < 5 s, preflight checks < 500 ms. (`build-all.sh` < 60 s is global CI context, informational only.)
- [x] **VI. Simplicity** — Provider stubs (Copilot, Gemini) are explicitly reserved in the constitution itself ("intentionally reserved in config and MUST remain unimplemented until a concrete, approved use case exists"). The `provider-state.json` is consumed exclusively by the Codex adapter in v1; it will be shared with future adapters when they are implemented. No new abstraction is added beyond what the original-plan.md specified.

## Project Structure

### Documentation (this feature)

```text
specs/001-peer-pack/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── review-command.md
│   └── execute-command.md
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
packs/peer/
├── extension.yml                  # Pack manifest
├── commands/
│   ├── review.md                  # /speckit.peer.review <target> instruction file
│   └── execute.md                 # /speckit.peer.execute instruction file
├── memory/
│   └── peer-guide.md              # Peer workflow reference (loaded into agent context)
└── templates/
    └── (empty in v1; preset template additions deferred)

shared/
├── providers/
│   └── codex/
│       └── adapter-guide.md       # Codex adapter invocation contract
└── schemas/
    └── peer-providers.schema.yml  # Provider config schema for .specify/peer.yml
```

**Structure Decision**: Single pack directory under `packs/peer/`. All peer-specific files are self-contained. Shared provider utilities go in `shared/` (consumed by the peer pack in v1; available for future packs). No build artifacts in v1 — the pack is pure Markdown/YAML/text. **Shared graduation criterion**: code moves from `packs/peer/` to `shared/` only when a second consumer pack exists — no preemptive sharing.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Provider stubs (Copilot, Gemini) in `.specify/peer.yml` | Explicitly reserved by constitution + original-plan.md; required for `--provider` flag validation to distinguish unconfigured from unimplemented | Omitting stubs entirely would prevent FR-012 (clear error for unimplemented providers) — no stub means no config entry to check against |
| `shared/providers/codex/` introduced with only one consumer | Adapter guide is the Codex invocation contract; co-locating with packs/peer/ would make it pack-private with no route to sharing | Pack-local adapter can't be discovered by future packs without moving; moving it later causes a breaking layout change |
| No `--format json` output flag | Structured output for automation is a valid need but introduces a schema contract requiring versioning and testing | A stable `--format json` flag with versioned schema is deferred to v2; prose output with stable prefixes is sufficient for v1 human workflows. **Revisit condition**: promote to v2 when 2+ automation consumers require parse-stable output, or when `--format json` is filed as a GitHub issue with 3+ upvotes |

## Adapter Interface

All provider adapters must satisfy this contract. The v1 Codex adapter (`shared/providers/codex/adapter-guide.md`) is the reference implementation.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Input: artifact path | string | Yes | Absolute path to artifact file — passed via `--file` |
| Input: prompt | string | Yes | Short natural-language review instruction; artifact and review files are passed separately via `--file` |
| Input: session_id | string | No | Resume token from prior round; absent on first invocation |
| Output: session_id | string | No | Optional stdout metadata line `session_id=<value>` when emitted by the adapter |
| Output: output_path | string | No | Optional stdout metadata line `output_path=<path>` when emitted by the adapter |
| Stderr contract | — | Yes | stderr receives all human-readable output: errors with canonical format `[peer/<command>] ERROR: <ERROR_CODE>: <message>`; success summaries with `[peer/<command>]` prefix; verbose/debug gated by `PEER_DEBUG=1` |
| Exit code 0 | — | Yes | Indicates success |
| Exit code nonzero | — | Yes | Failure; actionable `[peer/<command>] ERROR: <ERROR_CODE>: <message>` written to stderr |

**Exit-code to error-code mapping** — all adapters must honour this table:

| Exit Code | Error Code | Condition |
|-----------|-----------|----------|
| 0 | — | Success |
| 1 | `PROVIDER_UNAVAILABLE` | Script not found or not executable |
| 2 | `PROVIDER_TIMEOUT` | LLM did not respond within timeout |
| 3 | `PROVIDER_EMPTY_RESPONSE` | Adapter reported success semantics but no review file or usable summary was produced |
| 4 | `SESSION_INVALID` | `--session <id>` provided but not resumable |
| 5 | `VALIDATION_ERROR` | Precondition failed (bad artifact, missing config, etc.) |
| 6 | `UNIMPLEMENTED_PROVIDER` | Provider is configured but has no adapter implementation |
| 7 | `STATE_CORRUPTION` | `last_persisted_round` > review file round count; manual recovery required |
| 8 | `PARSE_FAILURE` | Provider response is present but missing the required terminal status marker |

## Canonical File Paths

| File | Canonical Path | Keyed By |
|------|---------------|----------|
| Peer config | `.specify/peer.yml` | Project root (one per repo) |
| Review file (per artifact) | `specs/<featureId>/reviews/<artifact>-review.md` | Feature directory name |
| Plan review (shared) | `specs/<featureId>/reviews/plan-review.md` | Feature directory name |
| Provider state | `specs/<featureId>/reviews/provider-state.json` | Feature directory name |
| Artifact: spec | `specs/<featureId>/spec.md` | Feature directory name |
| Artifact: research | `specs/<featureId>/research.md` | Feature directory name |
| Artifact: plan | `specs/<featureId>/plan.md` | Feature directory name |
| Artifact: tasks | `specs/<featureId>/tasks.md` | Feature directory name |

`featureId` derives from the spec directory name under `specs/` (directory listing is the source of truth). Branch name is advisory metadata only — detached HEAD or renamed branches do not affect file resolution. No two concurrent features share state files; no cross-feature collisions possible.

## Implementation Phases

*Phase 2 source files are created by `/speckit.tasks` + `/speckit.peer.execute`, not this plan.*

| Deliverable | FR Coverage | Entry Criterion | Exit Criterion |
|-------------|-------------|-----------------|----------------|
| `packs/peer/extension.yml` | FR-001, FR-013, FR-014 | Plan APPROVED | Validates with `validate-pack.sh` |
| `packs/peer/commands/review.md` | FR-001–FR-006, FR-011–FR-013, FR-015 | extension.yml exists | Artifact review, tasks review, and file-path delegation behavior are all documented consistently |
| `packs/peer/commands/execute.md` | FR-007–FR-013, FR-015 | review.md readiness rules defined | All tasks.md checkboxes complete; code review rounds appended |
| `packs/peer/memory/peer-guide.md` | FR-015 | commands/ exists | Injected into agent context on install |
| `shared/providers/codex/adapter-guide.md` | FR-011–FR-013 | commands/ exists | Codex invocation writes the expected review/result files; stdout metadata is well-formed when emitted |
| `shared/schemas/peer-providers.schema.yml` | FR-011, FR-015 | extension.yml exists | Accepts valid peer.yml; rejects invalid provider config |
| `scripts/validate-pack.sh` | SC-001–SC-006 | All source files exist + `.gitignore` contains state-file patterns | Passes all 14 automated artifact/execute matrix cases; delegated file-path review is validated separately as a manual acceptance check |
| `.gitignore` (state-file entries) | FR-003, FR-010 | validate-pack.sh exists | Contains `specs/*/reviews/provider-state.json` and `specs/*/reviews/*.bak.*` patterns |

**Automated test manifest**:

| Case ID | Description | Script/Invocation | Expected Result |
|---------|-------------|------------------|-----------------|
| T-01 | First-run state init | `validate-pack.sh --case first-run` | Creates review file + provider-state.json on success |
| T-02 | Session reuse | `validate-pack.sh --case session-reuse` | Round 2 invocation passes `--session <id>` |
| T-03 | Missing peer.yml | `validate-pack.sh --case missing-config` | Exit 5 with install instructions |
| T-04 | Disabled provider | `validate-pack.sh --case disabled-provider` | Exit 5 with enable instructions |
| T-05 | Unimplemented provider | `validate-pack.sh --case unimplemented-provider` | Exit 6 (`UNIMPLEMENTED_PROVIDER`) with v1-only message |
| T-06 | Malformed provider-state.json | `validate-pack.sh --case bad-state` | Fails with schema-version error |
| T-07 | Append-only integrity | `validate-pack.sh --case append-only` | Existing round is never overwritten |
| T-08 | Unknown target rejection | `validate-pack.sh --case bad-artifact` | Exit 5 when the target is neither an artifact keyword nor an existing file path |
| T-09 | Provider timeout | `validate-pack.sh --case timeout` | Exit 2 with `PROVIDER_TIMEOUT` message |
| T-10a | Lock release before timeout | `validate-pack.sh --case lock-release` | Competing lock released before timeout; second caller succeeds |
| T-10b | Stale lock removal | `validate-pack.sh --case stale-lock` | Lock older than 30 s with dead pid is reclaimed; caller succeeds |
| T-11 | Orphan-round forward recovery | `validate-pack.sh --case orphan-recovery` | `last_persisted_round` < review round count; resumes from next round |
| T-11b | State corruption detection | `validate-pack.sh --case state-corruption` | `last_persisted_round` > review round count; fails with `STATE_CORRUPTION` error |
| T-12 | Stdout metadata validation | `validate-pack.sh --case stdout-contract` | If stdout metadata is emitted, only `session_id=` and `output_path=` lines appear on stdout |
| T-13 | VCS ignore check | `validate-pack.sh --case vcs-ignore` | `provider-state.json` and `*.bak.*` patterns present in `.gitignore` |
| T-14 | CODEX_SKILL_PATH warning redaction | `validate-pack.sh --case skill-path-warn` | Override path emits warning with redacted home segment; full path only with `PEER_DEBUG=1` |

**Manual validation scenario**:

| Case ID | Description | Invocation | Expected Result |
|---------|-------------|------------|-----------------|
| M-01 | Delegated file-path review | `/speckit.peer.review docs/plans/example.md` | Routes to `/plan-review`; no `specs/<feature>/reviews/*` files or `provider-state.json` are created or modified |

**Phase dependency order**: `extension.yml` → `commands/` → `memory/` → `shared/` → `scripts/`

**FR → file traceability**:
- FR-001, FR-002, FR-005, FR-006: `review.md`
- FR-003: `review.md` + review file conventions
- FR-004: `review.md` for artifact consensus; `execute.md` for code-review verdicts
- FR-007, FR-008, FR-009, FR-010: `execute.md`
- FR-011: `peer-providers.schema.yml` + `review.md` + `execute.md`
- FR-012: `review.md` + `execute.md` + adapter error taxonomy
- FR-013: `review.md` + `execute.md` + `provider-state.json` conventions
- FR-014: `extension.yml` (`hooks: []`)
- FR-015: `extension.yml` + command docs + injected memory
