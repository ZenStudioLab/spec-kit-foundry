# Contract: `/speckit.peer.review`

**Pack**: `peer`  
**Command**: `review`  
**Version**: 1.0.0

---

## Invocation

```bash
/speckit.peer.review <artifact> [--provider <name>] [--feature <id>]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `artifact` | Yes | One of `spec`, `research`, `plan`, `tasks` |
| `--provider <name>` | No | Override `default_provider` from `.specify/peer.yml` |
| `--feature <id>` | No | Explicit feature id when feature context is ambiguous |

### Examples

```bash
# Review plan using default provider
/speckit.peer.review plan

# Review spec with explicit provider
/speckit.peer.review spec --provider codex

# Review tasks for a specific feature
/speckit.peer.review tasks --feature 001-peer-pack
```

---

## Preconditions

The command halts on any failed precondition with an actionable error and no partial normal-round append.

1. `artifact` must be one of `spec|research|plan|tasks`.
2. Feature context must resolve in this order:
   - current working directory spec context
   - then `--feature <id>`
   - otherwise fail and list available `specs/*` directories
3. `.specify/peer.yml` must exist and `version` must be integer `1`.
4. Resolved provider (`--provider` or `default_provider`) must exist in `providers`, be `enabled: true`, and have `mode: orchestrated`.
5. Adapter guide must exist at `shared/providers/<provider>/adapter-guide.md`.
6. For `codex`, script discovery order is:
   - `CODEX_SKILL_PATH` (if set; must exist, be readable, executable)
   - `~/.claude/skills/codex/scripts/ask_codex.sh`
7. When `CODEX_SKILL_PATH` override is used, emit warning:
   - default: `[peer/WARN] using CODEX_SKILL_PATH override: ~/...`
   - with `PEER_DEBUG=1`: full absolute path may be shown
8. Target artifact file `specs/<featureId>/<artifact>.md` must exist and be non-empty.
9. If `artifact=tasks`, all four artifacts must exist and be non-empty:
   - `spec.md`, `research.md`, `plan.md`, `tasks.md`
10. `max_artifact_size_kb` must validate as integer `1..10240` when present.
11. `CODEX_TIMEOUT_SECONDS` must validate as integer `10..600` when present (default `60`).
12. Command is explicit-only; no mandatory auto-hooks.

---

## Execution Steps

1. **Resolve feature and paths**
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
   - for `artifact=tasks`, enforce both per-file and combined prompt payload bounds
   - fail with `VALIDATION_ERROR` before adapter invocation on size overflow
   - Load prior context rounds from current review file:
   - include at most last `max_context_rounds` complete artifact rounds (default `3`)
   - exclude `## Code Review Round` sections from prior context loading
   - For `artifact in {spec,research,plan}`:
   - inject single artifact content within canonical delimiters:
   - `--- BEGIN ARTIFACT CONTENT ---`
   - `--- END ARTIFACT CONTENT ---`
   - For `artifact=tasks`, inject all four artifacts in this exact order and labeled sections:
   - `### spec.md` + delimiters
   - `### research.md` + delimiters
   - `### plan.md` + delimiters
   - `### tasks.md` + delimiters
   - Require terminal marker line in provider response:
   - `Consensus Status: NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED`

7. **Invoke provider adapter**
   - Call adapter (codex example):
   - `ask_codex.sh "<prompt>" --file <artifact-path> [--session <session_id>] --reasoning high`
   - Parse strict stdout contract:
   - line 1: `session_id=<value>`
   - line 2: `output_path=<path>`
   - Any stdout deviation is `PARSE_FAILURE`.

8. **Validate and normalize provider output**
   - `output_path` must exist and be non-empty.
   - Parse terminal marker from the last 5 lines using:
   - `^\*{0,2}Consensus Status\*{0,2}:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)$`
   - If status is missing, do not append a normal round. Prepare an error round with code `PARSE_FAILURE`.
   - On success, strip trailing status-marker lines from provider body and keep a single normalized status line for append.

9. **Append under lock (append-only)**
   - Acquire lock with `flock -x`; fallback to lockdir (`mkdir -m 000 <file>.lock`) with metadata file containing `pid`, `creation_timestamp`, `nonce`.
   - Stale-lock reclaim allowed only when:
   - owning pid is not running
   - lock age > 30 seconds
   - ownership check uses pid+nonce to avoid PID-reuse false reclaim
   - Retry up to 5 times at 200ms intervals; on failure emit `LOCK_CONTENTION`.
   - Append exactly one of the schemas below, then release lock.

10. **Persist provider state (atomic, merged)**
   - Upsert `<provider>.review` with:
   - `session_id`, `updated_at`, `session_started_at`, `rounds_in_session`, `context_reset_reason`, `last_persisted_round`
   - Invariant:
   - `0 <= last_persisted_round <= artifact_round_count`
   - If `last_persisted_round > artifact_round_count`, fail with `STATE_CORRUPTION` (no auto-recovery).
   - If `last_persisted_round < artifact_round_count`, safe-forward resume from next round.
   - Write order:
   - append round while lock held
   - release lock
   - write `provider-state.json` via temp file (mode `0600`) + atomic rename (final mode `0600`)
   - Preserve other provider/workflow keys.

   State update matrix:
   - normal round appended: increment `rounds_in_session`, set `last_persisted_round=N`
   - error round appended (for example `PARSE_FAILURE`): keep `rounds_in_session` unchanged, set `last_persisted_round=N`
   - lock contention / no append: do not write provider state
   - precondition failure before provider invocation: do not write provider state

11. **Evaluate consensus**
   - `NEEDS_REVISION`: revise artifact and rerun.
   - `MOSTLY_GOOD`: apply minor revisions; optional confirmation rerun.
   - `BLOCKED`: halt and report blocker.
   - `APPROVED`: report completion path and status.

12. **Emit canonical stderr summary**
   - Success line format:
   - `[peer/review] artifact=<artifact> round=<N> review_file=<path> consensus=<status>`
   - Debug/verbose content only when `PEER_DEBUG=1`.

---

## Round Append Schemas

### Normal Artifact Round

```markdown
---

## Round N — YYYY-MM-DD

<provider review body without terminal status marker>

Consensus Status: NEEDS_REVISION | MOSTLY_GOOD | APPROVED | BLOCKED
```

### Error Round

```markdown
---

## Round N — YYYY-MM-DD [ERROR: <error_code>]

Failed to complete round. Session state preserved. Retry with same command.
```

Error rounds count toward the artifact round counter.

---

## Adapter I/O Contract

| Stream | Contract |
|--------|----------|
| `stdout` | Exactly two lines in order: `session_id=<value>` then `output_path=<path>` |
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
| 3 | `PROVIDER_EMPTY_RESPONSE` | Missing/empty provider output |
| 4 | `SESSION_INVALID` | Resume session not accepted |
| 5 | `VALIDATION_ERROR` | Config/path/precondition failure |
| 6 | `UNIMPLEMENTED_PROVIDER` | Provider configured but adapter absent |
| 7 | `STATE_CORRUPTION` | `last_persisted_round` invariant violated |
| 8 | `PARSE_FAILURE` | Missing required terminal status marker |

### Error-Code Compatibility Notes

- `ADAPTER_MISSING` is a legacy alias of `UNIMPLEMENTED_PROVIDER` for error-round heading compatibility.
- `LOCK_CONTENTION` may appear in error-round headings when lock retries are exhausted and maps to exit code `5` (`VALIDATION_ERROR`) in v1.

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
| Unknown artifact | `Artifact must be one of spec|research|plan|tasks.` |
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
| Lock contention | `Could not acquire review file lock after 5 retries.` |
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

- Review history is append-only.
- Artifact round numbers are monotonic and computed via `^## Round [0-9]`.
- `tasks` review always loads all four artifacts into the prompt in fixed labeled order.
- Adapter stdout contract is strict two-line output; human logs never appear on stdout.
- Provider state updates are merged; review workflow does not overwrite execute workflow state.
- Commands are explicit only; no mandatory auto-hooks.
