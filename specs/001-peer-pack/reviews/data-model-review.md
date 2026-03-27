# Data Model Review: Spec Kit Peer Workflow Integration

**Artifact File**: specs/001-peer-pack/data-model.md
**Reviewer**: Codex (prompt-engineering-patterns applied)

---

## Round 1 — 2026-03-27

### Overall Assessment

The data model is structurally sound and readable. Entity boundaries are clean, the file-based storage approach is clearly justified, and the append-only review pattern is a strong auditability choice. However, evaluated through the lens of production prompt engineering patterns (context window management, structured output reliability, error recovery, schema versioning), several gaps emerge that would cause silent failures or non-recoverable states in a live multi-turn LLM workflow. The model needs hardening before it can safely back the command implementations.

**Rating**: 6.5/10

---

### Issues

#### Issue 1 (Critical): No schema version field in persisted entities

**Location**: Entity: ProviderState, Entity: PeerConfig

Neither `provider-state.json` nor `.specify/peer.yml` include a `version` field. This was flagged in plan-review Round 1 Issue 9 but was not carried forward into the data model. A schema-unversioned state file means:
- Any future field rename silently breaks session continuity
- No migration path exists; stale files can corrupt session lookup without any diagnostic signal
- The startup preflight (from plan.md) has no reliable way to detect incompatible state

**Suggestion**: Add `version: "1"` (string) as a top-level field to `provider-state.json` and a top-level `version: "1"` key to `.specify/peer.yml`. Define that the command reads this field first; if absent or unrecognized, log a warning and treat state as cold-start.

---

#### Issue 2 (Critical): No adapter response envelope entity — LLM output schema is undefined

**Location**: Entity: ReviewRound, Entity: ProviderState

The `ReviewRound` entity models the **written Markdown** result, but there is no entity representing the **raw LLM response** that is parsed to produce a `ReviewRound`. In production prompt engineering (structured output pattern), the output schema must be formally defined:

- What fields are required in the Codex response before it is safe to append to the review file?
- How is `statusMarker` extracted? (regex match, structured JSON output, last-line parse?)
- What happens when the response is valid Markdown but does not contain a valid statusMarker?

Without this, the implementation will make ad-hoc parsing decisions that diverge across providers.

**Suggestion**: Add an `AdapterResponse` entity with fields:
- `session_id: string` — returned by provider
- `output_path: string` — path to written response file
- `raw_content: string` — full response text (read from output_path)
- `parsed_status_marker: enum | null` — extracted from raw_content; null if not found
- `parse_valid: boolean` — whether required structure was present

Document the extraction rule: scan last 5 lines of raw_content for `**Consensus Status**: <MARKER>` or `Verdict: <MARKER>`; fail round if both are absent.

---

#### Issue 3 (High): SessionEntry missing context-continuity tracking fields

**Location**: Entity: ProviderState → SessionEntry

`SessionEntry` has only `session_id` and `updated_at`. This is insufficient for context window management — a core prompt engineering concern. The orchestrator has no basis to decide:
- Whether the current session context is nearing exhaustion (and a new session should be started)
- How many rounds have been conducted in the current session (to measure conversational drift)
- Whether a prior session was explicitly reset (vs. expired on the provider side)

This leads to the failure mode where the orchestrator silently sends a 9th round into an exhausted context, receiving hallucinated or truncated responses.

**Suggestion**: Add to `SessionEntry`:
- `rounds_in_session: integer` — count of rounds appended under this session_id
- `session_started_at: string` — ISO 8601 timestamp of session creation
- `context_reset_reason: string | null` — `"manual"`, `"provider_expired"`, `"max_rounds_exceeded"`, or null (normal continuation)

Add a `max_rounds_per_session` field to `PeerConfig` (default: 10) that the command checks before deciding to continue vs. reset.

---

#### Issue 4 (High): No entity for failed/error rounds — no partial-failure recovery path

**Location**: Entity: ReviewRound, Entity: ReviewFile

The current model only represents successful rounds. When a provider invocation fails after the round header has been written (or before), the review file can be left in an indeterminate state:
- Round header written but body absent → next run will miscount round N
- `provider-state.json` updated but review file not written → session_id points to a conversation that has a round the file doesn't
- Provider times out mid-response → partial content appended

There is no `FailedRound` or error marker schema to record these events.

**Suggestion**: Add an `ErrorRecord` entity with fields:
- `roundNumber: integer`
- `date: string`
- `provider: string`
- `error_code: enum` — `PROVIDER_TIMEOUT`, `PARSE_FAILURE`, `ADAPTER_MISSING`, `LOCK_CONTENTION`, `UNKNOWN`
- `error_message: string`

Add the **error round heading schema** to `ReviewFile`:
```markdown
---

## Round N — YYYY-MM-DD [ERROR: PROVIDER_TIMEOUT]

Failed to complete round. Session state preserved. Retry with same command.
```

