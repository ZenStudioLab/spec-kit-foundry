# Review Command Contract Review: Spec Kit Peer Workflow Integration
**Contract File**: specs/001-peer-pack/contracts/review-command.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
`review-command.md` captures the main lifecycle of `/speckit.peer.review`, but it is still materially out of sync with the stricter operational constraints defined in `plan.md` and `data-model.md`. The largest gaps are around feature resolution, validation/state invariants, and parse-safe append behavior under concurrency and failure. As written, the contract is understandable but not implementation-safe.
**Rating**: 6.9/10

### Issues
#### Issue 1 (High): Feature resolution algorithm conflicts with the plan’s authoritative resolution order
**Location**: `contracts/review-command.md` Execution Steps 1 (lines 48-50)
The contract resolves feature by branch/`FEATURE_ID`, while `plan.md` defines canonical order as current spec-dir context → explicit `--feature <id>` → disambiguation prompt. This can resolve the wrong feature in detached HEAD or branch-name drift scenarios.
**Suggestion**: Replace Step 1 with the plan’s canonical resolution order and explicitly document branch name as advisory only.

#### Issue 2 (Medium): Invocation surface omits `--feature <id>` despite plan-level requirement
**Location**: `contracts/review-command.md` Invocation/Parameters (lines 11-20)
There is no `--feature` parameter even though plan constraints define explicit `--feature <id>` as part of disambiguation behavior.
**Suggestion**: Add `--feature <id>` to invocation syntax, parameters table, and examples.

#### Issue 3 (High): Peer config version validation is missing from preconditions
**Location**: `contracts/review-command.md` Preconditions (lines 38-42)
The contract checks config existence but not schema version, while `plan.md` and `data-model.md` require `version: 1` checks and explicit failure/migration behavior.
**Suggestion**: Add preconditions for `peer.yml version == 1` and failure guidance for absent/unknown versions.

#### Issue 4 (Medium): Provider `mode` validation is omitted
**Location**: `contracts/review-command.md` Preconditions + Execution Steps 2 (lines 40, 52-55)
`data-model.md` requires resolved provider mode to be `orchestrated`, but this contract never validates it.
**Suggestion**: Add a precondition and validation step for `providers.<name>.mode == orchestrated`.

#### Issue 5 (Medium): Codex discovery order is underspecified and mismatched with plan behavior
**Location**: `contracts/review-command.md` Preconditions 5 (line 42)
Only default path existence is described; plan requires `CODEX_SKILL_PATH` override precedence, executable/readable checks, and warning semantics.
**Suggestion**: Document discovery order (`CODEX_SKILL_PATH` → default path), validation checks, and warning behavior to match plan constraints.

#### Issue 6 (High): Contract omits adapter stdout/stderr/exit-code obligations required by adapter interface
**Location**: `contracts/review-command.md` overall (missing), especially Steps 5-7 and Error Conditions
`plan.md` defines strict I/O and exit-code/error-code mapping, but this contract does not enforce stdout-only `session_id`/`output_path`, stderr formatting, or mapped exit semantics.
**Suggestion**: Add an explicit I/O contract section with canonical stdout/stderr formats and exit-code mapping references.

#### Issue 7 (High): Append flow lacks locking/atomicity guarantees, violating concurrency and append-only safety requirements
**Location**: `contracts/review-command.md` Step 6 (lines 75-85)
Step 6 describes plain append behavior but omits required cross-platform locking and contention handling from `plan.md`.
**Suggestion**: Add lock acquisition/retry/stale-lock reclaim semantics and require lock-held append operations.

#### Issue 8 (High): Parse-failure path can still append invalid content, conflicting with data-model parsing contract
**Location**: `contracts/review-command.md` Steps 6 + 8 (lines 75-85, 91-103)
The flow appends provider output and only then evaluates status; `data-model.md` says invalid parse must not append a normal round and should record explicit error behavior.
**Suggestion**: Introduce parse-validation before normal round append, and define the error-round behavior for `PARSE_FAILURE` explicitly.

