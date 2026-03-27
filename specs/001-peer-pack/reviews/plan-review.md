# Plan Review: Spec Kit Peer Workflow Integration
**Plan File**: specs/001-peer-pack/plan.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
The plan has a clear intent, clean directory boundaries, and a practical v1 scope, but it is currently too light on execution-critical details for a reliable implementation handoff. Core risks around state consistency, security controls, and testability are not specified tightly enough for a multi-turn CLI workflow that writes persistent artifacts. As written, the plan is directionally good but not yet implementation-safe.
**Rating**: 6/10

### Issues
#### Issue 1 (Critical): Missing concurrency/atomic-write strategy for append-only reviews and session state
**Location**: Technical Context, Storage and Constraints (lines 14, 19); Constitution Check V (line 30)
The plan requires append-only review files and JSON session persistence but does not define locking, atomic write, or conflict resolution. Concurrent runs (two terminals/agents) can corrupt `provider-state.json` or interleave round appends.
**Suggestion**: Define a write protocol: temp-file + atomic rename for JSON, file lock (`flock`/portable fallback) for markdown append, and deterministic retry/backoff behavior on lock contention.

#### Issue 2 (High): No explicit adapter interface contract despite “provider-abstracted layer” claim
**Location**: Summary (line 8); Structure Decision (line 70)
The plan declares provider abstraction but does not define required adapter inputs/outputs, normalized error codes, timeout behavior, or session lifecycle semantics.
**Suggestion**: Add an interface table in `plan.md` (or reference contract section) with method signatures, required fields, canonical error taxonomy, and expected exit codes.

#### Issue 3 (High): Path and filename safety is undefined for user-provided artifact/review targets
**Location**: Summary command shape (line 8); Constraints (line 19)
`/speckit.peer.review <artifact>` implies user-controlled target selection, but the plan does not define allowed artifact values or filesystem path normalization. This can allow path traversal or unintended file writes.
**Suggestion**: Restrict artifact input to a fixed enum (`spec|research|plan|tasks`), reject arbitrary paths, canonicalize review output path, and enforce repository-root containment checks.

#### Issue 4 (High): Security model omits prompt/content injection handling from reviewed artifacts
**Location**: Summary behavior (line 8); Code Quality claims (line 27)
The plan routes artifact content into an external LLM adapter but does not define sanitization/guardrails for malicious instructions embedded in artifacts.
**Suggestion**: Add explicit prompt-boundary rules: immutable system preamble, artifact-content delimiting, instruction-priority policy, and mandatory quoting of user content in adapter prompts.

#### Issue 5 (High): Test strategy is underspecified and over-reliant on manual scenarios
**Location**: Testing (line 15); Constitution Check III (line 28)
The plan references validation script + manual install cases, but no automated contract tests for command behavior, error paths, or state-transition correctness are defined.
**Suggestion**: Add automated test matrix for: first-run state init, session reuse, malformed/missing `.specify/peer.yml`, unsupported provider selection, and append-only round integrity.

#### Issue 6 (Medium): Performance goals do not cover actual peer command runtime or scaling behavior
**Location**: Performance Goals (line 18)
Targets are only for `validate-pack.sh` and `build-all.sh`; no SLOs exist for review/execute command latency, state file growth, or large artifact handling.
**Suggestion**: Add command-level budgets (e.g., initial response < N s for local preflight), max artifact size policy, and graceful degradation behavior when artifacts are large.

#### Issue 7 (Medium): Failure isolation is stated but rollback/idempotency behavior is not defined
**Location**: Constraints (line 19); Constitution Check II/IV (lines 27, 29)
The plan says unsupported providers fail clearly, but does not specify what happens if an execution fails after partial write to review/state files.
**Suggestion**: Define idempotent write sequence and rollback markers (e.g., write round header only after adapter success, or write explicit failed-round metadata with stable schema).

#### Issue 8 (Medium): External dependency discovery is brittle and not portable
**Location**: Primary Dependencies (line 13)
The dependency path `~/.claude/skills/codex/scripts/ask_codex.sh` is environment-specific and may fail across shells/systems without deterministic discovery.
**Suggestion**: Specify provider discovery order (config path override -> env var -> default path), plus a startup preflight command with actionable remediation text.

#### Issue 9 (Medium): Data model/versioning for persisted JSON/YAML is not defined
**Location**: Storage (line 14); shared schema path (line 67)
Persistent state is planned, but there is no schema version field, migration path, or backward compatibility policy.
**Suggestion**: Require `version` in `provider-state.json` and `.specify/peer.yml`, define migration policy for minor/major changes, and include compatibility checks in startup validation.

#### Issue 10 (Medium): Plan does not map requirements to implementation phases/deliverables
**Location**: Entire plan structure, especially absence after Complexity Tracking (lines 72-76)
There is no phase-by-phase work breakdown, dependency order, or requirement-to-artifact traceability in this file.
**Suggestion**: Add implementation phases with entry/exit criteria and a traceability table mapping each FR/NFR to concrete files and verification steps.

