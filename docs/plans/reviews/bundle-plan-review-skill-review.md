# Plan Review: Bundle plan-review Skill into spec-kit

**Plan File**: docs/plans/bundle-plan-review-skill.md
**Reviewer**: opencode

---
## Round 1 — 2026-04-04

### Overall Assessment
The plan addresses a legitimate self-containment issue by inlining an external skill dependency. The decision section (D1-D8) provides good rationale for key choices, and the three-step implementation structure is clear. However, Step 1's content specification is an outline, not actual skill markdown — leaving too much ambiguity for unambiguous execution. Additionally, several error scenarios and integration edge cases are unaddressed.

**Rating**: 6/10

### Issues

#### Issue 1 (Critical): Step 1 content is an outline, not implementation specification
**Location**: Step 1, lines 74-87 — "Content structure: 1. Frontmatter... 7. Exit Codes table"

The "Content structure" describes topics to cover rather than providing actual skill markdown. This leaves the implementer to reconstruct the plan-review skill from memory or external files. If the goal is to make the kit self-contained, the actual skill content must be present in the plan.

**Suggestion**: Include the full adapted `shared/skills/plan-review.md` as an appendix or embedded code block in the plan. At minimum, provide the complete prompt template for Steps 1–6.

---

#### Issue 2 (High): Step 2 invocation mechanism is underspecified
**Location**: Step 2, lines 94-95 — "Execute the workflow defined in `shared/skills/plan-review.md`, passing `input_file` as the plan file path"

How exactly does "passing `input_file`" work? This could mean:
- Setting an environment variable (`INPUT_FILE=...`)
- Passing as a command-line argument
- Writing to a temporary config file
- Something else

The peer pack's existing skill invocation pattern uses `/{provider}` dispatch. The plan references D1 (keeping `/{provider}` dispatch), but doesn't specify how the skill receives the input file path when invoked as a skill rather than a script.

**Suggestion**: Explicitly state the invocation mechanism. For example: "The skill is invoked via `skill:///shared/skills/plan-review.md?plan=<input_file>` or equivalent skill dispatch mechanism. The implementer must verify the skill can receive the file path at invocation time."

---

#### Issue 3 (High): D2 provider resolution ambiguity for positional syntax
**Location**: D2, lines 21-27 — "Positional syntax: `/{provider} <file>` (legacy)"

The resolution order says "positional prefix → default `codex`" but doesn't define what constitutes a valid positional prefix. The example `/{provider} <file>` suggests the provider name IS the command (e.g., `/codex some-plan.md`). But D2 also says `--provider <name>` sets the provider. 

The ambiguity: if a user writes `/codex --provider claude plans/foo.md`, which wins? If they write `/claude plans/foo.md --provider codex`, is `--provider` honored? The priority order is stated but the edge cases around mixing positional and flag syntax are not.

**Suggestion**: Add concrete examples covering all combinations:
- `/codex plans/foo.md` → provider=codex, file=plans/foo.md
- `/codex --provider claude plans/foo.md` → provider=claude (flag wins), file=plans/foo.md
- `/codex plans/foo.md --provider claude` → clarify whether --provider after positional is honored
- `plans/foo.md --provider codex` (no positional provider) → clarify whether this works

---

#### Issue 4 (High): D8 exit code mapping skips codes 4, 6, 7 with no explanation
**Location**: D8, lines 50-57 — exit codes 1, 2, 3, 5, 8 are mapped; codes 4, 6, 7 are unaddressed

The peer.review exit code table (referenced in D8) presumably has 8 codes (0-7 or 1-8). This plan maps to exit codes 1, 2, 3, 5, 8 but omits 4, 6, 7 without explaining why. An implementer or caller checking exit codes will find gaps.

**Suggestion**: Either:
1. Document what exit codes 4, 6, 7 represent in the peer's exit code table and why they don't apply to file mode, OR
2. Add explicit "N/A for file mode" notation for those codes

---

#### Issue 5 (High): No atomicity or rollback across the three steps
**Location**: "Files to Change" table and Implementation Steps section

If Step 1 creates `shared/skills/plan-review.md`, Step 2 modifies `packs/peer/commands/review.md`, and Step 3 modifies `packs/peer/extension.yml` — what happens if Step 3 fails? The skill and command file are already changed. There's no rollback, no validation that all three files are consistent, and no instruction to validate the bundle works before considering the task done.

**Suggestion**: Add a verification step after Step 3: "Validate the bundled skill works by invoking it on this plan file (docs/plans/bundle-plan-review-skill.md) and confirming a review file is created in docs/plans/reviews/. If validation fails, rollback all three changes."

---

#### Issue 6 (Medium): BLOCKED behavior vs. "append-only review file" invariant is contradictory
**Location**: Invariants line 4 (line 117) vs. D5 (lines 36-38)

Invariant 4 states: "Review file is append-only; no prior round is modified."
D5 states: "BLOCKED halts immediately without plan revision."

If a round produces a review file and the next round is BLOCKED, the workflow halts — so no plan revision occurs and the append-only nature is moot. But if a user manually revises the plan after seeing partial results and re-runs, the invariant implies they should append rather than overwrite. This isn't explicitly allowed or forbidden.

**Suggestion**: Clarify: "If BLOCKED occurs after round N, the review file contains rounds 1 through N. The user may manually revise the plan and re-run, which should append round N+1 to the same review file (continue the thread), not create a new file."

---

#### Issue 7 (Medium): Step 1 doesn't address skill file already existing
**Location**: Step 1, line 74 — "Create `shared/skills/plan-review.md`"

If `shared/skills/plan-review.md` already exists (from a prior partial attempt or other cause), the "Create" instruction is ambiguous — does it overwrite? Fail? Prompt?

**Suggestion**: Add: "If `shared/skills/plan-review.md` already exists, rename it to `shared/skills/plan-review.md.bak.<timestamp>` before creating the new file."

---

#### Issue 8 (Medium): Step 3 extension.yml update — skill path assumes relative position
**Location**: Step 3, lines 102-108 — `file: ../../shared/skills/plan-review.md`

The relative path `../../shared/skills/plan-review.md` assumes the extension.yml is at a specific directory depth. If extension.yml moves in the future (or is referenced from a different working directory), this path breaks silently.

**Suggestion**: Document that this path is relative to the extension.yml file location, not the working directory. Consider noting that a future improvement would use an absolute path or a variable resolved at runtime.

---

#### Issue 9 (Low): D3 "5 findings minimum" — no enforcement mechanism specified
**Location**: D3, line 30

The plan specifies a minimum of 5 findings but doesn't explain how this is enforced. Does the provider self-report finding count? Does the skill parse the response to count findings? If the provider returns only 3 findings, what happens?

**Suggestion**: Add to Step 3 (or the skill content): "If the provider returns fewer than 5 findings, treat the response as PROVIDER_EMPTY_RESPONSE (exit 3) and re-prompt with feedback that findings were below minimum."

---

#### Issue 10 (Low): No specification of what "forward --provider if supplied" means in practice
**Location**: Step 2, lines 95-96

The instruction to "forward --provider if supplied" doesn't specify whether this is done via environment variable, config file, skill invocation parameter, or something else. This matters for the skill's ability to actually receive and use the override.

**Suggestion**: Align with the invocation mechanism fix in Issue 2 — once that's specified, the "forward" mechanism should be explicit.

---

### Positive Aspects
- D1-D8 decision table provides clear rationale for key architectural choices — this is exemplary for implementation plans
- D6 review file path convention is well-reasoned and handles non-spec plans correctly
- Invariants section correctly scopes file-mode constraints and avoids leakage into artifact mode
- The three-step structure is appropriately granular and sequential
- Exit code mapping (D8) aligns with existing peer conventions, easing integration

### Summary

**Top 3 key issues:**
1. **Step 1 content is an outline, not the actual skill markdown** — without the full skill content in the plan, the self-containment goal is not achieved and implementers must reverse-engineer the original skill
2. **Invocation mechanism is underspecified** — "passing input_file" and "forward --provider" lack concrete mechanism definitions that prevent ambiguous implementation
3. **No rollback/atomicity across the three steps** — partial failure leaves the repo in an inconsistent state with no recovery path

**Consensus Status**: NEEDS_REVISION

---

## Round 13 — 2026-04-04

### Overall Assessment
Round 12 issues 62-66 are addressed as stated: Appendix A now contains the no-append/remove-partial safeguard for `PROVIDER_EMPTY_RESPONSE`, issue 63 is explicitly marked out-of-scope for serial AI orchestration, session reuse extraction is scoped to the current invocation stdout with last-match semantics, Step 4 now requires trap/finally restoration for shadow validation, and `/plan-review` parsing now excludes positional provider-prefix resolution.  
A new adversarial pass still finds several execution-contract gaps that can cause unintended plan mutation, rollback incompleteness, and validation data loss.

**Rating**: 9.0/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 62 | Appendix A missing no-append/remove-partial safeguard | **Resolved** | Appendix A Step 3 now includes explicit no-append/remove-partial behavior on `<5` findings |
| 63 | Missing concurrency/locking contract for append | **Intentionally Rejected (Out of Scope)** | Plan now explicitly scopes operation to serial AI orchestration; concurrent writes are non-goals |
| 64 | Session ID extraction under-scoped | **Resolved** | Session Reuse now parses only current invocation stdout and uses last valid match |
| 65 | Shadow validation lacked failure-safe restore | **Resolved** | Step 4 now mandates trap/finally cleanup and restore failure handling |
| 66 | `/plan-review` positional parse ambiguity | **Resolved** | Usage now excludes positional-prefix parsing when command token is `/plan-review` |
| 1-61 | (all prior issues) | **Resolved / Intentional where noted** | Per R1-R12 tracking and current file state |

### Issues

#### Issue 67 (High): `BLOCKED` contract conflicts with unconditional plan revision in Step 4
**Location**: Appendix A Step 4 line 399 vs Step 5 `BLOCKED` row line 408 and D5

Step 4 says to evaluate issues and revise the plan directly, while Step 5 says `BLOCKED` must halt immediately and not revise the plan. If the latest round consensus is `BLOCKED`, Step 4 may already have mutated the plan before the halt decision is applied.

**Suggestion**: Gate Step 4 with consensus-first control flow: parse latest round status first; if `BLOCKED`, skip any plan edits and exit `9` immediately.

---

#### Issue 68 (High): Rollback contract does not restore overwritten `shared/skills/plan-review.md` when it previously existed
**Location**: Step 1 overwrite rule line 90 vs Step 4 rollback clause lines 231-232

Step 1 explicitly allows overwriting an existing `shared/skills/plan-review.md`, but rollback only restores `review.md` and `extension.yml`, and only deletes `shared/skills/plan-review.md` if newly created. If the file existed and was overwritten, rollback does not restore prior content.

**Suggestion**: Extend rollback to include `shared/skills/plan-review.md`: restore from `HEAD` when tracked, or from a pre-step backup/hash snapshot when untracked but pre-existing.

---

#### Issue 69 (Medium): Validation cleanup can delete a pre-existing review artifact
**Location**: Step 4 item 4 line 229

Step 4 unconditionally deletes `docs/plans/reviews/bundle-plan-review-skill-review.md` after validation. If that file already existed before validation, this destroys prior review history rather than cleaning only newly created validation output.

**Suggestion**: Add pre-check state handling: if the target review file exists before validation, preserve/restore it (or run validation against a dedicated temporary plan path and temporary review output).

---

#### Issue 70 (Medium): `MOSTLY_GOOD` interactive prompt has no deterministic non-interactive fallback
**Location**: Appendix A Step 5 line 406 and loop guard line 410

Step 5 requires an interactive user prompt after `MOSTLY_GOOD`. In non-interactive automation contexts, this can stall execution even though a loop guard note exists.

**Suggestion**: Specify a non-interactive policy input (for example `--mostly-good-policy=stop|continue`) with a default behavior when no TTY/user is available.

---

#### Issue 71 (Medium): “Read latest round” logic is unspecified for Step 4
**Location**: Appendix A Step 4 line 399

Step 4 requires reading the latest round, but unlike D8, it does not define how to locate latest-round boundaries or exclude fenced/quoted pseudo-round text. This can make Step 4 evaluate stale or malformed content.

**Suggestion**: Reuse D8 parsing rules for latest-round extraction: last non-fenced/non-quoted `^## Round [0-9]+ — ` heading through EOF, then parse issues only inside that segment.

---

#### Issue 72 (Low): Path tokenization/quoting rules for `plan-file-path` are unspecified
**Location**: Usage examples lines 271-287 and D2 positional syntax

All examples use simple filenames. The plan does not define behavior for paths with spaces, leading dashes, or shell-sensitive characters, which can break argument parsing or be misread as flags.

**Suggestion**: Define argument parsing contract for quoted paths and `--` end-of-options handling; add at least one example with a spaced path.

---

### Positive Aspects
- Round 12 fixes were integrated with clearer, testable language in both Step 4 and Appendix A.
- Session reuse and provider-resolution rules are now significantly more deterministic than earlier rounds.
- Exit-code contracts and parse constraints are much more concrete than in the initial plan.

### Summary

**Top 3 key issues:**
1. **Control-flow contradiction on `BLOCKED`**: Step 4 can mutate the plan before Step 5 halts.
2. **Rollback incompleteness for shared skill overwrite**: pre-existing `shared/skills/plan-review.md` is not restored on failure.
3. **Validation data-loss risk**: Step 4 cleanup can delete a pre-existing review artifact.

**Consensus Status**: NEEDS_REVISION

---

## Round 14 — 2026-04-04

### Overall Assessment
Round 13 issues 67-72 are resolved in the current plan text: Step 4 now gates on consensus and exits immediately on `BLOCKED`, rollback distinguishes tracked vs pre-existing untracked `shared/skills/plan-review.md`, validation cleanup preserves pre-existing artifacts, `MOSTLY_GOOD` has a deterministic non-interactive fallback, Step 4 references D8 latest-round parsing, and Usage now documents quoting plus `--` separator behavior.  
A deeper adversarial pass still exposes several remaining specification gaps around validation side effects, failure atomicity, and control-flow determinism.

**Rating**: 9.1/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 67 | `BLOCKED` check must happen before any Step 4 edits | **Resolved** | Step 1 workflow bullet and Appendix A Step 4 now gate on consensus first and exit `9` on `BLOCKED` |
| 68 | Rollback must restore pre-existing `shared/skills/plan-review.md` | **Resolved** | Step 4 rollback now distinguishes tracked vs pre-existing-untracked and restores from HEAD/snapshot |
| 69 | Validation cleanup must not delete pre-existing review artifacts | **Resolved** | Cleanup now deletes only artifacts created by validation |
| 70 | `MOSTLY_GOOD` needs non-interactive fallback | **Resolved** | Both Step 1 and Appendix A now default to stop and proceed to Step 6 in non-interactive contexts |
| 71 | Step 4 must define latest-round extraction rules | **Resolved** | Both Step 4 instances now reference D8 latest-round extraction contract |
| 72 | Path quoting and `--` handling unspecified | **Resolved** | Appendix A Usage examples now include quoted path and `--` end-of-options example |
| 1-66 | Prior issues from earlier rounds | **Resolved / Intentional where previously recorded** | No regressions detected in this round's spot checks against current text |

### Issues

#### Issue 73 (High): Validation run can mutate the plan under review (self-modifying verification)
**Location**: Implementation Step 4 item 1 line 224 (`/speckit.peer.review docs/plans/bundle-plan-review-skill.md`) + Appendix A Step 4 line 401

Validation invokes the live review workflow against the same plan file being validated. Since Step 4 of the skill explicitly revises the plan in place, a successful \"verification\" can alter `docs/plans/bundle-plan-review-skill.md`, contaminating the source of truth and blurring validation output vs spec content edits.

**Suggestion**: Validate against a temporary copy (or dedicated fixture) and assert the source plan hash is unchanged after validation.

---

#### Issue 74 (High): Rollback is defined only for validation failure, not for earlier step failures
**Location**: Steps 1-3 lines 90-219 vs rollback clause line 229

Rollback is only specified under \"If validation fails.\" If Step 2 or Step 3 fails after Step 1 has already overwritten files, the plan leaves partial state without a recovery contract.