#### Issue 9 (High): Provider-state write invariants are incomplete (no `last_persisted_round` and no write-order contract)
**Location**: `contracts/review-command.md` Step 7 (lines 87-89)
State update does not require `last_persisted_round`, invariant checks, or the plan’s prescribed write order (`append round` before state update with atomic rename), increasing corruption risk.
**Suggestion**: Add mandatory state fields and enforce the documented write-order + atomic rename + reconciliation rules.

#### Issue 10 (Medium): Round counting rule is underspecified and may miscount
**Location**: `contracts/review-command.md` Step 4 (lines 62-65)
“Count existing `## Round ` headings” is looser than `data-model.md`’s anchored regex rule and explicit exclusion of code-review headings.
**Suggestion**: Adopt the exact anchored detection rule (`^## Round [0-9]`) and note that `## Code Review Round` must not increment artifact-round counters.

#### Issue 11 (High): Tasks-specific cross-artifact loading requirement is missing from review flow
**Location**: `contracts/review-command.md` Steps 5 + Rubrics (lines 67-71, 135-140)
Spec FR-005 requires `/speckit.peer.review tasks` to load all four artifacts and fail clearly if any are missing; this contract does not include that branch logic.
**Suggestion**: Add explicit `artifact == tasks` behavior: preload `spec.md`, `research.md`, `plan.md`, `tasks.md`; fail before invocation if any are missing.

#### Issue 12 (Medium): Loop semantics over-automate beyond spec narrative and need explicit policy boundaries
**Location**: `contracts/review-command.md` Step 8 (lines 93-99)
The contract mandates auto-apply/re-run loops, while the spec narrative frames iterative user revisions between rounds. Without policy boundaries, implementations may diverge on who performs edits and when to pause.
**Suggestion**: Clarify whether review iterations are user-mediated, orchestrator-mediated, or mode-dependent, and define stop/hand-off conditions clearly.

### Positive Aspects
- The command structure is clear and follows a logical end-to-end flow.
- Severity-labeled review expectations and status taxonomies are explicitly captured.
- Append-only review history and shared plan review file conventions are represented.
- Core provider preconditions and error messaging intent are present and actionable at a baseline level.

### Summary
Top blockers are: (1) feature resolution and config/state validation drift from authoritative plan/data-model rules, (2) missing I/O + locking + atomic write guarantees, and (3) missing tasks-specific cross-artifact behavior required by FR-005. These should be aligned before treating the contract as implementation-safe.
**Consensus Status**: NEEDS_REVISION

---
## Round 2 — 2026-03-27
### Overall Assessment
The revised `review-command.md` resolves most Round 1 blockers and is much closer to implementation-safe behavior. Core fixes are in place for feature resolution, provider-mode/config validation, locking, and round counting. Remaining gaps are now concentrated in state-version recovery, explicit tasks-context loading semantics, and a few cross-file contract drifts that can still cause inconsistent implementations.
**Rating**: 8.4/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Feature resolution algorithm conflicts with canonical order | RESOLVED | Contract now uses cwd spec context → `--feature` → fail with disambiguation list (Preconditions 7; Steps 1). |
| 2 | Invocation surface omitted `--feature <id>` | RESOLVED | `--feature <id>` added to invocation, parameters, and examples. |
| 3 | Missing peer config version validation | RESOLVED | Preconditions now require `.specify/peer.yml` `version == 1`. |
| 4 | Missing provider `mode` validation | RESOLVED | Preconditions now require `mode: orchestrated`. |
| 5 | Codex discovery order underspecified | PARTIALLY_RESOLVED | Discovery order is documented, but override warning/redaction behavior from plan constraints is still not specified. |
| 6 | Missing adapter I/O and exit mapping obligations | PARTIALLY_RESOLVED | Stdout/stderr and exit map added, but stderr canonical formatting details remain underspecified vs plan. |
| 7 | Missing lock/atomic append guarantees | RESOLVED | Lock acquisition, retry, stale-lock handling, and lock-held append are now defined. |
| 8 | Parse failure could append invalid normal round | PARTIALLY_RESOLVED | Parse-before-append is now explicit, but error-round schema/format is still not fully specified. |
| 9 | Incomplete provider-state invariants/write semantics | RESOLVED | `last_persisted_round`, invariant check, atomic write, and merge semantics are now documented. |
| 10 | Round counting rule underspecified | RESOLVED | Anchored rule `^## Round [0-9]` is now specified in step logic. |
| 11 | Tasks cross-artifact requirement missing | PARTIALLY_RESOLVED | Existence precheck added and invariant added, but explicit load/build behavior is not yet spelled out in execution steps. |
| 12 | Loop semantics over-automated vs policy boundaries | RESOLVED | Step 10 now keeps revisions user/orchestrator-driven and treats confirmation loops as optional. |

