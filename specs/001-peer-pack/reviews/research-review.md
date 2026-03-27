# Research Review: Spec Kit Peer Workflow Integration
**Research File**: specs/001-peer-pack/research.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
`research.md` established useful early decisions, but it is no longer synchronized with the current implementation direction captured in `plan.md`, `data-model.md`, and contracts. Several decisions now encode outdated schemas and prompt/output assumptions that can mislead implementation if treated as authoritative. In its current state, the research artifact needs revision before it can be considered a reliable source of truth.
**Rating**: 6.8/10

### Issues
#### Issue 1 (Critical): Provider state decision is incompatible with current state contract
**Location**: `research.md` Decision 2 (lines 23-49)
Decision 2 defines provider state as `provider -> workflow -> {session_id, updated_at}` only, but current docs require additional state semantics (`version`, lifecycle fields, and recovery invariants), including `STATE_CORRUPTION` handling in plan/data-model. This mismatch can cause incorrect persistence logic.
**Suggestion**: Rewrite Decision 2 to match the current authoritative state model (including versioning, reconciliation key(s), and lifecycle fields) and explicitly cross-reference the canonical schema source.

#### Issue 2 (High): Peer config schema in research is stale versus plan/data-model
**Location**: `research.md` Decision 3 (lines 52-76)
The example omits fields now required elsewhere (`version`, `max_rounds_per_session`, `max_context_rounds`) and leaves stub provider entries underspecified. Cross-file consumers may implement incomplete validation if they follow this section.
**Suggestion**: Update Decision 3 schema and rationale to mirror the current config contract in `data-model.md` and `plan.md`, including field defaults and validation bounds.

#### Issue 3 (High): Internal contradiction in extension manifest decision
**Location**: `research.md` Decision 6 (lines 107-123)
The prose says `provides.memory` should be empty in v1, but the YAML example includes `memory/peer-guide.md`. This is a direct contradiction inside the same decision.
**Suggestion**: Correct the decision text to match the example and current plan (memory included in v1), and remove conflicting wording.

#### Issue 4 (High): Research does not reconcile `plan-review.md` vs `code-review.md` ambiguity from spec narrative
**Location**: `research.md` Decision 4 (lines 79-90); Resolved Clarifications claim (lines 135-146)
Research asserts shared `plan-review.md` for plan + code review, but `spec.md` user-story narrative still references `reviews/code-review.md` in places. The research file claims all clarifications are resolved without addressing this conflict explicitly.
**Suggestion**: Add an explicit “spec narrative corrected” note and cite FR-010 as authoritative, with a deprecation note for `code-review.md` wording.

#### Issue 5 (Medium): Status marker set in research is outdated
**Location**: `research.md` Decision 4 (line 81)
Decision 4 only lists `NEEDS_REVISION | MOSTLY_GOOD | APPROVED` for artifact rounds, while current data model introduces additional operational statuses/error-round behavior (e.g., `BLOCKED` and error signaling patterns).
**Suggestion**: Align Decision 4 with the current status taxonomy and specify which statuses are valid for artifact vs code-review contexts.

#### Issue 6 (Medium): Prompt/output contract is underspecified for parse reliability
**Location**: `research.md` Decision 1 (lines 9-20), Decision 2 rationale (line 42)
Given downstream parsing depends on strict markers, research should define prompt/output constraints more explicitly (prompt-engineering pattern: structured outputs and deterministic terminators). Current text stays high-level and risks inconsistent agent outputs.
**Suggestion**: Add a prompt-contract subsection with deterministic output requirements (required terminal status line, fixed heading shape, and parse-failure fallback behavior).

#### Issue 7 (Medium): Delimiter strategy is not standardized across artifacts
**Location**: `research.md` Decision 1 impact (line 19)
Research does not declare a canonical artifact-content delimiter, while other docs use delimiter-dependent prompt logic with slight naming variations. This increases risk of prompt-template drift.
**Suggestion**: Add one canonical delimiter pair in research and cross-reference it from contracts/data-model to avoid template divergence.

