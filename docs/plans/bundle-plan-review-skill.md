# Plan: Bundle plan-review Skill into spec-kit

Make the peer pack self-contained by inlining the external `/plan-review` skill as `shared/skills/plan-review.md`, replacing the Step 1.1a delegation with an internal workflow reference.

---

## Context

`packs/peer/commands/review.md` Step 1.1a currently delegates file-mode reviews to the external `/plan-review` skill (`~/.claude/skills/plan-review/SKILL.md`). This creates a runtime dependency: the kit only works for file-mode review if the user has that skill installed separately.

The goal is to clone and adapt the skill into `shared/skills/plan-review.md` so the peer pack is fully self-contained, and update Step 1.1a to reference the internal copy.

**User-Facing Effect**: After this change, running `/speckit.peer.review <path>` (file mode) causes the peer pack command to route to the bundled `plan-review` skill. Directly invoking the skill as `/plan-review <path>` also works once the pack is loaded. In both cases the skill executes without requiring an external installation. The user experiences an iterative adversarial review loop: the configured provider critiques the plan, Claude evaluates and applies valid findings to the plan file, and rounds repeat until the provider reaches `MOSTLY_GOOD` or `APPROVED`. All review rounds are appended to a `reviews/` file adjacent to the plan.

Command syntax: `/speckit.peer.review <plan-file> [--provider <name>]` (primary) or `/plan-review <plan-file> [--provider <name>]` (direct, once pack is loaded).

_Routing note_: `/speckit.peer.review` is the peer pack command defined in `commands/review.md`; `plan-review` is the skill registered in `extension.yml`. The command invokes the skill — they are not the same thing.

---

## Decisions

### D1 — Provider invocation mechanism
Keep `/{provider}` skill dispatch (not `ask_codex.sh` terminal path).  
Rationale: file-mode is exempt from the Adapter Invocation Gate (artifact mode only); using skill dispatch keeps file-mode lightweight and consistent with the original plan-review behavior.

### D2 — Provider argument syntax
Support **both** invocation styles:
- Flag syntax: `--provider <name>` (preferred, matches peer.review convention)
- Positional syntax: `/{provider} <file>` (legacy, matches original plan-review)

Resolution order: `--provider` flag → positional prefix → default `codex`.  
Step 1.1a must forward `--provider` if supplied; ignore `--feature`.

Concrete examples (flag wins when both are present):
- `/codex plans/foo.md` → provider=codex, file=plans/foo.md
- `plans/foo.md --provider opencode` → provider=opencode, file=plans/foo.md
- `/codex plans/foo.md --provider opencode` → provider=opencode (flag wins), file=plans/foo.md
- `plans/foo.md` (no prefix, no flag) → provider=codex (default), file=plans/foo.md
- `/codex plans/foo.md --provider opencode --session abc123` → provider=opencode, file=plans/foo.md, session=abc123 (`--session` is optional; only used when continuing a prior round)