### Issues
#### Issue 1 (High): Provider-state schema version recovery flow is still missing
**Location**: `contracts/review-command.md` Step 3 (lines 69-77), Error Conditions (lines 163-176); cross-check `plan.md` Config Validation (line 27), `data-model.md` ProviderState version semantics (lines 168-169)
The contract reads `provider-state.json` and extracts session fields, but it does not define mandatory handling when `provider-state.json` is missing `version` or has an unsupported version. The plan and data model require backup + recreate guidance for pre-v1/unknown schemas.
**Suggestion**: Add an explicit version check in Step 3: if version is absent/unsupported, backup to `provider-state.json.bak.YYYYMMDDHHMMSS`, recreate with `version: 1`, and emit an actionable stderr message.

#### Issue 2 (High): Tasks review does not explicitly define how all four artifacts are loaded into the provider prompt
**Location**: `contracts/review-command.md` Step 6 (lines 88-99), Invariants (line 196); cross-check `spec.md` FR-005 (line 95)
The contract now checks that all four files exist, but Step 6 still describes prompt construction in singular “artifact content” terms and does not specify multi-artifact prompt assembly for `artifact=tasks`. This leaves room for non-compliant implementations that only review `tasks.md`.
**Suggestion**: Add a dedicated `artifact=tasks` branch in Step 6 that explicitly loads `spec.md`, `research.md`, `plan.md`, and `tasks.md` and injects all four into the prompt in fixed labeled sections.

#### Issue 3 (High): Provider-state schema is inconsistent across review and execute contracts
**Location**: `contracts/review-command.md` Step 3/9 and Outputs (lines 71, 116, 156) vs `contracts/execute-command.md` Step 3/5d (lines 73, 94)
`review-command.md` uses the data-model shape `<provider>.review`, while `execute-command.md` still uses `sessions[provider][execute]`. This mismatch can produce incompatible state writes and broken session reuse between commands.
**Suggestion**: Normalize both contracts to the same schema defined in `data-model.md` (`<provider_id>.<workflow>`), and add a migration/compatibility note if legacy `sessions.*` keys may exist.

#### Issue 4 (Medium): Parse-failure path lacks a canonical error-round append schema
**Location**: `contracts/review-command.md` Step 7 (line 103); cross-check `data-model.md` Error round schema (lines 71-78)
The contract correctly blocks normal append on parse failure, but it does not define the exact markdown shape for the error round. Without schema-level detail, implementations may produce divergent error entries that break deterministic parsing and audits.
**Suggestion**: Inline the exact error-round template (heading/body/status fields) and require it to count toward round numbering.

