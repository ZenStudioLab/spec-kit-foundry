# Plan Review: Agent Prohibition + Invocation Gate + Concrete Template

**Plan File**: docs/plans/refining-agent-for-codex-invocation.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
The plan moves in the right direction by making invocation behavior explicit and adding failure gates, but several controls are not operationally enforceable. Key sections rely on declarative language where procedural guarantees are needed, especially around terminal invocation proof, temp-file safety, and failure handling semantics. As written, this can still permit silent policy bypasses or inconsistent behavior between `review.md` and `execute.md`.
**Rating**: 5/10

### Issues
#### Issue 1 (Critical): Invocation gate is not independently verifiable
**Location**: R-3 Step 2.8, E-4 Adapter Invocation Gate  
The gate asks the same agent to attest it executed terminal commands, but provides no independent evidence requirement. A non-compliant agent can claim checks passed without any falsifiable artifact. This makes the control policy-like, not enforcement-like.  
**Suggestion**: Require concrete evidence checks (command transcript id, timestamped stdout capture, and verified `output_path` hash) and fail closed if artifacts are missing.

#### Issue 2 (Critical): `$(cat "$PROMPT_FILE")` is fragile for large or binary-like prompts
**Location**: R-2 Step 2.7b, E-2/E-3 invocation templates  
Quoted command substitution reduces shell injection risk, but it still pushes full prompt text into argv, which can hit `ARG_MAX`, strips trailing newlines, and cannot preserve NUL bytes. This creates correctness failures and hard-to-debug truncation behavior. It is a reliability and integrity risk for long artifacts.  
**Suggestion**: Add `--prompt-file "$PROMPT_FILE"` support (preferred) or pass prompt via stdin with explicit adapter behavior.

#### Issue 3 (High): Temp file naming with `$$` is predictable
**Location**: R-2 Step 2.7a (and mirrored execute edits)  
`/tmp/...-$$.txt` is guessable and not collision-resistant under concurrent runs or hostile local users. It also exposes a window for symlink/race abuse if permissions are weak. Predictability undermines safety claims.  
**Suggestion**: Use `mktemp` with restrictive permissions, e.g. `PROMPT_FILE="$(mktemp /tmp/peer-review-prompt.XXXXXX)"` and `umask 077`.

#### Issue 4 (High): Prompt file cleanup is not guaranteed on all failure paths
**Location**: R-2 Step 2.7b (`rm -f "$PROMPT_FILE"` after invocation), execute mirrored edits  
Cleanup only occurs after the command path shown; early returns, parse failures, or interrupts can leak files in `/tmp`. This can retain sensitive context and create clutter or accidental reuse. Security-sensitive workflows should fail safely with deterministic cleanup.  
**Suggestion**: Install `trap 'rm -f "$PROMPT_FILE"' EXIT INT TERM` immediately after file creation.

#### Issue 5 (High): Asymmetric gate design across `review.md` and `execute.md`
**Location**: R-3 standalone Step 2.8 vs E-4 inline gate in Step 2.4  
The plan says “symmetrical,” but execution differs in structure, wording, and scope. This increases drift risk and makes future updates inconsistent. Enforcement logic should be unified to avoid one file becoming weaker over time.  
**Suggestion**: Define a shared “Adapter Invocation Gate” block with identical normative language and reuse it in both files.

#### Issue 6 (Critical): “DISCARD” is not operational for already-emitted model output
**Location**: R-1 constraint, R-3 gate, E-1/E-4 constraints  
If the agent has already emitted inline review/verdict text, “discard” is aspirational unless there is a concrete buffering mechanism. In streaming contexts, tokens are already externalized and cannot be retracted. This creates a false sense of containment.  
**Suggestion**: Require “no content emission before successful gate,” with output buffering discipline and explicit instruction to abort before any substantive text.

#### Issue 7 (Medium): Substep numbering and nesting are inconsistent
**Location**: E-2 (`2.3c-i/ii/iii`) vs E-3/E-4 within Step 2.4  
Mixed numbering styles and nesting depth make the procedure harder to follow and easier to mis-implement. This is especially risky in long markdown command specs where step references drive behavior. Ambiguity weakens auditability.  
**Suggestion**: Normalize numbering scheme across both files (e.g., `2.3.1/2.3.2/2.3.3` and `2.4.1/...`) and reference by stable anchors.