#### Issue 8 (Medium): Error recovery design is missing from research decisions
**Location**: `research.md` Decisions 2, 4, 5 (lines 23-104)
Current implementation contracts include timeout, parse-failure, lock/contention, and state-corruption handling, but research does not document these as deliberate design decisions. This weakens traceability of failure-mode choices.
**Suggestion**: Add a dedicated decision for failure-mode handling and retry/recovery policy, including why each error path is fail-fast vs auto-recover.

#### Issue 9 (Low): Codex dependency decision omits override/discovery nuance now present in plan
**Location**: `research.md` Decision 5 (lines 93-104)
Decision 5 focuses on a fixed path prerequisite model, but current plan supports override/discovery behavior (`CODEX_SKILL_PATH`, redacted warnings). Research is now incomplete relative to implemented behavior.
**Suggestion**: Expand Decision 5 to include provider discovery precedence and rationale for override safety checks.

#### Issue 10 (Low): “All clarifications resolved” statement is overconfident given current drift
**Location**: `research.md` Status + Resolved Clarifications (line 5; lines 135-146)
The file claims complete resolution, but multiple key sections are outdated relative to current authoritative docs.
**Suggestion**: Change status to “Needs Sync” (or similar), add “Last verified against plan/data-model/contracts” timestamp, and include a sync checklist.

#### Issue 11 (Suggestion): Missing decision record for v1/v2 output-format tradeoff
**Location**: `research.md` (no explicit section; cross-check with `plan.md` Complexity Tracking lines 88-95)
Plan now documents a conscious v1 deferral of `--format json` with a revisit trigger, but research has no corresponding decision, reducing traceability of this important prompt/output tradeoff.
**Suggestion**: Add a decision capturing why human-readable output is retained in v1 and the exact criteria for moving to machine-readable output in v2.

### Positive Aspects
- The research file is well-structured into explicit decisions with rationale and alternatives.
- Decision 1 correctly anchors command artifacts in Markdown + frontmatter, consistent with command-pack conventions.
- Decision 4’s high-level intent to keep review history append-only and human-readable is sound.
- Decision 5 properly identifies external Codex skill dependency as a coupling boundary.

### Summary
Research quality is solid at a structural level, but the content is out-of-date versus current plan/data-model/contracts and should not be treated as authoritative until synchronized. Top priorities are updating the provider-state and config decisions, resolving manifest and review-file ambiguities, and adding explicit prompt/output reliability decisions.
**Consensus Status**: NEEDS_REVISION

---
## Round 2 — 2026-03-27
### Overall Assessment
The revised `research.md` fixed most Round 1 defects and is materially better structured. However, a few high-impact consistency gaps still remain across `research.md`, `plan.md`, `data-model.md`, and `contracts/review-command.md`, especially around prompt delimiter and state/error taxonomy contracts. The document is close, but not yet fully synchronized.
**Rating**: 8.4/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Provider state decision incompatible | PARTIALLY_RESOLVED | Decision now versioned/lifecycle-aware, but schema still diverges from plan/data-model details. |
| 2 | Peer config schema stale | RESOLVED | Added version and session/context controls. |
| 3 | Extension manifest contradiction | RESOLVED | Decision text now matches memory-included manifest. |
| 4 | `plan-review.md` vs `code-review.md` ambiguity | PARTIALLY_RESOLVED | Historical wording called out, but source docs still contain mixed narrative references. |
| 5 | Status marker taxonomy outdated | PARTIALLY_RESOLVED | Added broader taxonomy, but cross-doc alignment still incomplete. |
| 6 | Prompt/output contract underspecified | RESOLVED | Deterministic terminal markers and prompt-contract language added. |
| 7 | Delimiter strategy not standardized | PARTIALLY_RESOLVED | Canonical delimiter added in research, but still mismatched elsewhere. |
| 8 | Error recovery decision missing | PARTIALLY_RESOLVED | Added failure-mode decision, but error-code mapping not consistently propagated. |
| 9 | Codex discovery override nuance missing | RESOLVED | Discovery order and override validation now documented. |
| 10 | “All clarifications resolved” overconfident | PARTIALLY_RESOLVED | Status wording improved, but still claims full synchronization despite remaining drift. |
| 11 | Missing v1/v2 output-format decision | RESOLVED | Added explicit v1 output strategy + v2 trigger. |