**Suggestion**: Define a global failure handler spanning Steps 1-4: any non-zero after the first write must restore pre-step state for all touched files.

---

#### Issue 75 (Medium): Step 4 does not explicitly define behavior when consensus parsing fails
**Location**: Step 1 workflow Step 4 line 174 and Appendix A Step 4 line 401

Step 4 says \"parse latest round using D8 rules\" and branches only on `BLOCKED` vs \"otherwise evaluate issues.\" D8 defines `PARSE_FAILURE` exit `8`, but Step 4 does not explicitly state to halt on parse failure before any issue evaluation.

**Suggestion**: Add an explicit guard: if latest-round consensus parse fails, emit `PARSE_FAILURE` and exit `8` before evaluating or editing anything.

---

#### Issue 76 (Medium): Evidence requirement is mandatory but capture mechanism is unspecified
**Location**: Implementation Step 4 item 1 line 224

The plan requires \"a trace or log line\" proving bundled skill loading, but does not define which output stream, required logging mode, or acceptance regex. Different environments may not emit equivalent traces, causing false negatives or unverifiable passes.

**Suggestion**: Specify one deterministic evidence contract (exact output source + pattern), and define fallback behavior when trace logging is unavailable.

---

#### Issue 77 (Medium): Review-file append responsibility relies on provider-side file I/O without fallback
**Location**: Step 3 prompt lines 135-145 and command integration note line 201

The prompt requires the provider to append rounds directly to `{review-file-path}`. The plan does not define a fallback if provider execution returns text but cannot perform file writes in the current runtime, which can break round persistence.

**Suggestion**: Make persistence orchestrator-owned: provider returns structured round content, then the skill/orchestrator appends atomically to the review file.

---

### Positive Aspects
- Round 13 fixes were integrated consistently in both Step 1 and Appendix A, reducing prior contract drift.
- Consensus handling and fallback behavior are now materially clearer for `BLOCKED` and `MOSTLY_GOOD`.
- Rollback and validation cleanup logic are more careful with pre-existing artifacts.

### Summary

**Top 3 key issues:**
1. **Validation side effect risk**: Step 4 verifies by running against the live plan and can mutate it.
2. **Failure-atomicity gap**: rollback is only defined for validation failure, not all post-write failures.
3. **Control-flow determinism gaps**: parse-failure and evidence-capture contracts remain under-specified.

**Consensus Status**: NEEDS_REVISION

---

## Round 23 — 2026-04-04

### Overall Assessment
Round 22 issues 115-119 are reflected in the plan, and the new D3a prioritization policy is now present in decisions, Step 3 prompts, and Step 4 review-order language.  
However, this round still finds several high-severity execution-contract gaps, including missing machine-enforceable checks for the new severity-first policy and unresolved fallback/quarantine integrity risks.
**Rating**: 9.3/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 115 | Direct-write path missing exact-one heading predicate | Resolved | Step 3 now requires exactly one new heading with `N = prior_round_count + 1` |
| 116 | Tamper branch lacked immediate-exit semantics | Resolved | Tamper path now explicitly exits `5` immediately with no fallback/Step 4/edits |
| 117 | D8 `PARSE_FAILURE` narrower than Step 4 structural gate | Resolved | D8 now enumerates Step 4 structural gate classes beyond consensus parsing |
| 118 | Quarantine operation lacked concrete convention/failure behavior | Resolved | Quarantine convention and failure-path expectations are now described |
| 119 | Previous Round Tracking row validity under-specified | Resolved | Step 4 now requires numeric ID, allowed status, and non-empty notes |

### Issues

#### Issue 120 (High): D8 still drifts from Step 4 on `Previous Round Tracking` row validity semantics
**Location**: `docs/plans/bundle-plan-review-skill.md:71`, `docs/plans/bundle-plan-review-skill.md:451`

Step 4 now requires row-level validity (numeric issue ID, allowed status set, non-empty notes), but D8/Exit Codes still summarize clause (d) as a missing-row condition. That creates a split contract where implementers reading decision/exit-code sections can under-enforce parser behavior.

**Suggestion**: Update D8 and the Exit Codes table to mirror Step 4 clause (d) exactly: `PARSE_FAILURE` includes missing **or malformed** tracking rows with the same numeric/status/notes constraints.

#### Issue 121 (High): New severity-first policy is not represented in D8/Exit-Code enforcement rules
**Location**: `docs/plans/bundle-plan-review-skill.md:47-52`, `docs/plans/bundle-plan-review-skill.md:76`, `docs/plans/bundle-plan-review-skill.md:458`

D3a and Step 4 now require severity-first prioritization, but D8 `PARSE_FAILURE` rules and the Exit Codes table do not include any validation/failure mode for ordering violations. This creates contract drift: runtime intent says “Critical/High first,” while parser/exit-code contract can still treat low-first or unsorted reviews as structurally valid.

**Suggestion**: Extend D8 and the Exit Codes table so severity-order violations in the latest round trigger `PARSE_FAILURE` (exit `8`), or explicitly downgrade Step 4 language from requirement to best-effort guidance.

#### Issue 122 (High): Severity taxonomy is undefined, so severity-first ordering cannot be deterministically evaluated
**Location**: `docs/plans/bundle-plan-review-skill.md:164`, `docs/plans/bundle-plan-review-skill.md:184`, `docs/plans/bundle-plan-review-skill.md:392`, `docs/plans/bundle-plan-review-skill.md:418`

The format uses freeform `{severity}` and only narrative text says to start with Critical/High. Without a closed severity set and normalization rules, implementations cannot reliably determine ordering or detect violations.

**Suggestion**: Define an allowed severity enum (for example: Critical, High, Medium, Low), case-normalization rules, and explicit handling for unknown labels (reject as `PARSE_FAILURE`).

#### Issue 123 (High): Quarantine convention is referenced but not concretely specified in D8
**Location**: `docs/plans/bundle-plan-review-skill.md:182`, `docs/plans/bundle-plan-review-skill.md:410`, `docs/plans/bundle-plan-review-skill.md:65-74`

Step 3 repeatedly says “use the quarantine convention (see D8)”, but D8 does not provide an explicit operational contract (artifact path format, unique naming, write atomicity expectations, and hard failure rule if quarantine write fails). This can lead to inconsistent implementations and silent data loss.

**Suggestion**: Add an explicit D8 quarantine definition: write appended bytes to a unique sidecar artifact via `mktemp` (e.g., `<review-file>.quarantine.XXXXXX`), never discard silently, and exit `5` immediately if quarantine persistence fails.

#### Issue 124 (High): Fallback-trigger path can leave polluted appended bytes when stdout validation fails
**Location**: `docs/plans/bundle-plan-review-skill.md:182`, `docs/plans/bundle-plan-review-skill.md:410`

Fallback triggers when predicate (a) or (b) fails (with (c) passing). In that branch, if provider stdout then fails shape checks, the flow exits `3` without an explicit requirement to remove/quarantine any bytes already appended by provider direct-write attempts. That can leave malformed trailing content in the review file.

**Suggestion**: In the fallback branch, mandate cleanup of all bytes appended since pre-invocation EOF before any `PROVIDER_EMPTY_RESPONSE` exit, unless a valid replacement round is appended.

#### Issue 125 (Medium): Bundle verification under-checks structural gates compared to runtime Step 4
**Location**: `docs/plans/bundle-plan-review-skill.md:238`

Verification Step 4 item 3 checks only “>=5 issues + valid consensus” in latest segment. It does not require heading continuity (`N = prior+1`) or `Previous Round Tracking` row validity for rounds 2+, so validation can pass artifacts that runtime Step 4 would reject.

**Suggestion**: Make validation item 3 run the same D3 gate set as runtime Step 4 (a-d), and include severity-order checks once D3a enforcement is formalized.

#### Issue 126 (Medium): Verification commands are not shell-safe for spaced or flag-like temp paths
**Location**: `docs/plans/bundle-plan-review-skill.md:236`

Examples use unquoted expansions (e.g., `/speckit.peer.review $TMPPLAN`, `dirname $TMPPLAN`, `basename $TMPPLAN .md`). This can break if temp paths contain whitespace or edge characters and undermines reproducibility.

**Suggestion**: Quote all path expansions and include `--` for command arguments where applicable (e.g., `/speckit.peer.review -- \"$TMPPLAN\"`; `dirname -- \"$TMPPLAN\"`; `basename -- \"$TMPPLAN\" .md`).

### Positive Aspects
- Round 22 hardening materially improved direct-write integrity and tamper handling.
- The new D3a prioritization language is now consistently present in decision text and provider key-principle lines.
- Step 4 now explicitly instructs severity/impact-first evaluation order (Critical/High first).

### Summary
Top 3: (121) severity-first policy lacks enforceable parser/exit-code contract, (122) severity taxonomy undefined so ordering is non-deterministic, (124) fallback failure path can still preserve malformed appended bytes.
**Consensus Status**: NEEDS_REVISION

---

## Round 12 — 2026-04-04

### Overall Assessment
Round 11 issues 56-61 are addressed in the current plan: Step 4 no longer double-invokes, shadow verification now has one mandatory evidence path, consensus parsing is end-anchored, round counting excludes quoted lines, rollback distinguishes tracked vs newly created files, and issue 61 was handled in the Step 1 implementation instruction. However, a fresh adversarial pass still finds several execution-contract gaps and one internal spec drift that can reintroduce partial-history pollution.

**Rating**: 8.7/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 56 | Step 4 double invocation | **Resolved** | Step 4 now performs a single mandatory invocation path |
| 57 | Shadow verification lacked deterministic proof | **Resolved** | Step 4 now requires a mandatory trace/log proof of bundled skill load |
| 58 | Consensus regex not end-anchored | **Resolved** | D8 pattern now uses `\\s*$` end-anchor |
| 59 | Round count parser included quoted lines | **Resolved** | Round count rule now excludes non-quoted and non-fenced lines |
| 60 | Rollback did not distinguish tracked/new files | **Resolved** | Step 4 rollback now restores tracked files and deletes newly created bundled skill file |
| 61 | PROVIDER_EMPTY_RESPONSE lacked partial-append handling | **Resolved (Partially, regressed in Appendix)** | Step 1 instruction includes no-append/remove-partial policy, but Appendix A omits it |
| 1-55 | (all prior issues) | **Resolved / Intentional where noted** | Per R1-R11 tracking and current file state |

### Issues

#### Issue 62 (High): Step 1 vs Appendix A contract drift reintroduces partial-append risk
**Location**: Step 1 instruction line 172 vs Appendix A workflow line 393

The main implementation step says: on `<5 findings`, do not append (or remove partial append) before exiting `3`. But the Appendix A "verbatim skill file" only says to exit `3` and does not include the no-append/remove-partial safeguard. Since Appendix A is declared as the exact file content to generate, this drift can recreate the same history-pollution failure mode fixed in Round 11.

**Suggestion**: Make Appendix A authoritative and consistent by copying the full safeguard text into the Appendix A workflow (`do not append` or `remove partial append if already written`), then ensure Step 1 and Appendix A are byte-consistent for this rule.

---

#### Issue 63 (Medium): Step 3 append behavior has no concurrency/locking contract
**Location**: Appendix A Step 3 line 331 and prompt append instructions (round append at EOF)

The workflow requires appending rounds to a shared review file but defines no serialization mechanism. Two concurrent invocations against the same plan can interleave writes, corrupt separators/round numbering, and violate append-only invariants.

**Suggestion**: Add a lock contract for review file writes (for example, acquire a file lock before read-compute-append-release). At minimum, require detect-and-retry on write conflict with re-read of latest `N`.

---

#### Issue 64 (Medium): Session reuse extraction is under-scoped and can capture stale/foreign `session_id`
**Location**: Step 1 Session Reuse rule line 108 and Appendix A Session Reuse line 307

`session_id` extraction currently scans stdout for `session_id=<value>` but does not scope to the current provider invocation segment, nor define first/last match behavior. Logs can include echoed commands, quoted prior output, or multiple session IDs; using the wrong one can attach later rounds to an unrelated session.

**Suggestion**: Define deterministic extraction: parse only the current invocation output stream, ignore quoted/fenced lines, and use the last valid match from that stream (or require an explicit provider metadata field).

---

#### Issue 65 (Medium): Shadow validation mutates external state without a failure-safe restore contract
**Location**: Step 4 verification bullet 1 (temporary shadow with `mv ... SKILL.md.bak` and "restore immediately")

The plan requires mutating `~/.claude/skills/plan-review/SKILL.md` and restoring it after the test, but does not require a guaranteed restore path on interruption/failure between shadow and restore. A crash can leave the external skill hidden and break other workflows.

**Suggestion**: Specify a must-use guard (trap/finally pattern): always restore in cleanup regardless of success/failure, and fail validation if restoration cannot be completed.

---

#### Issue 66 (Low): Provider resolution rules are ambiguous for direct `/plan-review` parsing
**Location**: Appendix A Usage lines 290-297 (`/plan-review` direct parsing + positional `/{provider}` rule)

The same skill file states that direct `/plan-review ...` parses arguments internally, while also defining positional `/{provider}` as part of provider resolution order. Without an explicit exclusion, a naive parser could treat `/plan-review` itself as the positional provider token.

**Suggestion**: Add an explicit parse rule: when command name is `/plan-review`, do not apply positional `/{provider}` parsing to argv[0]; only parse provider from `--provider` (or from prefixed dispatch mode where command token is not `/plan-review`).

---

### Positive Aspects
- Round 11 fixes materially improved parser strictness and rollback precision in the primary plan text.
- The validation path is now clearer, with one mandatory evidence mechanism for bundled skill loading.
- Prior tracking continuity remains strong and helps isolate truly new issues.

### Summary

**Top 3 key issues:**
1. **Spec drift between Step 1 and Appendix A** can reintroduce partial append pollution despite Round 11's fix intent.
2. **No write-serialization contract** leaves multi-run append behavior vulnerable to file corruption.
3. **Session/shadow operational safety gaps** remain under-specified for robust real-world execution.

**Consensus Status**: NEEDS_REVISION

---

## Round 2 — 2026-04-04

### Overall Assessment
The revision addresses most of the high-priority Round 1 issues: D2 examples, exit code gaps, atomicity/rollback, BLOCKED re-run behavior, file-overwrite idempotency, and relative-path documentation are all resolved. However, the plan still describes the skill file's structure rather than providing its actual markdown content, and the invocation mechanism remains abstract — these two critical items from Round 1 are only partially addressed, not closed. Additionally, Step 4's validation step introduces a new problem: it leaves a real review file artifact in the repository.

**Rating**: 7/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Step 1 content is an outline, not implementation specification | **Partially Resolved** | Prompt template now fully specified, but it's the provider prompt, not the skill instruction file itself — the skill file structure is still described, not provided verbatim |
| 2 | Step 2 invocation mechanism is underspecified | **Partially Resolved** | "Named argument in scope" is clearer but still abstract; actual mechanism left to implementer inference |
| 3 | D2 provider resolution ambiguity | **Resolved** | Concrete examples added (lines 29-33) |
| 4 | D8 exit code mapping skips codes 4, 6, 7 | **Resolved** | Line 66-67 explains they are reserved for artifact mode |
| 5 | No atomicity or rollback across the three steps | **Resolved** | Step 4 (lines 208-216) adds verification and rollback |
| 6 | BLOCKED vs "append-only" invariant contradiction | **Resolved** | Lines 225-227 clarify re-run append behavior |
| 7 | Step 1 doesn't address skill file already existing | **Resolved** | Line 84: "idempotent by design" / overwrite |
| 8 | extension.yml relative path undocumented | **Resolved** | Line 206 documents the relative-to-extension.yml assumption |
| 9 | D3 "5 findings minimum" — no enforcement mechanism | **Resolved** | Lines 38-39 and 164 specify exit 3 enforcement |
| 10 | "Forward --provider" mechanism unspecified | **Partially Resolved** | Flag-wins behavior stated but forwarding mechanism still abstract |

### Issues

#### Issue 11 (High): Skill file is still structurally described, not provided verbatim
**Location**: Step 1, lines 86-181 — "Create the file with the following sections in order"