#### Issue 8 (Medium): Verification step 4 cannot reliably distinguish “old abstract” from “new concrete”
**Location**: Verification item 4  
The check says old one-liner should not appear “as bare abstract description,” but that criterion is subjective and hard to automate. A literal grep can produce false positives from examples, comments, or migration notes. This undermines verification quality.  
**Suggestion**: Define exact regex-based pass/fail patterns and exempted sections, or validate by required block presence instead of old-string absence.

#### Issue 9 (High): `tasks` artifact path flow remains ambiguous in `review.md`
**Location**: R-2/R-3 vs “artifact=tasks” mention in later parts  
The plan does not explicitly confirm whether Step 2.7/2.8 governs all artifact paths, including the special tasks-review flow. If tasks use a different load path/step, invocation and gate may be bypassed unintentionally. This is a likely loophole reintroduction.  
**Suggestion**: Add explicit statement: “All artifact modes, including tasks, must pass Step 2.7 + Step 2.8 before Part 3.”

#### Issue 10 (Medium): Constraint placement may be too far from point-of-failure
**Location**: R-1 and E-1 Role Model section only  
Placing constraints near the top improves visibility but not necessarily compliance at the critical step where violation occurs. In long files, agents may focus local context around invocation steps and miss earlier policy blocks. This is a human-factors and model-context issue.  
**Suggestion**: Duplicate a short “hard gate reminder” immediately before Step 2.7/2.3c/2.4 invocation sections.

#### Issue 11 (High): Missing explicit exit code behavior for PROVIDER_UNAVAILABLE
**Location**: R-3 and E-4 failure paths  
The plan says “STOP and report” but does not map to concrete exit code behavior. Without deterministic exit semantics, wrappers and CI cannot reliably detect and handle failure classes. This breaks automation contracts.  
**Suggestion**: Add mandatory exit code mapping (e.g., `exit 1` or a reserved code) aligned with existing exit-code tables.

#### Issue 12 (Medium): Stdout contract parsing remains underspecified
**Location**: R-2 Step 2.7c and execute mirrored parsing steps  
“Parse strict stdout contract” is referenced but no concrete parser rules are included here (exact regex, duplicate key handling, whitespace/path escaping, multi-line robustness). Partial or malformed stdout can slip through inconsistent parsers. This is a correctness and security boundary.  
**Suggestion**: Specify canonical parsing rules with exact patterns, required fields, and fail-closed behavior on any ambiguity.

#### Issue 13 (High): Execution batch path lacks explicit gate parity with code-review path
**Location**: E-2 Step 2.3c vs E-4 gate only in Step 2.4  
The added gate is explicitly “inside Step 2.4” for code review rounds, but the batch implementation invocation in 2.3c does not get the same enforceable gate text. This leaves a policy gap where implementation content could be accepted without equivalent proof.  
**Suggestion**: Add a gate immediately after 2.3c invocation substeps, mirroring Step 2.4 gate semantics.

### Positive Aspects
- The plan correctly identifies the inline-generation loophole and targets both command files.
- It upgrades abstract invocation guidance into concrete operational steps.
- It explicitly includes failure messaging for provider-unavailable states.
- It calls out a real shell quoting bug in the earlier suggestion and provides corrected syntax.

### Summary
Top risks are the non-falsifiable gate design, fragile prompt transport via argv substitution, and incomplete failure semantics (including missing exit-code contract). These three issues directly affect whether the prohibition can be enforced rather than merely stated. Until those are hardened, the plan can improve behavior but cannot guarantee compliance boundaries under adversarial or degraded conditions.  
Consensus Status: NEEDS_REVISION

## Round 2 — 2026-03-27
### Overall Assessment
The revision materially improves enforceability and closes most Round 1 loopholes, especially around explicit terminal invocation and symmetric gating across both command files. The biggest remaining risk is internal inconsistency in failure semantics (`PARSE_FAILURE` exit `8` vs “all gate failures exit `1`), plus a few operational ambiguities that can still let implementations drift.
**Rating**: 7.5/10

