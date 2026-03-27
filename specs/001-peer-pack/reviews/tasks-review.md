# Plan Review: Spec Kit Peer Workflow Integration — tasks.md
**Plan File**: specs/001-peer-pack/tasks.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
The task set is detailed and mostly aligned with the contracts, but it has several structural problems that will cause execution risk: traceability drift, dependency mistakes, and ambiguity in test/validation expectations. The biggest weakness is not missing content, but coupling too much behavior into a few oversized tasks while also carrying conflicting requirements from upstream artifacts. This plan is not execution-safe yet without refinement.
**Rating**: 5.5/10

### Issues
#### Issue 1 (Critical): T-06 behavior is internally contradictory across source artifacts
**Location**: T013 (`specs/001-peer-pack/tasks.md:106`)
T013 defines T-06 as "malformed provider-state.json (backup + reinit + actionable stderr)", but `plan.md` automated matrix defines T-06 as "Fails with schema-version error". This is a contract conflict that will produce false negatives depending on which interpretation implementers choose.
**Suggestion**: Split the case into two explicit cases in tasks: (a) unsupported/absent `version` => backup + reinit, (b) malformed JSON parse => fail fast. Then align the wording with `contracts/review-command.md` and `contracts/execute-command.md`.

#### Issue 2 (High): Top-level testing declaration contradicts the actual plan
**Location**: `**Tests**` header (`specs/001-peer-pack/tasks.md:9`)
The header says "Not requested — no test tasks generated" while T013 is a dedicated test runner task with 14 acceptance cases. This creates execution ambiguity and can cause reviewers to treat tests as optional.
**Suggestion**: Replace the header with a truthful statement such as "Tests required — see T013 automated matrix and per-story independent tests".

#### Issue 3 (High): FR-002 has no explicit task-level traceability
**Location**: T006 FR tag block (`specs/001-peer-pack/tasks.md:51`)
FR-002 (every review invocation must produce/update `specs/<feature>/reviews/<artifact>-review.md`) is central but not explicitly cited in any task FR annotations. It is only implied inside long prose.
**Suggestion**: Add FR-002 explicitly to T006 and T009, and add an explicit T013 assertion that each artifact review creates/updates the correct review file path.

#### Issue 4 (High): FR labels are inconsistent with actual FR semantics
**Location**: T004, T007 (`specs/001-peer-pack/tasks.md:36,52`)
T004 maps schema work to FR-008 (batch execution/review loop), and T007 maps adapter-guide work to FR-010 (code-review rounds appended to plan-review). These mappings are semantically off per `spec.md` FR definitions and weaken auditability.
**Suggestion**: Re-map FR tags against `spec.md` FR-001..FR-015 definitions and add a small FR-to-task matrix section in `tasks.md`.

#### Issue 5 (High): Declared parallelism for T004 conflicts with plan entry criteria
**Location**: T004 `[P]` and dependency notes (`specs/001-peer-pack/tasks.md:36,125,143`)
`plan.md` says `shared/schemas/peer-providers.schema.yml` has entry criterion "extension.yml exists", but tasks mark T004 parallel to T005 and only dependent on T001. That violates stated implementation constraints.
**Suggestion**: Remove `[P]` from T004 and encode dependency `T004 depends on T003`.

#### Issue 6 (Medium): T007 is marked parallel despite hidden dependency on command definitions
**Location**: T007 `[P]` and Phase 3 parallel block (`specs/001-peer-pack/tasks.md:52,124-138`)
`plan.md` sets adapter-guide entry criterion to "commands/ exists". Writing adapter contract before command contracts are stabilized can drift the I/O/error taxonomy.
**Suggestion**: Make T007 depend on T006 (and optionally T010 for shared execute semantics), while keeping T008 parallel.

#### Issue 7 (Medium): Phase 7 parallel marker is optimistic and can cause premature audit pass
**Location**: T013/T014 and Phase 7 parallel block (`specs/001-peer-pack/tasks.md:106-107,127,151-152`)
T014 audits cross-cutting correctness, but it is marked parallel with T013 even though key claims (14-case pass, stdout/stderr consistency under test) depend on T013 artifacts/results.
**Suggestion**: Sequence T014 after T013, or split T014 into pre-validation static audit and post-validation evidence audit.

