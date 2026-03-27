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
| `statusMarker` | `enum` | `NEEDS_REVISION`, `MOSTLY_GOOD`, or `APPROVED` |
| `content` | `string` | Raw Markdown body of the review round |

**Artifact review round heading schema** (in `ReviewFile`):
```markdown
---

## Round N — YYYY-MM-DD

<review content>

Consensus Status: NEEDS_REVISION | MOSTLY_GOOD | APPROVED
```

**Code review round heading schema** (code review rounds in plan review file):
```markdown
---

## Code Review Round N — YYYY-MM-DD

<review content>

Verdict: NEEDS_FIX | APPROVED
```

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

**Append-only rule**: Rounds are never edited after writing. New content is always appended at end of file after a `---` line. The command reads the file only to determine the current round number (`N = line count of ## Round` headings + 1).

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
| `featureId` | `string` | Feature directory name |
| `sessions` | `map<provider, map<workflow, SessionEntry>>` | Nested session lookup |

### SessionEntry

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `string` | Opaque session identifier returned by the codex skill |
| `updated_at` | `string` | ISO 8601 timestamp of last update |

**Storage path**: `specs/<featureId>/reviews/provider-state.json`

**Example**:
```json
{
  "codex": {
    "review": {
      "session_id": "sess_abc123",
      "updated_at": "2026-03-27T14:30:00Z"
    },
    "execute": {
      "session_id": "sess_def456",
      "updated_at": "2026-03-27T15:00:00Z"
    }
  }
}
```

**Creation**: File does not need to exist before first invocation. If absent, the command starts a new session. On first successful response from the provider, the file is created with the returned `session_id`.

**Update rule**: Read-modify-write the nested key `sessions[provider][workflow]`. Other keys are preserved.

---

## Entity: PeerConfig

Project-level configuration consumed by all peer commands.

| Field | Type | Description |
|-------|------|-------------|
| `default_provider` | `string` | Provider to use when `--provider` is not specified |
| `providers` | `map<string, ProviderEntry>` | Map of all configured providers |

### ProviderEntry

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | `boolean` | Whether the provider may be selected |
| `mode` | `string` | Execution mode (e.g., `orchestrated`) — extensible, not validated in v1 |

**Storage path**: `.specify/peer.yml` (project root)

**Example**:
```yaml
default_provider: codex
providers:
  codex:
    enabled: true
    mode: orchestrated
  copilot:
    enabled: false
  gemini:
    enabled: false
```

**Validation rules** (enforced by command logic at invocation time):
1. File must exist; fail clearly with install instructions if absent
2. `default_provider` must be a key in `providers`
3. The resolved provider (from `--provider` flag or `default_provider`) must have `enabled: true`
4. The resolved provider must have a corresponding adapter guide in `shared/providers/<id>/`

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
    └── provider-state.json              ← ProviderState (session continuity)
```