Specify: if an error round is present, the next successful round increments past it (N counts all headings including error rounds).

---

#### Issue 5 (High): Round number detection is ambiguous for shared review file

**Location**: Entity: ReviewFile — Append-only rule

The append-only rule says: `N = line count of ## Round headings + 1`. But `plan-review.md` is shared between artifact review rounds (`## Round N`) and code review rounds (`## Code Review Round N`). Both headings contain `## ` and `Round`. A naive grep for `## Round` would incorrectly include code review round headings.

The data model does not specify the exact detection rule, leaving implementations to make incorrect assumptions.

**Suggestion**: Specify the exact shell detection rule:
```bash
# For artifact rounds (in any review file):
grep -c '^## Round [0-9]' "$review_file"

# For code review rounds (only in plan-review.md):
grep -c '^## Code Review Round [0-9]' "$review_file"
```

State explicitly: `## Code Review Round N` headings are excluded from the artifact round count. The two sequences are independent monotonic counters within the same file.

---

#### Issue 6 (Medium): ProviderState.featureId is redundant and creates sync risk

**Location**: Entity: ProviderState

`featureId` is defined as a top-level field of `ProviderState`, but it is already encoded in the file path `specs/<featureId>/reviews/provider-state.json`. Storing it again inside the JSON means:
- If the file is copied to another feature directory, `featureId` reflects the source, not the destination
- Code that reads this field may behave differently from code that derives it from the path

**Suggestion**: Remove `featureId` from the `ProviderState` entity definition. Commands derive `featureId` from the active feature context (CLI argument or directory convention), never from the JSON content.

---

#### Issue 7 (Medium): Artifact entity missing prompt-boundary sanitization marker

**Location**: Entity: Artifact

The `Artifact` entity sends raw file content to LLM providers. The plan-review rounds 3–5 addressed prompt injection in the adapter prompts, but the data model does not reflect how the Artifact entity participates in this defense. Specifically, there is no field indicating:
- Whether content has been read (and thus needs delimiting before insertion into adapter prompt)
- What delimiter template should wrap the content

This means different adapter implementations may apply different (or no) delimiting, creating inconsistent prompt injection defenses across providers.

**Suggestion**: Add to Artifact:
- `content_delimiter: string` — default `"--- BEGIN ARTIFACT CONTENT ---"` / `"--- END ARTIFACT CONTENT ---"`. Document that adapters **must** wrap artifact content between these delimiters in every prompt. The delimiter strings are fixed across all providers; they do not contain user content.

---

#### Issue 8 (Medium): ReviewFile.rounds field is described as in-memory typed but no read policy is defined

**Location**: Entity: ReviewFile

`rounds: ReviewRound[]` implies the full file is parsed into a typed array. For large review files (10+ rounds × large content each), this means reading and parsing potentially hundreds of lines to merely determine the next round number. No read policy is stated.

From the prompt engineering patterns context: context efficiency matters. If the orchestrator reads all previous rounds to build the conversation context, token usage grows unboundedly with no truncation strategy.

**Suggestion**: Specify the read policy:
- For **round numbering**: parse headers only (grep round headings, count)
- For **context building**: pass last `max_context_rounds` rounds (default: 3) from the review file to the provider. Add `max_context_rounds: integer` to `PeerConfig` (default: `3`).
- The `rounds: ReviewRound[]` field in ReviewFile is a logical representation only; do not parse the full file into memory.

---

#### Issue 9 (Medium): PeerConfig.ProviderEntry.mode is semantically undefined

**Location**: Entity: PeerConfig → ProviderEntry

`mode: string` with value `orchestrated` and notation "extensible, not validated in v1" is meaningless without definition. In a prompt engineering context, "orchestrated" implies a specific execution model (Claude drives, Codex executes). But:
- What other modes exist or are planned?
- Is `mode` an input to adapter selection or purely informational?
- If it's not validated in v1, why is it in the data model?

**Suggestion**: Either:
a) Remove `mode` from v1 `ProviderEntry` entirely (Complexity Tracking principle: no stubs without proven need), OR  
b) Define the enum: `orchestrated` (default, only supported in v1) and document that unrecognized modes are rejected with an actionable error message.

---

#### Issue 10 (Low): statusMarker enum lacks error/terminal-failure states

**Location**: Entity: ReviewRound

Artifact review statuses are `NEEDS_REVISION`, `MOSTLY_GOOD`, `APPROVED`. Code review statuses are `NEEDS_FIX`, `APPROVED`. Neither enum includes a state for:
- A round where the provider explicitly flagged that review is **blocked** (e.g., prerequisite artifact missing)
- A round that terminates the workflow with a non-approvable verdict

