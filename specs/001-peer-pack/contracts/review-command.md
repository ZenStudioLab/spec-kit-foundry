# Contract: `/speckit.peer.review`

**Pack**: `peer`  
**Command**: `review`  
**Version**: 1.0.0

---

## Invocation

```bash
/speckit.peer.review <target> [--provider <name>] [--feature <id>]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `target` | Yes | One of `spec`, `research`, `plan`, `tasks`, or an existing file path |
| `--provider <name>` | No | Override `default_provider` from `.specify/peer.yml`; forwarded to the bundled file-mode plan-review workflow for file-path delegation |
| `--feature <id>` | No | Explicit feature id when feature context is ambiguous; ignored for file-path delegation |

### Examples

```bash
# Review plan using default provider
/speckit.peer.review plan

# Review spec with explicit provider
/speckit.peer.review spec --provider codex

# Review tasks for a specific feature
/speckit.peer.review tasks --feature 001-peer-pack

# Review a standalone file through the bundled file-mode plan-review workflow
/speckit.peer.review docs/plans/refining-agent-for-codex-invocation.md
```

---

## Preconditions

The command halts on any failed precondition with an actionable error and no partial normal-round append.

1. `target` must be either one of `spec|research|plan|tasks` or an existing file path.
2. Artifact-keyword precedence applies: if `target` is exactly `spec`, `research`, `plan`, or `tasks`, artifact mode wins even if a file with the same name exists in the current directory.
3. If `target` resolves to a canonical feature artifact path matching `specs/<id>/(spec|research|plan|tasks).md`, artifact mode wins and the command derives `featureId=<id>` and `artifact=<filename-without-.md>` from the path.
4. If `target` is not an artifact enum or canonical feature artifact path, it must resolve to an existing file path.
5. When `target` resolves to a standalone existing file path, the command MUST load the bundled `templates/plan-review.md` workflow within the peer pack against the resolved file path and halt after returning the delegated result.
6. File-path delegation mode MUST NOT load `.specify/peer.yml`, resolve feature context, read/write canonical artifact review files (`specs/<featureId>/reviews/spec-review.md`, `research-review.md`, `plan-review.md`, `tasks-review.md`), or update `provider-state.json`; any supplied `--provider` flag is forwarded into the bundled file-mode workflow and any supplied `--feature` flag is ignored.
7. Feature context must resolve in this order:
   - canonical feature path context derived from `specs/<id>/(spec|research|plan|tasks).md`
   - current working directory spec context
   - then `--feature <id>`
   - otherwise fail and list available `specs/*` directories
8. `.specify/peer.yml` must exist and `version` must be integer `1`.
9. Resolved provider (`--provider` or `default_provider`) must exist in `providers`, be `enabled: true`, and have `mode: orchestrated`.
10. Adapter guide must exist at `shared/providers/<provider>/adapter-guide.md`.
11. For `codex`, script discovery order is:
   - `CODEX_SKILL_PATH` (if set; must exist, be readable, executable)
   - `~/.claude/skills/codex/scripts/ask_codex.sh`
12. When `CODEX_SKILL_PATH` override is used, emit warning:
   - default: `[peer/WARN] using CODEX_SKILL_PATH override: ~/...`
   - with `PEER_DEBUG=1`: full absolute path may be shown
13. Target artifact file `specs/<featureId>/<artifact>.md` must exist and be non-empty.
14. If `artifact=tasks`, all four artifacts must exist and be non-empty:
   - `spec.md`, `research.md`, `plan.md`, `tasks.md`
15. `max_artifact_size_kb` must validate as integer `1..10240` when present.
16. `CODEX_TIMEOUT_SECONDS` must validate as integer `10..600` when present (default `60`).
17. Command is explicit-only; no mandatory auto-hooks.

---

## Execution Steps

1. **Resolve feature and paths**
   - Resolve `target` with artifact-keyword precedence first, then file-path delegation.
   - If `target` resolves to a standalone existing file path after the Step 1 resolution gate has ruled out canonical feature artifact paths (`specs/<id>/(spec|research|plan|tasks).md`), delegate immediately to the bundled file-mode workflow with `<resolved-path>` and stop. No remaining execution steps apply.
   - All remaining execution steps in this contract apply to artifact mode only.
   - Resolve `featureId` using precondition order.
   - Artifact path: `specs/<featureId>/<artifact>.md`.
   - Review path: `specs/<featureId>/reviews/<artifact>-review.md` (`plan` uses `plan-review.md`).
   - State path: `specs/<featureId>/reviews/provider-state.json`.
   - Ensure `specs/<featureId>/reviews/` exists.
   - If review file is missing, create an empty file before round counting (first-run bootstrap).

2. **Load peer config and provider**
   - Parse `.specify/peer.yml`.
   - Resolve provider and validate `enabled`/`mode`/adapter.
   - Apply codex discovery order and warning behavior.

3. **Load and recover provider state**
   - If `provider-state.json` is absent: initialize in-memory state as `{ "version": 1 }`.
   - If present, parse JSON and check `version`.
   - If `version` is absent or unsupported:
   - backup original as `provider-state.json.bak.YYYYMMDDHHMMSS`
   - reinitialize state as `{ "version": 1 }`
   - emit actionable stderr note explaining pre-v1 recovery and no migration in v1
   - Read session entry from `<provider>.review` when present.

4. **Resolve session lifecycle**
   - Read `max_rounds_per_session` (default `10`).
   - `rounds_in_session` counts successful provider rounds only.
   - If existing `rounds_in_session >= max_rounds_per_session`, start new provider session by omitting `--session` and set `context_reset_reason=max_rounds_exceeded`.
   - If prior session is invalid/expired (adapter exit `SESSION_INVALID`), restart once without `--session`.

5. **Determine artifact round number**
   - Count artifact rounds using anchored pattern:
   - `grep -c '^## Round [0-9]' <review_file>`
   - If review file was just created and has no rounds, treat count as `0`.
   - Next round is `N = count + 1`.

6. **Build review context**
   - Enforce size guards before prompt assembly:
   - each included artifact file must be `<= max_artifact_size_kb`
   - for `artifact=tasks`, enforce the per-file bounds before adapter invocation
   - fail with `VALIDATION_ERROR` before adapter invocation on size overflow
   - Load prior context rounds from current review file:
   - include at most last `max_context_rounds` complete artifact rounds (default `3`)
   - exclude `## Code Review Round` sections from prior context loading
   - For `artifact in {spec,research,plan}`:
   - assemble a short natural-language prompt; do not inline artifact contents
   - For `artifact=tasks`, inject all four artifacts in this exact order and labeled sections:
   - pass `spec.md`, `research.md`, `plan.md`, `tasks.md`, and `tasks-review.md` as `--file` arguments instead of inlining them
   - Require terminal marker line in the review written to the review file:
   - `Consensus Status: NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED`

7. **Invoke provider adapter**
   - Call adapter (codex example):
   - `ask_codex.sh "<prompt>" --file <artifact-path> --file <review-file> [--session <session_id>] --reasoning high`
   - For `artifact=tasks`, pass all four artifacts plus `tasks-review.md` via `--file`
   - Capture stdout metadata when present:
   - `session_id=<value>`
   - `output_path=<path>`
   - Missing metadata is warning-only in review mode; the review file written by the provider is the source of truth.

8. **Read consensus from the review file**
   - The provider writes the review directly to `specs/<featureId>/reviews/<artifact>-review.md`.
   - Read the terminal marker from the review file using:
   - `^\*{0,2}Consensus Status\*{0,2}:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)$`
   - If status is missing, append an error note manually with code `PARSE_FAILURE` and retry guidance.
   - `output_path`, when present, is informational only.

9. **Persist provider state (atomic, merged)**
   - Upsert `<provider>.review` with:
   - `session_id`, `updated_at`, `session_started_at`, `rounds_in_session`, `context_reset_reason`, `last_persisted_round`
   - Write `provider-state.json` via temp file + atomic rename.
   - Preserve other provider/workflow keys.

   State update matrix:
   - normal round written by provider: increment `rounds_in_session`, set `last_persisted_round=N`
   - error note appended manually (for example `PARSE_FAILURE`): keep `rounds_in_session` unchanged, set `last_persisted_round=N`
   - precondition failure before provider invocation: do not write provider state

10. **Evaluate consensus**
   - `NEEDS_REVISION`: revise artifact and rerun.
   - `MOSTLY_GOOD`: apply minor revisions; optional confirmation rerun.
   - `BLOCKED`: halt and report blocker.
   - `APPROVED`: report completion path and status.

11. **Emit canonical stderr summary**
   - Success line format:
   - `[peer/review] artifact=<artifact> round=<N> review_file=<path> consensus=<status>`
   - Debug/verbose content only when `PEER_DEBUG=1`.

---

## Error Note Schema

When the provider writes a review file entry but omits the terminal marker, append this error note:

```markdown
---

## Round N — YYYY-MM-DD [ERROR: <error_code>]
Codex wrote the review file but did not include a Consensus Status marker. Retry with same command.
```

---

## Adapter I/O Contract

| Stream | Contract |
|--------|----------|
| `stdout` | Optional metadata only: `session_id=<value>` and `output_path=<path>` when the adapter emits them |
| `stderr` | Human-readable logs only; errors use `[peer/review] ERROR: <ERROR_CODE>: <message>` |

### Stderr Rules

- Success summaries use `[peer/review]` prefix and include `artifact`, `round`, `review_file`, `consensus`.
- Errors use canonical format: `[peer/review] ERROR: <ERROR_CODE>: <message>`.
- Debug details must be gated by `PEER_DEBUG=1`.

### Exit Code Mapping

| Exit Code | Error Code | Condition |
|-----------|------------|-----------|
| 0 | - | Success |
| 1 | `PROVIDER_UNAVAILABLE` | Script not found or not executable |
| 2 | `PROVIDER_TIMEOUT` | Provider timeout exceeded |
| 3 | `PROVIDER_EMPTY_RESPONSE` | Provider returned success but no review file or usable summary was produced |
| 4 | `SESSION_INVALID` | Resume session not accepted |
| 5 | `VALIDATION_ERROR` | Config/path/precondition failure |
| 6 | `UNIMPLEMENTED_PROVIDER` | Provider configured but adapter absent |
| 7 | `STATE_CORRUPTION` | `last_persisted_round` invariant violated |
| 8 | `PARSE_FAILURE` | Missing required terminal status marker |

### Error-Code Compatibility Notes

- `ADAPTER_MISSING` is a legacy alias of `UNIMPLEMENTED_PROVIDER` for error-round heading compatibility.
- `LOCK_CONTENTION` is reserved for older review-contract drafts and is not used by the current review command path.

---

## Outputs

| Output | Path | Description |
|--------|------|-------------|
| Review file | `specs/<featureId>/reviews/<artifact>-review.md` | Append-only artifact review history |
| Provider state | `specs/<featureId>/reviews/provider-state.json` | Updated `<provider>.review` session entry |
| Backup state (recovery only) | `specs/<featureId>/reviews/provider-state.json.bak.*` | Pre-v1/unsupported schema backup |
| Revised artifact | `specs/<featureId>/<artifact>.md` | Revised only when user/orchestrator applies feedback |

---

## Error Conditions

| Condition | Error Message |
|-----------|---------------|
| Unknown target | `Target must be one of spec|research|plan|tasks or an existing file path.` |
| Unresolved feature context | `Could not resolve feature context. Run from feature context or pass --feature <id>.` |
| Missing artifact file | `Artifact '<name>' not found at specs/<feature>/<name>.md.` |
| Missing dependency for tasks review | `tasks review requires spec.md, research.md, plan.md, and tasks.md.` |
| Missing peer config | `peer.yml not found. Create .specify/peer.yml.` |
| Invalid peer config version | `peer.yml version mismatch. Expected version: 1.` |
| Invalid provider-state version | `provider-state.json version unsupported. Backed up and reinitialized to version 1.` |
| Provider disabled | `Provider '<name>' is disabled in .specify/peer.yml.` |
| Unsupported provider mode | `Provider '<name>' must use mode: orchestrated.` |
| Provider adapter missing | `Provider '<name>' adapter is not implemented in v1.` |
| Codex script unavailable | `Codex skill script not found or not executable.` |
| Missing status marker in provider output | `Provider output missing Consensus Status. Error round recorded as PARSE_FAILURE.` |
| State corruption | `provider-state.json is inconsistent with review rounds (STATE_CORRUPTION).` |

---

## Artifact-Specific Rubrics

| Artifact | Rubric Focus |
|----------|--------------|
| `spec` | Story completeness, FR/SC coverage, edge cases, ambiguity |
| `research` | Decision quality, alternatives, rationale strength, unresolved risks |
| `plan` | Feasibility, sequencing, architecture fit, constitution alignment |
| `tasks` | Coverage vs requirements, dependency order, missing tests, cross-artifact readiness |

---

## Invariants

- Review history is append-only; normal rounds are written directly by the provider.
- Artifact round numbers are monotonic and computed via `^## Round [0-9]`.
- `tasks` review always loads all four artifacts via `--file` arguments in fixed order.
- Adapter stdout, when used, contains metadata only; human logs never appear on stdout.
- Provider state updates are merged; review workflow does not overwrite execute workflow state.
- Commands are explicit only; no mandatory auto-hooks.
