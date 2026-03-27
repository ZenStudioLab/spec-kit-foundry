# Data Model: Spec Kit Peer Workflow Integration

**Feature**: `001-peer-pack`
**Date**: 2026-03-27

---

## Overview

All state for the peer pack is file-based. There are no databases, no in-memory caches shared across invocations, and no background processes. The data model defines the structure of files written during command execution and read at start of each invocation.

---

## Entity: Artifact

Represents a Spec Kit document that can be submitted to `/speckit.peer.review`.

| Field | Type | Description |
|-------|------|-------------|
| `name` | `enum` | One of `spec`, `research`, `plan`, `tasks` |
| `path` | `string` | Absolute or workspace-relative path to the Markdown file |
| `featureId` | `string` | Feature directory name (e.g., `001-peer-pack`) |
| `content_delimiter` | `string` | Fixed delimiter that wraps artifact content in every adapter prompt. Default: `--- BEGIN ARTIFACT CONTENT ---` / `--- END ARTIFACT CONTENT ---`. Adapters **must** use these exact strings; they never contain user data. |

**Storage**: Not persisted independently. Resolved at command invocation time by combining `featureId` with the artifact `name` to derive `path`.

**Resolution rule**:
```
spec     → specs/<featureId>/spec.md
research → specs/<featureId>/research.md
plan     → specs/<featureId>/plan.md
tasks    → specs/<featureId>/tasks.md
```

---

## Entity: ReviewRound

A single round of feedback produced by a provider for one artifact.

| Field | Type | Description |
|-------|------|-------------|
| `roundNumber` | `integer` | 1-indexed, monotonically increasing per artifact |
| `date` | `string` | ISO 8601 date (`YYYY-MM-DD`) |
| `provider` | `string` | Provider id that produced the round (e.g., `codex`) |
| `statusMarker` | `enum` | `NEEDS_REVISION`, `MOSTLY_GOOD`, `APPROVED`, or `BLOCKED` (artifact); `NEEDS_FIX` or `APPROVED` (code review) |
| `content` | `string` | Raw Markdown body of the review round. Unbounded in v1; a `max_artifact_bytes` guard can be added to `PeerConfig` in a future version if response size becomes a concern. |

**Artifact review round heading schema** (in `ReviewFile`):
```markdown
---

## Round N — YYYY-MM-DD

<review content>

Consensus Status: NEEDS_REVISION | MOSTLY_GOOD | APPROVED | BLOCKED
```

**Code review round heading schema** (code review rounds in plan review file):
```markdown
---

## Code Review Round N — YYYY-MM-DD

<review content>

Verdict: NEEDS_FIX | APPROVED
```

**Error round heading schema** (any review file, when provider invocation fails):
```markdown
---

## Round N — YYYY-MM-DD [ERROR: <error_code>]

Failed to complete round. Session state preserved. Retry with same command.
```

Error round headings count toward `N` for round numbering purposes. Error codes: `PROVIDER_TIMEOUT`, `PARSE_FAILURE`, `ADAPTER_MISSING`, `LOCK_CONTENTION`, `UNKNOWN`.

---

## Entity: ReviewFile

The append-only Markdown file for a given artifact within a feature.

| Field | Type | Description |
|-------|------|-------------|
| `artifactType` | `string` | The artifact type this file stores reviews for |
| `path` | `string` | `specs/<featureId>/reviews/<artifact>-review.md` |
| `rounds` | `ReviewRound[]` | All rounds in order, separated by `---` |
| `featureId` | `string` | Feature directory name |

**Path resolution**:
```
spec    → specs/<featureId>/reviews/spec-review.md
research→ specs/<featureId>/reviews/research-review.md
plan    → specs/<featureId>/reviews/plan-review.md   ← shared with code review
tasks   → specs/<featureId>/reviews/tasks-review.md
```

**Append-only rule**: Rounds are never edited after writing. New content is always appended at end of file after a `---` line.

**Round number detection rule**: Count only lines matching `^## Round [0-9]` (anchored, digit-prefixed). Lines matching `^## Code Review Round` are excluded from the artifact round counter — the two sequences are independent monotonic counters within the same file.

```bash
# Artifact round count (shell):
grep -c '^## Round [0-9]' "$review_file"

# Code review round count (plan-review.md only):
grep -c '^## Code Review Round [0-9]' "$review_file"
```

**Read policy**: For round numbering, parse headers only (grep, no full parse). For context building, pass the last `max_context_rounds` complete rounds (default: 3) to the provider. The `rounds: ReviewRound[]` field below is a logical representation — implementations must not parse the full file into memory on every invocation.

---

## Entity: AdapterResponse

The raw output produced by a provider invocation before it is parsed into a `ReviewRound`. Defines the structured output contract that all adapter implementations must satisfy.

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `string` | Opaque session identifier returned by the provider |
| `output_path` | `string` | Path to the file where the provider wrote its response |
| `raw_content` | `string` | Full response text read from `output_path` |
| `parsed_status_marker` | `enum \| null` | Extracted `NEEDS_REVISION`, `MOSTLY_GOOD`, `APPROVED`, `BLOCKED`, `NEEDS_FIX`, or `null` if not found |
| `parse_valid` | `boolean` | `true` if required structure (heading + status line) was present |

**Extraction rule**: Scan the last 5 lines of `raw_content` for status using format-agnostic patterns that match with or without bold markers:

```bash
# Artifact round status:
grep -iE '^\*{0,2}Consensus Status\*{0,2}:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)' "$output_file"

# Code review round status:
grep -iE '^\*{0,2}Verdict\*{0,2}:\s*(NEEDS_FIX|APPROVED)' "$output_file"
```