### D3 — Findings minimum
**5** (adopt peer.review artifact-mode standard, not plan-review's 10).

Enforcement: if the provider returns fewer than 5 findings, treat the response as `PROVIDER_EMPTY_RESPONSE` (exit `3`) and do not revise the plan. The caller should surface this error and halt.

### D3a — Findings prioritization and breadth
The review must prioritize the highest-severity, highest-impact issues first, and should surface as many well-supported issues as possible in a single round.

Quality is the controlling constraint: the reviewer should expand beyond the 5-issue minimum only when each additional issue is concrete, non-duplicative, and actionable. Do **not** pad the review with weak or speculative findings just to increase count.

### D4 — Review format
Keep both **Rating X/10** and **Positive Aspects** sections from plan-review.  
Rationale: file-mode reviews cover arbitrary plan files where qualitative richness matters; these sections are absent from artifact-mode format but appropriate here.

### D5 — BLOCKED status
Add `BLOCKED` to the consensus table.  
Halt immediately, do not revise plan, do not start another round. Human resolution required.

### D6 — Review file path convention
Keep plan-review convention: `reviews/{input-filename-without-.md}-review.md` in a `reviews/` directory **at the same level as the input file**.  
Rationale: the plan may not belong to a spec feature, so `specs/<featureId>/reviews/` does not apply.  
Examples:
- `plans/auth-refactor.md` → `plans/reviews/auth-refactor-review.md`
- `docs/my-plan.md` → `docs/reviews/my-plan-review.md`

### D7 — State persistence
No `provider-state.json` in file mode (matches existing Step 1.1a constraint and original plan-review behavior). Lightweight session_id tracking only — extract from provider stdout using reserved marker `[plan-review] session_id=<id>`, validate against `^[A-Za-z0-9._:-]{1,128}$`, pass `--session "<id>"` (shell-quoted) in subsequent rounds.

### D8 — Exit codes
Map file-mode errors to peer's canonical exit code table:
- `VALIDATION_ERROR` → exit `5` (file not found, empty, unresolvable path, or plan file write failure; also: shadow-backup creation or move failure before invocation, shadow-restore failure, shadow backup missing/unreadable at restore time, plan hash mismatch after validation, evidence line absent from stdout)
- `PROVIDER_UNAVAILABLE` → exit `1` (provider skill not found)
- `PROVIDER_TIMEOUT` → exit `2`
- `PROVIDER_EMPTY_RESPONSE` → exit `3` (includes fewer than D3-minimum findings)
- `PARSE_FAILURE` → exit `8` (any Step 4 D3 structural gate violation: (a) round heading number ≠ prior_count + 1; (b) fewer than 5 valid issue blocks [non-fenced/non-quoted, each with `**Location**:` and `**Suggestion**:`]; (c) count of valid `**Consensus Status**:` lines ≠ exactly one; (d) `### Previous Round Tracking` with at least one row absent for rounds 2+; also: latest-round consensus pattern mismatch against `^\*\*Consensus Status\*\*: (NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)\s*$`)
- `BLOCKED` → exit `9` (reviewer halted workflow; human resolution required before re-invoking; also: operator-imposed external round-limit exhausted)

Exit codes 4, 6, and 7 are not used by file mode. They are reserved for artifact-mode operations that file mode bypasses (state file corruption, feature resolution failure, and adapter gate failure respectively).

---

## Files to Change

| File | Change |
|------|--------|
| `shared/skills/plan-review.md` | **Create** — adapted plan-review skill with all decisions applied |
| `packs/peer/commands/review.md` | **Update** Step 1.1a — reference internal skill, forward `--provider` |
| `packs/peer/extension.yml` | **Update** — declare `plan-review` under `provides.skills` |

---

## Implementation Steps

### Step 1 — Create `shared/skills/plan-review.md`

If `shared/skills/plan-review.md` already exists, overwrite it (this step is idempotent by design). **If the file pre-exists and is untracked by git (not in HEAD), take a content snapshot before overwriting so rollback in Step 4 can restore the prior state.**

Create the file with the following sections in order:

**Frontmatter**
```yaml
---
name: plan-review
description: "Adversarial iterative review of any plan file with `/{provider}` skill dispatch, independent of spec feature context."
---
```

**Purpose** — 6-step loop summary (Steps 1–6) with BLOCKED in the consensus table.

**Usage** — both invocation styles, provider resolution order (flag wins over positional over default), flag-wins resolution with concrete examples from D2, session_id extraction fallback behavior, and the distinction between the `/speckit.peer.review` command and the `/plan-review` skill.

**Session Reuse** — after each provider invocation, scan **only the current invocation's stdout stream** (not prior output, quoted logs, or history) for lines matching `[plan-review] session_id=<value>` (exact format: `[plan-review] session_id=xxx`, no spaces around `=`, value on its own line; this reserved marker prevents spoofing via echoed transcript content). Require **exactly one** such line; if count is 0 or >1, disable session reuse for that invocation and emit `[plan-review] WARN: session_id extraction skipped (found {count} markers)`. If exactly one is found, validate the value against `^[A-Za-z0-9._:-]{1,128}$`; reject non-matching values silently. If found and valid, pass `--session "<id>"` (shell-quoted) in subsequent rounds so the provider retains prior review history. Do not halt on extraction failure.

**Workflow**:

**Note on Appendix A**: The full authoritative workflow specification is in **Appendix A**. The workflow bullets below (Steps 1–6) are a summary for orientation. In case of any discrepancy between this summary and Appendix A, **Appendix A takes precedence**.

- **Step 1 — Resolve input file**: Resolve `plan-file-path` to an absolute path. If the file does not exist or is empty, emit `[plan-review] ERROR: VALIDATION_ERROR: <reason>` and exit `5`.

- **Step 2 — Derive review file path**: Apply D6 convention. Run `mkdir -p <reviews-dir>` before writing; if `mkdir -p` fails, emit `[plan-review] ERROR: VALIDATION_ERROR: cannot create reviews directory: <reviews-dir>` and exit `5`. If the review file already exists, this is not the first round; instruct the provider to track prior issue resolution status.

- **Step 3 — Invoke provider**: Resolve the provider using D2 resolution order: `--provider <name>` flag → positional prefix from initial invocation → default `codex`. Then dispatch using `/{provider}` skill (e.g., `/codex` or `/opencode`). The invoking context must resolve the provider name before dispatching; the skill workflow itself does not re-parse arguments. Pass the following prompt verbatim, substituting `{plan-file-path}`, `{review-file-path}`, and `{provider}`:

  ```
  Read the contents of {plan-file-path} and review it critically as an independent third-party reviewer.

  Requirements:
  - Raise at least 5 concrete and actionable improvement points
  - Prioritize the highest-severity / highest-impact issues first, and include as many additional well-supported issues as you can find in this round without sacrificing specificity or confidence
  - Each issue must include: issue description + exact location/reference in the plan + improvement suggestion
  - Use severity levels: Critical > High > Medium > Low > Suggestion
  - If {review-file-path} already exists, read it first and track the resolution status of previous issues in the new round

  Analysis dimensions (apply relevant ones based on the plan type):
  - Architectural soundness: overdesign vs underdesign, module boundaries, single responsibility
  - Technology choices: rationale, alternatives, compatibility with the existing project stack
  - Completeness: missing scenarios, overlooked edge cases, dependency and impact scope
  - Feasibility: implementation complexity, performance risks, migration and compatibility concerns
  - Engineering quality: whether steps are precise enough to execute unambiguously
  - Security: authentication, authorization, data validation when relevant

  Append the current review round to {review-file-path}, creating the file if it does not exist.
  When creating for the first time, prepend this header before the first `---`:

  # Plan Review: {plan title}

  **Plan File**: {plan-file-path}
  **Reviewer**: {provider}

  Separate rounds with `---` and append new rounds at the end. Use this format:

  ## Round {N} — {YYYY-MM-DD}

  ### Overall Assessment
  {2-3 sentence overall assessment}
  **Rating**: {X}/10

  ### Previous Round Tracking (rounds 2+ only)
  | # | Issue | Status | Notes |
  |---|-------|--------|-------|

  ### Issues
  #### Issue 1 ({severity}): {title}
  **Location**: {location in the plan}
  {issue description}
  **Suggestion**: {improvement suggestion}
  ... (minimum 5 issues)

  ### Positive Aspects
  - ...

  ### Summary
  {Top 3 key issues}
  **Consensus Status**: NEEDS_REVISION / MOSTLY_GOOD / APPROVED / BLOCKED

  Key principle: be a critical reviewer, not a yes-man. Prioritize the most important issues first and include as many high-quality findings as you can support in one pass, but never trade specificity, evidence, or actionability for raw count.
  ```

  If the provider returns fewer than 5 findings, **do not append the round to the review file** (or remove the partial append if it already occurred); then exit `3` (`PROVIDER_EMPTY_RESPONSE`); do not revise the plan.

  **Provider file-write fallback**: the prompt instructs the provider to append directly to `{review-file-path}`. Before invoking the provider, record the pre-invocation byte size, last round count, and a sha256 hash of the pre-invocation file content (or note it does not yet exist). After the provider returns, check whether **all three** of the following are true: (a) byte size increased, (b) **exactly one** new `^## Round [0-9]+ — ` heading (with number N = prior_round_count + 1) is present in the appended delta (on non-fenced, non-quoted lines), AND (c) sha256 of pre-invocation content matches the first N bytes of the post-invocation file (N = pre-invocation byte size). **If predicate (c) is false (tamper detected)**, quarantine all appended bytes (all bytes since pre-invocation EOF) using the quarantine convention (see D8), emit `[plan-review] VALIDATION_ERROR: preexisting content tampered`, and exit `5` immediately — no fallback, no Step 4 parse, no plan edits. Fallback triggers only if **at least one** of predicates (a) or (b) is false (and (c) passed). If fallback is triggered, capture the provider's stdout and validate it passes the round-shape minima before appending to the review file: must contain **exactly one** `^## Round [0-9]+ — ` heading with round number N = prior_round_count + 1 (reject stdout containing multiple round headings or replayed old round blocks), at least 5 `#### Issue` entries, and a valid `**Consensus Status**:` line. If stdout is also empty or fails the structural gate, treat as `PROVIDER_EMPTY_RESPONSE` and exit `3`. Do not append stdout if both predicates are already satisfied (to prevent double-appending).

- **Step 4 — Read review, evaluate findings, revise plan**: Before parsing consensus, apply a mandatory D3 structural gate on the latest round: (a) validate the latest round heading number equals prior_round_count + 1 (if not, emit PARSE_FAILURE and exit `8`); (b) require at least 5 `#### Issue` entries on non-fenced, non-quoted lines where each counted issue block contains both `**Location**:` and `**Suggestion**:` fields; (c) require **exactly one** valid `**Consensus Status**:` line in the latest round segment (count ≠ 1 → PARSE_FAILURE exit `8`); (d) for rounds where prior_round_count ≥ 1, require `### Previous Round Tracking` with at least one table row containing a numeric issue ID, a non-empty status from the allowed set (Resolved/Rejected/Carried over/In progress), and a non-empty notes field referencing a prior issue outcome (if absent or malformed, emit PARSE_FAILURE exit `8`). This gate applies after every provider invocation, regardless of whether fallback triggered. If gate clause (b) fails, treat as `PROVIDER_EMPTY_RESPONSE` and exit `3`. On post-invocation structural/parse failure, remove or quarantine **all content appended since pre-invocation EOF** (not just the syntactic latest round) before exiting, to prevent partial or multi-round injections from persisting. Then parse the latest round using D8's latest-round extraction rules (last non-fenced/non-quoted `^## Round [0-9]+ — ` heading through EOF). **If latest-round consensus parsing fails (no `Consensus Status` match found), emit `[plan-review] PARSE_FAILURE` and exit `8` before evaluating or editing anything.** **If the consensus status is `BLOCKED`, skip all plan edits and exit `9` immediately.** Otherwise, evaluate issues in descending severity / impact order, starting with Critical and High findings. Adopt valid suggestions and revise the plan file directly. If rejecting a suggestion, note the reason briefly in the plan (rationale: rejection notes are intentional in-plan metadata, keeping design decisions and their resolutions co-located for future readers). Do not create a new file. If the plan file cannot be written to (e.g., disk full, permission error), emit `[plan-review] ERROR: VALIDATION_ERROR: cannot write to plan file: <plan-path>` and exit `5`.

- **Step 5 — Consensus dispatch**:

  | Status | Action |
  |--------|--------|
  | `NEEDS_REVISION` | Revise plan, then invoke provider again (back to Step 3) |
  | `MOSTLY_GOOD` | Revise plan, then ask the user interactively: "The reviewer rates this mostly good. Run one more round?" If yes, do not exit; return to Step 3 and continue the loop (final exit code emitted only at Step 6 or an error path). If no, proceed to Step 6. In non-interactive contexts (no TTY or user available), default behavior is to stop and proceed to Step 6 without additional rounds. |
  | `APPROVED` | Report completion; plan is ready for implementation |
  | `BLOCKED` | Halt immediately. Do not revise plan. Do not invoke provider again. Human resolution required. Exit `9`. |

  **Loop guard**: there is no hard round cap by default (the human operator drives termination). If operating in a fully automated context, callers should impose an external round limit. If the loop exceeds any externally imposed limit, emit `[plan-review] HALT: round limit exhausted` and halt with exit `9` (same code as `BLOCKED`; downstream automations may distinguish the two causes via the emitted diagnostic line).

- **Step 6 — Wrap-up report**: Report to user: rounds completed, major areas improved, final plan file path, review log file path. Then exit `0`.

**File Convention summary** — reference D6.

**Exit Codes table** — reference D8.

### Step 2 — Update `packs/peer/commands/review.md` Step 1.1a

Replace:
> Invoke `/plan-review <input_file>` and delegate the entire request to that skill.

With:
> Load `shared/skills/plan-review.md` as an instruction document. Bind `plan-file-path` to the resolved absolute value of `input_file`. If `--provider <name>` was supplied, bind `provider` to `<name>`; otherwise leave `provider` unset so the skill applies its default (`codex`). Execute the skill workflow with these bindings in scope.

_Invocation mechanics_: in this pack, "executing a skill" means loading the skill's markdown as an instruction context for the AI orchestrator (Claude), with the named variables available as substitution targets. This is not a subprocess or shell call. If `shared/skills/plan-review.md` cannot be found at load time, emit `[plan-review] ERROR: PROVIDER_UNAVAILABLE: shared/skills/plan-review.md not found` and exit `1`.

Remove the "Ignore `--provider`" bullet; replace with "forward `--provider` if supplied; ignore `--feature`".  
Update the failure line: "If the plan-review skill fails (non-zero exit), surface that failure unchanged and halt."

_Step 1.1a after the change_ consists solely of the replacement block above plus the two updated bullets. All other content in Step 1.1a (the constraint bullets that apply to file mode: do not load `.specify/peer.yml`, do not resolve `featureId`, etc.) is carried over unchanged.

### Step 3 — Update `packs/peer/extension.yml`

Add under `provides`:
```yaml
  skills:
    - name: plan-review
      file: ../../shared/skills/plan-review.md
      description: "Adversarial iterative review of any plan file, independent of spec feature context"
```

Note: `file` is relative to the `extension.yml` location (`packs/peer/`), not the working directory. Document this assumption in a comment above the entry.

### Step 4 — Verify the bundle

After all three file changes are in place, validate the bundle is self-contained. **Before modifying any file in Steps 1–3, take a content snapshot of every file to be modified** (both tracked and untracked), so rollback can restore from snapshots rather than from `git HEAD`. If a target file does not exist yet, record that fact so rollback knows to delete rather than restore.

**Global failure handler**: if any step (1–4) produces a non-zero exit after the first file write has occurred, trigger the rollback described at the end of this section before propagating the exit. This ensures partial-write states are never left behind.

1. Confirm that `shared/skills/plan-review.md` exists and is loadable. To verify the bundle eliminates the external dependency non-destructively, check whether `~/.claude/skills/plan-review/SKILL.md` exists: if it does, compute a unique backup path (`SKILLBAK=$(mktemp ~/.claude/skills/plan-review/SKILL.md.bak.XXXXXX)`), then move the file (`mv ~/.claude/skills/plan-review/SKILL.md $SKILLBAK`). **If backup creation or the move fails, emit `VALIDATION_ERROR` and exit `5` before invoking the workflow.** Register a cleanup handler (trap/finally) that restores from `$SKILLBAK` unconditionally on exit; if it does not exist (clean machine / CI), skip the shadow step and validate via the evidence contract only. Register a separate unconditional cleanup handler (trap/finally) to delete `$TMPPLAN` and `$TMPREVIEW` on both success and failure paths — this handler must never delete any artifact that pre-existed validation. **Compose both handlers into a single EXIT trap function** (ordered: (1) SKILL restore, (2) temp artifact cleanup) to prevent shell trap replacement from silently dropping one handler. Use `mktemp` (or equivalent) to generate a unique temp path for the plan copy (e.g., `TMPPLAN=$(mktemp /tmp/plan-review-validate-XXXXXX.md)`), copy the plan file there, and invoke the workflow against the copy: `/speckit.peer.review $TMPPLAN`. Derive the expected review file path from the temp basename using D6 convention (`TMPREVIEW=$(dirname $TMPPLAN)/reviews/$(basename $TMPPLAN .md)-review.md`). Record the sha256 content hash of the original plan before invoking (byte-size MAY be used as a fast-fail pre-check, but hash is the normative integrity check). The mandatory evidence of success is that the skill emits `[plan-review] loaded skill from: shared/skills/plan-review.md` to stdout during execution. **Fail validation with exit `5` (VALIDATION_ERROR) if**: (a) the shadow file cannot be restored, (b) shadow mode was entered and `$SKILLBAK` is missing or unreadable at restore time (external deletion race), (c) the original plan hash has changed after validation (plan was modified), or (d) the evidence line is absent from stdout.
2. Confirm a review file is created at the path derived from the temp basename using D6 convention (i.e., at `$TMPREVIEW` computed in item 1 above).
3. Confirm the review file at `$TMPREVIEW` contains at least 5 `#### Issue` entries and a valid `**Consensus Status**:` line **in the latest round segment** (apply D8 parser rules: latest-round segment = from the last non-fenced/non-quoted `^## Round [0-9]+ — ` heading to EOF).
4. After successful validation, clean up only artifacts created by validation: record whether `$(dirname $TMPREVIEW)` existed before invocation (pre-run existence flag). Delete the temp plan copy (`$TMPPLAN`) and its derived review file (`$TMPREVIEW`). Remove `$(dirname $TMPREVIEW)` only if: (a) it was absent pre-run, AND (b) it is empty after deleting `$TMPREVIEW`. Pre-existing artifacts are never deleted.

If validation fails (or at any point after the first file write), rollback all changes by restoring from the pre-step snapshots taken before execution: for each modified file, restore content from its snapshot; if a file was newly created (no pre-existing snapshot), delete it. Do not use `git checkout HEAD` for rollback — this would clobber any uncommitted changes the user already had. This preserves all other uncommitted work. **Rollback failure semantics**: if any individual restore/delete step fails, continue best-effort rollback on remaining artifacts, emit a `[plan-review] ROLLBACK_INCOMPLETE: <path>: <reason>` diagnostic for each failure, and terminate with `VALIDATION_ERROR` (exit `5`) at the end to signal partial state.

---

## Invariants (carried over from review.md, scoped to file mode)

- File-mode never touches `provider-state.json`
- File-mode never reads `.specify/peer.yml`
- File-mode never reads or writes `specs/<featureId>/reviews/`
- Review file is append-only within a session; no prior round is ever modified
- BLOCKED halts immediately without plan revision

Re-running after BLOCKED: if the user manually resolves the blocking issue and re-invokes, the new run appends round N+1 to the same review file (continuing the thread). The existing rounds are preserved untouched.

---

## Appendix A — `shared/skills/plan-review.md` (Complete Skill File)

The following is the verbatim content to write to `shared/skills/plan-review.md`. This is what Step 1 must produce exactly:

````markdown
---
name: plan-review
description: "Adversarial iterative review of any plan file with `/{provider}` skill dispatch, independent of spec feature context."
---

# Plan Review Skill

## Purpose

When invoked with a `plan-file-path`, start the adversarial plan iteration workflow:
1. Ask the configured provider to perform a critical review of the specified plan.
2. Read the review and evaluate whether its suggestions are sound.
3. Revise the plan based on valid suggestions and write changes back to the original plan file.
4. If review status is `NEEDS_REVISION`, ask the provider to review again automatically.
5. Repeat until consensus is `MOSTLY_GOOD` or `APPROVED` (or `BLOCKED` halts the loop).
6. Report review rounds, areas improved, and final file paths to the user.

## Usage

Primary entry point (via peer pack command):
```
/speckit.peer.review plans/my-feature-plan.md           # routes to this skill; provider=default
/speckit.peer.review plans/my-feature-plan.md --provider opencode
```

Direct provider dispatch invocation:
```
/codex plans/my-feature-plan.md                         # provider=codex
/opencode plans/my-feature-plan.md                      # provider=opencode
/codex plans/my-feature-plan.md --provider opencode     # provider=opencode (flag wins)
```

Direct `/plan-review` skill invocation:
```
/plan-review plans/my-feature-plan.md                   # provider=default (codex)
/plan-review plans/my-feature-plan.md --provider opencode
/plan-review plans/my-feature-plan.md --provider opencode --session abc123  # continuation round
```
_Note: `--session` is optional and only used when continuing a prior round._

**Invocation binding contract:** When invoked via `/speckit.peer.review`, argument binding is performed by the peer pack's `review.md` command (see Step 1.1a). When invoked directly as `/plan-review <plan-file> [--provider <name>] [--session <id>]`, the skill itself parses and binds `plan-file-path`, `provider`, and `session_id` from the command arguments before executing the workflow.

This skill is normally invoked via `/{provider} <plan-file>` dispatch (D1). Use `--provider <name>` flag to override the dispatched provider.

Provider resolution order:
1. `--provider <name>` flag (wins over all)
2. Positional prefix (`/{provider} <file>`) — _only when the command token is not `/plan-review`; when invoked as `/plan-review`, skip positional prefix and apply only flag and default_
3. Default: `codex`

Examples:
- `/codex plans/foo.md` → provider=codex, file=plans/foo.md
- `plans/foo.md --provider opencode` → provider=opencode, file=plans/foo.md
- `/codex plans/foo.md --provider opencode` → provider=opencode (flag wins), file=plans/foo.md
- `plans/foo.md` (no prefix, no flag) → provider=codex (default), file=plans/foo.md
- `/codex 'my plans/foo bar.md'` → provider=codex, file=my plans/foo bar.md (paths with spaces must be quoted)
- `/codex -- plans/foo.md` → file=plans/foo.md (`--` ends option parsing; required if path starts with `-`)

## Session Reuse

After each provider invocation, scan **only the current invocation's stdout stream** (not history, quoted output, or prior rounds) for lines matching `[plan-review] session_id=<value>` (exact format: `[plan-review] session_id=xxx`, no spaces around `=`, value on its own line; this reserved marker prevents spoofing via echoed transcript content). Require **exactly one** such line; if count is 0 or >1, disable session reuse for that invocation and emit `[plan-review] WARN: session_id extraction skipped (found {count} markers)`. If exactly one is found, validate the value against `^[A-Za-z0-9._:-]{1,128}$`; reject non-matching values silently. If found and valid, pass `--session "<id>"` (shell-quoted) in subsequent rounds so the provider retains prior review history. Do not halt on extraction failure.

## Workflow

### Step 1 — Resolve input file

Resolve `plan-file-path` to an absolute path. If the file does not exist or is empty:
- Emit: `[plan-review] ERROR: VALIDATION_ERROR: <reason>`
- Exit `5`

### Step 2 — Derive review file path

Apply D6 convention:
- Rule: `reviews/{input-filename-without-.md}-review.md` in a `reviews/` directory at the same level as the input file.
- Examples:
  - `plans/auth-refactor.md` → `plans/reviews/auth-refactor-review.md`
  - `docs/my-plan.md` → `docs/reviews/my-plan-review.md`

Run `mkdir -p <reviews-dir>` before writing. If `mkdir -p` fails (non-zero exit), emit `[plan-review] ERROR: VALIDATION_ERROR: cannot create reviews directory: <reviews-dir>` and exit `5`.

If the review file already exists, this is not the first round. Instruct the provider to read it and track prior issue resolution status.

### Step 3 — Invoke provider

Resolve the provider name using the order in the Usage section (flag → positional → default). Invoke the provider by sending it the review prompt via the `/{provider}` dispatch mechanism (e.g., `/codex` routes to the Codex agent with the prompt as input). The provider writes its review to the review file and returns its output, from which `session_id` is extracted for subsequent rounds.

Pass the following prompt, substituting `{plan-file-path}`, `{review-file-path}`, and `{provider}`:

```
Read the contents of {plan-file-path} and review it critically as an independent third-party reviewer.

Requirements:
- Raise at least 5 concrete and actionable improvement points
- Prioritize the highest-severity / highest-impact issues first, and include as many additional well-supported issues as you can find in this round without sacrificing specificity or confidence
- Each issue must include: issue description + exact location/reference in the plan + improvement suggestion
- Use severity levels: Critical > High > Medium > Low > Suggestion
- If {review-file-path} already exists, read it first and track the resolution status of previous issues in the new round

Analysis dimensions (apply relevant ones based on the plan type):
- Architectural soundness: overdesign vs underdesign, module boundaries, single responsibility
- Technology choices: rationale, alternatives, compatibility with the existing project stack
- Completeness: missing scenarios, overlooked edge cases, dependency and impact scope
- Feasibility: implementation complexity, performance risks, migration and compatibility concerns
- Engineering quality: whether steps are precise enough to execute unambiguously
- Security: authentication, authorization, data validation when relevant

Append the current review round to {review-file-path}, creating the file if it does not exist.
When creating the file for the first time, write the following header as the very first lines of the file (the file is empty at this point), then append the first round below it. When adding a subsequent round, append at EOF using `\n\n---\n\n## Round {N} — ...` N is computed from the count of lines matching pattern `^## Round [0-9]+ — ` on non-fenced, non-quoted lines in the review file, plus one.

Header to write on first creation:

# Plan Review: {plan title}

_Use the plan file name without extension as the title (e.g., `bundle-plan-review-skill` for `bundle-plan-review-skill.md`). If the plan file contains a `# Heading 1` on its first line, use that heading text instead._

**Plan File**: {plan-file-path}
**Reviewer**: {provider}

Separate rounds with `---` and append new rounds at the end. Use this format:

## Round {N} — {YYYY-MM-DD}

### Overall Assessment
{2-3 sentence overall assessment}
**Rating**: {X}/10

### Previous Round Tracking (rounds 2+ only)
| # | Issue | Status | Notes |
|---|-------|--------|-------|

### Issues
#### Issue 1 ({severity}): {title}
**Location**: {location in the plan}
{issue description}
**Suggestion**: {improvement suggestion}
... (minimum 5 issues)

### Positive Aspects
- ...

### Summary
{Top 3 key issues}
**Consensus Status**: NEEDS_REVISION / MOSTLY_GOOD / APPROVED / BLOCKED

Key principle: be a critical reviewer, not a yes-man. Prioritize the most important issues first and include as many high-quality findings as you can support in one pass, but never trade specificity, evidence, or actionability for raw count.
```

If the provider returns fewer than 5 findings, **do not append the round to the review file** (or remove the partial append if it already occurred); then exit `3` (`PROVIDER_EMPTY_RESPONSE`); do not revise the plan.

  **Provider file-write fallback**: before invoking the provider, record the pre-invocation byte size, last round count, and a sha256 hash of the pre-invocation file content (or note it does not yet exist). After the provider returns, check whether **all three** of the following are true: (a) byte size increased, (b) **exactly one** new `^## Round [0-9]+ — ` heading (with number N = prior_round_count + 1) is present in the appended delta (on non-fenced, non-quoted lines), AND (c) sha256 of pre-invocation content matches the first N bytes of the post-invocation file (N = pre-invocation byte size). **If predicate (c) is false (tamper detected)**, quarantine all appended bytes using the quarantine convention (see D8), emit `[plan-review] VALIDATION_ERROR: preexisting content tampered`, and exit `5` immediately — no fallback, no Step 4 parse, no plan edits. Fallback triggers only if **at least one** of predicates (a) or (b) is false (and (c) passed). If fallback is triggered, capture provider stdout and validate it passes the round-shape minima before appending to the review file: must contain **exactly one** `^## Round [0-9]+ — ` heading with round number N = prior_round_count + 1 (reject stdout containing multiple round headings or replayed old round blocks), at least 5 `#### Issue` entries, and a valid `**Consensus Status**:` line. If stdout is also empty or fails the structural gate, treat as `PROVIDER_EMPTY_RESPONSE` and exit `3`. Do not append stdout if both predicates are satisfied (to prevent double-appending).

  _Concurrency note: this skill is designed for serial AI orchestration and does not define a locking protocol. Concurrent invocations against the same plan are out of scope._

### Step 4 — Read review, evaluate findings, revise plan

Before parsing consensus, apply a mandatory D3 structural gate on the latest round: (a) validate the latest round heading number equals prior_round_count + 1 (if not, emit PARSE_FAILURE and exit `8`); (b) require at least 5 `#### Issue` entries on non-fenced, non-quoted lines where each counted issue block contains both `**Location**:` and `**Suggestion**:` fields; (c) require **exactly one** valid `**Consensus Status**:` line (count ≠ 1 → PARSE_FAILURE exit `8`); (d) for rounds where prior_round_count ≥ 1, require `### Previous Round Tracking` with at least one table row containing a numeric issue ID, a non-empty status from the allowed set (Resolved/Rejected/Carried over/In progress), and a non-empty notes field referencing a prior issue outcome (if absent or malformed, emit PARSE_FAILURE exit `8`). This gate applies after every provider invocation, regardless of whether fallback triggered. If gate clause (b) fails, treat as `PROVIDER_EMPTY_RESPONSE` and exit `3`. On post-invocation structural/parse failure, remove or quarantine **all content appended since pre-invocation EOF** (not just the syntactic latest round) before exiting, to prevent partial or multi-round injections from persisting.

Parse the latest round using D8's latest-round extraction rules (last non-fenced/non-quoted `^## Round [0-9]+ — ` heading through EOF). **If latest-round consensus parsing fails (no `Consensus Status` match found), emit `[plan-review] PARSE_FAILURE` and exit `8` before evaluating or editing anything.** **If the consensus status is `BLOCKED`, skip all plan edits and exit `9` immediately.** Otherwise, evaluate issues in descending severity / impact order, starting with Critical and High findings. Adopt valid suggestions and revise the plan file directly. If rejecting a suggestion, note the reason briefly in the plan (rationale: rejection notes are intentional in-plan metadata, keeping design decisions and their resolutions co-located for future readers). Never create a new plan file; edit in place. If the plan file cannot be written to (e.g., disk full, permission error), emit `[plan-review] ERROR: VALIDATION_ERROR: cannot write to plan file: <plan-path>` and exit `5`.

### Step 5 — Consensus dispatch

| Status | Action |
|--------|--------|
| `NEEDS_REVISION` | Revise plan, then invoke provider again (back to Step 3) |
| `MOSTLY_GOOD` | Revise plan, then ask the user interactively: "The reviewer rates this mostly good. Run one more round?" If yes, do not exit; return to Step 3 and continue the loop (final exit code emitted only at Step 6 or an error path). If no, proceed to Step 6. In non-interactive contexts (no TTY or user available), default is to stop and proceed to Step 6. |
| `APPROVED` | Report completion; plan is ready for implementation |
| `BLOCKED` | Halt immediately. Do not revise plan. Do not invoke provider again. Human resolution required. Exit `9`. |

**Loop guard**: there is no hard round cap by default (the human operator drives termination). If operating in a fully automated context, callers should impose an external round limit. If the loop exceeds any externally imposed limit, emit `[plan-review] HALT: round limit exhausted` and halt with exit `9` (same code as `BLOCKED`; downstream automations may distinguish the two causes via the emitted diagnostic line).

Re-running after BLOCKED: if the user manually resolves the blocking issue and re-invokes, the new run appends round N+1 to the same review file (continuing the thread). The existing rounds are preserved untouched.

### Step 6 — Wrap-up report

Report to user:
- How many review rounds were completed
- Which major areas were improved
- Final plan file path
- Review log file path

Then exit `0`.

## File Convention

- One review file per plan: `reviews/{topic}-review.md` at the same level as the plan file
- `{topic}` is the plan file name without `.md`
- Append all rounds to the same file separated by `---`

## Exit Codes

| Code | Condition |
|------|-----------|
| `0` | Success (workflow completed — `APPROVED`, `MOSTLY_GOOD` with terminal consensus, or user declined further rounds after `MOSTLY_GOOD`) |
| `1` | `PROVIDER_UNAVAILABLE` — provider skill not found |
| `2` | `PROVIDER_TIMEOUT` |
| `3` | `PROVIDER_EMPTY_RESPONSE` — fewer than 5 findings returned |
| `5` | `VALIDATION_ERROR` — file not found, empty, unresolvable path, review directory creation failure, plan file write failure; also: shadow-backup creation or move failure before invocation, shadow-restore failure, shadow backup missing/unreadable at restore time, plan hash mismatch after validation, evidence line absent from stdout |
| `8` | `PARSE_FAILURE` — any Step 4 D3 structural gate violation: round number ≠ prior+1; <5 valid issue blocks (non-fenced/non-quoted, each with Location + Suggestion); consensus count ≠ 1; missing Previous Round Tracking for rounds 2+; or consensus pattern mismatch |
| `9` | `BLOCKED` — reviewer halted workflow; human resolution required before re-invoking; also: operator-imposed external round-limit exhausted (distinguish via emitted diagnostic line) |

Exit codes 4, 6, and 7 are not used by this skill (reserved for artifact-mode peer operations).
````
