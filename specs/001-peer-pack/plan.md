# Implementation Plan: Spec Kit Peer Workflow Integration

**Branch**: `001-peer-pack` | **Date**: 2026-03-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-peer-pack/spec.md`

## Summary

Build the `peer` pack — a Spec Kit extension that adds adversarial review and orchestrated execution commands on top of the existing specify workflow. The pack provides `/speckit.peer.review <artifact>` (targeting spec, research, plan, or tasks) and `/speckit.peer.execute`, both backed by a provider-abstracted adapter layer with Codex as the v1 implementation. Review rounds are append-only Markdown files; provider session state is persisted in JSON for multi-turn continuity. The pack is independently installable with no sibling-pack runtime dependencies.

## Technical Context

**Language/Version**: Bash 5+ (scripts), YAML 1.2 (manifests/config), Markdown (command instruction files)
**Primary Dependencies**: Spec Kit (`specify` CLI), `/codex` skill (`~/.claude/skills/codex/scripts/ask_codex.sh` — external prerequisite, install from https://skills.sh/oil-oil/codex/codex)
**Storage**: File-based — append-only Markdown review files, JSON provider-state, YAML peer config
**Testing**: `scripts/validate-pack.sh <pack-dir>`, manual install scenarios (6 mandatory cases per constitution); automated test matrix: first-run state init (no review file, no `provider-state.json`), session reuse (`--session <id>` passed on round 2+), missing `.specify/peer.yml`, disabled provider, unimplemented provider, malformed `provider-state.json`, append-only integrity (no round overwritten), artifact enum rejection (unknown artifact name)
**Target Platform**: Linux/macOS (wherever Spec Kit runs)
**Project Type**: Spec Kit extension pack (command pack)
**Performance Goals**: `validate-pack.sh` < 5 s (command-pack acceptance gate); command preflight checks < 500 ms; default max artifact input: 50 KB, configurable via `max_artifact_size_kb` in `peer.yml`; `build-all.sh` < 60 s (global CI context; informational only, not a command-pack acceptance gate)
**Constraints**:

*I/O Contract*: command stdout exclusively for `session_id=<value>` then `output_path=<path>` (exactly two lines in that order) — nothing else may appear on stdout; command stderr receives all human-readable output: errors use canonical format `[peer/<command>] ERROR: <ERROR_CODE>: <message>`, success summaries use `[peer/<command>]` prefix and include artifact name, round number, review file path, consensus status; verbose/debug output goes to stderr gated by `PEER_DEBUG=1` env var.

*Locking*: review Markdown append uses cross-platform lock: try `flock -x` → fallback to lockdir (`mkdir -m 000 <file>.lock`) with lock metadata file recording pid + creation_timestamp + random nonce; stale lock detection: reclaim when pid is not running AND creation_timestamp > 30 s ago — nonce prevents false reclaim under PID reuse (ownership requires pid+nonce match); fail with actionable message after 5 retries at 200 ms intervals (1 s total); lock file removed on normal exit.

*State & Recovery*: `provider-state.json` created/updated with file mode `0600`; temp files for atomic rename created with `0600` mode before write, mode verified after rename; each provider/workflow entry in `provider-state.json` includes `last_persisted_round: N` — initialized to 0 on first write; invariant: 0 ≤ `last_persisted_round` ≤ round count in the corresponding review file; if `last_persisted_round < round count in review file`, resume from round N+1 (safe); if `last_persisted_round > round count in review file`, fail with `STATE_CORRUPTION` error and do not auto-recover; write-order: (1) acquire lock, (2) append round to review file, (3) release lock, (4) write `provider-state.json` including updated `last_persisted_round` via atomic rename.

*Config Validation*: `CODEX_TIMEOUT_SECONDS`: integer 10–600, default 60, env var override — on timeout emit `PROVIDER_TIMEOUT` (exit 2), no retries in v1; `max_artifact_size_kb` in `peer.yml`: integer 1–10240, default 50 — invalid values fail with bounds message at startup; `peer.yml` includes `version: 1`; `provider-state.json` includes `"version": 1` — absent `version` treated as pre-v1: auto-backup as `<file>.bak.YYYYMMDDHHMMSS`, then re-create with instructions; no migration in v1.

*Provider Discovery*: Codex script discovery order: `CODEX_SKILL_PATH` env var → `~/.claude/skills/codex/scripts/ask_codex.sh` → fail with install URL; when `CODEX_SKILL_PATH` override is set, preflight verifies existence + readability + executable bit and emits `[peer/WARN] using CODEX_SKILL_PATH override: ~/...` (home segment redacted by default; full path only with `PEER_DEBUG=1`).

*Feature Resolution*: current working directory spec dir → explicit `--feature <id>` flag → fail with disambiguation prompt listing available spec directories.

*VCS Policy*: `provider-state.json` and `*.bak.*` files are runtime state and MUST be listed in `.gitignore`.

*Other*: no mandatory auto-hooks; review rounds are append-only (no overwrites); session reuse via `--session <id>` codex skill flag; unsupported provider adapters must fail clearly without affecting Codex; artifact input restricted to `spec|research|plan|tasks` enum — arbitrary paths rejected; artifact content treated as opaque data in adapter prompts (structurally delimited, never interpolated as instructions).
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
│   ├── review.md                  # /speckit.peer.review <artifact> instruction file
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
| Input: prompt | string | Yes | Structured prompt: immutable system preamble + `--- BEGIN ARTIFACT CONTENT ---` / `--- END ARTIFACT CONTENT ---` delimiters around artifact content |
| Input: session_id | string | No | Resume token from prior round; absent on first invocation |
| Output: session_id | string | Yes | stdout line exactly `session_id=<value>` |
| Output: output_path | string | Yes | stdout line exactly `output_path=<path>` — stdout contains only these two lines in this order; nothing else may appear on stdout |
| Stderr contract | — | Yes | stderr receives all human-readable output: errors with canonical format `[peer/<command>] ERROR: <ERROR_CODE>: <message>`; success summaries with `[peer/<command>]` prefix; verbose/debug gated by `PEER_DEBUG=1` |
| Exit code 0 | — | Yes | Indicates success |
| Exit code nonzero | — | Yes | Failure; actionable `[peer/<command>] ERROR: <ERROR_CODE>: <message>` written to stderr |

**Exit-code to error-code mapping** — all adapters must honour this table:

| Exit Code | Error Code | Condition |
|-----------|-----------|----------|
| 0 | — | Success |
| 1 | `PROVIDER_UNAVAILABLE` | Script not found or not executable |
| 2 | `PROVIDER_TIMEOUT` | LLM did not respond within timeout |
| 3 | `PROVIDER_EMPTY_RESPONSE` | Adapter reported success semantics but wrapper received absent or empty `output_path` |
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
| `packs/peer/commands/review.md` | FR-001–FR-004, FR-008, FR-012, FR-014 | extension.yml exists | All 4 artifact types work; enum gate rejects unknown names |
| `packs/peer/commands/execute.md` | FR-005–FR-007, FR-011, FR-012, FR-014 | plan review APPROVED (SC-004) | All tasks.md checkboxes complete; code review rounds appended |
| `packs/peer/memory/peer-guide.md` | FR-013 | commands/ exists | Injected into agent context on install |
| `shared/providers/codex/adapter-guide.md` | FR-009, FR-010 | commands/ exists | Codex invocation yields correct `session_id` + `output_path` |
| `shared/schemas/peer-providers.schema.yml` | FR-008, FR-015 | extension.yml exists | Accepts valid peer.yml; rejects invalid provider config |
| `scripts/validate-pack.sh` | SC-001–SC-006 | All source files exist + `.gitignore` contains state-file patterns | Passes all 14 automated test matrix cases; completes < 5 s |
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
| T-08 | Artifact enum rejection | `validate-pack.sh --case bad-artifact` | Exit 5 rejecting unknown artifact name |
| T-09 | Provider timeout | `validate-pack.sh --case timeout` | Exit 2 with `PROVIDER_TIMEOUT` message |
| T-10a | Lock release before timeout | `validate-pack.sh --case lock-release` | Competing lock released before timeout; second caller succeeds |
| T-10b | Stale lock removal | `validate-pack.sh --case stale-lock` | Lock older than 30 s with dead pid is reclaimed; caller succeeds |
| T-11 | Orphan-round forward recovery | `validate-pack.sh --case orphan-recovery` | `last_persisted_round` < review round count; resumes from next round |
| T-11b | State corruption detection | `validate-pack.sh --case state-corruption` | `last_persisted_round` > review round count; fails with `STATE_CORRUPTION` error |
| T-12 | Stdout contract validation | `validate-pack.sh --case stdout-contract` | Only `session_id=` and `output_path=` lines on stdout; extra output fails test |
| T-13 | VCS ignore check | `validate-pack.sh --case vcs-ignore` | `provider-state.json` and `*.bak.*` patterns present in `.gitignore` |
| T-14 | CODEX_SKILL_PATH warning redaction | `validate-pack.sh --case skill-path-warn` | Override path emits warning with redacted home segment; full path only with `PEER_DEBUG=1` |

**Phase dependency order**: `extension.yml` → `commands/` → `memory/` → `shared/` → `scripts/`

**FR → file traceability**:
- FR-001 review command / FR-002 artifact rubrics: `review.md` + `adapter-guide.md`
- FR-003 append-only rounds: `review.md` (atomic write + flock constraints)
- FR-004 session continuity / FR-010 session persistence: `review.md` + `execute.md` + `provider-state.json`
- FR-005 readiness gate: `execute.md` (plan review APPROVED check)
- FR-006 batch execution / FR-007 checkbox updates: `execute.md`
- FR-008 provider config / FR-015 provider schema: `peer-providers.schema.yml` + `peer.yml`
- FR-009 Codex adapter: `adapter-guide.md`
- FR-011 execute command: `execute.md`
- FR-012 provider error isolation: enum gate in commands + error taxonomy
- FR-013 memory injection: `peer-guide.md` + `extension.yml`
- FR-014 no mandatory hooks: `extension.yml` (`hooks: []`)