#### Issue 5 (Medium): Stderr contract still omits canonical error/success formatting details
**Location**: `contracts/review-command.md` Adapter I/O Contract (line 133); cross-check `plan.md` I/O Contract (line 21)
The stderr rule currently says “human-readable logs/errors prefixed with `[peer/review]`” but does not require canonical error formatting (`[peer/<command>] ERROR: <ERROR_CODE>: <message>`), success summary fields, or `PEER_DEBUG=1` gating described in the plan.
**Suggestion**: Expand the stderr contract to include exact error format, success-summary minimum fields, and debug gating behavior.

#### Issue 6 (Medium): Round append format can duplicate consensus markers
**Location**: `contracts/review-command.md` Step 6 terminal requirement (lines 92-93) and Step 8 append block (lines 111-112)
Step 6 requires provider output to end with `Consensus Status`, then Step 8 appends `<provider output>` and appends another `Consensus Status: <status>` line. This can create duplicate or conflicting markers in one round.
**Suggestion**: Choose one canonical strategy: either append provider output verbatim (no extra status line) or strip status from provider output and append a normalized status line once.

#### Issue 7 (Low): Round heading delimiter style drifts from canonical schema
**Location**: `contracts/review-command.md` Step 8 heading format (line 110); cross-check `spec.md` FR-010 (line 100), `data-model.md` heading schema (line 53)
The contract uses `## Round N - YYYY-MM-DD` while canonical docs use `## Round N — YYYY-MM-DD`. This is minor but creates avoidable formatting drift across artifacts.
**Suggestion**: Use the exact canonical heading string with em dash to match spec/data-model examples.

#### Issue 8 (Low): Discovery override warning behavior is not captured
**Location**: `contracts/review-command.md` Preconditions 6 (lines 47-49); cross-check `plan.md` Provider Discovery constraints (line 29)
The contract defines discovery order and checks, but does not define the `[peer/WARN]` message behavior with home-path redaction/full-path in debug mode.
**Suggestion**: Add a brief note in preconditions or error/output section specifying override warning redaction behavior aligned with the plan.

#### Issue 9 (Medium): Error-code taxonomy still drifts from data-model error-round list
**Location**: `contracts/review-command.md` Exit Code Mapping (lines 140-147) vs `data-model.md` Error codes list (line 80)
The contract uses `UNIMPLEMENTED_PROVIDER` and `PROVIDER_UNAVAILABLE`, while the data model’s error-round list still references `ADAPTER_MISSING`. This can cause inconsistent test assertions and parser expectations.
**Suggestion**: Align error-code vocabulary across docs (preferred) or define explicit aliases/deprecation mapping in the contract.

### Positive Aspects
- The contract now reflects the canonical feature resolution order and includes explicit `--feature` support.
- Provider validation coverage improved materially (`version`, `enabled`, `mode`) and now matches core plan intent.
- Locking + retry semantics and `last_persisted_round` invariants significantly improved implementation safety.
- Round counting now uses the anchored pattern that cleanly avoids code-review header collisions.

### Summary
Top unresolved items are: (1) missing provider-state version recovery flow, (2) incomplete explicit `tasks` multi-artifact prompt-loading semantics, and (3) cross-contract provider-state schema mismatch with `execute-command.md`. Once these are aligned, the contract should be close to approval.
**Consensus Status**: NEEDS_REVISION

---
## Round 3 — 2026-03-27
### Overall Assessment
`review-command.md` is now substantially tighter and mostly aligned with `spec.md`, `plan.md`, `data-model.md`, `research.md`, and `execute-command.md`. Most prior cross-file drifts are fixed (state schema, parse-failure handling, warning semantics, delimiter/heading consistency). A small set of remaining contract gaps still affect deterministic first-run behavior and failure-mode predictability.
**Rating**: 9.1/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Provider-state version recovery missing | RESOLVED | Recovery flow now defined in Step 3 and Error Conditions. |
| 2 | `tasks` multi-artifact load not explicit | RESOLVED | Step 6 now defines labeled 4-artifact injection order. |
| 3 | Provider-state schema mismatch with execute | RESOLVED | Both contracts now use `<provider>.<workflow>`. |
| 4 | Parse-failure error-round schema missing | RESOLVED | Explicit error-round schema added. |
| 5 | Stderr canonical format underspecified | RESOLVED | Canonical stderr format and debug gating added. |
| 6 | Duplicate consensus marker risk | RESOLVED | Normalization now strips trailing provider status markers. |
| 7 | Round heading delimiter drift | RESOLVED | Canonical `## Round N — YYYY-MM-DD` format restored. |
| 8 | `CODEX_SKILL_PATH` warning behavior missing | RESOLVED | Redacted/default and debug/full-path behavior now specified. |
| 9 | Error-code taxonomy drift (`ADAPTER_MISSING`) | RESOLVED | Compatibility alias now documented. |