**Suggestion**: Add `BLOCKED` to the artifact review enum to represent cases where the reviewer cannot proceed (e.g., spec.md is absent, tasks.md has unresolved conflicts). The command terminates without retry when `BLOCKED` is returned.

---

### Positive Aspects

- The file-based, no-daemon storage approach is well-justified and eliminates entire classes of lifecycle and cleanup complexity.
- Append-only review files with `---` separators are an excellent auditability pattern — append is safe under most concurrency conditions.
- The `ReviewFile` path resolution table is clear and unambiguous for the 4 standard artifact types.
- `ProviderState` nesting `provider → workflow → SessionEntry` correctly supports independent session tracking for review vs. execute workflows per provider.
- The `PeerConfig` validation rules are enumerated and ordered, which is unusual but highly valuable for actionable startup errors.

---

### Summary

Top 3 issues: (1) No LLM response envelope entity — structured output contract is undefined and will cause fragile ad-hoc parsing; (2) No schema versioning — stale state files will silently corrupt session continuity; (3) No error round entity — partial failures leave review files in states the model cannot describe or recover from.

**Consensus Status**: NEEDS_REVISION

---

## Round 2 — 2026-03-27

### Overall Assessment

The Round 1 revisions substantially improve the data model. All critical and high-severity issues are addressed: `AdapterResponse` formalizes the structured output contract, `SessionEntry` now carries context-continuity fields, error rounds are defined with a typed heading schema, round detection is specified precisely, schema versioning is present in both persisted entities, and `BLOCKED` is added throughout. The remaining gaps are minor precision issues and one consistency concern. The model is close to implementation-safe.

**Rating**: 8.8/10

---

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | No schema version in persisted entities | RESOLVED | `version: "1"` added to both `ProviderState` and `PeerConfig`. |
| 2 | No AdapterResponse entity / LLM output schema undefined | RESOLVED | `AdapterResponse` entity added with extraction rule for last-5-lines scan. |
| 3 | SessionEntry missing context-continuity tracking | RESOLVED | `rounds_in_session`, `session_started_at`, `context_reset_reason` added. |
| 4 | No error/failure round entity | RESOLVED | Error round heading schema added; `ErrorRecord` implied via heading schema + error codes. |
| 5 | Round number detection ambiguous | RESOLVED | Exact `grep -c '^## Round [0-9]'` rule specified; two counters are independent. |
| 6 | ProviderState.featureId redundant | RESOLVED | `featureId` removed from `ProviderState`; derived from path at runtime. |
| 7 | Artifact missing prompt-boundary sanitization marker | RESOLVED | `content_delimiter` field added to Artifact entity. |
| 8 | ReviewFile read policy undefined | RESOLVED | Header-only grep for round numbering; `max_context_rounds` for context building. |
| 9 | PeerConfig.mode semantically undefined | RESOLVED | `mode` is now an enum; `orchestrated` is the only v1 value; unrecognized values rejected. |
| 10 | statusMarker enum missing error states | RESOLVED | `BLOCKED` added to artifact enum; `ReviewRound.statusMarker` updated. |

---

### Issues

#### Issue 1 (Medium): AdapterResponse extraction rule uses bold-syntax match that is format-fragile

**Location**: Entity: AdapterResponse — Extraction rule

The extraction rule scans for:
```
**Consensus Status**: <MARKER>
```
The double-asterisk bold is a Markdown rendering convention, not a machine-readable contract. A provider response may emit:
```
Consensus Status: NEEDS_REVISION
```
or
```
**Consensus Status**: NEEDS_REVISION
```
depending on how the provider formats its output. The current rule requires the bold syntax, which could silently fail for providers that output plain text.

**Suggestion**: Define the extraction regex to match with or without bold markers:
```bash
grep -iE '^\*{0,2}Consensus Status\*{0,2}:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)' "$output_file"
grep -iE '^\*{0,2}Verdict\*{0,2}:\s*(NEEDS_FIX|APPROVED)' "$output_file"
```
Document that adapter prompts must instruct providers to end responses with one of the defined status lines, regardless of bold formatting.

---

#### Issue 2 (Medium): PeerConfig `max_rounds_per_session` default (10) conflicts with `max_context_rounds` default (3) without documented relationship

**Location**: Entity: PeerConfig

`max_rounds_per_session: 10` and `max_context_rounds: 3` are both in `PeerConfig` but their relationship is undocumented. Specifically:
- `max_context_rounds: 3` means the provider sees only the last 3 rounds of prior content
- `max_rounds_per_session: 10` means the session resets after 10 rounds
- When `rounds_in_session > max_context_rounds`, the provider's conversational context window no longer spans its full history in the session

There is no guidance on what this means for session continuity semantics, or whether a session with 10 rounds is coherent when the provider only ever sees 3 at a time.

