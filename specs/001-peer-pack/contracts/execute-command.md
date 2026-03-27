# Contract: `/speckit.peer.execute`

**Pack**: `peer`
**Command**: `execute`
**Version**: 1.0.0

---

## Invocation

```
/speckit.peer.execute [--provider <name>]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--provider <name>` | No | Override the `default_provider` in `.specify/peer.yml` |

### Examples

```bash
# Execute tasks using the default provider
/speckit.peer.execute

# Execute tasks using a specific provider
/speckit.peer.execute --provider codex
```

---

## Roles

`/speckit.peer.execute` uses a strict **two-role model**:

| Role | Responsibility |
|------|---------------|
| **Orchestrator** (Claude) | Reads plan and tasks; dispatches batches to executor; writes code review rounds; revises pending tasks based on review feedback; marks the overall workflow done. **Never writes implementation code.** |
| **Executor** (Codex or configured provider) | Implements each assigned batch; marks completed task checkboxes in `tasks.md`; responds to code review verdicts |

This separation is a hard invariant. The orchestrator must not implement any feature logic, even if it is trivial. If the executor is unavailable, the command halts.

---

## Preconditions

The following must be true before execution begins. Any failure halts the command with a clear, actionable error message — no partial writes.

1. **`plan.md` exists**: `specs/<featureId>/plan.md` must be present and non-empty.
2. **`tasks.md` exists**: `specs/<featureId>/tasks.md` must be present and contain at least one `- [ ]` task.
3. **`plan.md` has `APPROVED` plan review**: `specs/<featureId>/reviews/plan-review.md` must exist and contain a round with `Consensus Status: APPROVED` or `Consensus Status: MOSTLY_GOOD`. This enforces the Cross-Artifact Readiness Gate (P2).
4. **Peer config exists**: `.specify/peer.yml` must exist at the project root.
5. **Provider is enabled**: The resolved provider must have `enabled: true` in peer.yml.
6. **Provider adapter exists**: `shared/providers/<provider>/adapter-guide.md` must exist.
7. **Codex skill is installed** (if provider is `codex`): `~/.claude/skills/codex/scripts/ask_codex.sh` must exist and be executable.

---

## Execution Steps

1. **Resolve feature context**
   - Identify the current feature from the active Spec Kit branch
   - Derive paths: `specs/<featureId>/plan.md`, `specs/<featureId>/tasks.md`

2. **Readiness gate check**
   - Read `specs/<featureId>/reviews/plan-review.md`
   - Verify at least one round contains `Consensus Status: APPROVED` or `Consensus Status: MOSTLY_GOOD`
   - If no approved/mostly-good round exists, halt: _"Plan is not approved. Run /speckit.peer.review plan first."_

3. **Read configuration and load provider state**
   - Parse `.specify/peer.yml`, resolve provider
   - Read `provider-state.json` to retrieve `sessions[provider][execute].session_id` if present

4. **Load execution context**
   - Read full `plan.md`
   - Read full `tasks.md`
   - Identify all unchecked tasks (`- [ ]`) — these form the pending work queue

5. **Batch dispatch loop** (iterate until all tasks complete or a blocking error occurs):

   a. **Assign batch**: Select the next coherent batch of unchecked tasks from the pending queue. Batch size should be small enough to keep executor context focused (guidance: 1–5 tasks, or one logical phase).

   b. **Invoke executor**:
      - Construct prompt: provide plan context, the specific batch of tasks, and instruction to mark each completed task as `- [x]` in `tasks.md`
      - Invoke via adapter (for codex: `ask_codex.sh "<prompt>" --file tasks.md [--session <session_id>]`)
      - Retrieve `session_id` and `output_path`

   c. **Verify task checkbox updates**:
      - Re-read `tasks.md`
      - Confirm that all tasks in the dispatched batch are now `- [x]`
      - If any remain unchecked, ask executor to recheck before proceeding

   d. **Update provider state**: Upsert `sessions[provider][execute]` in `provider-state.json`

   e. **Continue** if unchecked tasks remain

6. **Code review round** (after all tasks are marked complete, or at a natural review checkpoint):

   a. **Determine code review round number**:
      - Read `specs/<featureId>/reviews/plan-review.md`
      - Count existing `## Code Review Round ` headings → `R = count + 1`

   b. **Invoke executor for code review**:
      - Prompt: review the full implementation produced in this batch for correctness, security, and alignment with `plan.md`
      - Use `--reasoning high` for Codex
      - Append `output_path` content to `plan-review.md`:
        ```
        ---

        ## Code Review Round R — YYYY-MM-DD

        <executor output>

        Verdict: NEEDS_FIX | APPROVED
        ```

   c. **Evaluate verdict**:
      - `NEEDS_FIX`: Dispatch identified issues back to executor; loop from step 5b for fix batch
      - `APPROVED`: Proceed to finish

7. **Completion report**
   - All tasks are `- [x]`
   - Display summary: feature id, total tasks completed, total code review rounds, review file path

---

## Outputs

| Output | Path | Description |
|--------|------|-------------|
| Updated tasks | `specs/<featureId>/tasks.md` | Checkboxes marked `[x]` by executor |
| Code review rounds | `specs/<featureId>/reviews/plan-review.md` | Code Review Round entries appended |
| Provider state | `specs/<featureId>/reviews/provider-state.json` | Updated `execute` session entry for resolved provider |
| Implementation | workspace files | Written by executor; orchestrator does not write code |

---

## Error Conditions

| Condition | Error Message |
|-----------|--------------|
| `plan.md` missing | `plan.md not found. Run /speckit.plan first.` |
| `tasks.md` missing | `tasks.md not found. Run /speckit.plan first.` |
| No unchecked tasks | `All tasks are already complete. Nothing to execute.` |
| Plan review not approved | `Plan has no approved review. Run /speckit.peer.review plan first.` |
| `.specify/peer.yml` missing | `peer.yml not found. Create .specify/peer.yml with default_provider and providers config. See quickstart.md.` |
| Provider disabled | `Provider '<name>' is disabled in .specify/peer.yml. Set enabled: true or choose a different provider.` |
| Provider not implemented | `Provider '<name>' has no adapter in shared/providers/<name>/. Only 'codex' is supported in v1.` |
| Codex skill not installed | `Codex skill not found at ~/.claude/skills/codex/scripts/ask_codex.sh. Install: https://skills.sh/oil-oil/codex/codex` |
| Executor returns no output | `Provider '<name>' returned no output for batch starting at task N. Execution paused. Retry with /speckit.peer.execute.` |

---

## Invariants

- The **orchestrator never writes implementation code** — this includes bash scripts, YAML manifests, Markdown templates, and any other deliverable outputs. Only the executor writes these.
- Code review rounds are appended to `plan-review.md` (not a separate file) to keep all plan-related review history colocated
- `tasks.md` checkbox updates are performed by the executor, not the orchestrator — the orchestrator verifies them
- Provider state is merged — running execute does not overwrite review session state
- The command does not auto-hook into `specify` commands; it is always invoked explicitly
