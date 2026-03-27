# Plan: Agent Prohibition + Invocation Gate + Concrete Template

Plug the inline-review loophole in both peer command files by adding an explicit orchestrator prohibition, a pre-Part-3 invocation gate, and a concrete terminal command template. Applies symmetrically to `review.md` and `execute.md`.

---

## Decisions
- Both files get all three fixes symmetrically.
- Prompt passed via temp file written with `mktemp` (not `$$`), cleaned up via `trap` on all exit paths.
- Gate uses STOP + ABORT RESPONSE: agent must not continue writing or append anything; start a new response reporting the error. (`DISCARD` was imprecise — tokens already streamed cannot be retracted, so the correct frame is "abort and do not proceed.")
- Gate must require concrete `session_id` + `output_path` from actual terminal stdout as falsifiable attestation.
- Failure-code mapping (canonical, authoritative):
  - `PROVIDER_UNAVAILABLE` → exit `1`: Adapter was not invoked via terminal, or gate preconditions not met.
  - `PARSE_FAILURE` → exit `8`: Adapter stdout did not conform to the two-line contract.
  All other failure classes reported via the above where closest match applies.
- Critical Constraint block is placed BOTH in the Role Model section (global awareness) AND immediately before the invocation step (point-of-failure enforcement).
- All artifact modes, including `tasks`, must pass Step 2.7 + Step 2.8 before Part 3.
- The batch execution path (E-2 / Step 2.3c) gets its own gate, not just the code-review path.
- Unified gate language across both files to prevent drift.

---

## Phase 1 — review.md (3 edits)

### Edit R-1: Add Role Model section
After `## Purpose`, before `## Part 1` (immediately after the `---` separator):

Insert a new `## Role Model` section modeled after execute.md's structure:

| Role | Actor | Responsibility |
|------|-------|----------------|
| **Orchestrator** | Claude | Resolve feature/config/state; assemble prompts; invoke provider adapter via terminal; parse output; append review rounds; persist state; report consensus. **Never generates review content.** |
| **Provider** | Codex (or configured provider) | Generate all review content and status markers. |

Followed immediately by a `> **CRITICAL CONSTRAINT**` blockquote:

> **CRITICAL CONSTRAINT**: You are the ORCHESTRATOR, not the REVIEWER.
>
> Do not emit any review feedback, critique, or consensus status in this response before the Adapter Invocation Gate passes.
> - You MUST invoke `ask_codex.sh` via terminal to obtain review content.
> - You MUST NOT write review feedback, critique, or consensus status yourself.
> - If the provider is unavailable, ABORT and report the error. Never fall back to generating review content inline.
>
> This boundary is invariant. If the provider is unavailable, the command halts.

### Edit R-2: Refactor Step 2.7 into substeps 2.7a/b/c/d
Replace the current abstract invocation block with four concrete substeps:

**Step 2.7a — Write prompt to temp file** (via terminal):
```bash
PROMPT_FILE="$(mktemp /tmp/peer-review-prompt.XXXXXX)"
trap 'rm -f "$PROMPT_FILE"' EXIT INT TERM
cat > "$PROMPT_FILE" << 'PEER_PROMPT_EOF'
<assembled prompt from Step 2.6>
PEER_PROMPT_EOF
```
Using `mktemp` (not `$$`) ensures an unguessable filename with restricted permissions. The `trap` ensures cleanup on all exit paths, including failures and interrupts.

> **ARG_MAX constraint**: Passing `"$(cat "$PROMPT_FILE")"` as the first argument to `ask_codex.sh` is limited by the OS `ARG_MAX` (typically 2MB). For the current artifact sizes (≤ 50KB per `max_artifact_size_kb`), this is safe. If a future adapter revision adds a `--prompt-file` flag, prefer that. Until then, this pattern is correct within v1 constraints.

**Step 2.7b — Hard gate reminder** (inline, at point-of-invocation):
```
> ⚠️ ORCHESTRATOR GATE: Do not proceed past this point unless you are about to
> execute the terminal command below. Do not generate review content here.
```

**Step 2.7c — Invoke adapter via terminal**:
```bash
"$codex_script_path" \
  "$(cat "$PROMPT_FILE")" \
  --file "specs/<featureId>/<artifact>.md" \
  --reasoning high
  # Include: --session "<session_id>"  only when valid session_id exists (Step 2.2)
```
Use `$codex_script_path` resolved in Step 1.5 (not hardcoded default path). Cleanup is handled by the `trap` installed in Step 2.7a.

> **Single-session requirement (Steps 2.7a–d)**: Steps 2.7a through 2.7d share shell state (`PROMPT_FILE` variable, `trap` handler). They MUST be issued as one chained shell invocation block (e.g., joined with `&&` or as a single script), NOT as separate terminal calls. If split, `PROMPT_FILE` is undefined in later steps and `trap` may delete the file prematurely.