Step 1 still describes the skill file structure rather than providing `shared/skills/plan-review.md` as an actual file. The prompt template (lines 110-162) is the content sent *to the provider*, not the skill instruction file that the peer pack loads. The skill file itself is described as having "Frontmatter", "Purpose", "Usage", "Session Reuse", "Workflow" (with sub-steps), "File Convention summary", and "Exit Codes table" — but these are descriptions of what to include, not the actual file.

For true self-containment, the plan must include the complete skill file as an appendix or embedded code block, not a structural recipe.

**Suggestion**: Add an appendix to the plan titled "Appendix A — `shared/skills/plan-review.md` (Complete Skill File)" containing the full, verbatim skill file. The skill file is distinct from the provider prompt: it is the instruction document that governs how the review workflow executes.

---

#### Issue 12 (High): "Named argument in scope" — invocation mechanism still abstract
**Location**: Step 2, lines 189-191 — "_Invocation mechanics_"

The phrase "loading the skill file as an instruction context and executing it with the named argument in scope" is an architectural description, not an implementation specification. A developer implementing this needs to know:
- What syntax does the skill dispatch use? (e.g., `skill:///<path>?plan=<file>`? Environment variable? Something else?)
- What happens if the skill file cannot be loaded — is there a `PROVIDER_UNAVAILABLE` (exit 1) path?
- How does `--provider` forwarding work at the dispatch level?

The peer pack's existing patterns should be referenced explicitly. If the peer uses `/{provider}` dispatch for providers, and `skill://...` for skill files, those mechanisms should be named.

**Suggestion**: Either reference an existing peer pack pattern (e.g., "follow the same dispatch mechanism used by `shared/skills/artifact-review.md` in this pack") or specify: "Skill dispatch uses `skill://shared/skills/plan-review.md?plan=<input_file>` with `--provider` forwarded as `skill://shared/skills/plan-review.md?plan=<input_file>&provider=<name>`. If the skill file is not found, exit 1 (`PROVIDER_UNAVAILABLE`)."

---

#### Issue 13 (Medium): Step 4 validation leaves a real review file in the repository
**Location**: Step 4, lines 212-213 — "Confirm a review file is created at `docs/plans/reviews/bundle-plan-review-skill-review.md`"

The validation step runs the actual workflow on `docs/plans/bundle-plan-review-skill.md` and creates a real review file. This file is not a test artifact — it is a legitimate review of the plan being reviewed. The plan does not instruct the implementer to remove this file after validation, which means:
1. The repository now contains a review of itself (circular)
2. If validation succeeds, this file should arguably be committed — but it was created as a validation step, not a planned deliverable

**Suggestion**: Add: "After successful validation, remove the validation review file (`docs/plans/reviews/bundle-plan-review-skill-review.md`) and its containing directory if empty. The validation artifact is not a deliverable."

---

#### Issue 14 (Medium): Skill file Workflow section doesn't specify how provider selection happens
**Location**: Step 1, lines 102-177 — Workflow section; specifically Step 3 (lines 108-164)

The skill file's Workflow Step 3 says "Use `/{provider}` skill dispatch (default: `/codex`)." But the actual provider selection logic (the flag-vs-positional resolution from D2) is described in the "Usage" section of the skill file, not in the Workflow where it is executed. A skill that just says "Use `/{provider}`" without showing how the flag/positional resolution is implemented at runtime is incomplete — the implementer must infer how to wire D2's logic into the dispatch call.

**Suggestion**: In the skill file's Step 3, after "Use `/{provider}` skill dispatch (default: `/codex`)", add a note: "Provider resolution follows the order: `--provider <name>` flag → positional prefix from invocation → default codex. The invoking context must resolve the provider before dispatching."

---

#### Issue 15 (Low): Session ID extraction is fragile and undocumented
**Location**: Step 1, line 100 — "extract `session_id=xxx` from provider stdout"

The session reuse mechanism assumes a specific output format (`session_id=xxx`). There is no specification of:
- What happens if the provider does not output `session_id=xxx` at all
- Whether the session ID always appears on its own line
- Whether the format could be `session_id: xxx` or `session_id "xxx"` or similar variants
- Whether to halt or continue if session ID extraction fails

**Suggestion**: Add to the Session Reuse section: "If `session_id=xxx` is not found in provider stdout after the first invocation, proceed without session reuse (no session ID passed in subsequent rounds). Do not halt on extraction failure."

---

### Positive Aspects
- Most Round 1 issues are genuinely resolved — the revision is substantive, not cosmetic
- Step 4 verification + rollback is a strong addition that should be standard for all multi-file changes
- Round 1 Issue 2 (invocation) and Issue 10 (forward --provider) are addressed in principle even if mechanism details remain abstract
- Exit code gap explanation (reserved codes) is clear and prevents consumer confusion
- The BLOCKED re-run clarification is well-worded and prevents user confusion

### Summary

**Top 3 key issues:**
1. **Skill file is still structurally described, not provided verbatim** — Round 1 Issue 1 was partially addressed: the prompt template is now explicit, but it is the provider prompt, not the skill instruction file itself. The self-containment goal requires the actual skill file content.
2. **"Named argument in scope" invocation mechanism is still abstract** — Round 1 Issue 2 remains partially resolved. The phrase is an architectural description, not an implementation spec. An implementer cannot confidently build this without referencing other parts of the peer pack.
3. **Validation leaves a real review file artifact** — Step 4's validation creates a legitimate review file in the repository with no cleanup instruction, causing a circular self-review artifact.

**Consensus Status**: NEEDS_REVISION

---

## Round 3 — 2026-04-04

### Overall Assessment
Appendix A delivers the verbatim skill file — the primary structural gap from Rounds 1-2 is now closed and that was the right call. With the full content in place, internal inconsistencies that were invisible when the file was described structurally now surface: error prefix inconsistency between the command file and skill file, a non-standard skill invocation syntax in the Usage section that contradicts D1's `/{provider}` dispatch convention, and an unhandled `mkdir` failure path. These are implementable fixes but they are real spec defects.

**Rating**: 8/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Step 1 content is an outline, not implementation specification | **Resolved** | Appendix A (lines 233-400) provides full verbatim skill file |
| 2 | Step 2 invocation mechanism is underspecified | **Partially Resolved** | "Instruction context + bindings" is described architecturally; real mechanism still pack-specific (see Issue 16 below) |
| 3 | D2 provider resolution ambiguity | **Resolved** | Concrete examples in D2 and Appendix A |
| 4 | D8 exit code mapping skips codes 4, 6, 7 | **Resolved** | Line 66-67 and Appendix A line 399 explain reserved codes |
| 5 | No atomicity or rollback across the three steps | **Resolved** | Step 4 adds verification + rollback |
| 6 | BLOCKED vs "append-only" invariant contradiction | **Resolved** | Lines 225-227 and Appendix A line 372 clarify re-run append behavior |
| 7 | Step 1 doesn't address skill file already existing | **Resolved** | Line 84: idempotent overwrite |
| 8 | extension.yml relative path undocumented | **Resolved** | Line 206 documents relative-to-extension.yml |
| 9 | D3 "5 findings minimum" — no enforcement mechanism | **Resolved** | Lines 38-39, 164, and Appendix A line 357 specify exit 3 |
| 10 | "Forward --provider" mechanism unspecified | **Partially Resolved** | Binding mechanism described but still abstract (see Issue 16) |
| 11 | Skill file structurally described, not verbatim | **Resolved** | Appendix A provides verbatim content |
| 12 | "Named argument in scope" invocation still abstract | **Partially Resolved** | Binding semantics described but dispatch protocol unspecified (see Issue 16) |
| 13 | Step 4 validation leaves real review file | **Resolved** | Line 215 deletes validation artifact |
| 14 | Skill Workflow Step 3 doesn't show provider selection | **Resolved** | Appendix A line 299 wires D2 resolution explicitly into Step 3 |
| 15 | Session ID extraction fragile, no fallback | **Resolved** | Appendix A line 275: "do not halt on extraction failure" |

### Issues

#### Issue 16 (High): Error prefix is inconsistent — `[plan-review]` vs `[peer/review]`
**Location**: Step 2 line 191 vs. Appendix A line 282

Step 2 (in `packs/peer/commands/review.md`) specifies:
> Emit `[peer/review] ERROR: PROVIDER_UNAVAILABLE: shared/skills/plan-review.md not found`

But Appendix A line 282 specifies:
> Emit: `[plan-review] ERROR: VALIDATION_ERROR: <reason>`

The same workflow emits two different error prefixes depending on which file the error originates from. A caller monitoring for error patterns will see inconsistent branding. These should be unified. Given that the skill file lives at `shared/skills/plan-review.md`, the natural canonical prefix is `[plan-review]`.

**Suggestion**: Change Step 2 line 191 to use `[plan-review] ERROR: PROVIDER_UNAVAILABLE: shared/skills/plan-review.md not found` to match Appendix A. Or alternatively, change Appendix A line 282 to `[peer/review]` to match Step 2 — but the skill file should own its own error identity.

---

#### Issue 17 (High): Usage section uses non-standard invocation syntax
**Location**: Appendix A lines 256-260 — Usage section of skill file

The Usage section examples show:
```
/speckit.peer.review plans/my-feature-plan.md
/speckit.peer.review plans/my-feature-plan.md --provider opencode
/opencode plans/my-feature-plan.md
```

D1 explicitly states: "Keep `/{provider}` skill dispatch (not `ask_codex.sh` terminal path)." The `/{provider}` dispatch convention uses `/codex`, `/opencode`, etc. as the invocation syntax. The `/speckit.peer.review` syntax shown in the Usage section is not `/{provider}` dispatch — it looks like a fully-qualified skill name invocation, not a provider dispatch.

The first two examples appear to invoke the skill directly (`speckit.peer.review`) rather than dispatching to a provider. The third example `/opencode plans/my-feature-plan.md` does follow `/{provider}` but then the file path is the plan file, not the skill path.

This creates confusion: users may think they should type `/speckit.peer.review <plan>` when D1 says they should use `/{provider}` dispatch.

**Suggestion**: Revise the Usage examples to match D1's `/{provider}` dispatch convention:
```
/codex plans/my-feature-plan.md                # provider=codex, file=plans/my-feature-plan.md
/codex plans/my-feature-plan.md --provider opencode  # provider=opencode (flag wins)
/opencode plans/my-feature-plan.md              # provider=opencode, file=plans/my-feature-plan.md
```
Remove the `/speckit.peer.review` examples from the skill file Usage section, or clarify they are an alternative alias if the pack actually supports them.

---

#### Issue 18 (Medium): `mkdir -p` failure is not handled
**Location**: Appendix A line 293 — "Run `mkdir -p <reviews-dir>` before writing"

If `mkdir -p` fails due to permissions or a filesystem error, the workflow proceeds to Step 4 (write the review file) and likely fails there with a confusing write error. The workflow does not emit an error and exit. Since Step 2 derives the path, if the directory cannot be created, the skill should emit a `VALIDATION_ERROR` and exit `5` rather than proceeding to a silent failure.

**Suggestion**: After `mkdir -p <reviews-dir>`, check the exit status. If non-zero, emit `[plan-review] ERROR: VALIDATION_ERROR: cannot create reviews directory: <reviews-dir>` and exit `5`.

---

#### Issue 19 (Medium): "Plan title" in review header is undefined
**Location**: Appendix A line 323 — "Plan Review: {plan title}"

The prompt template instructs the provider to prepend `Plan Review: {plan title}` when creating the review file for the first time. But `{plan title}` is never defined — it is not the file name (which would be `bundle-plan-review-skill`), it is not the file path, and it is not obviously derivable without user input. The original plan-review skill may have assumed a specific convention.

If the provider substitutes literally with `{plan title}` (unresolved placeholder), the review file will have a malformed header. If it substitutes with the file name, the header will be `Plan Review: bundle-plan-review-skill.md` which is awkward.

**Suggestion**: Define `plan title` explicitly: either use the file name without extension (`bundle-plan-review-skill`) as the title, or use the first `# Heading 1` line in the plan file as the title if one exists. Add a note in the prompt template: "Use the plan file name without extension as the plan title (e.g., 'bundle-plan-review-skill')."

---

#### Issue 20 (Low): Step 1 and Appendix A Session Reuse descriptions differ in precision
**Location**: Step 1 line 100 vs. Appendix A line 275

Step 1 line 100 says "extract `session_id=xxx` from provider stdout" without specifying format details. Appendix A line 275 adds "exact format: `session_id=xxx`, no spaces, no quotes." Step 1 omits this specificity. An implementer reading only Step 1 (not Appendix A) would implement a less precise extractor. Since Step 1 and Appendix A must be consistent, this discrepancy should be resolved.

**Suggestion**: Add "exact format: `session_id=xxx`, no spaces, no quotes" to Step 1 line 100 to match Appendix A line 275.

---

### Positive Aspects
- Appendix A is the right structural answer to the R1/R2 criticism — providing the actual file content rather than a recipe is what true self-containment requires
- The verbatim skill file is internally consistent with all 8 decisions — D1 through D8 are all reflected in the skill file's Workflow, Usage, Exit Codes, and Session Reuse sections
- Step 4 rollback + validation artifact cleanup is a model verification pattern that should be standardized
- Error prefix use of `[plan-review]` is a sensible brand choice for the skill file
- The skill file's exit code table (Appendix A lines 388-399) is cleaner than the prose version in D8

### Summary

**Top 3 key issues:**
1. **Error prefix inconsistency** — Step 2 uses `[peer/review]` while Appendix A uses `[plan-review]`; these must be unified before implementation
2. **Usage section invocation syntax contradicts D1** — `/speckit.peer.review` is not `/{provider}` dispatch; examples in Appendix A lines 256-260 should be revised to match D1's stated convention
3. **`mkdir -p` failure is unhandled** — silent failure path could produce confusing downstream errors; should emit `VALIDATION_ERROR` exit `5`

**Consensus Status**: NEEDS_REVISION

---

## Round 4 — 2026-04-04

### Overall Assessment
All five Round 3 issues are resolved — error prefixes are unified, Usage syntax matches D1, mkdir failure is handled, plan title is defined, and Session Reuse descriptions are consistent. The plan is now structurally complete. However, two fundamental questions about the skill's execution model remain unanswered at the specification level: what "dispatch using `/{provider}`" means to an implementer who must build the orchestrator logic, and what the user actually types to invoke the skill given that Step 1.1a loads a skill file while D1 describes a `/{provider}` dispatch mechanism. These are architectural specification gaps, not typos.

**Rating**: 9/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 16 | Error prefix inconsistency — `[plan-review]` vs `[peer/review]` | **Resolved** | Step 2 line 191 now uses `[plan-review]` consistently |
| 17 | Usage section uses non-standard invocation syntax | **Resolved** | Appendix A lines 256-260 now show `/{provider}` dispatch with correct examples |
| 18 | `mkdir -p` failure is unhandled | **Resolved** | Appendix A line 295 now checks exit status and emits error |
| 19 | "Plan title" in review header is undefined | **Resolved** | Appendix A line 327 defines it explicitly |
| 20 | Step 1 and Appendix A Session Reuse descriptions differ in precision | **Resolved** | Step 1 line 100 now matches Appendix A line 277 precision |
| 1-15 | (all prior issues) | **Resolved** | See R1-R3 tracking tables |

### Issues

#### Issue 21 (High): `/{provider}` dispatch in skill Workflow Step 3 is described but not specified
**Location**: Appendix A line 301 — "Dispatch using `/{provider}` skill (e.g., `/codex`, `/opencode`)."

The skill file instructs the executor to "dispatch using `/{provider}`" but does not explain what that means in terms of actual mechanics. The executor is presumably an AI orchestrator (Claude, or a codex process) that is running the skill's instruction context. When it reaches "dispatch using `/{provider}`":
- Is this a recursive call — the orchestrator calls itself?
- Is this spawning a subprocess with the `/{provider}` command?
- Is this an IPC or API call to a provider service?
- Is this a no-op because the orchestrator IS the provider?

