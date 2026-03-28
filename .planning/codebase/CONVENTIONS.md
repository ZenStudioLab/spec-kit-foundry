# Code Conventions

## File & Naming Conventions

### Feature IDs
Zero-padded numeric prefix + hyphen + name: `001-peer-pack`, `002-next-feature`.

### Commands
Dot-separated namespace: `speckit.peer.<verb>` (e.g. `speckit.peer.review`, `speckit.peer.execute`).

### Providers
Lowercase single word: `codex`, `copilot`, `gemini`.

### Review artifacts
`<artifact>-review.md` (e.g. `spec-review.md`, `plan-review.md`, `data-model-review.md`).

### Test cases
`T-<NN>` with zero-padded two digits (e.g. `T-01`, `T-06a`, `T-06b`).

### Directory layout
```
packs/<pack-id>/
  extension.yml
  commands/<verb>.md
  memory/<guide>.md
  templates/
shared/
  schemas/
  providers/<provider-id>/adapter-guide.md
specs/<feature-id>/
  spec.md, research.md, plan.md, tasks.md, quickstart.md, data-model.md
  contracts/<command>-command.md
  reviews/<artifact>-review.md
  reviews/provider-state.json
scripts/
  validate-pack.sh
```

### Schema files
Live in `shared/schemas/`, named `<scope>.schema.yml`.

### State file
`specs/<featureId>/reviews/provider-state.json` — always `chmod 600`.

---

## Bash Conventions

### Script header
```bash
#!/usr/bin/env bash
# <script-name> — <one-line description>
# Usage: ...
# Exit 0: ...; Exit N: ...

set -euo pipefail
```

### Path derivation
SCRIPT_DIR and REPO_ROOT always derived from `${BASH_SOURCE[0]}`:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
```

### Output helpers
Two named helpers used consistently:
```bash
pass() { echo "[PASS] $1"; }
fail() {
  echo "FAIL_CASE=$1" >&2
  echo "[FAIL] $1: $2" >&2
  exit 1
}
```

### Temp directories
Always via `mktemp -d` with a `trap` for guaranteed cleanup:
```bash
TMPDIR_ROOT="$(mktemp -d /tmp/validate-pack-XXXXXX)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT
```

### JSON parsing in Bash
Inline `python3 -c "..."` used for JSON reads from provider-state.json (no `jq` dependency).

### Conditional tests
`[[ ]]` double-bracket syntax (not `[ ]`).

### Section separators
Visual rulers with `# ─── Section Name ────...` comments to delimit logical sections within a script.

---

## YAML Conventions

### Indentation
2-space indent throughout; YAML 1.2 spec.

### Schema header block
Every schema file opens with a comment preamble:
```yaml
# Schema: <filename>
# Validates the structure of <target file>
# Version: N
```

### Schema self-reference
`$schema` field at top level: `$schema: "peer-providers:1"`.

### Required fields listed explicitly
```yaml
required:
  - version
  - default_provider
  - providers
```

### Enums for bounded sets
Provider names use `enum: [codex, copilot, gemini]` — never free strings.

### Version pinning
Integer `version: 1` with `const: 1` constraint; must be bumped to introduce breaking changes.

### Extension manifest (`extension.yml`)
Top-level `schema_version`, then `extension:` block, then `requires:`, then `provides:`:
```yaml
schema_version: "1.0"
extension:
  id: peer
  name: "..."
  version: 1.0.0
  description: "..."
requires:
  speckit_version: ">=0.1.0"
provides:
  commands: [...]
  memory: [...]
```

---

## Markdown / Command File Conventions

### YAML front matter (required)
All command instruction files open with `---`-delimited front matter containing these fields in order:
```yaml
---
id: peer.execute
command: speckit.peer.execute
version: 1.0.0
pack: peer
description: "..."
invocation: "/speckit.peer.execute [--provider <name>] [--feature <id>]"
---
```

### Document structure
Command files follow this section order:
1. `# Command: \`/<command>\``
2. `## Purpose` — narrative description
3. `## Role Model` — table of Orchestrator vs Executor/Reviewer
4. `## Invocation` — usage string + parameter table
5. Further operational sections (flow, error handling, state management, etc.)

### Role enforcement (CRITICAL CONSTRAINT block)
Commands that delegate to a provider always include an explicit blockquote constraint:
```markdown
> **CRITICAL CONSTRAINT**: You are the ORCHESTRATOR, not the IMPLEMENTER or REVIEWER.
>
> Do not emit any implementation code, fix code, or code-review verdicts ...
```

### Role model table
Tabular summary of roles always present immediately after the `## Role Model` heading:
```markdown
| Role | Actor | Responsibility |
|------|-------|----------------|
| **Orchestrator** | Claude | ... **Never writes implementation...** |
| **Executor** | Codex | ... |
```

### Review artifacts
Review files are **appended** (not replaced) with structured rounds. Each round is a new section appended to the bottom of the file.

### Spec artifacts
One file per concern: `spec.md`, `research.md`, `plan.md`, `tasks.md`, `quickstart.md`, `data-model.md`. Contracts are in `specs/<featureId>/contracts/<command>-command.md`.

---

## Error Handling Conventions

### Error message format
```
[peer/<command>] ERROR: <ERROR_CODE>: <message>
```
Example: `[peer/review] ERROR: VALIDATION_ERROR: .specify/peer.yml not found. Create it with version: 1 and a providers map.`

### Exit codes
| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Provider unavailable |
| `5` | Validation error (config missing, disabled provider, etc.) |
| `6` | Unimplemented provider |
| `7` | Artifact too large |
| `8` | Parse failure (unparseable JSON/YAML) |

### Error message guidelines
- Always include the ERROR_CODE token in the message body so it is grep-able.
- Actionable: messages for exit 5 include instructions to fix (e.g. `set enabled: true in .specify/peer.yml`).
- Exit 1 (provider unavailable) → ABORT; never fall back to inline execution.
- Exit 6 (unimplemented provider) → no side effects; do not create any files.

### State corruption handling
- Absent or unsupported `version` in `provider-state.json` → backup + reinit; emit actionable stderr.
- Unparseable JSON → fail-fast (exit 8); no backup attempted (corrupt data, not version mismatch).

---

## State Management Conventions

### File location
`specs/<featureId>/reviews/provider-state.json`

### Permissions
Always `chmod 600` immediately after creation or reinit — contains session IDs.

### Schema version field
Top-level `"version": 1` (integer). Absence implies pre-v1 and triggers the backup+reinit path.

### Provider state structure
```json
{
  "version": 1,
  "<provider>": {
    "<command-type>": {
      "session_id": "sess_...",
      "updated_at": "<ISO8601>",
      "session_started_at": "<ISO8601>",
      "rounds_in_session": N,
      "context_reset_reason": null,
      "last_persisted_round": N
    }
  }
}
```

### Session reuse
Session ID is read from state and passed as `--session <id>` on rounds 2+ as long as `rounds_in_session < max_rounds_per_session`.

### Context reset
Triggered when `rounds_in_session >= max_rounds_per_session`. A new session starts; `context_reset_reason` records why.

### Backup convention
When state is reinitialised due to version mismatch, the old file is copied to `provider-state.json.bak.<YYYYMMDDHHmmSS>` before overwrite.
