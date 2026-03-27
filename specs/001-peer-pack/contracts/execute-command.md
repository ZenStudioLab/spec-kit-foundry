# Contract: `/speckit.peer.execute`

**Pack**: `peer`  
**Command**: `execute`  
**Version**: 1.0.0

---

## Invocation

```bash
/speckit.peer.execute [--provider <name>] [--feature <id>]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--provider <name>` | No | Override `default_provider` from `.specify/peer.yml` |
| `--feature <id>` | No | Explicit feature id when feature context is ambiguous |

### Examples

```bash
# Execute pending tasks with default provider
/speckit.peer.execute

# Execute tasks for explicit feature with codex
/speckit.peer.execute --provider codex --feature 001-peer-pack
```

---

## Roles

`/speckit.peer.execute` uses a strict two-role model:

| Role | Responsibility |
|------|----------------|
| **Orchestrator** (Claude) | Resolve feature/config/state, dispatch batches, verify task checkbox transitions, run code-review/fix loop, append code-review rounds, persist provider state, and report completion. Never writes implementation code. |
| **Executor** (Codex or configured provider) | Implements assigned batch, updates task checkboxes, responds to fix instructions, and returns review verdicts. |

This boundary is invariant. If executor is unavailable, the command halts.

---

## Preconditions

The command halts on any failed precondition with an actionable error and no partial normal-round append.

1. Feature context must resolve in this order:
   - current working directory spec context
   - then `--feature <id>`
   - otherwise fail and list available `specs/*` directories
2. `specs/<featureId>/plan.md` must exist and be non-empty.
3. `specs/<featureId>/tasks.md` must exist and contain at least one unchecked task (`- [ ]`), otherwise return "nothing to execute".
4. Hard readiness gate: latest artifact-review round in `specs/<featureId>/reviews/plan-review.md` must be `Consensus Status: APPROVED` or `Consensus Status: MOSTLY_GOOD`.
5. Hard readiness gate: `specs/<featureId>/reviews/tasks-review.md` must exist and latest artifact-review round must be `Consensus Status: APPROVED` or `Consensus Status: MOSTLY_GOOD`.
6. `.specify/peer.yml` must exist and `version` must be integer `1`.
7. Resolved provider must exist in config, be `enabled: true`, and have `mode: orchestrated`.
8. Provider adapter guide must exist at `shared/providers/<provider>/adapter-guide.md`.
9. For `codex`, script discovery order is:
   - `CODEX_SKILL_PATH` (if set; must exist, be readable, executable)
   - `~/.claude/skills/codex/scripts/ask_codex.sh`
10. When `CODEX_SKILL_PATH` override is used, emit warning:
   - default: `[peer/WARN] using CODEX_SKILL_PATH override: ~/...`
   - with `PEER_DEBUG=1`: full absolute path may be shown
11. If `provider-state.json` exists, it must be readable JSON; unsupported/absent version is recovered by backup + reinitialize to `version: 1`.
12. `max_artifact_size_kb` must validate as integer `1..10240` when present.
13. `CODEX_TIMEOUT_SECONDS` must validate as integer `10..600` when present (default `60`).
14. Commands are explicit-only; no mandatory auto-hooks.

---

## Execution Steps

1. **Resolve feature and paths**
   - Resolve `featureId` using precondition order.
   - Resolve:
   - `plan_path = specs/<featureId>/plan.md`
   - `tasks_path = specs/<featureId>/tasks.md`
   - `plan_review_path = specs/<featureId>/reviews/plan-review.md`
   - `state_path = specs/<featureId>/reviews/provider-state.json`

2. **Load peer config and provider**
   - Parse `.specify/peer.yml`.
   - Resolve provider (`--provider` or `default_provider`).
   - Validate `enabled`, `mode`, adapter, and codex discovery/warning behavior.

3. **Load and recover provider state**
   - If `provider-state.json` is absent: initialize in-memory state as `{ "version": 1 }`.
   - If present, parse JSON and check `version`.
   - If `version` is absent or unsupported:
   - backup original as `provider-state.json.bak.YYYYMMDDHHMMSS`
   - reinitialize state as `{ "version": 1 }`
   - emit actionable stderr note (pre-v1 recovery; no migration in v1)
   - Read session entry from `<provider>.execute` when present.

4. **Run readiness gate**
   - Resolve latest artifact-review consensus in `plan-review.md`:
   - scope to `^## Round [0-9]` sections only
   - read last anchored marker `^Consensus Status:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)$`
   - If latest status is not `APPROVED|MOSTLY_GOOD`, halt with:
   - `Plan has no approved review. Run /speckit.peer.review plan first.`
   - Resolve latest artifact-review consensus in `tasks-review.md`:
   - file must exist
   - read last anchored marker `^Consensus Status:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)$`
   - If latest status is not `APPROVED|MOSTLY_GOOD`, halt with:
   - `Tasks readiness is not approved. Run /speckit.peer.review tasks first.`