If the skill is loaded as an "instruction context" (per Step 2 line 191), the orchestrator reads and follows those instructions. "Dispatch using `/{provider}`" then asks the orchestrator to send a message to a provider — but no message-passing mechanism is defined. This creates a genuine implementation gap: two different implementers will pick two different interpretations and produce incompatible bundles.

**Suggestion**: Either (a) define "dispatch using `/{provider}`" as a concrete mechanism (e.g., "invoke the provider via `/{provider}` skill dispatch, which the orchestrator handles by passing the prompt to the provider process"), or (b) reframe Step 3 to describe what the AI executor does at that point rather than framing it as a dispatch call — for example: "At this step, the AI orchestrator evaluates the review prompt and generates a response as the provider, following the provider resolution result from Step 3's provider selection."

---

#### Issue 22 (High): Skill invocation entry point is ambiguous
**Location**: Appendix A lines 254-262 vs. Step 2 lines 188-194

Appendix A's Usage section describes how to invoke the skill with `/codex` or `/opencode` as providers, and line 262 says "This skill is normally invoked via `/{provider} <plan-file>` dispatch (D1)." But the skill file doesn't explain what the user actually types to start a review. The user-facing entry point is never defined.

Step 2 says to "Load `shared/skills/plan-review.md` as an instruction document" — but this describes how the internal mechanism works, not what the user types. There is no "user invocation syntax" specified anywhere.

The extension.yml declares `plan-review` as a provided skill, which implies a user might type something like `/plan-review <file>` or use a peer pack command. But the skill file's own usage section only shows `/{provider}` invocations, not a direct skill invocation.

**Suggestion**: Add to Appendix A's Usage section: "Direct invocation (when the skill is called by the peer pack command handler): load `shared/skills/plan-review.md` with `plan-file-path` bound to the plan file. Provider dispatch invocation: use `/{provider} <plan-file>` where the provider is `codex` (default) or another configured provider. The peer pack routes `/{provider} <plan-file>` to the provider, which loads the skill file and executes its workflow."

---

#### Issue 23 (Medium): Purpose section says "6-step loop" but Workflow has 6 numbered steps
**Location**: Appendix A line 252 — "5. Repeat until consensus..." vs. Workflow Steps 1-6

The Purpose section (lines 245-253) describes a 5-item numbered list, where item 5 says "Repeat until consensus..." but does not explicitly enumerate the steps as 1-6. However, the Workflow section contains Steps 1 through 6. The Purpose section's item 5 ("Repeat until consensus...") is a closing statement, not a step — so the workflow does have 6 distinct steps, but the Purpose describes 5 activities with the 6th being the loop continuation.

This is not incorrect, but it's slightly confusing. The reader expects 6 steps to be enumerated in the Purpose.

**Suggestion**: In Appendix A Purpose section, item 4, change "If review status is `NEEDS_REVISION`..." to "4. If review status is `NEEDS_REVISION`, ask the provider to review again automatically." Then item 5 becomes "5. Repeat until consensus..." which closes the description, matching the Workflow's Steps 1-6 structure.

---

#### Issue 24 (Low): First-round header "prepend before the first `---`" is ambiguous
**Location**: Appendix A lines 322-323 — "prepend this header before the first `---`"

The instruction tells the provider to create a header and "prepend before the first `---`." On a first-round file, there is no prior `---` in the file. The instruction assumes a delimiter structure that doesn't exist on first creation. While this is likely understood by any human reader, the instruction could mislead a strict instruction-follower.

**Suggestion**: Change to: "When creating for the first time, write the header as the first lines of the file (the file will be empty at this point). When appending a subsequent round, place the new round after the last `---` divider."

---

#### Issue 25 (Low): Step 2 Step 2's description of skill execution is circular with Step 1
**Location**: Step 2 lines 188-191 vs. Appendix A line 247

Step 2 says: "Load `shared/skills/plan-review.md` as an instruction document... Execute the skill workflow with these bindings in scope." The skill's Purpose says: "When invoked with a `plan-file-path`, start the adversarial plan iteration workflow." These are tautological — Step 2 describes loading and executing the skill, and the skill describes what happens when it's loaded and executed.

This isn't wrong, but it means there is no external behavioral contract — no description of what the bundle does from the user's perspective that isn't also a description of the skill's internal mechanics. The plan lacks a "What this does" summary separate from "How it works."

**Suggestion**: Add a one-paragraph "Effect" or "User-Facing Summary" section to the plan (before Step 1) that describes what a user experiences when they run this bundle — e.g., "After this change, running a file-mode review on a plan file will invoke the bundled `plan-review` skill, which performs an iterative adversarial review using the configured provider, appending review rounds to a `reviews/` file at the same level as the plan."

---

### Positive Aspects
- All five Round 3 issues are cleanly resolved — the plan's internal consistency is now strong
- The verbatim skill file with embedded prompt template is the right level of detail for implementation
- The architecture correctly separates concerns: the command file handles argument binding, the skill file handles the review workflow
- Error handling is now comprehensive: file resolution, mkdir, insufficient findings, parse failure, provider unavailability
- The plan has reached the point where remaining issues are architectural framing questions, not specification defects

### Summary

**Top 3 key issues:**
1. **`/{provider}` dispatch in skill Workflow Step 3 is described but not specified** — "dispatch using `/{provider}`" is a named behavior, not a defined mechanism; an implementer of the orchestrator that executes the skill needs to know what this means mechanically
2. **Skill invocation entry point is ambiguous** — the user-facing command is never defined; a user reading the skill file cannot determine what to type to invoke it
3. **Purpose section 5-item description vs. 6-step Workflow creates minor confusion** — not incorrect but structurally inconsistent in how steps are enumerated

**Consensus Status**: NEEDS_REVISION

---

## Round 5 — 2026-04-04

### Overall Assessment
All five Round 4 issues are resolved: provider dispatch is now mechanistically described, entry point is clearly separated into primary and direct-invocation paths, Purpose section correctly enumerates 6 steps, first-round header instruction is unambiguous, and the User-Facing Effect section gives the plan a proper external contract. The plan is now thorough and internally consistent. However, two new issues surface from the additions made in this round: the User-Facing Effect references `/speckit.peer.review` but the extension.yml registers the skill as `plan-review`, creating a potential routing mismatch; and the skill file's Workflow Step 3 now describes a human-like task delegation that does not reflect how an actual AI orchestrator would mechanically implement `/{provider}` dispatch.

**Rating**: 9/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 21 | `/{provider}` dispatch described but not specified | **Resolved** | Appendix A line 313 now describes "passing the review prompt as a task to the resolved provider" |
| 22 | Skill invocation entry point ambiguous | **Resolved** | Appendix A lines 259-272 separate primary entry point from direct dispatch |
| 23 | Purpose section says 5 steps but Workflow has 6 | **Resolved** | Appendix A Purpose now correctly lists 6 numbered items |
| 24 | First-round header instruction ambiguous | **Resolved** | Appendix A line 335 explicitly handles first-round vs. subsequent rounds |
| 25 | Plan lacks user-facing summary / circular description | **Resolved** | Plan line 13 adds User-Facing Effect section |
| 1-20 | (all prior issues) | **Resolved** | See R1-R4 tracking tables |

### Issues

#### Issue 26 (High): User-Facing Effect references `/speckit.peer.review` but extension.yml registers `plan-review`
**Location**: Plan line 13 — User-Facing Effect; Appendix A lines 259-263 — primary entry point examples; extension.yml line 201 — skill declaration

The User-Facing Effect (line 13) says: "running `/speckit.peer.review <path>` (file mode) or directly invoking the `plan-review` skill". The Usage section's primary entry point (lines 259-263) shows examples as `/speckit.peer.review plans/my-feature-plan.md`.

However, the extension.yml (Step 3) registers the skill as `plan-review` under `provides.skills`. It does NOT register `speckit.peer.review` — that would be the name of a command, not a skill. If a user types `/speckit.peer.review <path>`, the peer pack's command router must route that to the `plan-review` skill — but the plan never describes this routing. The user-facing command and the registered skill name are decoupled without an explicit link.

If the peer pack's convention is that commands live in `packs/peer/commands/` and skills in `shared/skills/`, then `/speckit.peer.review` might be a command that invokes the skill — but this relationship is never described in the plan.

**Suggestion**: In the User-Facing Effect and the primary entry point in the Usage section, clarify the routing: "`/speckit.peer.review` is the peer pack command; it invokes the `plan-review` skill registered in `extension.yml`. The command is not the skill." Or, if the skill is directly invokable as `/plan-review <file>`, use that consistently everywhere instead of `/speckit.peer.review`.

---

#### Issue 27 (Medium): "Pass as a task to the resolved provider" is an AI-human description, not a mechanical specification
**Location**: Appendix A line 313 — "Invoke the provider agent by passing the review prompt below as a task to the resolved provider (e.g., `/codex` means Claude invokes the Codex provider agent with the prompt as its task description)"

The phrase "passing the review prompt as a task to the resolved provider" describes how a human might conceptually delegate work to another agent — it is not a mechanical specification of what actually happens when `/{provider}` dispatch occurs. Terms like "provider agent," "task description," and "Claude invokes the Codex provider agent" imply a specific multi-agent architecture that may not match the actual implementation.

The original phrasing "dispatch using `/{provider}` skill (e.g., `/codex`)" was abstract but neutral — it didn't assume a particular internal architecture. The new phrasing is more concrete but potentially wrong for certain implementations of the dispatch mechanism. If the orchestrator is itself codex or opencode (not Claude delegating to them), this description creates a false model.

**Suggestion**: Revert to a phrasing that is implementation-neutral but still informative: "Invoke the provider by sending it the review prompt via the `/{provider}` dispatch mechanism (e.g., `/codex` routes to the Codex agent with the prompt as input). The provider writes its review to the review file and returns its output, from which `session_id` is extracted." This preserves the dispatch reference without committing to a specific agent architecture.

---

#### Issue 28 (Low): Step 1 mkdir error path doesn't match Step 2's error line format
**Location**: Step 1 line 108 vs. Appendix A line 307

Step 1 (line 108) says: "If the review file already exists, this is not the first round; instruct the provider to track prior issue resolution status." But Appendix A line 307 says the mkdir error uses: "Emit `[plan-review] ERROR: VALIDATION_ERROR: cannot create reviews directory: <reviews-dir>` and exit `5`."

Step 1 line 106 says: "Resolve `plan-file-path` to an absolute path. If the file does not exist or is empty, emit `[plan-review] ERROR: VALIDATION_ERROR: <reason>` and exit `5`."

These match. But Step 1 line 108 doesn't mention mkdir error handling at all — the mkdir check is only in Appendix A. This creates an inconsistency: Step 1 describes mkdir as just "Run `mkdir -p <reviews-dir>` before writing" without error handling, while Appendix A adds the error check. An implementer reading only Step 1 would not include the error check.

**Suggestion**: In Step 1 line 108, after "Run `mkdir -p <reviews-dir>` before writing", add: "If `mkdir -p` fails, emit `[plan-review] ERROR: VALIDATION_ERROR: cannot create reviews directory` and exit `5`." This matches Appendix A line 307.

---

#### Issue 29 (Low): "Ask the user whether another round is needed" for MOSTLY_GOOD is underspecified
**Location**: Appendix A lines 385-386 — "MOSTLY_GOOD | Revise plan, ask user whether another round is needed"

The skill's Step 5 says that on `MOSTLY_GOOD`, it should "ask the user whether another round is needed." But:
- What happens if the user says "yes"? Does the workflow loop back to Step 3?
- What happens if the user says "no"? Does it proceed to Step 6?
- Is this an interactive prompt? If so, how is it surfaced?
- Does it exit with code 0 in both cases?

For `NEEDS_REVISION` the plan explicitly says "invoke provider again (back to Step 3)." For `MOSTLY_GOOD` the plan doesn't specify what "ask the user" produces behaviorally. This asymmetry could lead to inconsistent implementations.

**Suggestion**: Add to the `MOSTLY_GOOD` row: "If the user requests another round, invoke provider again (back to Step 3). If the user declines, proceed to Step 6 (Wrap-up report). The 'ask' is an interactive prompt surfaced to the user by the orchestrator; exit 0 on both confirmation and declination."

---

#### Issue 30 (Low): Step 1 Step 2 description doesn't mention `provider` binding behavior
**Location**: Step 1 line 88 vs. Appendix A lines 276-279

Step 1 (line 88) says the skill file should have a "**Usage** — both invocation styles, provider resolution order, and concrete examples from D2." But Step 1 does NOT describe how the `provider` binding works in the context of the skill file's execution — specifically, that the skill applies the `--provider` flag at resolution time, not at invocation time.

The provider resolution order (flag → positional → default) is stated in D2 and in the Usage section, but Step 1 doesn't instruct the implementer to include this detail in the skill file's content description. Since Step 1 is supposed to be the recipe for building the skill file, if the implementer only reads Step 1 they might not realize the skill file needs to document the resolution order explicitly.

**Suggestion**: In Step 1 line 88, expand "both invocation styles, provider resolution order, and concrete examples from D2" to explicitly mention "including flag-wins resolution order and the session_id extraction fallback behavior."

---

### Positive Aspects
- All five Round 4 issues are cleanly resolved with substantive changes, not cosmetic ones
- The User-Facing Effect section (line 13) is exactly what was needed to give the plan an external contract
- Provider dispatch Step 3 is now mechanistically described ("passing the prompt as a task") even if some implementation-specific framing remains (see Issue 27)
- The distinction between primary entry point (via peer pack command) and direct provider dispatch is now clearly articulated
- The plan has reached a state where remaining issues are refinements, not structural gaps — it is close to implementation-ready

### Summary

**Top 3 key issues:**
1. **`/speckit.peer.review` vs. `plan-review` naming mismatch** — User-Facing Effect and Usage primary entry point use `/speckit.peer.review` but extension.yml registers `plan-review`; the routing between command name and skill name is never explained
2. **"Pass as a task to the resolved provider" is too human-conceptual** — describes a multi-agent delegation model that may not match actual implementation; should be rephrased to be architecture-neutral
3. **Step 1 and Appendix A mkdir error handling inconsistent** — Step 1 omits the mkdir error check that Appendix A includes; an implementer reading only Step 1 would miss it

**Consensus Status**: NEEDS_REVISION

---

## Round 6 — 2026-04-04

### Overall Assessment
All five Round 5 issues are resolved: routing is clarified, provider dispatch phrasing is improved, mkdir error handling is consistent between Step 1 and Appendix A, MOSTLY_GOOD interaction is fully specified, and Step 1 Usage description now covers all required details. The plan is at its most complete it has been. Two residual issues remain: the verification step's invocation method is ambiguous in a subtle way (it says to invoke without external skill installed but the peer pack routing makes this confusing), and the User-Facing Effect does not specify what the user types to invoke the workflow — the primary entry point is named but the command syntax is absent.

**Rating**: 9/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 26 | `/speckit.peer.review` vs. `plan-review` routing mismatch | **Resolved** | Lines 13-15 add Routing note; Step 1 line 102 mentions command/skill distinction |
| 27 | "Pass as a task" too human-conceptual | **Resolved** | Appendix A line 315 now uses "sending it the review prompt via the `/{provider}` dispatch mechanism" |
| 28 | Step 1 mkdir error handling inconsistent | **Resolved** | Step 1 line 110 now includes the error check |
| 29 | MOSTLY_GOOD "ask user" underspecified | **Resolved** | Step 1 line 177 and Appendix A line 388 fully specify the interaction |
| 30 | Step 1 doesn't mention provider binding behavior | **Resolved** | Step 1 line 102 explicitly covers flag-wins resolution and session_id fallback |
| 1-25 | (all prior issues) | **Resolved** | See R1-R5 tracking tables |

### Issues

#### Issue 31 (Medium): Step 4 verification invocation is ambiguous
**Location**: Step 4 line 214 — "Invoke the workflow on a real plan file... without the external `/plan-review` skill installed"

The verification step says to invoke the workflow "without the external `/plan-review` skill installed." But after Step 2 updates Step 1.1a to load the internal skill, the external skill's presence or absence is irrelevant to the new workflow — Step 1.1a no longer calls it. The external skill could still be installed and the internal workflow would still work.