#### Issue 11 (Low): Responsibility boundaries between `packs/peer` and `shared/` may be over-generalized for v1
**Location**: Source Code structure (lines 62-70)
Shared provider utilities are introduced before multiple consumers exist, increasing cognitive overhead and possible premature abstraction.
**Suggestion**: Document explicit criteria for when code graduates from pack-local to shared; until then keep v1 adapter contracts pack-local and mirror in `shared/` only when reused.

#### Issue 12 (Suggestion): UX contract for command output is too vague for consistent operator experience
**Location**: Constitution Check IV (line 29)
“Actionable errors” is good but no standard output format is defined for success, warnings, or next actions.
**Suggestion**: Define CLI output templates with stable sections (`Result`, `Round`, `Session`, `Next step`) and canonical stderr patterns for parseability.

### Positive Aspects
- The feature scope is clearly stated and intentionally constrained to a v1 Codex-backed implementation.
- The directory layout is simple and readable, with a clean distinction between pack artifacts and shared schema concerns.
- Append-only review rounds are a strong auditability choice for iterative peer-review workflows.
- The plan explicitly acknowledges provider error isolation and avoids hard coupling to sibling packs.

### Summary
Top 3 key issues: (1) missing concurrency-safe state/write protocol, (2) missing formal provider adapter interface and error contract, and (3) insufficiently specified automated verification for stateful and failure-path behavior.
**Consensus Status**: NEEDS_REVISION

---
## Round 2 — 2026-03-27
### Overall Assessment
The plan improved substantially and addresses most of Round 1’s structural gaps, especially around adapter contract definition, traceability, and baseline safety constraints. Remaining concerns are now concentrated in implementation precision: cross-platform locking behavior, deterministic parsing/contracts for automation, and operational recovery paths. The design is close to execution-ready but still needs hardening for reliability and portability.
**Rating**: 7.8/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Concurrency/atomic writes undefined | PARTIALLY_RESOLVED | Atomic rename + `flock` + delayed round header added, but lock portability/retry semantics still missing. |
| 2 | Adapter interface contract missing | PARTIALLY_RESOLVED | Interface table and taxonomy added; deterministic parsing and exit-code mapping still incomplete. |
| 3 | Artifact/path safety undefined | RESOLVED | Artifact enum restriction and arbitrary-path rejection are now specified. |
| 4 | Prompt/content injection guardrails missing | PARTIALLY_RESOLVED | Delimiters + opaque-content handling added; no secret/redaction policy yet. |
| 5 | Test strategy underspecified | PARTIALLY_RESOLVED | Automated test matrix added, but harness/ownership and per-case assertions remain vague. |
| 6 | Performance goals missing command-level constraints | PARTIALLY_RESOLVED | Preflight SLA and size limit added; no full command runtime/timeout SLOs. |
| 7 | Rollback/idempotency unclear | PARTIALLY_RESOLVED | Round-header ordering improved; cross-file transactional integrity still not specified. |
| 8 | Dependency discovery brittle | RESOLVED | Discovery order and env override now documented. |
| 9 | Versioning/migration absent | PARTIALLY_RESOLVED | Version fields and incompatibility failure added; migration strategy still absent. |
| 10 | No FR-to-deliverable mapping | RESOLVED | Implementation phases and FR traceability table added. |
| 11 | Shared boundary over-generalized | RESOLVED | Explicit shared-graduation criterion added. |
| 12 | UX output contract too vague | PARTIALLY_RESOLVED | Prefix/error/success output shape added; machine-readable contract still missing. |

### Issues
#### Issue 1 (Critical): File-lock approach is not portable to stated macOS target and lacks fallback path
**Location**: Technical Context, Constraints (line 19); Target Platform (line 16)
The plan mandates advisory `flock`, but `flock` is not reliably available by default on macOS environments. This creates a correctness gap for append-only guarantees on one of the declared target platforms.
**Suggestion**: Specify a cross-platform lock strategy with ordered fallbacks (e.g., `flock` -> lockdir via `mkdir` -> fail-fast with remediation), plus lock acquisition timeout and retry behavior.

#### Issue 2 (High): Adapter success outputs are parse-fragile and underspecified
**Location**: Adapter Interface table (lines 88-89)
`session_id=<value>` and `output_path=<path>` in stdout are easy to break with extra logs, whitespace, or multiline output from wrappers.
**Suggestion**: Require a strict machine-parseable payload (single-line JSON or dedicated output file), and reserve stderr exclusively for non-contract logs/errors.

#### Issue 3 (High): Error taxonomy is not bound to deterministic exit-code mapping
**Location**: Adapter Interface + Error taxonomy (lines 91-98)
Categories exist but there is no one-to-one mapping between taxonomy values and exit codes. Tooling cannot reliably branch behavior based only on exit status.
**Suggestion**: Define a canonical mapping table (`exit_code`, `error_code`, `message_template`) and require adapters to emit both consistently.

#### Issue 4 (High): Persistent file locations and naming rules are still ambiguous
**Location**: Summary + Storage/Constraints (lines 8, 14, 19)
The plan says state and review files exist, but not their exact canonical paths, naming convention, or scope key (feature, branch, repo). This can create collisions across concurrent features.
**Suggestion**: Define exact paths (e.g., `.specify/peer/provider-state.json`, `specs/<feature>/reviews/plan-review.md`) and naming rules keyed by feature id.