5. **Build pending queue**
   - Read full `tasks.md`.
   - Enforce size guards before prompt assembly:
   - `plan.md <= max_artifact_size_kb`
   - `tasks.md <= max_artifact_size_kb`
   - combined execution payload (plan context + batch context) must respect configured bounds
   - fail with `VALIDATION_ERROR` on overflow
   - Extract unchecked items (`- [ ]`) in document order.
   - If queue is empty, exit successfully with "nothing to execute".

6. **Batch execute + review/fix loop**
   - While unchecked tasks remain:
   - Select next coherent batch (guideline: 1-5 tasks or one logical phase).
   - Build execution prompt with:
   - relevant `plan.md` context
   - selected batch task lines and IDs
   - instruction that executor must mark completed batch checkboxes in `tasks.md`
   - Invoke adapter:
   - `ask_codex.sh "<prompt>" --file <tasks_path> [--session <session_id>] --reasoning high`
   - Parse strict stdout contract (`session_id`, `output_path`).
   - Validate `output_path` non-empty.
   - Re-read `tasks.md` and verify every dispatched task is now `- [x]`.
   - If any dispatched task remains unchecked, return `VALIDATION_ERROR` and request executor correction before advancing.
   - Run bounded code review for this batch (Step 7).
   - Recompute unchecked queue from current `tasks.md`.

7. **Code review round for current batch**
   - Determine code review round number:
   - `R = grep -c '^## Code Review Round [0-9]' <plan_review_path> + 1`
   - Build review prompt with:
   - batch scope and expected outcomes
   - plan constraints
   - requirement to end with terminal line:
   - `Verdict: NEEDS_FIX|APPROVED`
   - Invoke adapter (same session unless reset required).
   - Parse verdict from last 5 lines using:
   - `^\*{0,2}Verdict\*{0,2}:\s*(NEEDS_FIX|APPROVED)$`
   - If verdict is missing, prepare parse-failure code-review error round with verdict forced to `NEEDS_FIX`.
   - Loop bounds (required to avoid unbounded retries):
   - `max_fix_rounds_per_batch=3`
   - `max_parse_failures_per_batch=2`
   - If either cap is exceeded, halt the command with `VALIDATION_ERROR` and actionable remediation.
   - Acquire lock and append round using schema in this contract.
   - If verdict is `NEEDS_FIX`, dispatch fix instructions for the flagged issues and re-run Step 7 until `APPROVED`.

8. **Session lifecycle and state updates**
   - Track `max_rounds_per_session` (default `10`).
   - `rounds_in_session` counts successful provider rounds only.
   - If `rounds_in_session >= max_rounds_per_session`, start a new session by omitting `--session` and set `context_reset_reason=max_rounds_exceeded`.
   - If adapter returns `SESSION_INVALID`, restart once without `--session`; if it fails again, halt.
   - After each provider invocation, merge-write `<provider>.execute` with:
   - `session_id`, `updated_at`, `session_started_at`, `rounds_in_session`, `context_reset_reason`, `last_persisted_round`
   - `last_persisted_round` tracks appended code-review rounds in `plan-review.md`.
   - Invariant:
   - `0 <= last_persisted_round <= code_review_round_count`
   - If `last_persisted_round > code_review_round_count`, fail with `STATE_CORRUPTION`.
   - If `last_persisted_round < code_review_round_count`, safe-forward resume from next code-review round.
   - Persist via temp file mode `0600` + atomic rename to mode `0600`.

   State update matrix:
   - batch execution invocation (no review append yet): on success, update session lifecycle fields and increment `rounds_in_session`; keep `last_persisted_round` unchanged
   - successful code-review append: update session lifecycle fields, increment `rounds_in_session`, and set `last_persisted_round=R`
   - parse-failure code-review error-round append: keep `rounds_in_session` unchanged, set `last_persisted_round=R`
   - lock contention / no append: do not write provider state
   - precondition failure before provider invocation: do not write provider state

9. **Completion report**
   - Success requires:
   - all tasks in `tasks.md` marked `[x]`
   - latest batch code review verdict is `APPROVED`
   - Emit canonical stderr summary with:
   - feature id
   - total completed task count
   - total code-review rounds
   - `plan-review.md` path

---

## Code Review Append Schemas

### Normal Code Review Round

```markdown
---

## Code Review Round R — YYYY-MM-DD

<provider review body without terminal verdict marker>

Verdict: NEEDS_FIX | APPROVED
```

### Error Code Review Round

```markdown
---

## Code Review Round R — YYYY-MM-DD [ERROR: <error_code>]

Failed to complete code review round. Session state preserved. Retry with same command.

Verdict: NEEDS_FIX
```

---

## Adapter I/O Contract

| Stream | Contract |
|--------|----------|
| `stdout` | Exactly two lines in order: `session_id=<value>` then `output_path=<path>` |
| `stderr` | Human-readable logs only; errors use `[peer/execute] ERROR: <ERROR_CODE>: <message>` |

