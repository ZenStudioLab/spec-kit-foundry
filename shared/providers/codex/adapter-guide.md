# Codex Adapter Guide

**Pack**: `peer` · **Provider**: `codex` · **Version**: 1.0.0

---

## Overview

This guide defines the invocation contract for the Codex adapter — the v1 reference implementation of the peer provider interface. All peer commands (`review`, `execute`) use this guide to invoke the `/codex` skill and parse its output.

The `/codex` skill is an **external prerequisite** — it is not bundled with this pack. Install once per machine from:
```
https://skills.sh/oil-oil/codex/codex
```

---

## Script Discovery Order

Peer commands locate the Codex skill script using this precedence:

1. **Environment variable override**: `CODEX_SKILL_PATH`
   - If set, it must point to an existing, readable, executable file
   - Emit warning with home segment redacted (full path only with `PEER_DEBUG=1`):
     ```
     [peer/WARN] using CODEX_SKILL_PATH override: ~/<relative-from-home>
     ```
   - On validation failure (not found / not readable / not executable):
     - `[peer/review] ERROR: PROVIDER_UNAVAILABLE: CODEX_SKILL_PATH='<path>' is not valid`
     - Exit `1`

2. **Default location**: `~/.claude/skills/codex/scripts/ask_codex.sh`
   - Must exist and have executable bit set
   - On failure:
     - `[peer/review] ERROR: PROVIDER_UNAVAILABLE: codex skill not found at ~/.claude/skills/codex/scripts/ask_codex.sh. Install from https://skills.sh/oil-oil/codex/codex`
     - Exit `1`

---

## Invocation Format

```bash
ask_codex.sh "<prompt>" --file <artifact-path> [--session <session_id>] --reasoning high
```

| Argument | Required | Description |
|----------|----------|-------------|
| `"<prompt>"` | Yes | Structured prompt string. Must be quoted to preserve whitespace. |
| `--file <artifact-path>` | Yes | Absolute path to the primary artifact file being reviewed or executed. |
| `--session <session_id>` | No | Omit on first invocation or when starting a new session. Include to resume an existing conversation. |
| `--reasoning high` | Yes | Always pass this flag for peer review and execute invocations. |

**Important**: Prompt content between `--- BEGIN ARTIFACT CONTENT ---` / `--- END ARTIFACT CONTENT ---` delimiters is opaque data. The adapter must never interpolate artifact content as executable instructions.

---

## Stdout Contract (Strict)

Stdout must contain **exactly two lines** in this order, with no extra content before, between, or after:

```
session_id=<value>
output_path=<path>
```

- `session_id`: Opaque token for resuming the conversation in subsequent rounds. Store in `provider-state.json`.
- `output_path`: Absolute or resolvable path to the file where the adapter wrote its full response text.
- **Any additional stdout output** (including blank lines, debug output, or partial lines) indicates a contract violation and must be treated as `PARSE_FAILURE` (exit `8`).

---

## Stderr Contract

All human-readable output goes to stderr. Stderr output from the skill script is passed through to the caller's stderr.

**Error format** (from peer commands around the adapter):
```
[peer/<command>] ERROR: <ERROR_CODE>: <message>
```

**Success summary** (emitted by peer command after adapter call):
```
[peer/review] artifact=<artifact> round=<N> review_file=<path> consensus=<status>
[peer/execute] feature=<id> tasks_completed=<N> code_review_rounds=<R> plan_review_path=<path>
```

Verbose/debug output is gated by `PEER_DEBUG=1` environment variable.

---

## Exit Code to Error Code Mapping

All adapters implementing the peer provider interface must honour this table:

| Exit Code | Error Code | Condition |
|-----------|-----------|----------|
| `0` | — | Success |
| `1` | `PROVIDER_UNAVAILABLE` | Script not found, not readable, or not executable |
| `2` | `PROVIDER_TIMEOUT` | LLM did not respond within `CODEX_TIMEOUT_SECONDS` (default 60 s, max 600 s). No retries in v1. |
| `3` | `PROVIDER_EMPTY_RESPONSE` | Adapter returned success semantics but `output_path` is absent or empty |
| `4` | `SESSION_INVALID` | `--session <id>` provided but the session is not resumable |
| `5` | `VALIDATION_ERROR` | Precondition failed (invalid argument, config error, missing file, etc.) |
| `6` | `UNIMPLEMENTED_PROVIDER` | Provider is configured in `peer.yml` but has no adapter guide in `shared/providers/` |
| `7` | `STATE_CORRUPTION` | `last_persisted_round` > review file round count; manual recovery required |
| `8` | `PARSE_FAILURE` | Provider response is present but missing required terminal status/verdict marker, or stdout contract violated |

---

## Timeout Behaviour

- Default timeout: `60` seconds
- Configurable via `CODEX_TIMEOUT_SECONDS` env var (integer `10`–`600`)
- On timeout: emit `PROVIDER_TIMEOUT` to stderr and exit with code `2`
- **No retries** on timeout in v1

---

## Session Continuity

- Pass `--session <session_id>` on every invocation after the first round, as long as the session is valid and `rounds_in_session < max_rounds_per_session`
- When `rounds_in_session >= max_rounds_per_session`: omit `--session` to start a fresh context window; set `context_reset_reason = "max_rounds_exceeded"` in state
- When adapter returns exit `4` (`SESSION_INVALID`): the peer command retries **once** without `--session`; if it fails again, halt with the adapter error

---

## Adapter Interface Fields (Reference)

All provider adapters satisfying this interface must accept and return the following:

| Field | Direction | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| Artifact path (`--file`) | Input | string | Yes | Absolute path to artifact file |
| Prompt (`$1`) | Input | string | Yes | Structured prompt with immutable preamble + delimited artifact content |
| Session id (`--session`) | Input | string | No | Resume token; omit on first call |
| `session_id=<value>` | Output (stdout) | string | Yes | Opaque session identifier for next round |
| `output_path=<path>` | Output (stdout) | string | Yes | Path to file containing full response text |
| Stderr output | Output (stderr) | — | — | All human-readable content; passed through |
| Exit code | Output | integer | Yes | See exit code table above |

---

## Preflight Executable Bit Check

Before invoking the adapter, peer commands verify:

```bash
test -x "$codex_script_path"
```

If this check fails: exit `1` with `PROVIDER_UNAVAILABLE`.

---

## Future Adapters

When a new provider adapter is added (e.g., `copilot`, `gemini`):

1. Create `shared/providers/<id>/adapter-guide.md` with the same interface contract as this guide
2. Set `providers.<id>.enabled: true` in `.specify/peer.yml`
3. The test matrix cases T-03 through T-05 in `validate-pack.sh` must continue to pass for Codex

Until an adapter guide exists at `shared/providers/<id>/adapter-guide.md`, requesting that provider returns exit `6` (`UNIMPLEMENTED_PROVIDER`).