### Issues
#### Issue 1 (High): First-run review file bootstrap is not deterministic
**Location**: `contracts/review-command.md` Execution Steps 1/5/9 (lines ~67-71, 92-95, 125-133); cross-check `plan.md` test T-01 (line ~159)
The contract does not explicitly require creating `specs/<featureId>/reviews/` and `<artifact>-review.md` when absent before round counting/appending. Step 5 assumes a readable review file for `grep -c`, which can fail on first run and break SC-001/T-01 behavior.
**Suggestion**: Add an explicit bootstrap step: ensure `reviews/` exists, create review file if missing, treat missing file as round count `0` before computing `N`.

#### Issue 2 (Medium): `LOCK_CONTENTION` is emitted but has no deterministic exit-code mapping
**Location**: `contracts/review-command.md` Step 9 (line ~131), Exit Code Mapping (lines ~203-214), Compatibility Notes (lines ~217-218)
The contract specifies `LOCK_CONTENTION` on lock failure but does not map it to a required numeric exit code. This creates ambiguity for test harnesses and CI assertions.
**Suggestion**: Add explicit mapping for `LOCK_CONTENTION` (either a dedicated exit code or a defined mapping to `VALIDATION_ERROR`) and make it consistent across `plan.md`, `data-model.md`, and `execute-command.md`.

#### Issue 3 (Medium): Artifact-size guard is validated but not enforced at prompt-build time
**Location**: `contracts/review-command.md` Preconditions 10 (line ~59), Step 6 (lines ~97-106); cross-check `plan.md` Performance Goals/Config Validation (lines ~18, 27)
`max_artifact_size_kb` is validated as a config value, but there is no execution step that enforces size limits on actual loaded content. This is especially ambiguous for `artifact=tasks`, where four artifacts are injected.
**Suggestion**: Add pre-invocation enforcement: check each included file size (and optionally combined prompt payload) against configured limits; fail with a deterministic error code/message before adapter invocation.

#### Issue 4 (Medium): Provider-state update semantics on error rounds remain ambiguous
**Location**: `contracts/review-command.md` Step 8 (parse-failure path, lines ~122-124), Step 10 (lines ~134-145), Error Round schema (lines ~179-182); cross-check `data-model.md` ProviderState creation/update semantics (lines ~209-213)
The contract says parse failures append error rounds and that session state is preserved, but Step 10 broadly defines state upsert after append. It is unclear whether parse-failure rounds should increment `rounds_in_session`/`last_persisted_round` or leave session counters unchanged.
**Suggestion**: Add explicit rule matrix for state writes by round type (normal vs error) so recovery logic is deterministic and consistent with `last_persisted_round` invariants.

### Positive Aspects
- Canonical feature resolution order and `--feature` support are now explicit and consistent.
- Parse-safety improved materially (strict stdout contract, terminal-marker parsing, normalized append schema).
- Locking/recovery details now include stale-lock reclaim safeguards (pid+nonce) and bounded retries.
- Review/execute provider-state key shape is now aligned, removing a major cross-contract drift.
- Error-round schemas and compatibility aliasing significantly reduce parser ambiguity.