**Suggestion**: Add a note: "These two values are independent. `max_context_rounds` controls token budget per invocation; `max_rounds_per_session` controls provider session lifecycle. A provider may have a 10-round session where only the last 3 rounds are passed as context each time — this is the intended behavior for token efficiency."

---

#### Issue 3 (Low): `ReviewRound.content` is unbounded with no max-size policy noted

**Location**: Entity: ReviewRound

`content: string` has no size constraint documented. For very large provider responses (e.g., a code review round with full diffs), the review file could grow significantly. No truncation, pagination, or max-size guidance exists.

**Suggestion**: Add a note that `content` is unbounded in v1. If artifact or response size becomes a concern, a `max_artifact_bytes` field can be added to `PeerConfig` in a future version. For v1, this is an accepted known limitation.

---

#### Issue 4 (Low): File Layout Summary does not include `data-model-review.md` and other non-standard review files

**Location**: File Layout Summary

The layout shows standard artifact review files (`spec-review.md`, `research-review.md`, etc.) but the actual `reviews/` directory can contain additional files for non-standard artifacts (e.g., `data-model-review.md` written during planning). The summary implies only 4 review files exist.

**Suggestion**: Add a note: "Additional review files (e.g., `data-model-review.md`, `research-review.md`) may be created during the `/speckit.plan` workflow for non-standard planning artifacts. All follow the same append-only `ReviewFile` format."

---

### Positive Aspects

- The `AdapterResponse` entity cleanly separates the raw LLM output contract from the stored `ReviewRound` — this is exactly the structured output pattern and will prevent ad-hoc parsing divergence across adapter implementations.
- Schema versioning is now consistent across both persisted artifacts, with cold-start fallback behavior specified in both cases.
- The context reset rule in `ProviderState` is precise and actionable — specifying that `rounds_in_session` is checked *before* invocation prevents a round from being wasted on an exhausted context.
- The two independent round counters (`## Round N` vs. `## Code Review Round N`) with explicit grep patterns eliminate a whole class of off-by-one bugs that would be hard to diagnose in the field.

---

### Summary

The Round 1 revisions resolved all critical and high issues cleanly. Remaining concerns are precision refinements, not structural gaps. The extraction regex needs to tolerate bold/plain text variation; the `max_rounds_per_session` / `max_context_rounds` relationship needs a one-line clarification. Minor documentation gaps in the file layout summary and the `ReviewRound.content` unbounded size are acknowledged-as-acceptable low-priority items.

**Consensus Status**: MOSTLY_GOOD

---

## Round 3 — 2026-03-27

### Overall Assessment

All `MOSTLY_GOOD` issues from Round 2 have been resolved precisely. The extraction regex is now format-agnostic with explicit shell patterns. The `max_rounds_per_session` / `max_context_rounds` relationship is documented clearly. The file layout summary explicitly includes non-standard review files with a note on extensibility. The `ReviewRound.content` unbounded size is acknowledged as a v1 known limitation with a clear upgrade path noted. The data model is complete, self-consistent, and sufficient to back implementation.

**Rating**: 9.6/10

---

### Previous Round Tracking

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Extraction rule bold-syntax fragile | RESOLVED | Regex now uses `\*{0,2}` to match with or without bold; case-insensitive flag added. |
| 2 | `max_rounds_per_session` / `max_context_rounds` relationship undocumented | RESOLVED | Inline note added to PeerConfig table: independent values, session lifecycle vs. per-invocation budget. |
| 3 | `ReviewRound.content` unbounded, no policy | RESOLVED | Table note added: unbounded in v1, upgrade path (`max_artifact_bytes`) documented for future. |
| 4 | File layout summary excludes non-standard review files | RESOLVED | `data-model-review.md` added as example; explanatory note added for arbitrary planning artifact review files. |

---

### Issues

None. The model accurately represents all entities, their storage contracts, failure modes, and read/write policies. Implementation can proceed directly from this document.

---

### Positive Aspects

- The complete entity chain (`Artifact → AdapterResponse → ReviewRound → ReviewFile`) now forms a coherent, parseable pipeline where each step has a defined input/output contract.
- The format-agnostic extraction regex (`\*{0,2}`) correctly handles both Markdown-rendering-aware and plain-text provider outputs without requiring adapter-level normalization.
- `PeerConfig` now covers all runtime control knobs a user might need to tune (session lifecycle, context window budget, provider routing) in a single, versioned YAML file.
- The `BLOCKED` terminal status correctly handles the case where the reviewer cannot proceed — preventing infinite retry loops on fundamentally broken artifacts.
- The read policy (header-only grep for numbering, last-N rounds for context) directly applies the token-efficiency principle from prompt engineering patterns and prevents unbounded memory growth in long-running features.

---

### Summary

No issues remain. All entities are complete, all contracts are specified, and all failure paths have a defined outcome. The data model is ready for implementation handoff.

**Consensus Status**: APPROVED