**Step 2.7d — Parse strict stdout contract**: Capture stdout and parse exactly two lines:
- Line 1: `session_id=<value>`  
- Line 2: `output_path=<path>`

Any deviation (extra lines, missing lines, wrong format, blank line, trailing whitespace) is a `PARSE_FAILURE` (exit `8`). Parsing rules: exact prefix match `session_id=` / `output_path=`, no surrounding whitespace, value is the remainder of the line. Record parsed `session_id` and `output_path`.

> **Bug note from original suggestion**: `"$(cat /tmp/peer-review-prompt-$$).txt"` misplaces `.txt` outside the subshell. Correct form: `"$(cat /tmp/peer-review-prompt-$$.txt)"`. This plan supersedes that with `mktemp`.

### Edit R-3: Add Step 2.8 — Adapter Invocation Gate
Insert between Step 2.7 and Part 3. This gate applies to **all artifact types, including `tasks`**:

```markdown
### Step 2.8 — Adapter Invocation Gate

This gate applies to ALL artifact types, including `tasks`.

Before proceeding to Part 3, all of the following must be true:

1. `ask_codex.sh` was executed via a terminal invocation — the shell command ran; you did not reason around it or simulate its output.
2. You have the actual `session_id=` and `output_path=` values from terminal stdout — not reconstructed, assumed, or carried over from a previous round. These values are your falsifiable attestation.
3. The file at the resolved `output_path` exists and is non-empty.
4. The `output_path` file's mtime is ≥ the timestamp when Step 2.7c began, and neither `session_id` nor `output_path` has been carried over from a previous round.

**If any check fails**:
- **ABORT the current response immediately.** Do NOT write or append any review content. Do NOT proceed to any step in Part 3.
- Emit only this error line and stop — do not emit any additional content:
  `[peer/review] ERROR: PROVIDER_UNAVAILABLE: adapter was not invoked via terminal or output attestation is missing/stale`
  → exit `1`

> _[Operator context — not runtime output]:_ Set `PEER_DEBUG=1` to surface full adapter stderr. Resolve the underlying cause (e.g., missing codex skill, wrong `CODEX_SKILL_PATH`) before retrying.
```

> **On ABORT vs DISCARD**: Tokens already emitted in a streaming response cannot be retracted. The correct instruction is: do not emit substantive review content before the gate check. Step 2.8 fires only after Step 2.7 — so by the gate point, the agent has not yet written the review body. Gate failure at Step 2.8 is terminal: Part 3 is not entered.

---

## Phase 2 — execute.md (5 edits)

### Edit E-1: Strengthen Role Model section

Two changes to the existing Role Model table + blockquote:

- Orchestrator responsibility cell: append "**or code review verdicts**."
- Replace existing constraint text with unified CRITICAL CONSTRAINT blockquote (same normative language as review.md, tailored for execute):

> **CRITICAL CONSTRAINT**: You are the ORCHESTRATOR, not the IMPLEMENTER or REVIEWER.
>
> Do not emit any implementation code, fix code, or code-review verdicts in this response before the Adapter Invocation Gate passes.
> - You MUST invoke `ask_codex.sh` via terminal for all implementation batches AND all code-review rounds.
> - You MUST NOT write implementation code, fix code, or code review verdicts yourself.
> - If the provider is unavailable, ABORT and report the error. Never fall back to inline execution or review.
>
> This boundary is invariant. If the executor is unavailable, the command halts.