#### Issue 5 (Medium): Cross-file consistency model is incomplete for state+review writes
**Location**: Constraints (line 19)
The plan orders round header write after adapter success, but does not define behavior if `provider-state.json` update succeeds and review append fails (or vice versa).
**Suggestion**: Add a two-step commit protocol (stage -> verify -> commit) or recovery markers so reruns are idempotent and detectable.

#### Issue 6 (Medium): Timeout behavior is named but not operationally defined
**Location**: Error taxonomy (line 95); Performance goals (line 18)
`PROVIDER_TIMEOUT` exists without timeout thresholds, retry count, or cancellation behavior. Different implementations may diverge.
**Suggestion**: Set explicit timeout defaults, max retries, backoff policy, and operator override controls in config.

#### Issue 7 (Medium): Schema-version policy lacks migration and operator recovery workflow
**Location**: Constraints (line 19)
The plan says incompatible schema versions fail with clear error, but does not define migration tooling or safe archival path for old files.
**Suggestion**: Add migration command/procedure (`v1 -> v2`), backup naming convention, and downgrade/rollback notes.

#### Issue 8 (Medium): Automated test matrix lacks executable ownership and assertion detail
**Location**: Testing (line 15); Implementation deliverables (line 111)
Cases are listed, but not tied to concrete test files, test harness invocation, or expected assertion outputs per case.
**Suggestion**: Add a test manifest table: case id -> script/test file -> expected result -> CI gate command.

#### Issue 9 (Medium): Artifact size limit is arbitrary without escape hatch for valid larger plans
**Location**: Performance goals (line 18)
A hard 50 KB cap may block realistic artifacts (large `spec.md`/`tasks.md`) and reduce tool usefulness.
**Suggestion**: Add rationale-backed default + override mechanism (`peer.yml` max size), and optional chunked review mode for large files.

#### Issue 10 (Low): Internal consistency conflict around script authorship
**Location**: Constitution Check II (line 27); Implementation deliverables (line 111)
The plan states “No scripts are authored in this pack” while listing `scripts/validate-pack.sh` as a deliverable for this feature.
**Suggestion**: Clarify wording to “no new runtime scripts in `packs/peer/`” and explicitly state whether `scripts/validate-pack.sh` is modified vs newly authored.

#### Issue 11 (Suggestion): Output contract remains human-friendly but weak for downstream automation
**Location**: Constraints output format (line 19)
Prefixing stdout/stderr improves readability but still leaves consumers parsing prose fields.
**Suggestion**: Define optional `--format json` output with a stable schema (`command`, `artifact`, `round`, `status`, `review_path`, `session_id`, `consensus`).

### Positive Aspects
- The plan now includes explicit adapter interface and error taxonomy sections, which significantly improves implementation clarity.
- FR-to-file traceability and phase dependency ordering are now present and useful for execution planning.
- Safety constraints (artifact enum restriction, atomic rename, delayed round header write) materially improved reliability compared to Round 1.
- Shared-module graduation criteria now reduce premature abstraction risk.

### Summary
Top 3 key issues: (1) non-portable locking strategy for macOS, (2) missing deterministic machine contract for adapter output/error mapping, and (3) incomplete recovery model for cross-file write consistency.
**Consensus Status**: NEEDS_REVISION

---
## Round 3 — 2026-03-27
### Overall Assessment
The plan is materially stronger than Round 2 and now covers most structural concerns, including canonical paths, lock fallback, exit-code mapping, and a concrete test manifest. However, there are still implementation-safety gaps in contract consistency and failure recovery that can produce ambiguous runtime behavior. Given those gaps, the plan is close but not yet genuinely implementation-safe.
**Rating**: 8.3/10

### Previous Round Tracking (Round 2 issues)
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Locking not portable / no fallback | RESOLVED | Added `flock` fallback to lockdir with retry loop in constraints. |
| 2 | Adapter outputs parse-fragile | PARTIALLY_RESOLVED | Last-two-lines rule added, but stdout still permits extra informational content. |
| 3 | No exit-code mapping | RESOLVED | Explicit exit-code to error-code table added. |
| 4 | Canonical file paths ambiguous | RESOLVED | Dedicated canonical paths section now defines all core file locations. |
| 5 | Cross-file write consistency incomplete | PARTIALLY_RESOLVED | Retry/recovery intent added, but no concrete recovery algorithm/state marker contract. |
| 6 | Timeout policy not operational | PARTIALLY_RESOLVED | Default timeout + env override added; retry/cancel semantics remain underdefined. |
| 7 | Migration/recovery workflow absent | PARTIALLY_RESOLVED | Version handling clarified for v1, but no backup-safe remediation path documented. |
| 8 | Test matrix lacked execution detail | RESOLVED | Added test manifest with case IDs, invocation, and expected result. |
| 9 | Artifact size limit had no escape hatch | RESOLVED | `max_artifact_size_kb` config override now specified. |
| 10 | Script authorship inconsistency | RESOLVED | Clarified runtime scripts vs repo-level validation script scope. |
| 11 | No machine-readable output mode | UNRESOLVED | Explicitly deferred to v2; still absent for automation consumers. |