Adapter prompts must instruct providers to end responses with one of the defined status lines. If neither pattern matches, set `parse_valid = false` and record an error round (`PARSE_FAILURE`). Do not append an invalid round to the review file.

---

## Entity: Provider

Represents a configured AI provider that can perform peer review or batch execution.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Provider identifier (e.g., `codex`, `copilot`, `gemini`) |
| `enabled` | `boolean` | Whether this provider is available for use |
| `adapterImplemented` | `boolean` | Whether an adapter guide exists in `shared/providers/<id>/` |

**v1 state**:
- `codex`: enabled=true, adapterImplemented=true
- `copilot`: enabled=false (stub only)
- `gemini`: enabled=false (stub only)

---

## Entity: ProviderState

Per-feature, per-provider session continuity state. Written after every successful invocation so that subsequent rounds can resume the same conversation context.

| Field | Type | Description |
|-------|------|-------------|
| `version` | `string` | Schema version, currently `"1"`. Commands read this first; treat absent or unrecognized version as cold-start and log a warning. |
| `sessions` | `map<provider, map<workflow, SessionEntry>>` | Nested session lookup |

### SessionEntry

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `string` | Opaque session identifier returned by the codex skill |
| `updated_at` | `string` | ISO 8601 timestamp of last successful update |
| `session_started_at` | `string` | ISO 8601 timestamp when this session_id was first assigned |
| `rounds_in_session` | `integer` | Count of rounds appended under this session_id (successful rounds only) |
| `context_reset_reason` | `string \| null` | Why the previous session was ended: `"manual"`, `"provider_expired"`, `"max_rounds_exceeded"`, or `null` (first session / normal continuation) |

**Storage path**: `specs/<featureId>/reviews/provider-state.json`

**Example**:
```json
{
  "version": "1",
  "codex": {
    "review": {
      "session_id": "sess_abc123",
      "updated_at": "2026-03-27T14:30:00Z",
      "session_started_at": "2026-03-27T14:00:00Z",
      "rounds_in_session": 3,
      "context_reset_reason": null
    },
    "execute": {
      "session_id": "sess_def456",
      "updated_at": "2026-03-27T15:00:00Z",
      "session_started_at": "2026-03-27T15:00:00Z",
      "rounds_in_session": 1,
      "context_reset_reason": null
    }
  }
}
```

**Creation**: File does not need to exist before first invocation. If absent, the command starts a new session. On first successful response from the provider, the file is created with all `SessionEntry` fields populated.

**Update rule**: Read-modify-write the nested key `sessions[provider][workflow]`. Other keys are preserved. Write is atomic: write to a temp file, then rename into place.

**Context reset rule**: Before invoking the provider for a new round, check `rounds_in_session` against the `max_rounds_per_session` value in `PeerConfig` (default: `10`). If exceeded, start a new session (omit `--session` flag), reset `rounds_in_session` to 0, and set `context_reset_reason` to `"max_rounds_exceeded"`.

---

## Entity: PeerConfig

Project-level configuration consumed by all peer commands.

| Field | Type | Description |
|-------|------|-------------|
| `version` | `string` | Schema version, currently `"1"`. Commands check on startup; fail clearly if absent or unrecognized. |
| `default_provider` | `string` | Provider to use when `--provider` is not specified |
| `providers` | `map<string, ProviderEntry>` | Map of all configured providers |
| `max_rounds_per_session` | `integer` | Maximum rounds before context is automatically reset. Default: `10`. Independent of `max_context_rounds` — these two values control different aspects: session lifecycle vs. per-invocation token budget. A provider may complete a 10-round session where only the last 3 rounds are passed as context each time; this is expected behavior for token efficiency. |
| `max_context_rounds` | `integer` | Number of prior rounds passed to provider for context per invocation. Default: `3`. |

### ProviderEntry

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | `boolean` | Whether the provider may be selected |
| `mode` | `enum` | Execution model: `orchestrated` (Claude drives, provider executes — the only supported mode in v1). Unrecognized values are rejected with an actionable error. |

**Storage path**: `.specify/peer.yml` (project root)

**Example**:
```yaml
version: "1"
default_provider: codex
max_rounds_per_session: 10
max_context_rounds: 3
providers:
  codex:
    enabled: true
    mode: orchestrated
  copilot:
    enabled: false
    mode: orchestrated
  gemini:
    enabled: false
    mode: orchestrated
```

**Validation rules** (enforced by command logic at invocation time):
1. File must exist; fail clearly with install instructions if absent
2. `version` must be `"1"`; fail with migration guidance if absent or different
3. `default_provider` must be a key in `providers`
4. The resolved provider (from `--provider` flag or `default_provider`) must have `enabled: true`
5. The resolved provider must have a corresponding adapter guide in `shared/providers/<id>/`
6. `mode` for the resolved provider must be `orchestrated`

---

## File Layout Summary

```
.specify/
└── peer.yml                             ← PeerConfig (project-level)

specs/<featureId>/
├── spec.md                              ← Artifact (spec)
├── research.md                          ← Artifact (research)
├── plan.md                              ← Artifact (plan)
├── tasks.md                             ← Artifact (tasks)
└── reviews/
    ├── spec-review.md                   ← ReviewFile (spec rounds)
    ├── research-review.md               ← ReviewFile (research rounds)
    ├── plan-review.md                   ← ReviewFile (plan rounds + code review rounds)
    ├── tasks-review.md                  ← ReviewFile (tasks rounds)
    ├── data-model-review.md             ← ReviewFile (data-model planning artifact, if reviewed)
    └── provider-state.json              ← ProviderState (session continuity)
```

**Note**: Additional review files may be created during the `/speckit.plan` workflow for non-standard planning artifacts (e.g., `data-model.md`, `quickstart.md`). All follow the same append-only `ReviewFile` format with independent round counters.