### Issues Resolved
| Issue | Resolution Quality |
|-------|--------------------|
| Issue 1 (Gate attestation) | Partial — requiring real `session_id=` and `output_path=` is better, but still self-attested unless cross-checked against runtime evidence. |
| Issue 2 (ARG_MAX / prompt passing) | Partial — risk is acknowledged and bounded for current sizes, but still leaves a known scaling failure mode in-core flow. |
| Issue 3 (`mktemp` vs `$$`) | Adequate — switched to `mktemp` with correct intent and stronger temp-file safety. |
| Issue 4 (cleanup on failure/interrupt) | Adequate — `trap` on `EXIT INT TERM` clearly addresses cleanup paths. |
| Issue 5 (batch path missing gate) | Adequate — E-2 now adds an explicit post-invocation gate before batch verification. |
| Issue 6 (`DISCARD` semantics) | Partial — moving to `ABORT` is correct, but “new response” wording is still operationally fuzzy for single-turn execution. |
| Issue 7 (orchestrator boundary clarity) | Adequate — new/strengthened Role Model + CRITICAL CONSTRAINT materially tightens boundary. |
| Issue 8 (verification checklist weakness) | Partial — checklist improved, but grep assertion remains too narrow to reliably catch variants. |
| Issue 9 (`tasks` flow coverage) | Adequate — Step 2.8 now explicitly applies to all artifact types including `tasks`. |
| Issue 10 (point-of-invocation reminder) | Adequate — added hard gate reminder immediately before invocation steps. |
| Issue 11 (script path hardcoding risk) | Adequate — explicit use of resolved `$codex_script_path` removes hardcoded path drift. |
| Issue 12 (stdout contract ambiguity) | Partial — strict parse rules are defined, but split authority between files/docs still risks divergence. |
| Issue 13 (E-2 structural gap) | Adequate — Step 2.3 was concretized into gated substeps with clear placement. |

### Remaining or New Issues
#### Issue N1 (High): Failure-code contradiction
**Location**: R-2 Step 2.7d vs Revised Verification Checklist item 5  
Step 2.7d declares parse deviations as `PARSE_FAILURE` exit `8`, while checklist says every gate failure is exit `1` (`PROVIDER_UNAVAILABLE`).  
**Suggestion**: Define one canonical mapping table (parse failure, invoke failure, missing output file) and use it consistently across all sections.

#### Issue N2 (Medium): ABORT instruction is still not fully operational
**Location**: R-3 Step 2.8 (“ABORT current response… In a new response, report…”)  
“New response” is not reliably actionable in all orchestration contexts.  
**Suggestion**: Replace with deterministic instruction: “Return only the error line and stop; do not emit any additional content.”

#### Issue N3 (Medium): Internal contradiction about Part 3 on failure
**Location**: R-3 note under “On ABORT vs DISCARD”  
Text says Step 2.8 blocks Part 3, but later says “if invocation failed mid-review, the error round format in Part 3 takes over.”  
**Suggestion**: Pick one model. Prefer “no Part 3 progression on gate failure” for consistency.

#### Issue N4 (Medium): Checklist grep rule is too brittle
**Location**: Revised Verification Checklist item 7  
`grep` for a single literal form (`ask_codex.sh "<prompt>"`) misses equivalent anti-patterns with spacing/quoting variants.  
**Suggestion**: Use a regex-based check for placeholder prompt literals and direct inline prompt anti-patterns, not one exact string.

#### Issue N5 (Low): Substep numbering style inconsistency
**Location**: R-2 body (`2.7a/b/c/d`) vs checklist (`2.7.a/b/c/d`)  
Two numbering forms are specified.  
**Suggestion**: Standardize one format and enforce it in both files/checklist.

#### Issue N6 (Medium): Attestation still vulnerable to stale reuse without hard recency check
**Location**: Step 2.8 attestation condition  
The text forbids carry-over, but does not require objective recency validation.  
**Suggestion**: Require `output_path` mtime >= invocation start timestamp and non-reuse of prior round `output_path/session_id`.