The more precise intent is: invoke the workflow via the peer pack command (which now uses the internal skill), and confirm it works without needing the external skill to be installed as a fallback. But Step 4 doesn't say which invocation path to use — it says "invoke the workflow" without specifying whether that means `/speckit.peer.review`, `/plan-review`, or the updated Step 1.1a directly.

**Suggestion**: In Step 4 line 214, replace "Invoke the workflow on a real plan file" with "Invoke the workflow via the updated Step 1.1a path (i.e., the peer pack command that now loads `shared/skills/plan-review.md`), not via the external `/plan-review` skill."

---

#### Issue 32 (Low): User-Facing Effect names two entry points but doesn't give command syntax for either
**Location**: Plan lines 13-15

The User-Facing Effect says `/speckit.peer.review <path>` "causes the peer pack command to route to the bundled skill" and `/plan-review <path>` "also works once the pack is loaded." But neither is given with argument syntax:
- What are the actual arguments? Is it just `<path>` or `<path> [--provider <name>]`?
- Which is the recommended primary entry point?
- Does `/plan-review` require the pack to be pre-loaded, and if so how?

The Routing note (line 15) clarifies the relationship between the two, but the user-facing invocation syntax is still absent from the plan entirely.

**Suggestion**: Add to the User-Facing Effect: "Command syntax: `/speckit.peer.review <plan-file> [--provider <name>]` (primary) or `/plan-review <plan-file> [--provider <name>]` (direct)."

---

#### Issue 33 (Low): Exit code `0` description doesn't cover the MOSTLY_GOOD-with-user-decline path
**Location**: Appendix A lines 410-412 — "Success (terminal consensus reached)"

Exit code `0` is defined as "Success (terminal consensus reached)" which maps to the `APPROVED` consensus. However, the workflow also exits `0` when `MOSTLY_GOOD` is reached and the user declines another round (per the now-specified Step 5 / Appendix A Step 5 behavior). This is a normal termination but not "terminal consensus reached" — the user chose to stop, not the provider.

If a caller interprets exit `0` as "provider approved the plan," they will misinterpret the MOSTLY_GOOD-with-decline case.

**Suggestion**: Change exit code `0` description from "Success (terminal consensus reached)" to "Success (workflow completed; terminal consensus reached or user declined further rounds)."

---

#### Issue 34 (Low): Step 4 validation doesn't test the actual bundling concern
**Location**: Step 4 lines 214-215

The validation step runs the workflow on `docs/plans/bundle-plan-review-skill.md` and confirms a review file is created. This tests that the skill works, but it doesn't test the specific concern this bundle is meant to address: whether the peer pack works when the external `/plan-review` skill is NOT installed. The validation should explicitly confirm this scenario — not just that the skill works, but that the external dependency has been eliminated.

**Suggestion**: Expand Step 4 item 1: "Confirm the external `/plan-review` skill is not installed in `~/.claude/skills/`. Invoke the workflow via the peer pack command. Confirm it succeeds using only the internal `shared/skills/plan-review.md` skill."

---

#### Issue 35 (Low): Step 2 update's replacement text is not the full Step 1.1a content
**Location**: Step 2 lines 192-194 — the "With:" block

The Step 2 replacement block shows what to say in the new Step 1.1a: "Load `shared/skills/plan-review.md` as an instruction document..." But the existing `review.md` command file presumably has more content in Step 1.1a than just this one line — there may be surrounding context, other bullets in the step, or other steps. The plan only shows the replacement text, not the full Step 1.1a after the change.

An implementer updating Step 1.1a needs to know the complete new content of that step, not just the first sentence. If Step 1.1a contains multiple bullets and only one is being replaced, the plan should show the entire new step.

**Suggestion**: Either (a) show the complete new Step 1.1a as it would appear after the change, or (b) explicitly state that Step 1.1a consists only of the replaced line and nothing else.

---

### Positive Aspects
- All 30 issues across Rounds 1-5 are resolved; the plan is structurally and specificationally complete
- Round 5's resolution of MOSTLY_GOOD interaction (user prompt, exit codes, branching) is the most technically precise addition yet
- The Routing note (lines 15) is a model of clarity — one sentence that resolves a whole class of confusion
- The consistent application of mkdir error handling across Step 1 and Appendix A shows careful cross-referencing
- The plan now reads as a complete implementation specification rather than a structural sketch

### Summary

**Top 3 key issues:**
1. **Step 4 verification invocation is ambiguous** — the step should explicitly say to invoke via the updated Step 1.1a path, not just "invoke the workflow"; the external skill's presence/absence is now irrelevant to the new routing
2. **User-Facing Effect names entry points without giving command syntax** — users need to know `/speckit.peer.review <plan-file> [--provider <name>]` not just that the command "routes to the skill"
3. **Exit code 0 description doesn't cover the MOSTLY_GOOD-with-decline path** — this is a caller-facing contract issue; any script consuming exit codes will misinterpret it

**Consensus Status**: NEEDS_REVISION (three Low-severity issues and one Medium; all addressable in a single revision pass; no blocking defects remain)

---

## Round 7 — 2026-04-04

### Overall Assessment
The plan has reached a high degree of completeness across six revision rounds. All 35 prior issues are resolved. Applying fresh eyes to the fully-formed specification, I find four residual issues that have survived prior rounds because they sit at the intersection of two sections — where one part of the plan specifies something that another part of the plan contradicts or ignores. These are not new conceptual problems but residual specification gaps at section boundaries: the mkdir error description still differs between Step 1 and Appendix A, the session reuse mechanism references `--session` throughout but D2's invocation examples never show it, and the skill file's frontmatter and invocation description use different conventions for describing the dispatch mechanism.

**Rating**: 9/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 31 | Step 4 verification invocation ambiguous | **Resolved** | Step 4 items 1-2 now explicitly invoke via peer pack command and confirm external skill absent |
| 32 | User-Facing Effect lacks command syntax | **Resolved** | Line 15 adds full syntax `[/speckit.peer.review \| /plan-review] <plan-file> [--provider <name>]` |
| 33 | Exit code 0 misses MOSTLY_GOOD-with-decline | **Resolved** | Appendix A line 417 updated to cover user-declined case |
| 34 | Step 4 validation doesn't test bundling concern | **Resolved** | Step 4 item 1 now explicitly tests absence of external skill |
| 35 | Step 2 replacement not full Step 1.1a | **Resolved** | Step 2 line 202 clarifies what's carried over vs. replaced |
| 1-30 | (all prior issues) | **Resolved** | See R1-R6 tracking tables |

### Issues

#### Issue 36 (Low): `mkdir -p` error description still differs between Step 1 and Appendix A
**Location**: Step 1 line 110 vs. Appendix A line 314

Step 1 line 110 says: `cannot create reviews directory` (no colon, no `<reviews-dir>`)
Appendix A line 314 says: `cannot create reviews directory: <reviews-dir>` (colon + placeholder)

This was partially addressed in R6 but only fixed in Appendix A. Step 1 was not updated to match. An implementer reading only Step 1 will write a different error message than what the skill file specifies.

**Suggestion**: Change Step 1 line 110 to: `cannot create reviews directory: <reviews-dir>` to match Appendix A.

---

#### Issue 37 (Low): `--session` is used in Session Reuse but never shown in D2 invocation examples
**Location**: D2 lines 27-39 (invocation examples) and Session Reuse throughout

D2 specifies the resolution order and gives concrete examples of `/{provider} <file>` invocations, but none of the examples include `--session`. The Session Reuse section (Step 1 line 106 and Appendix A line 296) says to "pass `--session <id>` in subsequent rounds." A user reading D2's examples will not see `--session` mentioned at all, and might reasonably assume `--session` is not part of the syntax.

This is particularly confusing because `--session` is a first-class parameter that affects behavior, not an internal detail.

**Suggestion**: Add a D2 example showing `--session` usage: `/codex plans/foo.md --provider opencode --session abc123` → provider=opencode, file=plans/foo.md, session=abc123. And clarify that `--session` is optional and only used in subsequent rounds.

---

#### Issue 38 (Low): Step 6 Wrap-up report doesn't specify exit code
**Location**: Step 1 line 183 — "Report to user: rounds completed..." and Appendix A line 399-400 — same text

Both the Step 1 Workflow Step 6 description and the Appendix A Step 6 description tell the skill to "report to user" the wrap-up information, but neither specifies the exit code. The Exit Codes table shows exit `0` for success, but this is not connected to Step 6's wrap-up behavior. An implementer could reasonably write a Step 6 that does not exit at all (just prints and returns), which would leave the process hanging or with an undefined exit code.

**Suggestion**: Add to Step 6 description in both Step 1 and Appendix A: "Then exit `0`."

---

#### Issue 39 (Low): Skill file frontmatter says "provider dispatch" but D1 says `/{provider}` skill dispatch — naming not reconciled
**Location**: Appendix A frontmatter (line 249) — "provider dispatch" vs. D1 line 24 — `/{provider}` skill dispatch

D1 names the mechanism "`/{provider}` skill dispatch." The skill file's frontmatter description says "with provider dispatch." The Usage section (line 281) also says "`/{provider} <plan-file>` dispatch (D1)." So the term used in the frontmatter ("provider dispatch") is a shorthand for the `/{provider}` convention, but this is never explicitly stated. A reader could reasonably think "provider dispatch" means something different from "`/{provider}` skill dispatch."

**Suggestion**: Change frontmatter description to: "Adversarial iterative review of any plan file with `/{provider}` skill dispatch, independent of spec feature context." Or add to Usage: "The `/{provider}` dispatch mechanism described in D1 is referred to in this skill as 'provider dispatch' for brevity."

---

### Positive Aspects
- All 35 prior issues resolved across 6 rounds — a thorough and disciplined revision process
- Step 4 verification is now a model implementation step: explicit external-dependency check, peer pack command invocation, artifact cleanup
- Command syntax in the User-Facing Effect is exactly the right level of detail
- Exit code 0 description covering the user-declined case is precise and caller-safe
- The plan reads as a professional implementation specification at this point

### Summary

**Top 3 key issues:**
1. **`mkdir -p` error description still differs between Step 1 and Appendix A** — Step 1 line 110 omits the colon and `<reviews-dir>` that Appendix A line 314 includes; the R6 fix was only applied to Appendix A
2. **`--session` used throughout but never shown in D2 examples** — the session reuse mechanism is specified but invisible in the invocation syntax examples; users won't know `--session` is part of the interface
3. **Step 6 Wrap-up report doesn't specify exit code** — both Step 1 and Appendix A describe what to report but not that the process should exit `0`; undefined exit behavior could leave processes hanging

**Consensus Status**: NEEDS_REVISION (four Low-severity issues, all single-line fixes; no structural or specification defects remain)

---

## Round 8 — 2026-04-04

### Overall Assessment
All four Round 7 issues are resolved: mkdir error text is consistent, D2 includes the `--session` example, Step 6 specifies `exit 0`, and frontmatter uses `/{provider}` skill dispatch. After a thorough line-by-line pass comparing Step 1 against Appendix A, all sections are consistent and complete. The plan now has all 39 prior issues resolved across 7 rounds. Four new observations surface, all at the Suggestion/Low boundary: BLOCKED has no explicit exit code (the halt is specified behaviorally but not numerically), PARSE_FAILURE's "marker" detection is unspecified, the "If rejecting a suggestion" behavior in Step 4 has no error path, and the `---` backtick formatting around the divider in the prompt template is inconsistent with surrounding backtick usage.

**Rating**: 9.5/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 36 | `mkdir -p` error description differs between Step 1 and Appendix A | **Resolved** | Step 1 line 113 now includes `: <reviews-dir>` to match Appendix A line 315 |
| 37 | `--session` never shown in D2 examples | **Resolved** | D2 line 40 now includes explicit `--session` example with annotation |
| 38 | Step 6 doesn't specify exit code | **Resolved** | Step 1 line 184 and Appendix A line 408 both say "Then exit `0`" |
| 39 | Frontmatter "provider dispatch" vs D1 `/{provider}` naming | **Resolved** | Appendix A line 250 frontmatter now uses `/{provider}` skill dispatch |
| 1-35 | (all prior issues) | **Resolved** | See R1-R7 tracking tables |

### Issues

#### Issue 40 (Suggestion): BLOCKED has no explicit exit code
**Location**: Step 5 / Appendix A Step 5 consensus table — "BLOCKED | Halt immediately..."

BLOCKED is specified as "halt immediately, do not revise plan, do not invoke provider again." The halt behavior is clear, but no exit code is specified. The Exit Codes table doesn't include a code for BLOCKED. Should BLOCKED exit 0 (normal halt) or something else (e.g., exit 4 which is "reserved for artifact-mode")?

If BLOCKED means "human must intervene," a non-zero exit code makes sense for scripting callers. But if BLOCKED is treated as a normal workflow termination (user chose to stop), exit 0 is appropriate.

**Suggestion**: Add to the BLOCKED row: "Exit `4` (or document why it exits `0` if that is the intent)."

---

#### Issue 41 (Suggestion): PARSE_FAILURE "consensus status marker" is undefined
**Location**: D8 line 71 — "PARSE_FAILURE — consensus status marker absent after provider ran"

The exit code 8 condition is "consensus status marker absent after provider ran." But nowhere in the plan is the format of this marker defined. The provider prompt asks the provider to write `**Consensus Status**: NEEDS_REVISION / MOSTLY_GOOD / APPROVED / BLOCKED` in the Summary section. Is the marker detection:
- Looking for the literal bold text `**Consensus Status**: APPROVED`?
- Looking for the word `APPROVED` anywhere in the file?
- Looking for `[Consensus Status: APPROVED]` as a dedicated tag?
- Something else?

An implementer writing the parse logic must guess this.

**Suggestion**: Define the marker format: "The skill searches the provider's output for one of the four consensus status values (`NEEDS_REVISION`, `MOSTLY_GOOD`, `APPROVED`, `BLOCKED`) appearing within a `**Consensus Status**:` line in the review file. If none are found, exit `8`."

---

#### Issue 42 (Suggestion): Step 4 "If rejecting a suggestion" has no failure path
**Location**: Step 1 line 172 / Appendix A line 387 — "If rejecting a suggestion, note the reason briefly in the plan. Never create a new plan file; edit in place."

What happens if writing the rejection reason to the plan file fails (e.g., disk full, permission error)? The plan doesn't specify an error code or behavior. This is a silent gap in error handling.

**Suggestion**: Add: "If the plan file cannot be written to (e.g., disk full, permission error), emit `[plan-review] ERROR: VALIDATION_ERROR: cannot write to plan file: <plan-path>` and exit `5`."

---

#### Issue 43 (Suggestion): Prompt template `---` formatting is inconsistent
**Location**: Step 1 line 142 — "Separate rounds with `---`" (has backticks) vs. Appendix A line 354 — "Separate rounds with --- and append new rounds" (no backticks)

The Step 1 prompt template instruction says "Separate rounds with `---`" (with backticks). The Appendix A prompt template says "Separate rounds with ---" (no backticks). These should match. The backtick form is more correct since `---` is a markdown element, not a command.

**Suggestion**: Change Appendix A line 354 to "Separate rounds with `---` and append new rounds" to match Step 1.

---

### Positive Aspects
- All 39 prior issues resolved across 7 rounds — an impressively thorough revision process
- Every cross-reference between Step 1 and Appendix A is now consistent: frontmatter, mkdir error, Step 6 exit, `--session` examples, `/{provider}` naming
- The plan is at the boundary of what a specification can achieve without being the actual implementation
- Step 4 verification remains the standout implementation step: explicit, testable, with rollback
- Exit codes are comprehensive and well-documented; the reserved code explanations prevent consumer confusion

### Summary

**Top 3 key issues:**
1. **BLOCKED has no explicit exit code** — behavioral spec exists (halt immediately) but no numeric code; could be exit 4, exit 0, or undefined
2. **PARSE_FAILURE "consensus status marker" is undefined** — the detection format is left entirely to the implementer to infer from context
3. **Step 4 plan-write failure path is undefined** — rejection notes are specified but the write-failure error handling is not

**Consensus Status**: MOSTLY_GOOD (four Suggestion/Low items, none blocking; the plan is ready for implementation with the understanding that these minor items may be addressed during implementation or in a follow-up)