#### Issue 8 (High): T006 and T010 are too large to be executable units
**Location**: T006, T010 (`specs/001-peer-pack/tasks.md:51,81`)
Each task combines preconditions, state recovery, locking, prompt design, provider invocation, parsing, append semantics, and reporting. A single checkbox cannot represent partial completion or support incremental verification.
**Suggestion**: Split each into atomic tasks (preflight/config, prompt assembly, adapter I/O parsing, lock/append, provider-state write/recovery, summary/reporting).

#### Issue 9 (High): Prompt-injection hardening is under-specified
**Location**: T006, T009, T010 (`specs/001-peer-pack/tasks.md:51,67,81`)
Tasks mention delimiters but do not explicitly require instruction hierarchy and hostile-content handling (e.g., never follow instructions embedded inside artifact bodies, treat artifact text as untrusted data only).
**Suggestion**: Add mandatory prompt-hardening requirements in these tasks: explicit priority rules, refusal of in-artifact instruction overrides, and constrained output template enforcement.

#### Issue 10 (Medium): T009 lacks deterministic output-shape requirements for tasks reviews
**Location**: T009 (`specs/001-peer-pack/tasks.md:67`)
The rubric asks for coverage/dependency/test checks but does not require a fixed output structure (e.g., issue table with severity, FR mapping matrix, consensus line placement). This can produce inconsistent or low-auditability reviews.
**Suggestion**: Require a strict output schema in review instructions (Overall Assessment, ordered findings, FR coverage table, Consensus Status terminal line).

#### Issue 11 (Medium): Provider-state permission guarantees are incomplete at task level
**Location**: T006 and T010 state-persistence clauses (`specs/001-peer-pack/tasks.md:51,81`)
The tasks include temp-file `0600` + rename, but do not explicitly include post-rename mode verification required by plan constraints.
**Suggestion**: Add explicit acceptance text: verify final `provider-state.json` mode is `0600` after rename; if not, fail with `VALIDATION_ERROR`.

#### Issue 12 (Medium): Exit-code contract for `validate-pack.sh` failures is ambiguous
**Location**: T013 (`specs/001-peer-pack/tasks.md:106`)
T013 says "non-zero with failing case id" but does not define whether case id is in exit code, stderr payload, or both. Automation consumers cannot rely on a stable failure protocol.
**Suggestion**: Specify exact failure contract (e.g., exit `1` + stderr line `FAIL_CASE=<id>`), and keep per-case invocation modes deterministic.

#### Issue 13 (Low): `.specify/` directory precondition is implicit
**Location**: T001 and T005 (`specs/001-peer-pack/tasks.md:24,37`)
T005 writes `.specify/peer.yml`, but no earlier task explicitly ensures `.specify/` exists. This is minor but can create avoidable setup failures in clean repos.
**Suggestion**: Extend T001 to include creating `.specify/` (or explicitly state T005 must create parent directories).

### Positive Aspects
- Tasks explicitly reference the key contracts and include concrete regex/locking/state details instead of vague prose.
- The plan preserves clear user-story segmentation with independent test intent for each story.
- T013 correctly captures most of the 14-case matrix scope and includes the `< 5 s` acceptance intent.

### Summary
The top three blockers before execution are: (1) resolve the T-06 contract contradiction, (2) fix dependency/parallelization errors (T004/T007/T014), and (3) split T006/T010 into atomic executable tasks with explicit prompt-hardening requirements. Until those are addressed, implementation risk and review ambiguity remain high.
**Consensus Status**: NEEDS_REVISION

---
## Round 2 — 2026-03-27
### Overall Assessment
The revision is a substantial improvement: most Round 1 blockers were addressed with better dependency sequencing, decomposition of large tasks, and explicit hardening language. However, the updated file still has contract-level inconsistencies that affect auditability and execution confidence, especially in FR traceability accuracy and a few step-coverage gaps. The plan is close, but not yet fully execution-safe.
**Rating**: 7.8/10