### Summary
The contract is close to implementation-safe, and most prior blockers are fixed. Remaining concerns are concentrated in first-run bootstrap determinism, lock-failure exit-code determinism, explicit size-limit enforcement, and state-update semantics for error rounds. These are solvable with small clarifications but still material for reliable implementation.

Consensus Status: NEEDS_REVISION


---
## Round 4 — 2026-03-27
### Overall Assessment
`review-command.md` has improved significantly and closes most prior implementation-safety gaps (bootstrap, parse normalization, lock flow, state matrix, and size-guard enforcement are now explicit). The remaining issues are narrower but still material: one state-semantic conflict with the data model and two cross-file consistency drifts that can cause divergent implementations.
**Rating**: 9.3/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | First-run review file bootstrap not deterministic | RESOLVED | Step 1 now creates `reviews/` and bootstraps missing review files before counting rounds. |
| 2 | `LOCK_CONTENTION` exit-code mapping undefined | PARTIALLY_RESOLVED | Review contract now maps it to exit `5` in compatibility notes, but cross-contract consistency with `execute-command.md` is still not aligned. |
| 3 | Size guard validated but not enforced at prompt build | RESOLVED | Step 6 now enforces per-file and combined bounds before invocation. |
| 4 | Error-round state update semantics ambiguous | PARTIALLY_RESOLVED | Matrix is now present, but its behavior conflicts with `data-model.md` `rounds_in_session` semantics. |

### Issues
#### Issue 1 (High): `rounds_in_session` semantics conflict with authoritative data model
**Location**: `contracts/review-command.md` Step 10 state matrix (lines ~154-157) vs `data-model.md` SessionEntry definition (line ~178)
The contract now increments `rounds_in_session` for error rounds (e.g., `PARSE_FAILURE`), but `data-model.md` defines `rounds_in_session` as “successful rounds only.” This creates deterministic state drift across implementations.
**Suggestion**: Align to one rule across docs. Preferred: keep `rounds_in_session` as successful rounds only, and track error rounds separately (or keep only `last_persisted_round` for append counters).

#### Issue 2 (Medium): `max_context_rounds` behavior is still not specified in execution flow
**Location**: `contracts/review-command.md` Execution Steps 4/6 (no context-window step), cross-check `plan.md` config intent (line ~27) and `data-model.md` read policy (line ~115, `max_context_rounds`)
The contract validates config and session limits but does not define how many prior rounds are injected into prompts. This leaves `max_context_rounds` effectively non-operational and invites implementation drift.
**Suggestion**: Add an explicit context-window step: read last `max_context_rounds` complete artifact rounds and include them in provider prompt assembly before current artifact payload.

#### Issue 3 (Medium): Lock-contention exit behavior is inconsistent across review/execute contracts
**Location**: `contracts/review-command.md` compatibility note (line ~231) vs `contracts/execute-command.md` lock/error sections (lines ~234, ~268-270, no explicit exit mapping)
`review-command.md` now defines `LOCK_CONTENTION -> exit 5`, but `execute-command.md` still does not define a deterministic numeric mapping. This breaks cross-command consistency for shared tooling/tests.
**Suggestion**: Define the same explicit lock-contention exit mapping in `execute-command.md` (and keep both contracts + test expectations aligned).

### Positive Aspects
- First-run bootstrap, recovery backup flow, and append schema determinism are now clearly specified.
- Parser determinism is improved with strict stdout contract and normalized terminal status handling.
- Size-limit enforcement is now present before provider invocation, including tasks multi-artifact payload handling.
- State write-order and atomicity requirements are explicit and aligned with lock/append safety intent.

### Summary
The contract is very close to implementation-ready. Remaining work is focused on semantic alignment (`rounds_in_session`), operationalizing `max_context_rounds`, and eliminating cross-contract lock-exit drift. Once those are resolved, approval is justified.

Consensus Status: NEEDS_REVISION