---

## Round 9 — 2026-04-04

### Overall Assessment
The plan is mature and internally consistent in most places, and Round 8’s four issues are addressed. A deeper adversarial pass still finds several execution-contract gaps: consensus parsing can false-pass by matching older rounds, usage examples do not fully reflect supported entry points, and a few spec statements diverge between decisions and the embedded skill file. These are fixable but should be tightened before implementation to avoid ambiguous behavior.

**Rating**: 8.8/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 40 | BLOCKED has no explicit exit code | **Resolved** | D8 line 72 and Appendix A line 427 define `BLOCKED` as exit `9` |
| 41 | PARSE_FAILURE marker undefined | **Resolved** | D8 line 71 / Appendix A line 426 now define `**Consensus Status**: <VALUE>` marker |
| 42 | Step 4 rejection/write failure path undefined | **Resolved** | Step 4 line 174 and Appendix A line 388 now define write-failure handling with exit `5` |
| 43 | Prompt template divider formatting inconsistent | **Resolved** | Step 1 line 143 and Appendix A line 355 both use backticked `---` |
| 1-39 | (all prior issues) | **Resolved** | Per Round 8 tracking and current file state |

### Issues

#### Issue 44 (High): PARSE_FAILURE rule can false-pass by matching older rounds
**Location**: D8 line 71 and Appendix A line 426

The parse rule says to search the review file for a line matching `**Consensus Status**: <VALUE>`. In a multi-round file, this can succeed even if the latest appended round is malformed, because older rounds already contain valid consensus lines. That creates a silent false-positive and can incorrectly advance the workflow.

**Suggestion**: Require parsing only the latest round segment (from the last `## Round` heading to EOF) and validate exactly one consensus line there. If absent or invalid in that segment, exit `8`.

---

#### Issue 45 (Medium): Exit code `5` description is narrower than actual behavior
**Location**: D8 line 67 vs Appendix A line 425

D8 defines `VALIDATION_ERROR` to include plan write failure. Step 2/Step 4 also include mkdir/write failures under exit `5`. Appendix A’s Exit Codes table describes code `5` only as file-not-found/empty/unresolvable path, omitting mkdir and write-failure cases. This creates a caller-facing contract mismatch.

**Suggestion**: Update Appendix A code `5` row to include directory creation and plan write failures (e.g., “file/path validation, review dir creation failure, or plan write failure”).

---

#### Issue 46 (Medium): Direct `/plan-review` entry point is declared but not exemplified in skill usage
**Location**: Plan line 15 and Appendix A Usage lines 266-283

Top-level plan text documents two entry points: `/speckit.peer.review` and `/plan-review`. Appendix A Usage shows `/speckit.peer.review` plus provider dispatch (`/codex`, `/opencode`) but no `/plan-review` examples. That leaves the published interface incomplete where users are most likely to look.

**Suggestion**: Add explicit Usage examples for `/plan-review <plan-file>` and `/plan-review <plan-file> --provider <name>`, with a short note that it routes through the same skill workflow.

---

#### Issue 47 (Low): `--session` support is documented in decisions but missing from Appendix Usage examples
**Location**: D2 line 40 vs Appendix A examples lines 290-295

D2 includes an explicit `--session` example and states it is optional for subsequent rounds. Appendix A’s example list omits `--session`, which can cause implementers and users to miss the feature in practice.

**Suggestion**: Add one Appendix Usage example including `--session` and note “optional; only for continuation rounds.”

---

#### Issue 48 (Medium): Round-append instruction is structurally ambiguous
**Location**: Appendix A lines 344-345

The prompt says to append subsequent rounds “after the last `---` divider.” In this file format, `---` is a separator before round sections, not a durable end-of-file anchor. “After last divider” can be interpreted inconsistently and risks malformed insertion when spacing varies.

**Suggestion**: Replace with a deterministic append rule: “append at EOF using `\n\n---\n\n## Round {N} — ...`” and compute `N` from existing round headings.

---

#### Issue 49 (Low): Rejection rationale is written into the plan file, mixing execution spec with review metadata
**Location**: Step 4 line 174 and Appendix A line 388

Step 4 says rejected suggestions should be noted “in the plan.” This introduces reviewer meta-commentary into the implementation plan itself, which can degrade plan readability and create churn unrelated to execution steps.

**Suggestion**: Record rejection rationale in the review log (latest round notes) instead of the plan file, while keeping the plan focused on executable implementation content.

---

### Positive Aspects
- Decision coverage (D1-D8) is comprehensive and now explicitly covers BLOCKED and parse/write error classes.
- Step 4 verification now tests true bundling behavior (external dependency absent) and includes cleanup.
- Step 1 and Appendix A are mostly synchronized, a major improvement over early rounds.
- The review prompt format and severity model are clear and actionable for provider outputs.

### Summary

**Top 3 key issues:**
1. **Consensus parsing can false-pass** by matching older rounds instead of validating the latest round only.
2. **Exit code `5` contract mismatch** between decisions/workflow and Appendix Exit Codes table.
3. **Interface documentation drift** (`/plan-review` and `--session` are supported but incompletely shown in Appendix usage examples).

**Consensus Status**: NEEDS_REVISION

---

## Round 10 — 2026-04-04

### Overall Assessment
Round 9 issues 44-48 are now addressed with concrete spec updates (latest-round parse scope, expanded exit code `5`, direct `/plan-review` usage examples, `--session` example, and deterministic EOF append rule). Issue 49 is intentionally rejected, and the rationale is now explicitly documented in-plan as a conscious design choice. Despite that progress, several execution-contract gaps remain around direct invocation ownership, loop termination, round-index robustness, and validation safety.

**Rating**: 8.9/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 44 | PARSE_FAILURE can false-pass by matching older rounds | **Resolved** | D8 / Appendix Exit Codes now scope parsing to latest round segment |
| 45 | Exit code `5` contract mismatch | **Resolved** | Appendix Exit Codes now includes review-dir creation and plan write failure |
| 46 | `/plan-review` entry point not exemplified | **Resolved** | Appendix Usage now includes explicit `/plan-review` examples |
| 47 | `--session` missing from Appendix examples | **Resolved** | Appendix Usage now includes `--session` continuation example |
| 48 | Round-append instruction ambiguous | **Resolved** | Prompt now specifies deterministic EOF append with `\n\n---\n\n## Round {N}` |
| 49 | Rejection rationale location | **Rejected (Intentional)** | Plan explicitly keeps rejection rationale in-plan as intentional metadata |
| 1-43 | (all prior issues) | **Resolved** | Per R1-R9 tracking and current plan state |

### Issues

#### Issue 50 (High): Direct `/plan-review` invocation has no defined argument-binding owner
**Location**: Step 1 Step 3 line 116, Step 2 replacement block line 197, Appendix A Usage lines 281-291

The plan states that provider/plan path binding is done by invoking context and that the skill workflow does not re-parse arguments. That is coherent for `/speckit.peer.review` (which binds variables in `review.md`), but Appendix Usage also advertises direct `/plan-review ...` invocation without defining who binds `plan-file-path` and `provider` in that path. This leaves direct invocation behavior under-specified.

**Suggestion**: Add an explicit direct-invocation contract: either (a) `/plan-review` must parse and bind `plan-file-path`/`provider` itself, or (b) remove direct `/plan-review` from supported interfaces.

---

#### Issue 51 (Medium): Consensus loop has no termination guard
**Location**: Step 1 Step 5 lines 176-183, Appendix A Step 5 lines 398-405

The workflow can re-enter Step 3 indefinitely on repeated `NEEDS_REVISION`. There is no max-round cap, timeout budget, or escalation path. In practice, this can hang automation and produce unbounded churn on stubborn reviewers.

**Suggestion**: Define a hard stop (for example `max_rounds=5` default). On exhaustion, halt with explicit status (`BLOCKED` or `PROVIDER_TIMEOUT`) and non-zero exit.

---

#### Issue 52 (Medium): Round number derivation is vulnerable to false counts
**Location**: Step 1 prompt line 352, Appendix A prompt line 352

`N` is computed from “count of existing `## Round` headings plus one,” but the rule does not constrain what qualifies as a heading. The literal string can appear in quoted examples or fenced blocks, causing inflated numbering and malformed history.

**Suggestion**: Specify anchored heading parsing (for example `^## Round [0-9]+ — ` on non-fenced lines only) when computing `N`.

---

#### Issue 53 (Medium): Validation step requires mutating global user environment
**Location**: Step 4 verification line 222

The plan requires confirming external `/plan-review` is not installed (or temporarily removing it) from `~/.claude/skills/`. That is an out-of-repo side effect, not always permitted in CI/shared environments, and can disrupt unrelated workflows.

**Suggestion**: Replace with a non-destructive verification method (for example isolate skill search path for the test run, or assert bundled-skill resolution precedence via trace/log output).

---

#### Issue 54 (Medium): Rollback instruction is overly broad for dirty worktrees
**Location**: Step 4 verification line 228

“Rollback all three changes (restore originals from version control)” is unsafe when files are pre-dirty or have concurrent edits. It can accidentally discard unrelated local modifications in those files.

**Suggestion**: Scope rollback to this change set only (patch-level revert), and require preserving unrelated pre-existing edits.

---

#### Issue 55 (Low): PARSE_FAILURE rule can false-fail on duplicate consensus lines
**Location**: D8 line 71 (“exactly one line matching `**Consensus Status**: <VALUE>` in latest segment)

Requiring exactly one marker line is brittle: the latest segment can legitimately contain two marker-like lines (for example quoted template text plus actual summary), causing avoidable exit `8` even when a valid final status exists.

**Suggestion**: Parse the last valid `**Consensus Status**:` line in the latest round summary block, and treat additional matches as a warning, not hard failure.

---

### Positive Aspects
- Round 9 high/medium concerns were addressed with concrete, testable text updates.
- Prior-issue tracking discipline is strong; historical continuity is clear.
- Exit-code mapping is now substantially clearer and closer to executable behavior.
- Step 1 and Appendix A remain highly synchronized compared to early rounds.

### Summary

**Top 3 key issues:**
1. **Direct `/plan-review` ownership gap**: argument binding is undefined outside `review.md` orchestration.
2. **No loop guard**: repeated `NEEDS_REVISION` can run indefinitely with no explicit stop policy.
3. **Verification safety concerns**: global skill mutation and broad rollback instructions are risky in real environments.

**Consensus Status**: NEEDS_REVISION

---

## Round 11 — 2026-04-04

### Overall Assessment
Round 10 issues 50-55 are addressed as claimed: direct `/plan-review` now has an explicit binding owner, loop-guard guidance is present in both Step 5 blocks, round-count matching is anchored to non-fenced lines, validation moved to a shadow/non-destructive approach, rollback scope is narrowed to three files, and PARSE_FAILURE now uses last-match semantics. A fresh adversarial pass still finds execution-contract gaps in validation determinism, parser strictness, rollback completeness, and failure-recovery behavior.

**Rating**: 8.9/10

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 50 | Direct `/plan-review` invocation has no argument-binding owner | **Resolved** | Appendix Usage now defines explicit binding contract for direct `/plan-review` |
| 51 | Consensus loop has no termination guard | **Resolved** | Loop guard note added in both Step 5 instances |
| 52 | Round number derivation vulnerable to false counts | **Resolved** | Round count now anchored to `^## Round [0-9]+ — ` on non-fenced lines |
| 53 | Validation required mutating global environment | **Resolved (Partially, narrowed risk)** | Step 4 now allows shadow/log-based verification instead of requiring uninstall |
| 54 | Rollback instruction overly broad | **Resolved** | Rollback explicitly scoped to only the three files changed by this plan |
| 55 | PARSE_FAILURE false-fails on duplicate markers | **Resolved** | D8 now uses last valid marker in latest segment rather than exactly-one |
| 1-49 | (all prior issues) | **Resolved / Intentional where noted** | Per R1-R10 tracking and current file state |

### Issues

#### Issue 56 (High): Step 4 triggers the workflow twice, creating ambiguous validation side effects
**Location**: Implementation Step 4 items 1-2

Step 4 item 1 already says to invoke `/speckit.peer.review ...`, and item 2 immediately instructs invoking the same command again. This can create two appended rounds or two validation artifacts, making pass/fail attribution ambiguous and adding avoidable noise.

**Suggestion**: Collapse Step 4 to a single invocation path with a single expected artifact lifecycle (create -> verify -> cleanup), and remove the duplicate invoke instruction.

---

#### Issue 57 (High): “Shadow or logs/trace” verification is non-deterministic and not acceptance-testable
**Location**: Implementation Step 4 item 1 (“temporarily rename or shadow ... or assert in logs/trace output”)

The step provides multiple mutually different proof strategies but does not define which one is required or what constitutes sufficient evidence. Different implementers can pass validation with incompatible standards.

**Suggestion**: Define one mandatory evidence path (for example, require a trace line proving `shared/skills/plan-review.md` was resolved) and treat other methods as optional troubleshooting only.

---

#### Issue 58 (Medium): Consensus regex is not end-anchored, allowing malformed statuses to pass
**Location**: D8 PARSE_FAILURE pattern `^\\*\\*Consensus Status\\*\\*: (NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)`

The pattern anchors only at line start. A line like `**Consensus Status**: APPROVED but pending` can still match and be accepted as valid, weakening parser strictness.

**Suggestion**: End-anchor and whitespace-normalize the parser pattern, e.g. `^\\*\\*Consensus Status\\*\\*: (NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)\\s*$`.

---

#### Issue 59 (Medium): Round-index parser and consensus parser use different exclusion rules
**Location**: Prompt rule for `{N}` computation vs D8 parse rule

`{N}` is computed from non-fenced lines only, while D8 explicitly excludes both fenced and quoted lines. This inconsistency leaves round counting vulnerable to quoted `## Round ...` lines, even though consensus parsing already guards that case.

**Suggestion**: Align both rules by excluding quoted lines for round-index counting as well (or define one shared parser contract used by both operations).

---

#### Issue 60 (Medium): Rollback command cannot fully restore when created file was previously untracked
**Location**: Implementation Step 4 rollback instruction (`git checkout HEAD -- <file>`)

For newly created files (for example `shared/skills/plan-review.md` in a repo where it did not previously exist), `git checkout HEAD -- <file>` may fail or leave the untracked file in place. The rollback contract claims “pre-change state” but does not guarantee it.

**Suggestion**: Define rollback by pre-change existence: restore tracked files from HEAD, and explicitly remove files that were newly created by this plan.

---

#### Issue 61 (Low): PROVIDER_EMPTY_RESPONSE path lacks cleanup guidance for partial review-file writes
**Location**: D3 enforcement text + Step 3 provider-write behavior

D3 says to exit `3` if fewer than 5 findings, but Step 3 also says the provider writes the round to the review file. If a partial/invalid round is already appended, no cleanup/remediation policy is defined, and subsequent rounds inherit a polluted history.

**Suggestion**: Define failure handling for short responses: either require provider output validation before append, or mandate rolling back the last appended round on `PROVIDER_EMPTY_RESPONSE`.

---

### Positive Aspects
- The plan continues to improve in traceability, with strong continuity from prior rounds.
- The direct `/plan-review` contract is now explicit and much more implementable.
- Latest-round parsing scope and last-match logic materially reduce prior false-positive/false-failure modes.
- Rollback scope is now localized to planned files instead of broad repository rollback.

### Summary

**Top 3 key issues:**
1. **Validation determinism gap**: Step 4 currently duplicates invocation and allows non-uniform proof paths.
2. **Parser strictness gap**: consensus regex can accept malformed status lines without end anchoring.
3. **Rollback/recovery gap**: current rollback and short-response handling do not fully guarantee clean pre-change or pre-round state.

**Consensus Status**: NEEDS_REVISION

---

## Round 15 — 2026-04-04