### Positive Aspects
- Symmetric hardening of `review.md` and `execute.md` is strong and reduces policy drift.
- The point-of-failure gate placement is much better than prior abstract guidance.
- Moving from abstract to concrete terminal templates should materially improve compliance in practice.
- Explicitly covering `tasks` closes a known bypass class.

### Summary
This revision is close, but not yet release-ready as a normative command spec. Resolve the failure-code/flow contradictions and tighten the checklist and recency validation semantics, then it should be in good shape for a final pass.

Consensus Status: NEEDS_REVISION

### Overall Assessment
The Round 3 plan is substantially stronger: it closes the inline-fallback loophole with explicit orchestrator boundaries, adds concrete invocation mechanics, and introduces strict pre-Part-3 gating. Most of the previously flagged ambiguity has been resolved, especially around ABORT semantics, substep structure, and terminal-only attestation language.

There are still a few real inconsistencies that matter operationally: one failure-code conflict remains in `review.md`, freshness checks are asymmetric between `review.md` and `execute.md`, and one verification check no longer matches the planned invocation form. These are fixable, but they prevent clean approval as-is.  
**Rating**: 7.5/10

### Issues Resolved
| Issue | Resolution Quality |
|-------|--------------------|
| N1 | Fully resolved. Canonical failure-code mapping is now explicit and centralized in Decisions. |
| N2 | Fully resolved. ABORT behavior now clearly says “emit only the error line and stop.” |
| N3 | Fully resolved. Terminal gate-failure behavior before Part 3 is explicitly stated. |
| N4 | Partially resolved. Regex check was improved, but now mismatches the updated `$codex_script_path` invocation form. |
| N5 | Fully resolved. Numbering normalization is consistent (`2.7a/b/c/d`, `2.3.1...`, `2.4.1...`). |
| N6 | Partially resolved. Stale-attestation defense was added in `review.md`, but not mirrored in `execute.md` gates. |

### Remaining or New Issues

#### Issue N7 (High): Exit-code contradiction still exists for stdout-contract failures in `review.md`
`Step 2.7d` defines malformed stdout contract as `PARSE_FAILURE` (exit `8`), but `Step 2.8` failure line includes “stdout contract was not satisfied” under `PROVIDER_UNAVAILABLE` (exit `1`). Same condition can map to two different exits.

#### Issue N8 (Medium): Freshness/non-reuse gate is missing on `execute.md` paths
`review.md` Step 2.8 includes mtime + non-reuse checks; `execute.md` batch/code-review gates only require terminal invocation + captured values + non-empty file. This leaves a stale-output reuse bypass in execution flows.

#### Issue N9 (Medium): Verification regex in checklist #7 does not cover current invocation style
Checklist #7 searches for `ask_codex.sh ... "<...` patterns, but planned invocations use `"$codex_script_path"`. Placeholder first-arg regressions can pass undetected.

#### Issue N10 (Low): Structural inconsistency in checklist count
Checklist #4 says gate text appears in “three places in execute.md” but lists only two locations (post E-2 and post E-4).

### Positive Aspects
- Strong, explicit orchestrator/provider separation in both command files.
- Concrete temp-file + trap pattern is a clear improvement over abstract invocation text.
- Strict two-line stdout contract parsing is well-defined and testable.
- Gate placement before review generation/parsing is correctly emphasized.
- Symmetry goal is largely achieved and much cleaner than prior rounds.

### Summary
This is close, but not yet clean: one high-severity failure-semantic contradiction and two meaningful coverage gaps remain. Tightening the exit-code branching in `review.md`, adding freshness/non-reuse checks to both `execute.md` gates, and fixing checklist verification logic/counting should bring it to approval-ready.  
Consensus Status: NEEDS_REVISION

### Overall Assessment
The plan is much tighter than prior rounds, and N7–N10 are genuinely addressed in this revision. The failure taxonomy is now coherent, freshness checks were added where missing, the regex scope was expanded, and the checklist count language is corrected.

One implementation-critical gap remains: the new `mktemp` + `trap` pattern is split across substeps that are likely to run as separate terminal invocations, which can invalidate `PROMPT_FILE`/`EXEC_PROMPT_FILE` and delete temp files before adapter invocation. That can make the gate fail even when the operator followed the steps literally.