### Stderr Rules

- Success summaries use `[peer/execute]` prefix and include `feature`, `batch`, `pending`, `code_review_round`, `verdict` (if applicable).
- Errors use canonical format: `[peer/execute] ERROR: <ERROR_CODE>: <message>`.
- Debug details must be gated by `PEER_DEBUG=1`.

### Exit Code Mapping

| Exit Code | Error Code | Condition |
|-----------|------------|-----------|
| 0 | - | Success |
| 1 | `PROVIDER_UNAVAILABLE` | Script not found or not executable |
| 2 | `PROVIDER_TIMEOUT` | Provider timeout exceeded |
| 3 | `PROVIDER_EMPTY_RESPONSE` | Missing/empty provider output |
| 4 | `SESSION_INVALID` | Resume session not accepted |
| 5 | `VALIDATION_ERROR` | Config/path/precondition/checkpoint failure |
| 6 | `UNIMPLEMENTED_PROVIDER` | Provider configured but adapter absent |
| 7 | `STATE_CORRUPTION` | `last_persisted_round` invariant violated |
| 8 | `PARSE_FAILURE` | Missing required terminal verdict marker |

### Error-Code Compatibility Notes

- `ADAPTER_MISSING` is a legacy alias of `UNIMPLEMENTED_PROVIDER` for error-round heading compatibility.
- `LOCK_CONTENTION` may appear in error-round headings when lock retries are exhausted and maps to exit code `5` (`VALIDATION_ERROR`) in v1.

---

## Locking and Append Safety

- Appends to `plan-review.md` use cross-platform lock strategy:
- try `flock -x`
- fallback lockdir (`mkdir -m 000 <file>.lock`) with metadata (`pid`, `creation_timestamp`, `nonce`)
- stale-lock reclaim requires dead pid + age > 30s + nonce ownership check
- retry limit: 5 attempts, 200ms interval
- on lock acquisition failure, halt with `LOCK_CONTENTION`
- no existing round content is overwritten

---

## Outputs

| Output | Path | Description |
|--------|------|-------------|
| Updated tasks | `specs/<featureId>/tasks.md` | Batch-completed task checkboxes marked `[x]` by executor |
| Code review rounds | `specs/<featureId>/reviews/plan-review.md` | Append-only `Code Review Round` history |
| Provider state | `specs/<featureId>/reviews/provider-state.json` | Updated `<provider>.execute` session entry |
| Backup state (recovery only) | `specs/<featureId>/reviews/provider-state.json.bak.*` | Pre-v1/unsupported schema backup |
| Implementation files | workspace paths | Written by executor; orchestrator does not author implementation code |

---

## Error Conditions

| Condition | Error Message |
|-----------|---------------|
| Unresolved feature context | `Could not resolve feature context. Run from feature context or pass --feature <id>.` |
| `plan.md` missing | `plan.md not found. Run /speckit.plan first.` |
| `tasks.md` missing | `tasks.md not found. Run /speckit.plan first.` |
| No unchecked tasks | `All tasks are already complete. Nothing to execute.` |
| Plan review not approved | `Plan has no approved review. Run /speckit.peer.review plan first.` |
| Tasks review missing | `tasks-review.md not found. Run /speckit.peer.review tasks first.` |
| Tasks review not approved | `Tasks readiness is not approved. Run /speckit.peer.review tasks first.` |
| Missing peer config | `peer.yml not found. Create .specify/peer.yml.` |
| Invalid peer config version | `peer.yml version mismatch. Expected version: 1.` |
| Invalid provider-state version | `provider-state.json version unsupported. Backed up and reinitialized to version 1.` |
| Provider disabled | `Provider '<name>' is disabled in .specify/peer.yml.` |
| Unsupported provider mode | `Provider '<name>' must use mode: orchestrated.` |
| Provider adapter missing | `Provider '<name>' adapter is not implemented in v1.` |
| Codex script unavailable | `Codex skill not found or not executable.` |
| Batch tasks not checked | `Executor did not mark all dispatched tasks complete. Execution paused.` |
| Missing verdict marker | `Provider output missing Verdict. Error code-review round recorded as PARSE_FAILURE.` |
| Lock contention | `Could not acquire plan-review lock after 5 retries.` |
| State corruption | `provider-state.json is inconsistent with code review rounds (STATE_CORRUPTION).` |

---

## Invariants

- Orchestrator never writes implementation code.
- Executor is responsible for task checkbox transitions in `tasks.md`.
- Code review rounds are appended to `reviews/plan-review.md` using `## Code Review Round N — YYYY-MM-DD`.
- Code review and artifact review counters are independent in the shared file.
- Provider state is merged by key; execute workflow does not overwrite review workflow state.
- Adapter stdout contract remains strict two-line output; human logs never appear on stdout.
- Commands are explicit only; no mandatory auto-hooks.