### Issues
#### Issue 1 (High): Canonical artifact delimiter is still inconsistent across files
**Location**: `research.md` Decision 1 (line 13); `data-model.md` Artifact delimiter (line 23); `plan.md` Adapter Interface input prompt (line 103)
Research/Data Model define `--- BEGIN ARTIFACT CONTENT ---`, while Plan Adapter Interface still specifies `--- BEGIN ARTIFACT ---`. This creates prompt-template drift risk and brittle parsing behavior.
**Suggestion**: Pick one canonical delimiter pair and update all references (research, data model, plan, adapter guide, and contract examples) in one sync change.

#### Issue 2 (High): Provider-state schema is not fully aligned across research, plan, and data-model
**Location**: `research.md` Decision 2 example (lines 30-51); `plan.md` State & Recovery (line 25); `data-model.md` ProviderState (lines 166-210)
Research includes `last_persisted_round` per workflow entry; Plan treats it as core reconciliation invariant; Data Model does not currently define this field in `SessionEntry`. The result is multiple competing schemas.
**Suggestion**: Define one authoritative ProviderState schema (including where `last_persisted_round` lives), then update all three docs and examples to match exactly.

#### Issue 3 (High): Error/status taxonomy still diverges from spec/plan/contracts
**Location**: `research.md` Decision 4 (line 99) + Decision 7 (line 157); `spec.md` FR-004 (line 94); `plan.md` exit-code table (lines 115-123); `contracts/review-command.md` error conditions (lines 117-125)
Research introduces `BLOCKED` and `PARSE_FAILURE` semantics, while spec/contract/plan do not consistently define or map them. This can produce incompatible behavior across implementations.
**Suggestion**: Create a single taxonomy matrix (status markers + error codes + exit codes + where each is valid) and reference it from all artifacts.

#### Issue 4 (Medium): Version type is inconsistent (`1` vs `"1"`)
**Location**: `research.md` Decision 2/3 examples (lines 32, 70); `data-model.md` ProviderState/PeerConfig version fields (lines 168, 220, 237)
Research examples use numeric `1`, while Data Model currently specifies string `"1"`. This is a subtle but implementation-relevant contract difference.
**Suggestion**: Standardize on one type (string or integer), enforce via schema, and update all examples/contracts accordingly.

#### Issue 5 (Medium): Synchronization claim remains stronger than evidence
**Location**: `research.md` status line (line 5) and Resolved Clarifications (line 186)
The file claims synchronization with plan/data-model/contracts, but unresolved contract drift still exists (delimiter/state/taxonomy).
**Suggestion**: Change status to "Partially Synchronized" until cross-file contract checks pass, and add a short unresolved-items checklist.

#### Issue 6 (Suggestion): Add a prompt-engineering conformance checklist to prevent future drift
**Location**: `research.md` Decisions 1, 7, 8 (lines 11-23, 155-180)
You now encode strong prompt design choices, but there is no lightweight conformance gate ensuring contracts keep those constraints over time.
**Suggestion**: Add a checklist section (delimiter, terminal marker, parse fallback, status mapping, stdout/stderr contract) and reference it in review criteria for research/plan/contracts.

### Positive Aspects
- The revised research document is much more rigorous and decision-oriented than Round 1.
- Prompt-engineering concerns are now explicitly represented (deterministic markers, output strategy, failure policy).
- Most previously identified schema/config/manifest gaps were fixed.
- The document now captures rationale and alternatives with clearer implementation intent.

### Summary
Round 2 removed most major issues, but three synchronization gaps remain high priority: delimiter contract mismatch, provider-state schema divergence, and taxonomy drift. After those are aligned, the research artifact should be ready for approval.
**Consensus Status**: NEEDS_REVISION