### Overall Assessment
After 14 rounds of adversarial review, the plan has addressed most structural gaps but retains significant implementation-contract issues in three areas: (1) drift between the Step 1 embedded workflow and Appendix A, (2) rollback semantics that can destroy pre-existing tracked edits, and (3) underspecified detection and failure conditions in the new validation step. The core design is sound but the precision required for deterministic implementation is not yet achieved.
**Rating**: 8.7/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 73 | Self-modifying validation | Resolved | Temp copy used; hash check added |
| 74 | Global failure handler | Resolved | Added to Step 4 |
| 75 | PARSE_FAILURE not guarded | Resolved | Both Step 4 instances updated |
| 76 | Evidence contract undefined | Resolved | stdout message pattern defined |
| 77 | Provider append fallback | Resolved | Orchestrator fallback added |

### Issues

#### Issue 78 (High): Step 1 workflow and Appendix A are no longer behaviorally equivalent (contract drift)
**Location**: Step 1 workflow Step 4 bullet vs Appendix A Step 4
Step 1's embedded workflow and Appendix A Step 4 have diverged — the PARSE_FAILURE guard phrasing, BLOCKED handling, and fallback text are not identical, reintroducing dual truth sources.
**Suggestion**: Declare Appendix A as canonical and replace Step 1 workflow with a strict reference ("see Appendix A for full specification"), or perform a line-by-line sync to make them byte-equivalent.

#### Issue 79 (High): Rollback can destroy pre-existing tracked local edits in target files
**Location**: Step 4 rollback clause
Rollback prescribes `git checkout HEAD -- <file>` for tracked files. If those files already had local user edits before execution, this clobbers them.
**Suggestion**: Require pre-change snapshots for all to-be-modified files (tracked and untracked) and restore from snapshots, not from HEAD.

#### Issue 80 (Medium): New validation fail conditions are not bound to explicit exit codes
**Location**: Implementation Step 4 item 1 — shadow restore failure, original plan mutated, evidence line missing
D8 does not map these three new conditions explicitly. "Fail validation" is operationally under-specified.
**Suggestion**: Add explicit mapping (exit `5` / `VALIDATION_ERROR`) for shadow-restore failure, plan hash mismatch, and evidence-line absence.

#### Issue 81 (Medium): External-skill shadow precondition is undefined when file does not exist
**Location**: Implementation Step 4 item 1
Validation assumes `~/.claude/skills/plan-review/SKILL.md` exists. On clean machines or CI without the external skill installed, this file may be absent.
**Suggestion**: Conditional shadowing: if file exists, shadow+restore; if absent, skip shadow and validate via evidence contract only.

#### Issue 82 (Medium): Provider fallback append detection is unspecified
**Location**: Step 3 provider file-write fallback (both instances)
The fallback triggers "if review file was not updated" but defines no detection algorithm (size/mtime/hash/round-marker). Implementations may diverge or double-append.
**Suggestion**: Define detection: compare pre/post byte size AND check for a new `^## Round` marker; only append on fallback if neither condition is met.

#### Issue 83 (Medium): Fixed `/tmp` validation path is collision-prone
**Location**: Implementation Step 4 item 1
Static temp path (`/tmp/bundle-plan-review-skill-validate.md`) collides in concurrent CI or multi-user environments.
**Suggestion**: Use `mktemp` (or equivalent) to generate a unique temp path; derive the review path from that unique basename.

### Positive Aspects
- Issues 73-77 all correctly resolved in this round
- The fallback-append contract (Issue 77) is well-scoped

### Summary
Top 3: (78) step/appendix contract drift, (79) rollback clobbers pre-existing edits, (82) fallback detection undefined
**Consensus Status**: NEEDS_REVISION

---

## Round 16 — 2026-04-04

### Overall Assessment
The plan has made significant progress addressing structural gaps, but three new high-severity issues emerged from the mktemp change: the review path assertion in step 4.2 is still hardcoded, the cleanup directory is hardcoded, and the fallback boolean logic has dangerous ambiguity. Additionally, the integrity check uses byte-size which misses same-size mutations, and exit code documentation omits new subconditions.
**Rating**: 8.6/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 78 | Contract drift | Resolved | Appendix A canonical; note added |
| 79 | Rollback clobbers edits | Resolved | Snapshot-based rollback added |
| 80 | Validation exit codes | Resolved | Explicit exit 5 mapping added |
| 81 | Shadow precondition | Resolved | Conditional shadowing added |
| 82 | Fallback detection | Resolved | Detection algorithm defined |
| 83 | Fixed /tmp path | Resolved | mktemp used |

### Issues

#### Issue 84 (High): Validation review path is still hardcoded despite mktemp change
**Location**: Implementation Step 4 item 2
Item 2 asserts review file at `docs/plans/reviews/bundle-plan-review-skill-validate-review.md`, but with mktemp the temp file lives in `/tmp/`; D6 would derive review path relative to temp location.
**Suggestion**: Replace hardcoded path check with "confirm review file at path derived from temp basename using D6 convention."

#### Issue 85 (High): Cleanup directory hardcoded to docs/plans/reviews/
**Location**: Implementation Step 4 item 4
With mktemp temp file in `/tmp/`, D6-derived review path is in `/tmp/reviews/` not `docs/plans/reviews/`. Cleanup targets the wrong directory.
**Suggestion**: Compute cleanup directory from the derived review path, not a fixed repo path.

#### Issue 86 (High): Provider fallback boolean is ambiguous for partial-update case
**Location**: Step 3 provider file-write fallback (both instances)
"If neither condition is met" triggers fallback, but if only one of (size increase / new round marker) is met, behavior is undefined.
**Suggestion**: Change to: fallback triggers unless **both** predicates are satisfied (size increased AND new round marker present).

#### Issue 87 (Medium): Shadow backup name is fixed and collision-prone
**Location**: Implementation Step 4 item 1 — `SKILL.md.bak`
Repeated or parallel runs overwrite the prior `.bak` file, destroying the restore source.
**Suggestion**: Use a unique backup path (e.g., `SKILL.md.bak.<pid>` or mktemp) and track the exact restore source path.

#### Issue 88 (Medium): Validation integrity check uses byte-size, not content hash
**Location**: Implementation Step 4 item 1 — "record byte size (or hash)"
Same-size content mutations (e.g., one sentence replaced with another of equal length) would pass the byte-size check.
**Suggestion**: Require content hash (sha256 or equivalent) as the normative integrity check; byte-size comparison can be a fast-fail pre-check only.

#### Issue 89 (Medium): D8 and Appendix A exit code table still omit new VALIDATION_ERROR subconditions
**Location**: D8 exit codes table and Appendix A Exit Codes section
Shadow-restore failure, evidence-line absence, and plan-integrity mismatch are not listed, leaving implementers without authoritative exit-code mapping.
**Suggestion**: Add explicit sub-bullets or notes under exit 5 in both D8 and Appendix A tables.

### Positive Aspects
- Issues 78-83 all cleanly resolved
- mktemp change (83) is a genuine improvement

### Summary
Top 3: (84) hardcoded review path, (85) hardcoded cleanup dir, (86) fallback boolean ambiguity
**Consensus Status**: NEEDS_REVISION

---

## Round 17 — 2026-04-04

### Overall Assessment
The plan is converging rapidly. Issues 84-89 are all resolved. Five new issues remain, but they are narrower in scope: two high-severity gaps in the validation evidence/shadow contract and three medium operational underspecifications. The core structure is sound and close to MOSTLY_GOOD.
**Rating**: 9.0/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 84 | Hardcoded review path | Resolved | Derived from temp basename |
| 85 | Hardcoded cleanup dir | Resolved | Derived from computed path |
| 86 | Fallback boolean ambiguity | Resolved | Clarified: triggers if at least one predicate false |
| 87 | Shadow backup collision | Resolved | mktemp unique backup path |
| 88 | Byte-size integrity | Resolved | sha256 normative check |
| 89 | Exit code subconditions | Resolved | Both D8 and Appendix A updated |

### Issues

#### Issue 90 (High): Validation success criteria can false-pass on stale/template content
**Location**: Implementation Step 4 item 3
Step 4.3 only checks for "5 issues and a Consensus Status line" without latest-round scoping or non-fenced/non-quoted parsing (unlike D8). Could pass using old rounds or embedded template text.
**Suggestion**: Reuse D8 parser rules in Step 4.3: require 5+ `#### Issue` entries and a valid `Consensus Status` line in the **latest round segment** only.

#### Issue 91 (High): Shadow creation failure path is not specified
**Location**: Implementation Step 4 item 1
Failure on shadow **restore** is defined, but failure during shadow **creation** (mktemp or mv failure before invocation) is not. This can silently invalidate the external-dependency proof.
**Suggestion**: Add pre-invocation check: if backup creation or shadow move fails, emit `VALIDATION_ERROR` and exit `5` before invoking the workflow.

#### Issue 92 (Medium): Fallback marker pattern is weaker than canonical round heading
**Location**: Step 3 provider fallback (both instances)
Fallback uses `^## Round [0-9]+` but canonical round heading format is `^## Round [0-9]+ — `. Mismatch permits false positives.
**Suggestion**: Align fallback predicate with exact canonical pattern `^## Round [0-9]+ — `.

#### Issue 93 (Medium): MOSTLY_GOOD "Exit 0 in either case" is ambiguous when user says yes
**Location**: Step 5 MOSTLY_GOOD row (both instances)
"Exit 0 in either case" is ambiguous: if user says "yes", the loop continues to Step 3 where non-zero exits may occur later.
**Suggestion**: Rephrase: "no immediate exit on 'yes'; continue loop; emit final exit code only at terminal Step 6 or error path."

#### Issue 94 (Medium): Cleanup condition "created solely by validation" is not operationalized
**Location**: Implementation Step 4 item 4
Detection mechanism for "created solely by validation" is unspecified, leading to inconsistent implementations.
**Suggestion**: Record whether the review directory existed before invocation; remove it only if: (a) it was absent pre-run, AND (b) it is empty post-cleanup.

### Positive Aspects
- Converging well; most prior issues fully resolved
- sha256 hash integrity contract is a clear improvement

### Summary
Top 3: (90) validation false-pass on stale rounds, (91) shadow creation failure unspecified, (93) MOSTLY_GOOD exit semantics ambiguous
**Consensus Status**: NEEDS_REVISION

---

## Round 18 — 2026-04-04

### Overall Assessment
The Round 17 fixes (90-94) are correctly integrated and materially improve validation determinism. However, an adversarial pass still finds contract-level gaps in failure taxonomy, cleanup scope, and fallback append safety that can produce false success signals or ambiguous exits under edge conditions. The plan remains close, but not yet operationally closed.
**Rating**: 9.1/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 90 | Step 4.3 latest-round scoped validation | Resolved | Step 4 item 3 now applies D8 parser rules to latest segment |
| 91 | Shadow creation failure path | Resolved | Step 4 item 1 now exits 5 pre-invocation on mktemp/mv failure |
| 92 | Canonical fallback round marker | Resolved | Step 3 fallback now uses `^## Round [0-9]+ — ` |
| 93 | MOSTLY_GOOD yes-path exit ambiguity | Resolved | Step 5 now states no immediate exit on yes; continue loop |
| 94 | Cleanup pre-run existence flag | Resolved | Step 4 item 4 now operationalizes directory cleanup guard |

### Issues

#### Issue 95 (High): `VALIDATION_ERROR` taxonomy is inconsistent after adding shadow-creation failure
**Location**: Decision D8, Appendix A Exit Codes table, Step 4 item 1
Step 4 now defines shadow **creation** failure (backup path creation / move failure) as exit `5`, but D8 + Appendix A exit-5 condition text still enumerates only shadow-restore/hash/evidence failures. This creates spec drift between behavior and canonical error taxonomy.
**Suggestion**: Update D8 and Appendix A exit-code `5` text to explicitly include shadow-backup creation/move failure before invocation.

#### Issue 96 (High): Validation temp artifacts are not covered by failure-path cleanup
**Location**: Step 4 item 4 + rollback paragraph
Success-path cleanup deletes `$TMPPLAN`/`$TMPREVIEW`, but failure-path rollback only restores Steps 1-3 snapshots. On validation failure after temp-file creation, temporary artifacts can be left behind, violating the "clean verification" contract.
**Suggestion**: Add an unconditional trap/finally cleanup for `$TMPPLAN` and `$TMPREVIEW` on both success and failure (without touching pre-existing artifacts).

#### Issue 97 (Medium): Exit code `9` semantics are overloaded
**Location**: Step 5 Loop guard note vs D8 `BLOCKED` mapping
Step 5 says external round-limit exhaustion should halt with exit `9`, while D8 defines exit `9` specifically as reviewer `BLOCKED`. This conflates two distinct terminal causes and weakens downstream automation diagnostics.
**Suggestion**: Either map loop-limit exhaustion to a separate code (recommended) or explicitly extend D8 definition for exit `9` to include "operator-imposed round-limit halt."

#### Issue 98 (Medium): Provider fallback can append non-round stdout without structural validation
**Location**: Step 3 Provider file-write fallback
When fallback triggers, spec says append provider stdout directly if non-empty. There is no structural gate requiring stdout to contain a valid `## Round {N} — ...` block, 5+ issues, and consensus line. This can corrupt the review file with logs/noise while still passing "non-empty stdout."
**Suggestion**: Require fallback stdout to satisfy the same round-shape minima before append; otherwise treat as `PROVIDER_EMPTY_RESPONSE` (or `PARSE_FAILURE`) and do not write.

#### Issue 99 (Medium): Shadow restore requirement does not define behavior when backup file is missing mid-run
**Location**: Step 4 item 1 restore contract
The plan requires unconditional restore from `$SKILLBAK`, but does not define the exact failure branch if `$SKILLBAK` is deleted/unreadable before restore (e.g., external cleanup race). Current text implies failure, but the branch is not explicitly machine-testable.
**Suggestion**: Specify: if shadow mode was entered and `$SKILLBAK` is missing/unreadable at restore time, emit `VALIDATION_ERROR`, exit `5`, and fail validation deterministically.

### Positive Aspects
- Round 17 remediation is correctly applied and materially reduces false-pass risk.
- Latest-segment parsing and cleanup guard are now much more deterministic than earlier revisions.

### Summary
Top 3: (95) D8/Appendix exit taxonomy drift after shadow-creation fix, (96) failure-path temp artifact leakage, (98) fallback append lacks structural validation gate.
**Consensus Status**: NEEDS_REVISION

---

## Round 19 — 2026-04-04

### Overall Assessment
Round 18 fixes (95-99) close meaningful correctness gaps, especially around cleanup and shadow restore determinism. A fresh adversarial pass still finds unresolved enforcement and operability gaps: D3 minimum-findings can still be bypassed on direct-write success paths, trap composition remains under-specified, and rollback/session contracts still allow ambiguous behavior under hostile or noisy runtime conditions.
**Rating**: 9.0/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 95 | Exit-5 taxonomy includes shadow-backup create/move failure | Resolved | D8 + Appendix A now enumerate pre-invocation backup creation/move failure under exit `5` |
| 96 | Unconditional temp cleanup on success/failure | Resolved | Step 4 now requires trap/finally cleanup for `$TMPPLAN` and `$TMPREVIEW` on both paths |
| 97 | Exit 9 covers BLOCKED and round-limit halt with diagnostic | Resolved | D8 + Step 5 now define shared exit `9` and diagnostic differentiation |
| 98 | Fallback stdout requires structural gate | Resolved | Step 3 now requires heading + 5 issues + consensus before fallback append |
| 99 | Missing/unreadable `$SKILLBAK` at restore is explicit exit 5 | Resolved | Step 4 now defines deterministic `VALIDATION_ERROR` on restore-time backup loss |

### Issues

#### Issue 100 (High): D3 minimum-findings rule is still bypassable on direct provider-write success
**Location**: Step 3 fallback contract (`docs/plans/bundle-plan-review-skill.md:176`) and Step 4 parse/apply (`docs/plans/bundle-plan-review-skill.md:178`)
The 5-finding structural gate is only applied when fallback captures stdout. If provider write is considered successful (size increased + new round marker), there is no mandatory pre-apply gate that latest round has at least 5 `#### Issue` entries. This leaves D3 enforceability path-dependent.
**Suggestion**: Require the same latest-round structural validation (5+ `#### Issue` entries + valid consensus line) after every provider invocation, regardless of whether fallback executed.

