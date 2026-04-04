---
name: plan-review
description: "Internal bundled plan-review workflow for file-mode peer review, independent of spec feature context."
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

This file is an internal pack resource loaded by `speckit.peer.review` in file mode. It is not exposed as a standalone `/plan-review` command by this repository's current pack configuration.

This workflow is for standalone file-mode review only. Canonical feature artifact paths under `specs/<featureId>/(spec|research|plan|tasks).md` are routed to artifact mode by `speckit.peer.review` and must not be delegated here.

_Note: `--session` is optional and only used when continuing a prior round._

**Invocation binding contract:** When invoked via `/speckit.peer.review`, argument binding is performed by the peer pack's `review.md` command (see Step 1.1a). `review.md` binds `plan-file-path` and optional `provider` before loading this file. No standalone direct-invocation contract is defined in this repository configuration.

Provider resolution order:
1. Bound `provider` value from `speckit.peer.review`, if supplied
2. Default: `codex`

Examples:
- `/speckit.peer.review plans/foo.md` → provider=codex, file=plans/foo.md
- `/speckit.peer.review plans/foo.md --provider opencode` → provider=opencode, file=plans/foo.md
- `/speckit.peer.review 'my plans/foo bar.md' --provider codex` → provider=codex, file=my plans/foo bar.md

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

Resolve the provider name using the order in the Usage section (bound `provider` → default). Invoke the resolved provider by sending it the review prompt through the orchestrator's provider-dispatch mechanism. The provider writes its review to the review file and returns its output, from which `session_id` is extracted for subsequent rounds.

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