### Issues
#### Issue 1 (Critical): Contract inconsistency between exit-code mapping and test expectations
**Location**: Exit-code table (lines 95-105); Test manifest T-05 (line 143)
The plan maps exit code `1` to `PROVIDER_UNAVAILABLE`, but T-05 expects unimplemented provider to return exit `1` with a v1-only message. This creates conflicting behavior for a core failure path and makes automated validation non-deterministic.
**Suggestion**: Assign a distinct error code/exit code for unimplemented providers (e.g., `6 UNIMPLEMENTED_PROVIDER`) and update both the mapping table and T-05 expectation.

#### Issue 2 (High): Lockdir fallback has no stale-lock ownership or cleanup policy
**Location**: Constraints (line 19)
The lock fallback defines acquisition attempts but not stale lock detection, ownership metadata, or cleanup after process crashes. A crash can leave a permanent lock and block all future writes.
**Suggestion**: Define lockfile metadata (pid + timestamp), stale timeout policy, and safe stale-lock reclamation rules; add mandatory cleanup on normal exit.

#### Issue 3 (High): Recovery path for partial write is described but not formally specified
**Location**: Constraints (line 19)
The plan states incomplete states are "detected and recovered," but does not define exact detection criteria, reconciliation order, or whether replay can duplicate rounds.
**Suggestion**: Add a deterministic recovery algorithm (inputs, state checks, decision table, idempotency guarantees) and bind it to explicit test cases.

#### Issue 4 (High): Stdout parsing contract remains brittle under informational output
**Location**: Adapter Interface output rules (lines 89-90)
The contract allows additional informational stdout and instructs consumers to parse the last two lines. Any wrapper/toolchain mutation can break this assumption.
**Suggestion**: Reserve stdout exclusively for contract fields (or single JSON line) and move informational output to a debug log file behind a verbosity flag.

#### Issue 5 (Medium): Sensitive state file handling lacks permission hardening
**Location**: Constraints (line 19); Canonical file paths (line 113)
`provider-state.json` stores session continuity data but file permissions/umask are not specified. On shared environments this can leak state between users.
**Suggestion**: Require secure file mode (e.g., `0600`) for provider state and enforce it on create/update.

#### Issue 6 (Medium): `featureId` derivation is underspecified and potentially inconsistent
**Location**: Canonical file paths note (line 119)
The plan says `featureId` is branch name, but spec directory naming and branch naming can diverge (renames, detached head, CI checkouts), producing path mismatches.
**Suggestion**: Define a single source of truth for `featureId` (prefer spec directory slug), and treat branch name as advisory metadata only.

#### Issue 7 (Medium): Config value validation bounds are missing
**Location**: Performance/constraints config fields (lines 18-19)
`max_artifact_size_kb` and `CODEX_TIMEOUT_SECONDS` are configurable but no min/max bounds or invalid-value behavior is defined.
**Suggestion**: Add validation rules (integer range, default fallback, explicit error on invalid values) and include boundary tests.

#### Issue 8 (Medium): Version incompatibility handling may force destructive remediation
**Location**: Constraints version policy (line 19)
Absent/old `version` currently leads to fail + re-create instruction, but no backup procedure is mandated before re-creation.
**Suggestion**: Require automatic backup (`*.bak.<timestamp>`) before any re-create instruction and document recovery steps.

#### Issue 9 (Medium): Test manifest still misses critical failure-path scenarios
**Location**: Test manifest (lines 137-146)
Current cases do not explicitly test timeout mapping, lock contention/stale lock recovery, partial-write recovery, or stdout contract parsing rules.
**Suggestion**: Add at least four cases: timeout (`T-09`), lock contention (`T-10`), orphan recovery (`T-11`), and stdout contract validation (`T-12`).

#### Issue 10 (Low): Performance risk statement is overly absolute
**Location**: Constitution Check V (line 30); timeout/lock behavior (line 19)
The claim "No performance risk" is too strong given 60s timeouts, retries, and file-lock contention paths.
**Suggestion**: Reword to bounded risk with explicit thresholds and monitoring criteria.

#### Issue 11 (Suggestion): Machine-readable output is deferred without transitional compatibility path
**Location**: Complexity tracking deferral (line 78); output format constraints (line 19)
Deferring `--format json` to v2 leaves automation clients scraping text in v1.
**Suggestion**: Add a minimal v1 transitional mode (e.g., optional sidecar metadata file) to avoid locking integrations into prose parsing.

### Positive Aspects
- The plan now has substantially stronger operational detail than earlier rounds, especially around file layout, error contracts, and test execution shape.
- The introduction of explicit exit-code/error-code mapping is a major reliability improvement.
- Canonical path definitions and size/timeout configurability make the design more practical across real workflows.
- Round-over-round responsiveness to review feedback is strong and measurable.