#### Issue 101 (Medium): Cleanup-handler composition is under-specified and can drop one trap
**Location**: Step 4 item 1 dual trap instructions (`docs/plans/bundle-plan-review-skill.md:230`)
The plan requires one cleanup handler for SKILL restore and a separate one for temp cleanup. In shell implementations, trap replacement semantics can overwrite an earlier handler unless explicitly chained, causing either restore or temp cleanup to be skipped.
**Suggestion**: Specify a single composed EXIT cleanup function (ordered restore -> temp cleanup) or an explicit trap-chaining mechanism.

#### Issue 102 (Medium): Fallback structural gate does not enforce single-round integrity
**Location**: Step 3 fallback gate (`docs/plans/bundle-plan-review-skill.md:176`) and prompt rounding contract (`docs/plans/bundle-plan-review-skill.md:361`)
Current gate only requires at least one round heading, 5 issues, and a consensus line. It can still accept stdout containing multiple rounds or replayed old round blocks, which can corrupt sequencing/history while passing minima.
**Suggestion**: Require exactly one appended round block with round number `N = prior_round_count + 1`; reject stdout with multiple/new-old mixed round headings.

#### Issue 103 (Medium): Session reuse extraction remains spoofable by untrusted stdout content
**Location**: Session Reuse rules (`docs/plans/bundle-plan-review-skill.md:108` and `docs/plans/bundle-plan-review-skill.md:315`)
Using the last raw `session_id=<value>` line from stdout allows accidental or adversarial content in provider output to hijack session reuse (for example echoed transcript lines).
**Suggestion**: Bind session ID from trusted provider metadata, or require a reserved machine marker (for example `[plan-review] session_id=<id>`) emitted only by orchestrator plumbing.

#### Issue 104 (Medium): Rollback procedure lacks deterministic behavior when rollback itself fails
**Location**: Step 4 rollback paragraph (`docs/plans/bundle-plan-review-skill.md:235`)
The plan mandates restoring snapshots/deleting created files on failure, but does not define what to do if restoration/deletion fails (permission errors, missing snapshot, I/O faults). This can leave partial state without clear terminal diagnostics.
**Suggestion**: Define rollback failure semantics explicitly: continue best-effort rollback, emit aggregated rollback diagnostics, and terminate with `VALIDATION_ERROR` (exit `5`) if rollback is incomplete.

### Positive Aspects
- Round 18 materially improved failure taxonomy and validation cleanup determinism.
- Latest-round scoped parsing and fallback structural gating are significantly stronger than earlier rounds.

### Summary
Top 3: (100) D3 enforcement still path-dependent, (101) trap composition ambiguity, (102) fallback gate lacks single-round integrity.
**Consensus Status**: NEEDS_REVISION

---

## Round 20 — 2026-04-04

### Overall Assessment
Round 19 issues 100-104 are implemented as described: D3 gate is now mandatory post-invocation, trap composition is explicitly single EXIT with restore-then-cleanup ordering, fallback enforces exactly one new round heading with `N=prior+1`, session reuse requires `[plan-review] session marker`, and rollback failure semantics now define `ROLLBACK_INCOMPLETE` + exit `5`.  
A new adversarial pass still finds sequencing and validation hardening gaps that allow malformed or manipulated rounds to pass key control points.
**Rating**: 9.1/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 100 | Mandatory post-invocation D3 gate | Resolved | Step 4 now applies D3 gate after every provider invocation |
| 101 | Trap composition ambiguity | Resolved | Step 4 now requires one composed EXIT handler with restore -> temp cleanup order |
| 102 | Fallback single-round integrity | Resolved | Fallback now requires exactly one new round heading with `N = prior + 1` |
| 103 | Session marker spoofing hardening | Resolved | Session extraction now requires reserved `[plan-review] session_id=<id>` marker |
| 104 | Rollback failure semantics undefined | Resolved | Step 4 now defines best-effort rollback, per-artifact diagnostics, and exit `5` on incomplete rollback |

### Issues

#### Issue 105 (High): Direct-write success path still does not enforce round-number continuity
**Location**: Step 4 post-invocation gate + parse flow (`docs/plans/bundle-plan-review-skill.md:409-411`)
Fallback enforces `N = prior_round_count + 1`, but direct provider-write success path does not validate round heading number continuity before applying findings. A provider can append `## Round 999` and still pass D3 + consensus checks.
**Suggestion**: After every provider invocation (including direct-write success), validate latest round heading number equals `prior_round_count + 1`; otherwise treat as `PARSE_FAILURE` (exit `8`) and do not apply edits.

#### Issue 106 (Medium): Consensus parser allows multi-consensus override in one round
**Location**: D8 parser rule (`docs/plans/bundle-plan-review-skill.md:71`)
Current rule says if multiple consensus matches exist in latest segment, use the last one. This permits adversarial round content with conflicting statuses where a trailing line silently overrides earlier status.
**Suggestion**: Require exactly one valid `**Consensus Status**:` line in latest segment. If count is not exactly one, emit `PARSE_FAILURE` and exit `8`.

#### Issue 107 (Medium): Invalid latest round can be left persisted after structural/parse failure
**Location**: Step 4 failure paths (`docs/plans/bundle-plan-review-skill.md:409-411`)
When D3 or consensus parsing fails, the workflow exits (`3`/`8`) but does not define cleanup/quarantine of the newly appended malformed round. This can poison subsequent runs and repeatedly fail parsing.
**Suggestion**: On post-invocation structural/parse failure, remove or quarantine only the newly appended latest round (preserving prior rounds), then exit with the original error code.

#### Issue 108 (Medium): `session_id` value format remains under-constrained for safe forwarding
**Location**: Session Reuse rules (`docs/plans/bundle-plan-review-skill.md:315`)
The marker format is constrained, but `<value>` character set/length is not. Unvalidated values (whitespace/control chars/leading `-`) can break downstream CLI argument parsing when passed as `--session <id>`.
**Suggestion**: Define strict session-id regex (for example `^[A-Za-z0-9._:-]{1,128}$`), reject non-matching values, and require shell-safe argument quoting when forwarding.

#### Issue 109 (Medium): D3 structural gate is too weak to guarantee actionable issue blocks
**Location**: D3 + Step 4 gate (`docs/plans/bundle-plan-review-skill.md:35`, `docs/plans/bundle-plan-review-skill.md:409`)
Gate requires only 5 `#### Issue` headings plus a consensus line. Stubbed issue headings with missing `Location`/`Suggestion` can pass, reducing review quality while still driving plan mutations.
**Suggestion**: Strengthen post-invocation structural gate to require each counted issue block contains `**Location**:` and `**Suggestion**:` fields (or fail with `PROVIDER_EMPTY_RESPONSE` exit `3`).

### Positive Aspects
- The 100-104 fixes substantially improved determinism and narrowed several spoofing/failure surfaces.
- Step 4 now has clearer stop conditions (`PARSE_FAILURE`, `BLOCKED`) before any plan mutation.

### Summary
Top 3: (105) missing direct-path round-number continuity check, (106) multi-consensus last-match override, (107) malformed latest-round persistence after failure.
**Consensus Status**: NEEDS_REVISION

---

## Round 21 — 2026-04-04

### Overall Assessment
Round 20 issues 105-109 are reflected in the plan: direct-path continuity check is present, consensus parsing is now single-match strict, post-invocation structural/parse failures quarantine the appended latest round, session IDs are regex-validated and shell-quoted, and D3 now requires `Location` and `Suggestion` in counted issues.  
The flow is substantially hardened, but adversarial edge cases remain around write-integrity guarantees, marker extraction determinism, and structural gate precision.
**Rating**: 9.3/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 105 | Direct-write round continuity missing | Resolved | Step 4 now requires latest heading number `N = prior_count + 1` |
| 106 | Multi-consensus last-match override | Resolved | D8 now requires exactly one valid consensus line |
| 107 | Malformed round persistence after parse/structural failure | Resolved | Step 4 now quarantines/removes newly appended latest round before exit |
| 108 | session_id format under-constrained | Resolved | Session reuse now validates against `^[A-Za-z0-9._:-]{1,128}$` and forwards shell-quoted |
| 109 | D3 gate lacked actionable-field checks | Resolved | Counted issue blocks now require both `**Location**:` and `**Suggestion**:` |

### Issues

#### Issue 110 (High): Direct-write success path has no preexisting-content integrity check
**Location**: Step 3 fallback gate predicates (`docs/plans/bundle-plan-review-skill.md:403`)
Direct-write success is accepted when byte size increases and a new round marker appears. This does not detect provider-side tampering of preexisting content (e.g., rewriting earlier rounds while still appending one new round), so history integrity can be silently corrupted.
**Suggestion**: Record and verify an integrity marker for preexisting content (e.g., hash of pre-invocation bytes up to prior EOF). If mismatch after provider return, emit `PARSE_FAILURE` (or `VALIDATION_ERROR`) and quarantine the new append.

#### Issue 111 (Medium): Session marker extraction is still “last-match wins” and not cardinality-checked
**Location**: Session Reuse (`docs/plans/bundle-plan-review-skill.md:315`)
The workflow scans stdout for the last matching `[plan-review] session_id=<value>` line. Multiple valid markers in one stdout stream are currently allowed, so a trailing marker can silently override an earlier legitimate one.
**Suggestion**: Require exactly one valid session marker per invocation. If marker count is 0 or >1, disable session reuse for that invocation and emit a diagnostic line.

#### Issue 112 (Medium): D3 counted-issue detection does not explicitly exclude fenced/quoted pseudo-issues
**Location**: Step 4 structural gate clause (b) (`docs/plans/bundle-plan-review-skill.md:409`)
Round heading and consensus parsing explicitly scope to non-fenced/non-quoted lines, but issue counting language does not restate that same exclusion. Pseudo-issue headings inside fenced blocks or quotes can inflate counts and satisfy the minimum gate incorrectly.
**Suggestion**: Explicitly require issue counting to ignore fenced and quoted lines, matching D8/latest-round extraction semantics.

#### Issue 113 (Medium): “Quarantine latest round” rule is ambiguous when a single invocation appends multiple rounds
**Location**: Step 4 failure handling (`docs/plans/bundle-plan-review-skill.md:409`)
The plan says to remove/quarantine only the newly appended latest round on failure. If a malicious direct-write appends two rounds in one invocation, quarantining only the latest may leave an earlier injected round persisted.
**Suggestion**: Define quarantine scope as “all content appended since pre-invocation EOF” rather than only the syntactic latest round.

#### Issue 114 (Low): Required round schema still under-enforced for continuity metadata
**Location**: Provider output schema vs Step 4 structural gate (`docs/plans/bundle-plan-review-skill.md:380-383`, `409`)
The output format requires `### Previous Round Tracking` for rounds 2+, but structural validation does not enforce its presence or minimum row quality. This allows loss of issue-lifecycle continuity while still passing gates.
**Suggestion**: For rounds where `prior_round_count >= 1`, require `### Previous Round Tracking` with at least one table row referencing prior issues, or fail with `PARSE_FAILURE`.

### Positive Aspects
- The 105-109 fixes close major parser-abuse paths and substantially improve failure-path determinism.
- Step 4 now correctly treats structural quality as mandatory before plan mutation.

### Summary
Top 3: (110) missing preexisting-content integrity verification on direct write, (111) non-unique session marker acceptance, (113) quarantine scope too narrow for multi-round append attacks.
**Consensus Status**: NEEDS_REVISION

---

## Round 22 — 2026-04-04

### Overall Assessment
Round 21 issues 110-114 are reflected in the plan: pre-invocation sha256 is recorded, direct-write tamper checks verify first-N-byte integrity, session marker extraction is exact-one with WARN diagnostics, D3 issue counting is non-fenced/non-quoted, quarantine scope is expanded to all bytes since pre-invocation EOF, and rounds 2+ now require `Previous Round Tracking` with at least one row.  
The specification is materially stronger, but adversarial gaps remain in direct-write heading cardinality, failure-path determinism, and parse-contract alignment.
**Rating**: 9.5/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 110 | Direct-write preexisting-content integrity missing | Resolved | Pre-invocation sha256 + first-N-byte post-check now specified |
| 111 | Non-unique session marker acceptance | Resolved | Extraction now requires exactly one marker; emits WARN on 0 or >1 |
| 112 | D3 issue counting could include fenced/quoted pseudo-issues | Resolved | Clause (b) now explicitly scopes to non-fenced/non-quoted lines |
| 113 | Quarantine scope too narrow for multi-round append | Resolved | Quarantine now covers all bytes appended since pre-invocation EOF |
| 114 | Missing required `Previous Round Tracking` enforcement | Resolved | D3 clause (d) now requires section with at least one table row for rounds 2+ |

### Issues

#### Issue 115 (High): Direct-write path does not require exactly one new round heading in appended delta
**Location**: Step 3 provider file-write fallback predicates (`docs/plans/bundle-plan-review-skill.md:175-176`)
Direct-write success currently accepts any append where size grows and at least one new round marker exists beyond prior count. Unlike fallback stdout validation, it does not require exactly one new heading in the appended bytes. A provider can append multiple new round headers (or duplicate `N`) and still pass predicate checks, while Step 4 only validates the last segment.
**Suggestion**: For direct-write success, require exactly one new non-fenced/non-quoted `## Round` heading in the post-invocation delta, with heading number `N = prior_round_count + 1`; otherwise treat as structural failure and quarantine appended bytes.

#### Issue 116 (High): Tamper-detection branch does not explicitly mandate immediate exit semantics
**Location**: Step 3 tamper check clause (`docs/plans/bundle-plan-review-skill.md:176`)
The text says to emit `VALIDATION_ERROR` and quarantine appended content when first-N-byte hash mismatches, but it does not explicitly state to stop before any fallback append or Step 4 evaluation. This leaves control-flow interpretation open.
**Suggestion**: Add explicit branch contract: after tamper mismatch, quarantine delta, emit diagnostic, and exit `5` immediately (no fallback, no Step 4 parse, no plan edits).

#### Issue 117 (Medium): PARSE_FAILURE definition in D8 is narrower than Step 4 behavior
**Location**: D8 `PARSE_FAILURE` definition vs Step 4 D3 gate (`docs/plans/bundle-plan-review-skill.md:71`, `409`)
D8 defines `PARSE_FAILURE` only around consensus-line matching, while Step 4 uses `PARSE_FAILURE` for additional structural faults (round number mismatch, missing tracking section/row). This mismatch can break automated assertions that rely on D8 as the canonical contract.
**Suggestion**: Expand D8 `PARSE_FAILURE` wording to include all Step 4 structural-gate violations, not only consensus-line failures.

#### Issue 118 (Medium): Quarantine operation is specified semantically but not operationally
**Location**: Step 3/Step 4 quarantine requirements (`docs/plans/bundle-plan-review-skill.md:176`, `409`)
The plan repeatedly requires quarantining appended bytes but does not define destination path convention, collision handling, or behavior when quarantine write fails. That creates implementation drift and potential silent data loss.
**Suggestion**: Define a deterministic quarantine artifact convention (path, naming, overwrite policy) and explicit failure behavior (e.g., emit `VALIDATION_ERROR` and retain original file untouched if quarantine persistence fails).

#### Issue 119 (Medium): `Previous Round Tracking` gate validates row presence but not row validity
**Location**: Step 4 D3 clause (d) (`docs/plans/bundle-plan-review-skill.md:409`)
The gate requires at least one table row, but does not require parseable issue IDs, status values, or references to prior issues. A dummy row can satisfy the gate while continuity remains unusable.
**Suggestion**: Require at least one row with numeric issue ID, non-empty status from an allowed set, and a note referencing a prior issue outcome.

### Positive Aspects
- Round 21 hardening significantly improved write-integrity checks and downgrade resistance.
- The stricter session marker contract and D3 gate additions reduce common parser-spoof classes.
- Quarantine scope expansion to all appended bytes closes a major multi-round injection vector.

### Summary
Top 3: (115) direct-write path still allows multi-heading append ambiguity, (116) tamper branch lacks explicit immediate-exit control flow, (117) D8 parse-failure contract is narrower than enforced behavior.
**Consensus Status**: NEEDS_REVISION