### Edit E-2: Refactor Step 2.3c (batch execution invocation)
Replace the abstract bash snippet in Step 2.3c with four concrete substeps (matching review.md pattern exactly — issue #5 fix):

- **Step 2.3.1** — Write execution prompt to temp file:
  ```bash
  EXEC_PROMPT_FILE="$(mktemp /tmp/peer-exec-prompt.XXXXXX)"
  trap 'rm -f "$EXEC_PROMPT_FILE"' EXIT INT TERM
  cat > "$EXEC_PROMPT_FILE" << 'EXEC_PROMPT_EOF'
  <assembled prompt from Step 2.3b>
  EXEC_PROMPT_EOF
  ```
- **Step 2.3.2** — Hard gate reminder (inline, point-of-invocation): same `⚠️ ORCHESTRATOR GATE` warning block as review.md Step 2.7b.
- **Step 2.3.3** — Invoke adapter via terminal with `--file "$tasks_path"`
- **Step 2.3.4** — Parse strict stdout contract (same parsing rules as review.md Step 2.7d)

> **Single-session requirement (Steps 2.3.1–2.3.4)**: Steps 2.3.1 through 2.3.4 share shell state (`EXEC_PROMPT_FILE` variable, `trap` handler). They MUST be issued as one chained shell invocation block, NOT as separate terminal calls.

Add **Adapter Invocation Gate** immediately after Step 2.3.4, before Step 2.3d (task checkbox verification):

```markdown
**Adapter Invocation Gate — Batch Execution** (before verifying checkboxes):
1. `ask_codex.sh` was executed via terminal for this batch.
2. Actual `session_id=` and `output_path=` were captured from terminal stdout.
3. File at `output_path` exists and is non-empty.
4. The `output_path` file's mtime is ≥ invocation start; neither `session_id` nor `output_path` has been carried over from a previous batch.
If any check fails: ABORT. Emit only the error line below and stop — do not emit any additional content: `[peer/execute] ERROR: PROVIDER_UNAVAILABLE: execution adapter was not invoked via terminal` → exit `1`.
```

### Edit E-3: Refactor Step 2.4 code-review invocation
Replace abstract invocation in Step 2.4 with four concrete substeps:

- **Step 2.4.1** — Write code-review prompt to temp file (`mktemp`, `trap`)
- **Step 2.4.2** — Hard gate reminder  
- **Step 2.4.3** — Invoke adapter via terminal with `--file "$tasks_path"`
- **Step 2.4.4** — Parse strict stdout contract (same rules as Step 2.7d)

> **Single-session requirement (Steps 2.4.1–2.4.4)**: Steps 2.4.1 through 2.4.4 share shell state. They MUST be issued as one chained shell invocation block, NOT as separate terminal calls.

### Edit E-4: Add Adapter Invocation Gate inside Step 2.4
Insert immediately after Step 2.4.4, before "Parse verdict from last 5 lines":

```markdown
**Adapter Invocation Gate — Code Review** (before parsing verdict or acquiring lock):
1. `ask_codex.sh` was executed via terminal for this code-review round.
2. Actual `session_id=` and `output_path=` were captured from terminal stdout.
3. File at `output_path` exists and is non-empty.
4. The `output_path` file's mtime is ≥ invocation start; neither `session_id` nor `output_path` has been carried over from a previous round.
If any check fails: ABORT. Emit only the error line below and stop — do not append a round or advance the loop:
`[peer/execute] ERROR: PROVIDER_UNAVAILABLE: code-review adapter was not invoked via terminal` → exit `1`.
```

### Edit E-5: Update E-1 constraint language
Replace `DISCARD` with `ABORT` throughout execute.md to match the revised gate semantics (issue #6 fix).

---

## Revised Verification Checklist

1. CRITICAL CONSTRAINT block appears in **both** the Role Model section AND immediately before the invocation step (Step 2.7b / Step 2.3.2 / Step 2.4.2) in both files.
2. All invocation sections use `mktemp` (not `$$`) with `trap` cleanup.
3. Both files use normalized substep numbering: `2.7a/b/c/d` for review.md; `2.3.1/2.3.2/2.3.3/2.3.4` and `2.4.1/2.4.2/2.4.3/2.4.4` for execute.md.
4. Gate text is present in **two hard gate blocks** in execute.md: after E-2 batch invocation AND after E-4 code-review invocation. The CRITICAL CONSTRAINT in the Role Model (E-1) is a separate prohibition block. Gate text is present in **one hard gate block** in review.md: Step 2.8.
5. Gate invocation failures (adapter not called via terminal, preconditions unmet) report ABORT + exit `1` (`PROVIDER_UNAVAILABLE`). Stdout parse failures (malformed two-line contract) report exit `8` (`PARSE_FAILURE`). Both trigger ABORT; no Part 3 progression on either.
6. Step 2.8 (review.md) contains explicit note: "This gate applies to ALL artifact types, including `tasks`."
7. Verify no invocation block in either command file passes a placeholder literal as the first argument to the script path variable. Run `grep -rE '(ask_codex\.sh|"\$codex_script_path")\s+"<'` across the command files — zero matches expected outside `## Relevant files` or comment sections. This covers both legacy `ask_codex.sh "<prompt>"` and updated `"$codex_script_path" "<assembled..."` variants.
8. Run `scripts/validate-pack.sh` to confirm the pack still passes structural linting.

---

## Relevant files
- `packs/peer/commands/review.md` — edits R-1, R-2, R-3
- `packs/peer/commands/execute.md` — edits E-1, E-2, E-3, E-4, E-5
- **`--prompt-file` adapter contract change** (Issue #2 from review): Passing the prompt as `$(cat file)` via argv hits ARG_MAX at ~2MB. For v1 artifact sizes (≤50KB), this is safe. A `--prompt-file` flag in the adapter contract is the right long-term fix but is a separate contract change beyond this plan's scope.
- **Stdout contract canonical definition** (Issue #12): Parsing rules are defined in `shared/providers/codex/adapter-guide.md`. This plan references "same parsing rules as adapter-guide.md" for each substep. A normative inline copy of those rules in the command files would reduce docs drift but is a consistency concern for a separate pass.

## Further Considerations
1. **adapter-guide.md** could get an "Orchestrator must invoke via terminal tool" note, but this is low priority since command files are the agent's primary instruction source at runtime.
2. **`PEER_DEBUG=1`** is referenced in gate error guidance as a diagnostic hint for surfacing full adapter stderr output.