### Summary
Top 3 key issues: (1) conflicting exit-code semantics between the adapter contract and tests, (2) missing formal stale-lock/recovery algorithms, and (3) parser fragility from mixed informational stdout with contract fields.
**Consensus Status**: NEEDS_REVISION

---
## Round 4 — 2026-03-27
### Overall Assessment
The plan is now much closer to execution quality and has resolved most of the structural risks raised in Rounds 1–3. However, there are still contract-level inconsistencies and a few operational ambiguities that can cause implementation divergence in agent instructions. It is strong, but not yet fully implementation-safe.
**Rating**: 8.8/10

### Previous Round Tracking (Round 3 issues)
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Exit-code mapping vs tests inconsistent | RESOLVED | Added `UNIMPLEMENTED_PROVIDER` (exit 6) and aligned T-05. |
| 2 | Lock fallback lacked stale-lock policy | PARTIALLY_RESOLVED | Metadata + stale detection added, but retry window still too short for normal contention scenarios. |
| 3 | Partial-write recovery not formalized | PARTIALLY_RESOLVED | Recovery intent is clearer, but algorithm still relies on weak signals (`updated_at`). |
| 4 | Stdout parsing brittle | PARTIALLY_RESOLVED | Stdout now constrained to two lines, but success-field requirements conflict elsewhere in plan text. |
| 5 | Provider-state permissions missing | RESOLVED | `provider-state.json` mode `0600` now explicitly required. |
| 6 | `featureId` source ambiguous | RESOLVED | Source of truth changed to spec directory name. |
| 7 | Config bounds undefined | RESOLVED | Bounds for `CODEX_TIMEOUT_SECONDS` and `max_artifact_size_kb` are now defined. |
| 8 | Version mismatch could be destructive | RESOLVED | Auto-backup before re-create is now specified. |
| 9 | Missing failure-path tests | RESOLVED | T-09 through T-12 added. |
| 10 | Performance claim overly absolute | RESOLVED | Reworded to bounded-risk framing. |
| 11 | No machine-readable output mode | UNRESOLVED | JSON output remains explicitly deferred to v2. |

### Issues
#### Issue 1 (Critical): Output contract is internally contradictory on success payload
**Location**: Constraints (line 19); Adapter Interface output rules (lines 89-90)
The constraints say stdout is exclusively two lines (`session_id`, `output_path`), but the same constraints also state success output includes artifact name, round number, review path, and consensus status. Those cannot all coexist on stdout under the current rule.
**Suggestion**: Define one canonical success channel: either (a) keep stdout strictly two lines and write extra success fields to a sidecar metadata file, or (b) formally expand stdout contract and update adapter/tests accordingly.

#### Issue 2 (High): Stderr contract conflicts with verbosity behavior
**Location**: Constraints (line 19); Adapter Interface `Stderr contract` (line 91)
Line 91 says stderr is exclusively for errors, while line 19 routes non-contract output to stderr behind verbosity. This causes conflicting expectations for parsers and reviewers.
**Suggestion**: Reserve stderr strictly for errors, and route verbose informational output to a dedicated log file or separate debug stream contract.

#### Issue 3 (High): Automated test case count in exit criteria is stale
**Location**: Implementation deliverables (line 134); Test manifest (lines 140-151)
The exit criterion still says "all 8 automated test matrix cases" while the manifest now defines 12 cases (T-01..T-12). This can prematurely pass implementation with incomplete coverage.
**Suggestion**: Update line 134 to require all 12 cases (or explicitly define required vs optional tiers).

#### Issue 4 (High): Recovery detection logic is weakly specified and semantically fragile
**Location**: Constraints recovery rule (line 19)
Recovery relies on "round count in review file vs `updated_at` in provider-state.json," which is not a robust invariant for synchronization and can mis-detect under clock skew/manual edits.
**Suggestion**: Track an explicit monotonic `last_persisted_round` in provider-state.json and use that as the sole reconciliation key.

#### Issue 5 (Medium): Atomic-rename flow does not explicitly preserve secure file mode
**Location**: Constraints (`0600` + atomic rename, line 19)
The plan requires `0600` and atomic rename but does not state whether temp files are created with secure mode before rename. Mode drift can occur depending on creation defaults.
**Suggestion**: Specify temp-file creation with explicit secure permissions before write+rename, followed by a post-rename mode verification step.

#### Issue 6 (Medium): Lock timing policy can fail legitimate short-lived contention
**Location**: Constraints lock policy (line 19); Test T-10 (line 149)
With only 3 retries at 100 ms, an active but healthy lock lasting >300 ms can trigger avoidable failures even under normal concurrent use.
**Suggestion**: Increase retry budget (or use configurable exponential backoff) to tolerate expected contention while still bounding wait time.

#### Issue 7 (Medium): Exit code 3 condition wording remains logically ambiguous
**Location**: Exit-code mapping table (line 102)
Condition says "Exit 0 but `output_path` absent or empty" under exit code 3, which conflates provider exit and wrapper-normalized exit.
**Suggestion**: Clarify wording to "adapter returned success semantics but wrapper normalized to exit 3 due missing/empty `output_path`."