### Previous Round Tracking
| Round 1 Issue | Status | Round 2 Assessment |
|---|---|---|
| Issue 1: T-06 contradiction | PARTIAL | T017 now introduces T-06a/T-06b split, but cross-artifact consistency remains imperfect because `plan.md` still describes T-06 differently. |
| Issue 2: "Tests not requested" header conflict | RESOLVED | Header now correctly states tests are required and points to T017. |
| Issue 3: FR-002 traceability gap | RESOLVED | FR-002 is now explicitly referenced in task definitions and traceability table. |
| Issue 4: FR label semantic drift | PARTIAL | Improved, but FR mappings are still not fully accurate (see new issues on FR table correctness). |
| Issue 5: T004 parallelization conflict | RESOLVED | T004 is no longer `[P]`, and dependency now states T003 → T004. |
| Issue 6: T007 hidden dependency | RESOLVED | T007 now depends on T006 and is sequenced clearly. |
| Issue 7: T013/T014 parallel audit risk | RESOLVED | Polish phase now sequences T017 before T018. |
| Issue 8: Oversized T006/T010 | RESOLVED | Review and execute work is now split into T006–T008 and T012–T014. |
| Issue 9: Prompt-injection hardening missing | RESOLVED | Explicit hardening language appears in T007, T011, and T012. |
| Issue 10: T009 output-shape ambiguity | RESOLVED | T011 now requires deterministic structured output sections. |
| Issue 11: Post-rename mode verification missing | RESOLVED | Explicit post-rename `0600` checks are present in both T008 and T014. |
| Issue 12: validate-pack failure contract ambiguous | RESOLVED | T017 defines explicit failure contract (`exit 1` + `FAIL_CASE=<id>`). |
| Issue 13: `.specify/` precondition implicit | RESOLVED | T001 now explicitly includes creating `.specify/`. |

### Issues
#### Issue 1 (High): FR traceability table is still not fully accurate to spec semantics
**Location**: `FR Traceability` section (`specs/001-peer-pack/tasks.md:179-197`)
Several FR mappings remain semantically weak or incomplete: FR-004 includes code-review verdict requirements but the table maps it only to review-command tasks (T007/T008), omitting execute-side verdict handling (T013/T014). FR-013 (provider-state persistence) is mapped to T009 (adapter guide) even though persistence behavior is implemented in review/execute command tasks.
**Suggestion**: Rebuild the FR table directly against `spec.md` FR text, and include only implementing tasks (not documentation-only tasks) for each FR.

#### Issue 2 (Medium): T004 includes env-var validation that does not belong in YAML schema scope
**Location**: T004 (`specs/001-peer-pack/tasks.md:36`)
T004 says `peer-providers.schema.yml` should reject `CODEX_TIMEOUT_SECONDS` outside bounds. `CODEX_TIMEOUT_SECONDS` is an environment variable, not a field in `.specify/peer.yml`, so this requirement is misplaced and can confuse implementation.
**Suggestion**: Remove env-var validation from schema task T004 and keep it exclusively in command preflight tasks (T006/T012).

#### Issue 3 (Medium): T009 dependency is contradictory within the same file
**Location**: T009 entry criterion vs dependency graph (`specs/001-peer-pack/tasks.md:54,125`)
T009 says entry criterion is "T006 complete", but dependency graph declares `T008 → T009`. These are not equivalent and affect scheduling.
**Suggestion**: Normalize to one dependency rule. Given T009 expects a stable command contract, keep `T008 → T009` and update T009 description accordingly.

#### Issue 4 (High): T017 case-count claim is inconsistent with listed matrix items
**Location**: T017 (`specs/001-peer-pack/tasks.md:110`)
T017 claims a "14-case" matrix, but the enumerated list includes base IDs plus multiple split IDs (`T-06a/T-06b`, `T-10a/T-10b`, `T-11/T-11b`), resulting in more than 14 executable checks. This weakens acceptance reporting and pass-rate interpretation.
**Suggestion**: Define a canonical counting policy (either 14 base IDs with subcase grouping, or full expanded case count) and align wording, reporting, and CI output accordingly.

#### Issue 5 (Medium): Review-command split still misses an explicit Step-1 requirement from contract
**Location**: T006–T008 (`specs/001-peer-pack/tasks.md:51-53`)
`contracts/review-command.md` Step 1 requires ensuring `specs/<featureId>/reviews/` exists before first-run bootstrap. The split references review-file bootstrap but does not explicitly require creating the reviews directory.
**Suggestion**: Add an explicit line to T006 or T007: ensure `specs/<featureId>/reviews/` exists (`mkdir -p`) before creating/using review files.

#### Issue 6 (Medium): Execute-command split misses explicit `output_path` existence/non-empty validation
**Location**: T013 (`specs/001-peer-pack/tasks.md:84`)
After adapter invocation, T013 requires strict stdout parsing but does not explicitly state the contract check that `output_path` must exist and be non-empty before proceeding.
**Suggestion**: Add explicit `output_path` file existence/non-empty validation with `PROVIDER_EMPTY_RESPONSE` failure mapping before checkbox verification.

