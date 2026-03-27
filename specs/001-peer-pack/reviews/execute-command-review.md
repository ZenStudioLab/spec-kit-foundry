# Execute Command Contract Review: Spec Kit Peer Workflow Integration
**Contract File**: specs/001-peer-pack/contracts/execute-command.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
`execute-command.md` is generally strong and now aligns with most of the shared contract mechanics (state schema, append schemas, lock strategy, and strict stdout/stderr conventions). The remaining gaps are concentrated in execution-gate ambiguity and loop-bounding semantics, which are material for implementation safety because they can cause drift across implementations or non-terminating behavior.
**Rating**: 8.6/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| N/A | N/A - first review round | N/A | No prior `execute-command` review round was provided in scope. |

### Issues
#### Issue 1 (High): Readiness-gate policy is cross-file ambiguous (`plan`-only vs `tasks` authoritative gate)
**Location**: `contracts/execute-command.md` Preconditions 4 (line ~57); `spec.md` User Story 2 narrative (line ~30); `plan.md` FR traceability note (line ~182)
The execute contract gates on approved `plan` review only, while `spec.md` describes `/speckit.peer.review tasks` as the authoritative gate before execution. This ambiguity can split implementations between “plan-only allowed” and “tasks-review required.”
**Suggestion**: Declare one canonical gate policy in both contracts and `spec.md` (either enforce `tasks-review` approval in execute preconditions, or explicitly mark tasks review as recommended-but-not-required everywhere).

#### Issue 2 (High): Fix/review loop is unbounded and can violate no-unbounded-loop constraint
**Location**: `contracts/execute-command.md` Step 7c (lines ~136-139), Step 6 loop (lines ~109-124); `plan.md` Constitution Check V (line ~46)
`NEEDS_FIX` causes repeated Step 7 reruns with no max-attempt cap, and parse-failure verdict coercion to `NEEDS_FIX` can keep the loop alive indefinitely. This conflicts with the plan’s explicit “No unbounded loops” constraint.
**Suggestion**: Add deterministic caps (e.g., `max_fix_rounds_per_batch`, `max_parse_failures_per_batch`) and a terminal halt state/error when exceeded.

#### Issue 3 (Medium): Approval-marker parser in readiness gate is not deterministic enough
**Location**: `contracts/execute-command.md` Step 4 (lines ~99-102)
The contract says “scan for `Consensus Status: APPROVED|MOSTLY_GOOD`” but does not require anchored-line parsing within artifact review rounds. Simple substring scanning can produce false positives from quoted text or malformed content.
**Suggestion**: Define an anchored regex and section-scoped check (artifact `## Round` entries only; exclude `## Code Review Round` bodies).

#### Issue 4 (Medium): `LOCK_CONTENTION` is emitted but not mapped to a required exit code
**Location**: `contracts/execute-command.md` Locking section (line ~234), Exit Code Mapping (lines ~208-219), Compatibility notes (line ~223)
The contract uses `LOCK_CONTENTION` in append logic and error conditions, but no deterministic numeric exit code is assigned. This weakens CI/test determinism and error handling parity.
**Suggestion**: Add explicit `LOCK_CONTENTION` exit mapping (or explicitly map it to `VALIDATION_ERROR`) and keep that mapping consistent with `review-command.md` and `data-model.md`.

#### Issue 5 (Medium): State-persistence semantics are underspecified for non-append invocations
**Location**: `contracts/execute-command.md` Step 8 (lines ~144-151)
Step 8 says state is written “after each provider invocation,” while `last_persisted_round` tracks appended code-review rounds. The contract does not explicitly define field behavior for execution invocations that do not append a code-review round yet.
**Suggestion**: Add a per-invocation update matrix: which fields change for (a) batch execution call, (b) successful code-review append, (c) parse-failure error-round append, and (d) lock-contention/no-append cases.

### Positive Aspects
- Provider-state schema now matches the shared `<provider>.<workflow>` model and aligns with `review-command.md`.
- Code-review append schema is explicit and parser-friendly (`## Code Review Round N — YYYY-MM-DD` + terminal `Verdict`).
- Lock strategy is documented with stale-lock safeguards (pid + nonce + age check).
- Orchestrator/executor boundary is clearly stated and mostly enforceable.