#### Issue 8 (Medium): Transient state and backup artifacts are not explicitly repo-hygiene scoped
**Location**: Canonical paths (lines 111-114); backup rule (line 19)
The plan writes `provider-state.json` and `.bak.*` files inside `specs/<feature>/reviews/` but does not state whether these are expected to be committed or ignored. This risks noisy diffs and accidental state sharing.
**Suggestion**: Add explicit VCS policy (`.gitignore` guidance or commit policy) for runtime state and backup artifacts.

#### Issue 9 (Low): `CODEX_SKILL_PATH` trust boundary is unspecified
**Location**: Constraints discovery order (line 19)
Allowing arbitrary env-path override is useful but unsafe without minimal validation expectations (owner, executable bit, path existence).
**Suggestion**: Add preflight checks for executable existence + readability and emit a warning when using non-default override paths.

#### Issue 10 (Low): Feature selection remains implicit for command execution context
**Location**: Summary command signature (line 8); Canonical path derivation (line 120)
Commands accept only `<artifact>` and rely on implicit feature resolution from directory context. In repositories with multiple specs, this can be ambiguous for operators.
**Suggestion**: Define deterministic resolution order (current working directory -> explicit feature flag -> fail with disambiguation prompt).

#### Issue 11 (Suggestion): JSON output deferral lacks an explicit compatibility roadmap checkpoint
**Location**: Complexity Tracking deferral (line 78)
Deferring `--format json` to v2 is acceptable, but there is no dated or criteria-based trigger to revisit the decision.
**Suggestion**: Add a concrete revisit condition (e.g., "promote when 2+ automation consumers require parse-stable output") and link it to a tracked follow-up item.

### Positive Aspects
- Most high-severity contract and safety issues from prior rounds were addressed quickly and concretely.
- The plan now reflects command-pack reality well: instruction-driven behavior, bounded preflight checks, and validation-script-centric SLOs.
- Test manifest coverage has expanded to include timeout, contention, orphan recovery, and stdout contract validation.
- Canonical paths and config bounds are now significantly clearer for implementers.

### Summary
Top 3 key issues: (1) contradictory success/stderr output contracts, (2) stale automated-test exit criterion count, and (3) fragile recovery invariant based on `updated_at` rather than a monotonic round marker.
**Consensus Status**: NEEDS_REVISION

---
## Round 5 — 2026-03-27
### Overall Assessment
The plan has matured significantly and resolves most earlier correctness defects, but it now shows spec-drift and complexity creep for a Markdown/YAML command-pack. Several new inconsistencies were introduced while hardening behavior (test count drift, retry-policy drift, and prefix-format drift). It is close, but still not implementation-safe enough to approve.
**Rating**: 8.6/10

### Previous Round Tracking (Round 4 issues)
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Success output contract contradiction | RESOLVED | Stdout is now strictly two lines; success summaries moved to stderr. |
| 2 | Stderr/verbosity contract conflict | RESOLVED | Stderr contract now explicitly includes human-readable and debug output behavior. |
| 3 | Automated test count stale | PARTIALLY_RESOLVED | Updated from 8 to 12, but manifest now lists 13 cases (new drift). |
| 4 | Fragile recovery invariant | PARTIALLY_RESOLVED | `last_persisted_round` added, but reverse-drift/corruption paths remain undefined. |
| 5 | Atomic rename mode preservation missing | RESOLVED | Temp-file mode and post-rename verification now specified. |
| 6 | Lock retry budget too short | PARTIALLY_RESOLVED | Increased to 5x200ms; still tight for real concurrent editor/agent contention. |
| 7 | Exit code 3 wording ambiguous | RESOLVED | Mapping now clearly states wrapper-normalized semantics. |
| 8 | VCS hygiene for state files missing | RESOLVED | Explicit `.gitignore` policy and T-13 check added. |
| 9 | `CODEX_SKILL_PATH` trust checks missing | RESOLVED | Existence/readability/executable checks and warning requirement added. |
| 10 | Feature resolution implicit | RESOLVED | Resolution order + `--feature` fallback and disambiguation prompt now defined. |
| 11 | JSON deferral lacked revisit trigger | RESOLVED | Explicit revisit trigger criteria added in complexity tracking. |

### Issues
#### Issue 1 (High): Test manifest and exit criterion are out of sync again
**Location**: Implementation deliverable exit criterion (line 134); test manifest (lines 140-153)
The exit criterion requires passing 12 cases, but the manifest defines 13 cases (`T-01` to `T-13`). This reintroduces ambiguity in what “done” means.
**Suggestion**: Update line 134 to 13 cases or define mandatory/optional subsets explicitly.

#### Issue 2 (High): Retry policy is inconsistent across sections
**Location**: Constraints lock policy (line 19); Constitution Check V (line 30); T-10 expectation (line 149)
Constraints and tests now use 5 retries at 200ms, but Constitution Check V still states 3 retries at 100ms.
**Suggestion**: Align all retry constants to one canonical value and reference a single source-of-truth section.