---
## Round 3 — 2026-03-27
### Overall Assessment
`research.md` is now substantially synchronized with `spec.md`, `plan.md`, `data-model.md`, and `contracts/review-command.md`, and nearly all Round 2 gaps are closed. The remaining concerns are narrow and mostly about keeping one canonical error/taxonomy contract visible across artifacts so implementers do not infer conflicting behavior. The document is close to final quality but still benefits from one final alignment pass.
**Rating**: 9.2/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Canonical artifact delimiter inconsistency | RESOLVED | `plan.md`, `data-model.md`, and `research.md` now consistently use `--- BEGIN ARTIFACT CONTENT ---` / `--- END ARTIFACT CONTENT ---`. |
| 2 | Provider-state schema divergence | RESOLVED | `last_persisted_round` is now present and aligned in `research.md`, `plan.md`, and `data-model.md`. |
| 3 | Error/status taxonomy divergence | PARTIALLY_RESOLVED | Core statuses now align (`BLOCKED`, `PARSE_FAILURE`, `STATE_CORRUPTION`), but secondary error-code naming still drifts across docs. |
| 4 | Version type inconsistency (`1` vs `"1"`) | RESOLVED | Version fields are now consistently modeled as integer `1`. |
| 5 | Synchronization claim stronger than evidence | PARTIALLY_RESOLVED | Document quality improved significantly, but remaining taxonomy drift means “fully synchronized” is still slightly overstated. |
| 6 | Add prompt-engineering conformance checklist | UNRESOLVED | Useful guardrail still not documented as a checklist artifact. |

### Issues
#### Issue 1 (High): Secondary error-code namespace is still not canonicalized across referenced artifacts
**Location**: `research.md` Decision 7 (Failure-Mode Handling), `plan.md` “Exit-code to error-code mapping” table, `data-model.md` “Error round heading schema”
The main status model is now aligned, but error-code names still diverge (`PROVIDER_UNAVAILABLE` in `plan.md` vs `ADAPTER_MISSING` in `data-model.md`, plus `LOCK_CONTENTION`/`UNKNOWN` only in `data-model.md`). Because `research.md` frames cross-file synchronization and design rationale, this unresolved namespace split can still produce inconsistent implementations.
**Suggestion**: Add one canonical error taxonomy matrix (error code, trigger condition, exit code, and whether it can appear in an error round heading), and reference that single matrix from `research.md`, `plan.md`, and `data-model.md`.

#### Issue 2 (Medium): Sync status line in research still overstates current cross-file parity
**Location**: `research.md` header status line (`Status: Revised — synchronized with ...`)
Given the remaining taxonomy drift, the explicit “synchronized” claim is slightly stronger than current evidence.
**Suggestion**: Either (a) update the remaining taxonomy drift immediately and keep the status as-is, or (b) temporarily change to “mostly synchronized” until the taxonomy matrix is unified.

#### Issue 3 (Suggestion): Prompt-engineering conformance controls remain implicit instead of explicit
**Location**: `research.md` Decisions 1, 7, 8
The document now contains strong prompt-contract decisions (canonical delimiters, deterministic terminal markers, parse expectations), but lacks an explicit conformance checklist for future edits.
**Suggestion**: Add a short “Prompt/Parsing Conformance Checklist” section with pass/fail items: delimiter pair, terminal status marker, stdout two-line contract, parse-failure behavior, and error-code mapping reference.

### Positive Aspects
- Cross-file consistency improved materially since Round 2; the major structural mismatches are now fixed.
- The research document now captures rationale, alternatives, and impact with implementation-relevant precision.
- Provider-state and delimiter contracts are now coherent across the core artifacts.
- The failure-mode and output-strategy decisions are clearly articulated and useful for maintainers.

### Summary
The research artifact is close to final quality and is largely implementation-ready, with only one meaningful alignment gap remaining: a fully canonical shared error taxonomy. Once that is unified (or explicitly delegated to one authoritative matrix), this review can be moved to APPROVED with high confidence.
**Consensus Status**: MOSTLY_GOOD