**Rating**: 8/10

### Issues Resolved
| Issue | Resolution Quality |
|-------|--------------------|
| N7 | Fully resolved. `PARSE_FAILURE` is separated into parse substeps with exit `8`; `PROVIDER_UNAVAILABLE` no longer conflates parse-contract failure. |
| N8 | Fully resolved. Freshness/non-reuse condition (`mtime >= invocation start` + no carry-over) is present in both execute gate blocks. |
| N9 | Fully resolved. Verification regex now covers both `ask_codex.sh` and `"$codex_script_path"` forms. |
| N10 | Fully resolved. Checklist now correctly states two execute hard gate blocks, with CRITICAL CONSTRAINT called out separately. |

### Remaining or New Issues
#### Issue N11 (High): Temp-file lifecycle is unsafe across split terminal substeps
`Step 2.7a` / `2.7c` (review) and `2.3.1` / `2.3.3`, `2.4.1` / `2.4.3` (execute) are split into separate substeps, but `PROMPT_FILE` vars and `trap` semantics assume one shell context. If executed as separate terminal calls, variable state is lost and `trap` may remove the file before invocation.  
Fix: require each invocation flow (write prompt -> invoke -> parse) to run in a single shell block, with cleanup at the end of that same block.

#### Issue N12 (Medium): “Emit only this error line” conflicts with adjacent diagnostic guidance
In `review.md` Step 2.8, the failure branch says “emit only this error line and stop,” then immediately adds diagnostic/user guidance bullets. This is ambiguous and can lead to violating the single-line failure contract.  
Fix: explicitly mark diagnostic text as author/operator note (non-runtime output), or move it outside the ABORT output contract block.

### Positive Aspects
- Clear, canonical exit-code mapping with explicit `PROVIDER_UNAVAILABLE` vs `PARSE_FAILURE`.
- Symmetric hard-gate design across `review.md` and `execute.md`.
- Strong anti-inline fallback language in CRITICAL CONSTRAINT blocks.
- Good falsifiability requirements (`session_id`, `output_path`, existence, non-empty, freshness, non-reuse).
- Verification checklist is now concrete and testable.

### Summary
This Round 4 revision resolves the prior N7–N10 concerns well and is close to shippable. The main blocker is execution reliability of the new temp-file flow under real terminal-tool behavior; that needs one more edit to enforce single-shell invocation blocks. After that plus a minor clarification on single-line error output semantics, the plan should be implementation-ready.  
Consensus Status: **NEEDS_REVISION**

### Overall Assessment
N11 and N12 are both properly resolved in this revision. The plan now explicitly closes the shell-state lifecycle gap by requiring single-session execution for each temp-file/trap substep group, and it removes the runtime-output ambiguity by separating operator diagnostics from the mandated single-line ABORT output.

I do not see any remaining blocker-level contradictions in the Round 5 text. The gate semantics, failure mapping, and stop conditions are now consistent enough to implement safely.

**Rating**: 9.6/10

### Issues Resolved
| Issue | Resolution Quality |
|-------|--------------------|
| N11 | Strong. Single-session requirement is explicitly added to all affected substep groups (R-2, E-2, E-3), directly addressing temp-file/trap scope and premature cleanup risks. |
| N12 | Strong. The diagnostic hint is clearly moved out of runtime output with explicit operator-only labeling, removing conflict with “emit only this error line.” |

### Remaining or New Issues
None — plan is ready for implementation.

### Positive Aspects
- Failure taxonomy is now explicit and coherent (`PROVIDER_UNAVAILABLE` vs `PARSE_FAILURE`).
- Gate attestation is falsifiable (`session_id` + `output_path` from actual stdout, plus freshness checks).
- Enforcement is placed both globally (Role Model) and at invocation points.
- Coverage includes all artifact paths, including `tasks`, and both execute-mode gates.
- ABORT semantics are now precise and aligned with streaming realities.

### Summary
This Round 5 plan is implementation-ready: it resolves the prior lifecycle and output-contract defects without introducing new blockers, and it provides clear, testable guardrails for orchestrator behavior across both command files.  
Consensus Status: APPROVED