#### Issue 3 (High): Error prefix format is inconsistent between constraints and adapter contract
**Location**: Constraints error format (line 19); Adapter stderr contract (line 91)
Constraints mandate `[peer/<command>] ERROR:` while adapter contract says `[peer/ERROR_CODE]` for errors. Both cannot be simultaneously authoritative.
**Suggestion**: Define one canonical error format (or a two-field format) and update both sections and tests accordingly.

#### Issue 4 (Medium): Lock contention test has non-deterministic pass criteria
**Location**: T-10 (line 149)
“Fails with stale lock message or succeeds on release” allows two opposite outcomes as pass, which weakens regression detection.
**Suggestion**: Split T-10 into deterministic scenarios (e.g., `T-10a` release-before-timeout => success, `T-10b` stale-lock => specific failure/recovery).

#### Issue 5 (Medium): Recovery logic covers only one drift direction
**Location**: Constraints recovery rule (line 19); T-11 (line 150)
Only the case `review_rounds > last_persisted_round` is defined. The inverse case (state ahead of review due truncation/manual edit) is unspecified.
**Suggestion**: Add reconciliation rules for all drift permutations and corresponding tests.

#### Issue 6 (Medium): `last_persisted_round` lifecycle is underdefined
**Location**: Constraints state schema mention (line 19)
The plan introduces `last_persisted_round` but does not define initialization value, update atomicity guarantees for first run, or validation bounds.
**Suggestion**: Add a mini state-schema contract (`version`, `last_persisted_round`, `updated_at`, optional `session_id`) with invariants.

#### Issue 7 (Medium): Stale-lock reclaim rule is vulnerable to PID reuse edge cases
**Location**: Constraints stale-lock logic (line 19)
“Reclaim if owning pid is dead” can misfire under PID reuse on long-running systems, especially with coarse timestamps.
**Suggestion**: Include lock token/nonce in metadata and require token match before reclaim; keep PID as advisory only.

#### Issue 8 (Medium): `.gitignore` requirement is not represented as an implementation deliverable
**Location**: Constraints VCS policy (line 19); Implementation Phases table (lines 126-134)
The plan mandates `.gitignore` updates but does not include `.gitignore` in deliverables, creating scope ambiguity.
**Suggestion**: Add `.gitignore` as a tracked deliverable with explicit FR/SC linkage and exit criterion.

#### Issue 9 (Low): Warning output may leak local filesystem details
**Location**: Constraints override warning (line 19)
Emitting full override path in `[peer/WARN]` can expose user-specific paths in shared logs/reviews.
**Suggestion**: Redact home segments by default (e.g., `~`) or gate full-path emission behind debug mode.

#### Issue 10 (Suggestion): Constraints section is overloaded for an instruction-file project
**Location**: Constraints block (line 19)
A single dense constraints paragraph contains multiple contracts, policies, and algorithms, increasing misinterpretation risk for AI agents consuming Markdown instructions.
**Suggestion**: Split into structured sub-sections (`I/O Contract`, `State & Recovery`, `Locking`, `Config Validation`, `VCS Policy`) with short bullet rules.

#### Issue 11 (Suggestion): Complexity level may exceed v1 command-pack needs
**Location**: Complexity Tracking (lines 72-79); Constraints (line 19)
Given this is a non-compiled command-pack, the current recovery+locking+warning surface may be over-engineered for initial release.
**Suggestion**: Define a strict “v1 minimum” profile and move optional hardening behaviors behind explicit v1.1/v2 backlog items.

### Positive Aspects
- Most previously raised correctness gaps have been addressed with concrete updates, not vague statements.
- The plan now has stronger operational boundaries for state files, feature resolution, and adapter exit semantics.
- Test coverage breadth is notably improved, especially around timeout, recovery, and output-contract validation.
- The document reflects command-pack realities better than earlier rounds.

### Summary
Top 3 key issues: (1) newly reintroduced spec drift across test/retry/error-format sections, (2) incomplete reconciliation model for state/file divergence, and (3) growing complexity density that may hurt instruction reliability for agents.
**Consensus Status**: NEEDS_REVISION

---
## Round 6 — 2026-03-27
### Overall Assessment
The plan is now substantially consistent and implementation-ready for a Spec Kit command-pack, with most prior defects resolved. Remaining items are narrow contract-alignment and documentation-scope refinements rather than foundational design flaws. This is no longer in major-risk territory.
**Rating**: 9.2/10

### Previous Round Tracking (Round 5 issues)
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Test count mismatch (12 vs 13) | RESOLVED | Exit criterion updated; manifest now aligned to 14 defined cases. |
| 2 | Retry policy drift across sections | RESOLVED | Constraints, Constitution, and tests now use 5x200ms consistently. |
| 3 | Error prefix mismatch | PARTIALLY_RESOLVED | Canonical format added, but one remaining stderr-format inconsistency still exists (see Round 6 Issue 1). |
| 4 | Non-deterministic lock contention test | RESOLVED | Split into deterministic `T-10a` and `T-10b`. |
| 5 | Recovery only one-directional | RESOLVED | Added explicit corruption branch (`last_persisted_round > review count`) and fail behavior. |
| 6 | `last_persisted_round` lifecycle undefined | RESOLVED | Initialization and invariant rules are now specified. |
| 7 | PID reuse risk on stale-lock reclaim | RESOLVED | Nonce-based ownership check added. |
| 8 | `.gitignore` not tracked as deliverable | RESOLVED | `.gitignore` added to deliverables with explicit exit criterion. |
| 9 | Override warning leaked local path | RESOLVED | Home redaction by default, full path only in debug mode. |
| 10 | Constraints block overloaded | RESOLVED | Constraints are now split into structured subsections. |
| 11 | v1 complexity too high | PARTIALLY_RESOLVED | Structure improved, but one optional simplification remains beneficial (see Round 6 Suggestion). |