### Summary
The contract is close to implementation-safe but still has material ambiguity at the execution gate and loop-termination levels. Tightening gate policy, bounding loops, and pinning parser/exit-code determinism would make this safe to implement consistently across agents.

Consensus Status: NEEDS_REVISION


---
## Round 2 — 2026-03-27
### Overall Assessment
`execute-command.md` is materially improved: loop bounds, parser anchoring, lock error mapping, and state-write matrix are now explicit. Remaining risk is concentrated in readiness-gate semantics and one state-model mismatch that can still cause unsafe or divergent behavior across implementations.
**Rating**: 9.0/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Readiness-gate policy ambiguity (`plan` vs `tasks`) | PARTIALLY_RESOLVED | Contract now defines hard/soft gates, but still leaves a cross-file semantic mismatch and stale-approval risk. |
| 2 | Unbounded fix/review loop | RESOLVED | `max_fix_rounds_per_batch` and `max_parse_failures_per_batch` caps were added. |
| 3 | Non-deterministic approval marker parser | RESOLVED | Gate now scopes to artifact rounds with anchored consensus regex. |
| 4 | `LOCK_CONTENTION` exit mapping missing | RESOLVED | Mapping to exit `5` is now specified in compatibility notes. |
| 5 | State persistence semantics for non-append calls underspecified | PARTIALLY_RESOLVED | Matrix exists, but still conflicts/ambiguity remains vs data-model `rounds_in_session` semantics. |

### Issues
#### Issue 1 (High): Readiness gate can pass on stale historical approval
**Location**: `contracts/execute-command.md` Preconditions 4 (line ~57), Step 4 (lines ~99-103)
The gate checks for at least one approved artifact-review round in `plan-review.md`, which allows execution even if newer artifact rounds are `NEEDS_REVISION` or `BLOCKED`. This can regress safety by executing against a no-longer-approved plan.
**Suggestion**: Gate on the **latest artifact-review round** consensus (excluding code-review rounds), not any historical approved marker.

#### Issue 2 (High): Hard/soft gate policy still conflicts with spec narrative
**Location**: `contracts/execute-command.md` Preconditions 4-5 (lines ~57-59); `spec.md` User Story 2 “authoritative gate before execution” (line ~30)
The contract makes `tasks-review` advisory (except latest `BLOCKED`), while spec narrative describes it as authoritative before execute. This leaves implementers with conflicting interpretations of required readiness.
**Suggestion**: Normalize one policy across `spec.md`, `plan.md`, and both contracts: either require tasks-review readiness for execute, or explicitly downgrade it everywhere to non-blocking advisory.

#### Issue 3 (Medium): `rounds_in_session` semantics remain inconsistent with data model
**Location**: `contracts/execute-command.md` State update matrix (lines ~161-165); `data-model.md` SessionEntry `rounds_in_session` definition (line ~178)
Matrix says to update lifecycle fields for parse-failure error-round appends; combined with current wording, this can imply incrementing `rounds_in_session` on non-successful rounds, while data model defines it as successful rounds only.
**Suggestion**: Explicitly define `rounds_in_session` update rule in execute contract (and align review contract/data-model): increment only on successful provider rounds, or revise data-model definition to include error-round appends.

#### Issue 4 (Medium): Size-limit guard is validated but not enforced for execute context payloads
**Location**: `contracts/execute-command.md` Preconditions 12 (line ~69), Step 6 prompt build (lines ~116-121); `plan.md` Performance/Config constraints (lines ~18, ~27)
`max_artifact_size_kb` is validated as a config value, but execute flow does not enforce payload bounds when loading plan/tasks context and dispatching batches. This can cause oversized prompts and inconsistent runtime behavior.
**Suggestion**: Add explicit pre-invocation size checks for `plan.md`, `tasks.md`, and assembled batch context payload; fail deterministically with `VALIDATION_ERROR` on overflow.

### Positive Aspects
- Loop-bounding is now explicit and materially improves termination safety.
- Approval parsing is now anchored and scoped to artifact review headings.
- Locking behavior and `LOCK_CONTENTION` handling are clearer and more testable.
- Provider-state recovery and per-invocation state-write matrix are now documented.

### Summary
The contract is close to implementation-safe and most Round 1 blockers are fixed. Remaining material risk is in readiness-gate correctness (latest-status vs historical-status and hard/soft policy alignment) plus one unresolved state-model consistency point.

Consensus Status: NEEDS_REVISION