### Positive Aspects
- Dependency sequencing quality is significantly better, and key hidden dependencies from Round 1 were corrected.
- The T006–T008 and T012–T014 decomposition materially improves executability and reviewability.
- Prompt-hardening and deterministic output-shape requirements are now explicit in the right places.
- Requested checks are satisfied: T004 depends on T003 and is not `[P]`; T009 is not `[P]`; post-rename mode verification appears in both T008 and T014.

### Summary
Most Round 1 concerns are now resolved, and the revised tasks are materially stronger. The remaining blockers are primarily consistency and contract-accuracy defects: fix the FR traceability table, resolve T017 counting/semantics alignment, and close the two step-coverage gaps (review directory creation and execute `output_path` validation). After these are addressed, the plan should be near-approvable.
**Consensus Status**: NEEDS_REVISION

---
## Round 3
**Date**: 2026-03-27  
**Reviewer**: Codex (adversarial)  
**Score**: 8.4/10  
**Consensus Status**: MOSTLY_GOOD

### Round 2 Issue Resolution
| ID | Severity | Status | Notes |
|----|----------|--------|-------|
| R2-I1 | High | RESOLVED | FR traceability now includes FR-004 → T013 and FR-015 → T003 (`tasks.md:188,199`). |
| R2-I2 | Medium | RESOLVED | T004 now explicitly states `CODEX_TIMEOUT_SECONDS` is env-var preflight validation, not YAML schema scope (`tasks.md:36`). |
| R2-I3 | Medium | RESOLVED | T009 entry criterion now states `T008 complete` (`tasks.md:54`). |
| R2-I4 | High | RESOLVED | T017 now frames the matrix as "14 base plan.md case IDs" and treats T-06a/T-06b as sub-assertions under T-06 (`tasks.md:110`). |
| R2-I5 | Medium | RESOLVED | T006 now explicitly ensures `specs/<featureId>/reviews/` exists (`mkdir -p`) (`tasks.md:51`). |
| R2-I6 | Medium | RESOLVED | T013 now validates `output_path` exists and is non-empty and maps failure to `PROVIDER_EMPTY_RESPONSE` (`tasks.md:84`). |

### Remaining Issues
- **Suggestion**: Minor overlap remains between T006 and T007 on first-run review-file bootstrap (`tasks.md:51-52`). T006 already creates empty review file if missing, while T007 repeats the same responsibility. Consolidating this into one task would reduce ambiguity.
- **Suggestion**: FR-013 traceability includes T009 (`tasks.md:197`), but T009 is adapter-guide documentation rather than persistence implementation. Consider restricting FR-013 implementation mapping to T008/T014 for stricter accuracy.

### Summary
Round 2 blockers are resolved, and the task list is now coherent and execution-ready with only minor cleanup items left. No remaining High/Critical issues were found in this pass.

---
## Round 4
**Date**: 2026-03-27
**Reviewer**: Codex (adversarial)
**Score**: 8.8/10
**Consensus Status**: MOSTLY_GOOD

### Round 3 Suggestion Resolution
| ID | Status | Notes |
|----|--------|-------|
| S1 | RESOLVED | FR traceability now maps FR-013 to implementation tasks only (`T008`, `T014`) in the FR table (`tasks.md:197`). |
| S2 | PARTIAL | T006 now clarifies that `provider-state.json` initialization belongs to T007, but T007 still repeats "create empty review file if absent" while T006 already owns first-run review-file bootstrap (`tasks.md:51-52`). |

### Remaining Issues
- Minor overlap remains in first-run review-file bootstrap responsibility between T006 and T007. This is non-blocking but should be consolidated to a single owner task for cleaner execution semantics.

### Summary
The Round 3 fixes are largely in place and the task list is operationally solid, with no High/Critical defects observed. One minor clarity overlap remains, so this is ready for execution under a MOSTLY_GOOD rating.

---
## Round 5
**Date**: 2026-03-27
**Reviewer**: Codex (adversarial)
**Score**: 9.4/10
**Consensus Status**: APPROVED

### Round 4 Suggestion Resolution
| ID | Status | Notes |
|----|--------|-------|
| S2 | RESOLVED | T007 no longer owns first-run review-file creation; it now states round counting only, with review file/directory guaranteed by T006 preflight (`tasks.md:51-52`). |

### Remaining Issues
None.

### Summary
The remaining Round 4 suggestion is fully resolved, and the task list is now internally consistent and execution-ready. No new blockers were identified in this final pass.