### Issues
#### Issue 1 (Medium): Error message contract is still inconsistent in two adjacent sections
**Location**: Adapter Interface `Stderr contract` (line 107); Adapter Interface failure line (line 109)
Line 107 defines canonical error format as `[peer/<command>] ERROR: <ERROR_CODE>: <message>`, while line 109 says failure writes actionable `[peer/ERROR_CODE]` message to stderr. These are different wire contracts.
**Suggestion**: Keep one canonical stderr error schema and update line 109 to match it exactly.

#### Issue 2 (Medium): `STATE_CORRUPTION` is used but not mapped in exit/error taxonomy
**Location**: State & Recovery (line 25); Test `T-11b` (line 169); Exit-code mapping table (lines 115-121)
`STATE_CORRUPTION` is now a defined failure path and test expectation, but it does not appear in the error-code mapping table, leaving exit-code behavior undefined.
**Suggestion**: Add `STATE_CORRUPTION` to the mapping table with a deterministic exit code (or explicitly fold it into `VALIDATION_ERROR` with a required subcode).

#### Issue 3 (Low): Performance gate includes a non-command-pack metric that may be out-of-scope
**Location**: Performance Goals (line 18); Constitution Check V (line 46)
The plan still includes `build-all.sh < 60 s` even though this artifact is a command-pack and stated SLO focus is preflight + validation script behavior.
**Suggestion**: Mark `build-all.sh` as informational/global CI context, and keep command-pack acceptance gates scoped to `validate-pack.sh` + preflight checks.

#### Issue 4 (Suggestion): Consider reducing v1 operational surface in command instructions
**Location**: Constraints subsections (lines 21-35); Complexity Tracking (lines 90-94)
The design is now coherent but still fairly dense for AI-instruction artifacts. Some hardening details may be better promoted to v1.1 once real-world usage validates need.
**Suggestion**: Keep current behavior, but tag non-essential hardening clauses as “v1 optional” in comments to lower implementation friction for first rollout.

### Positive Aspects
- Prior rounds’ major blockers (path safety, state integrity, locking fallback, mapping consistency, test determinism) were addressed thoroughly.
- The constraints are now structured in a way that is far more usable for AI agents reading Markdown instructions.
- Implementation deliverables and test manifest are materially stronger and closer to executable acceptance criteria.
- The plan now reads like a realistic v1 command-pack implementation target.

### Summary
Top 3 key issues: (1) finalize one canonical stderr error schema, (2) add explicit taxonomy mapping for `STATE_CORRUPTION`, and (3) trim/clarify out-of-scope performance gate language.
**Consensus Status**: MOSTLY_GOOD

---
## Round 7 — 2026-03-27
### Overall Assessment
The plan is now coherent, internally consistent, and appropriately scoped for a Spec Kit command-pack implemented via Markdown/YAML instructions. The previously blocking contract mismatches and taxonomy gaps are resolved, and acceptance/validation criteria are now aligned. No significant implementation blockers remain.
**Rating**: 9.7/10

### Previous Round Tracking (Round 6 issues)
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Stderr error schema inconsistency | RESOLVED | Adapter failure line now matches canonical format `[peer/<command>] ERROR: <ERROR_CODE>: <message>`. |
| 2 | `STATE_CORRUPTION` missing from taxonomy mapping | RESOLVED | Added to exit-code table with deterministic exit code `7`. |
| 3 | `build-all.sh` treated as command-pack gate | RESOLVED | Reframed as informational/global CI context in Performance Goals and Constitution V. |
| 4 | Optional complexity reduction suggestion | RESOLVED | Constraints are now well-structured and complexity is acceptable for v1 command-pack execution. |

### Issues (if any remain)
#### Issue 1 (Suggestion): Link the v2 `--format json` revisit trigger to a concrete tracker item
**Location**: Complexity Tracking, `--format json` row (line 94)
The revisit condition is clear, but there is no explicit issue/ADR reference for where that trigger will be evaluated.
**Suggestion**: Add a placeholder issue ID or backlog reference so the trigger is operationally discoverable.

### Positive Aspects
- Contract consistency is now strong across constraints, adapter interface, and test manifest.
- Failure taxonomy and exit-code behavior are explicit and test-backed, including `STATE_CORRUPTION`.
- Acceptance gates are now aligned with command-pack reality (validation + preflight), with global CI metrics clearly demoted to informational context.
- The plan is actionable for implementation without requiring additional architectural clarification.

### Summary
The plan is implementation-ready with no material blockers.
**Consensus Status**: APPROVED
