---
id: peer.review
command: speckit.peer.review
version: 1.0.0
pack: peer
description: "Adversarial peer review of a Spec Kit artifact, or routing to the bundled plan-review workflow for explicit file paths."
invocation: "/speckit.peer.review <target> [--provider <name>] [--feature <id>]"
---

# Command: `/speckit.peer.review`

## Purpose

Invoke an adversarial peer review loop against a Spec Kit artifact, or route to the bundled plan-review workflow when the user supplies an explicit file path.

There are two execution modes:
- **Artifact mode**: `<target>` is one of `spec`, `research`, `plan`, or `tasks`. Run the full peer-review loop described below.
- **File delegation mode**: `<target>` resolves to an existing file path. Bypass the artifact-mode workflow and execute the bundled `templates/plan-review.md` workflow from this pack against that path.

In artifact mode, each iteration:
1. Codex reviews the artifact and appends a round to the review file with a `Consensus Status`.
2. Claude reads the findings, evaluates which are valid, and **revises the artifact directly**.
3. If status is `NEEDS_REVISION` → automatically proceed to the next round (back to Step 2.6).
4. If status is `MOSTLY_GOOD` → apply minor revisions, then ask the user whether to run one more round.
5. If status is `APPROVED` → report completion; artifact is accepted.
6. If status is `BLOCKED` → halt immediately; a blocking issue requires human resolution before continuing.

The loop continues until a terminal consensus (`APPROVED`, `MOSTLY_GOOD` with user declining another round, or `BLOCKED`) is reached.

---

## Invocation

```
/speckit.peer.review <target> [--provider <name>] [--feature <id>]
```

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `target` | Yes | Either one of `spec`, `research`, `plan`, `tasks`, or an existing file path |
| `--provider <name>` | No | Override `default_provider` from `.specify/peer.yml`; in file delegation mode this value is forwarded to the bundled `plan-review` skill |
| `--feature <id>` | No | Explicit feature id when cwd context is ambiguous; ignored in file delegation mode |

---

## Role Model

Artifact mode only. File delegation mode is handled separately in Step 1.1a and does not use the peer adapter.

| Role | Actor | Responsibility |
|------|-------|----------------|
| **Orchestrator** | Claude | Resolve feature/config/state; assemble prompts; invoke provider adapter via terminal; read consensus; **revise the artifact based on valid findings**; loop until terminal consensus; persist state; report outcomes. **Never generates review content.** |
| **Provider** | Codex (or configured provider) | Generate all review content and status markers. |

> **CRITICAL CONSTRAINT (artifact mode only)**: You are the ORCHESTRATOR, not the REVIEWER.
>
> In artifact mode, do not emit any review feedback, critique, or consensus status in this response before the Adapter Invocation Gate passes.
> - You MUST invoke `ask_codex.sh` via terminal to obtain review content.
> - You MUST NOT write review feedback, critique, or consensus status yourself.
> - If the provider is unavailable, ABORT and report the error. Never fall back to generating review content inline.
>
> This boundary is invariant for artifact mode. If the provider is unavailable, the artifact-review command path halts.

---

## Part 1: Preflight, Config, and Feature Resolution

### Step 1.1 — Target Mode Resolution Gate

Resolve `<target>` in this order:

1. If `<target>` is exactly one of `spec`, `research`, `plan`, or `tasks`, set `review_mode=artifact` and `artifact=<target>`.
2. Else, if `<target>` resolves to an existing file path (relative or absolute) and that path matches `specs/<featureId>/(spec|research|plan|tasks).md`, set `review_mode=artifact`, `featureId=<featureId-from-path>`, and `artifact=<filename-without-.md>`. Canonical feature artifact paths always use artifact mode, even when passed as file paths.
3. Else, if `<target>` resolves to an existing file path (relative or absolute), set `review_mode=file` and `input_file=<resolved absolute path>`.
4. Else fail.

If the value is neither a supported artifact target nor an existing file path:
- Emit to stderr: `[peer/review] ERROR: VALIDATION_ERROR: unknown target '<x>'; must be one of spec|research|plan|tasks or an existing file path`
- Exit with code `5`
- **Do NOT create, modify, or read any review file or provider-state.json**

### Step 1.1a — File Delegation Fast Path

> **File delegation mode**: This mode bypasses the artifact-mode Codex review loop above. Treat the bundled `plan-review` skill as the sole executor for the delegated file review.

If `review_mode=file`:

1. Treat `input_file` as the sole review subject.
2. Load `templates/plan-review.md` from this pack as an instruction document. Bind `plan-file-path` to the resolved absolute value of `input_file`. If `--provider <name>` was supplied, bind `provider` to `<name>`; otherwise leave `provider` unset so the skill applies its default (`codex`). Execute the skill workflow with these bindings in scope.
3. Return the delegated result to the user.

_Invocation mechanics_: in this pack, "executing a bundled workflow" means loading the template markdown as an instruction context for the AI orchestrator (Claude), with the named variables available as substitution targets. This is not a subprocess or shell call. If `templates/plan-review.md` cannot be found at load time, emit `[plan-review] ERROR: PROVIDER_UNAVAILABLE: templates/plan-review.md not found` and exit `1`.

In file delegation mode:
- Do **NOT** load `.specify/peer.yml`
- Do **NOT** resolve `featureId`
- Forward `--provider` if supplied; ignore `--feature`
- Do **NOT** read or write canonical artifact review files (`specs/<featureId>/reviews/spec-review.md`, `research-review.md`, `plan-review.md`, `tasks-review.md`)
- Do **NOT** create or update `provider-state.json`
- Do **NOT** invoke `ask_codex.sh` through the peer adapter path

If the `plan-review` skill fails (non-zero exit), surface that failure unchanged and halt.

All remaining steps in this command apply to `review_mode=artifact` only.

### Step 1.2 — Feature Resolution

Resolve the `featureId` using this order of precedence:

1. **Canonical file-path context**: if Step 1.1 already derived `featureId` from `specs/<id>/(spec|research|plan|tasks).md`, use that `<id>`
2. **Current working directory context**: check if cwd is under `specs/<id>/` — use that `<id>`
3. **Explicit flag**: `--feature <id>` if provided
4. **Fail**: list all `specs/*/` directory names and exit with:
   - `[peer/review] ERROR: VALIDATION_ERROR: cannot determine feature; use --feature <id>. Available: <list>`
   - Exit code `5`

### Step 1.3 — Load and Validate `peer.yml`

Check that `.specify/peer.yml` exists:
- If absent: emit `[peer/review] ERROR: VALIDATION_ERROR: .specify/peer.yml not found. Create it with version: 1 and a providers map.` → exit `5`

Parse YAML. Check `version` field:
- Must be integer `1`
- If absent, not an integer, or not equal to `1`: emit `[peer/review] ERROR: VALIDATION_ERROR: peer.yml version must be integer 1` → exit `5`

Check `max_artifact_size_kb` if present:
- Must be integer in range 1–10240
- If invalid: emit `[peer/review] ERROR: VALIDATION_ERROR: max_artifact_size_kb must be integer 1–10240` → exit `5`

### Step 1.4 — Resolve and Validate Provider

Determine provider: use `--provider <name>` if given, else `default_provider` from `peer.yml`.

**Check 1 — Provider exists in config**:
If the provider name is not a key in `providers` map:
- Emit: `[peer/review] ERROR: VALIDATION_ERROR: unknown provider '<name>'; must be one of: <list of provider keys>`
- Exit `5`

**Check 2 — Provider enabled**:
If `providers.<name>.enabled` is not `true`:
- Emit: `[peer/review] ERROR: VALIDATION_ERROR: provider '<name>' is disabled; set enabled: true in .specify/peer.yml`
- Exit `5`

**Check 3 — Provider mode**:
If `providers.<name>.mode` is not `orchestrated`:
- Emit: `[peer/review] ERROR: VALIDATION_ERROR: provider '<name>' mode must be 'orchestrated'`
- Exit `5`

**Check 4 — Adapter guide exists**:
Check for `shared/providers/<name>/adapter-guide.md`. If absent:
- Emit: `[peer/review] ERROR: UNIMPLEMENTED_PROVIDER: provider '<name>' has no adapter implementation in v1; use codex`
- Exit `6`

### Step 1.5 — Codex Script Discovery (Codex provider only)

If provider is `codex`:

1. Check `CODEX_SKILL_PATH` env var (if set):
   - Verify file exists, is readable, and has executable bit set
   - If any check fails: emit `[peer/review] ERROR: PROVIDER_UNAVAILABLE: CODEX_SKILL_PATH='<path>' is not valid (not found, not readable, or not executable)` → exit `1`
   - On success, emit to stderr (with home segment redacted):
     `[peer/WARN] using CODEX_SKILL_PATH override: ~/<relative-from-home>`
   - With `PEER_DEBUG=1`, full absolute path may be shown instead
   - Use this path as the codex script

2. Else check default: `~/.claude/skills/codex/scripts/ask_codex.sh`
   - If not found or not executable: emit `[peer/review] ERROR: PROVIDER_UNAVAILABLE: codex skill not found at ~/.claude/skills/codex/scripts/ask_codex.sh. Install from https://skills.sh/oil-oil/codex/codex` → exit `1`
   - Use this path as the codex script

### Step 1.6 — Validate Artifact File

Artifact mode only.

Check `specs/<featureId>/<artifact>.md`:
- Must exist
- Must be non-empty

If missing or empty:
- Emit: `[peer/review] ERROR: VALIDATION_ERROR: artifact file not found or empty: specs/<featureId>/<artifact>.md`
- Exit `5`

### Step 1.7 — Validate `CODEX_TIMEOUT_SECONDS`

If `CODEX_TIMEOUT_SECONDS` env var is set:
- Must be integer in range `10`–`600`
- If invalid: emit `[peer/review] ERROR: VALIDATION_ERROR: CODEX_TIMEOUT_SECONDS must be integer 10–600` → exit `5`
- Default is `60` if unset

### Step 1.8 — Bootstrap Review Directory and Review File

Artifact mode only.

After all precondition checks pass:

1. Ensure `specs/<featureId>/reviews/` exists — create with `mkdir -p` if absent
2. Determine review file path: `specs/<featureId>/reviews/<artifact>-review.md`
3. If review file does not exist: create an **empty file** (touch/create, no content)
   - This is the first-run bootstrap for the review file only
   - `provider-state.json` initialization is handled in Part 2

> **CONSTRAINT**: No review file is created or modified on any precondition failure in Steps 1.1–1.7. The review directory and empty review file are created **only after** all preconditions pass.

---

## Part 2: State Recovery, Session Lifecycle, Round Counting, and Prompt Assembly

Artifact mode only.

### Step 2.1 — Load and Recover Provider State

Determine state path: `specs/<featureId>/reviews/provider-state.json`

**If file does not exist**: Initialize in-memory state as `{ "version": 1 }`. Do not write to disk yet.

**If file exists**:
1. Attempt to parse as JSON
   - If JSON is unparseable: emit `[peer/review] ERROR: VALIDATION_ERROR: provider-state.json is not valid JSON` → exit `5`
2. Check `version` field in parsed JSON:
   - If `version` is absent or not equal to `1`:
     - Create backup: copy to `provider-state.json.bak.YYYYMMDDHHMMSS` (timestamp at backup time, UTC)
     - Reinitialize in-memory state as `{ "version": 1 }`
     - Emit to stderr (actionable): `[peer/review] WARN: provider-state.json version mismatch — pre-v1 state backed up to provider-state.json.bak.<timestamp>. No migration in v1. Starting fresh session.`

**Read session entry** (if present): read `state.<provider>.review` for existing session fields:
- `session_id`, `rounds_in_session`, `session_started_at`, `context_reset_reason`, `last_persisted_round`

### Step 2.2 — Session Lifecycle

Read `max_rounds_per_session` from `peer.yml` (default `10`).

**Session reset decision**:
- If `rounds_in_session >= max_rounds_per_session`:
  - Omit `--session` flag from adapter invocation
  - Set `context_reset_reason = "max_rounds_exceeded"`
  - Reset in-memory `rounds_in_session = 0`
- Else:
  - Use `session_id` from state (if present) as `--session <id>` in adapter invocation

> If adapter returns exit code `4` (`SESSION_INVALID`): restart once without `--session` flag. If it fails again on the retry, halt with the adapter's error.

### Step 2.3 — Determine Artifact Round Number

Count existing artifact rounds in the review file (skip Code Review Round headings):

```bash
artifact_round_count=$(grep -c '^## Round [0-9]' "$review_file" 2>/dev/null || echo 0)
N=$((artifact_round_count + 1))
```

**State corruption check**:
- Read `last_persisted_round` from state (default `0`)
- If `last_persisted_round > artifact_round_count`:
  - Emit: `[peer/review] ERROR: STATE_CORRUPTION: last_persisted_round (<X>) exceeds review file round count (<Y>). Manual recovery required.`
  - Exit `7`
- If `last_persisted_round < artifact_round_count`: safe-forward resume — continue from round `N`

### Step 2.4 — Enforce Artifact Size Guard

For `artifact` in `{spec, research, plan}`:
- Read file size of `specs/<featureId>/<artifact>.md`
- If size exceeds `max_artifact_size_kb` (default 50 KB):
  - Emit: `[peer/review] ERROR: VALIDATION_ERROR: artifact size exceeds max_artifact_size_kb (<X> KB > <limit> KB)`
  - Exit `5`

For `artifact = tasks`: see Part 5 (US2 extension).

### Step 2.5 — Build Prior Context

Read `max_context_rounds` from `peer.yml` (default `3`).

Extract up to the last `max_context_rounds` complete artifact rounds from the review file:
- Include only sections that begin with `^## Round [0-9]`
- Exclude any section beginning with `^## Code Review Round`
- Parse headers only — do NOT load entire file into memory on every call
- A "complete round" is a section from its `## Round N` header to the next `---` separator (inclusive)

### Step 2.6 — Assemble Prompt (for artifact ∈ {spec, research, plan})

Compose a short natural-language instruction string (no file contents inlined). Codex reads the artifact file itself via its workspace access.

**Template** (substitute `<featureId>`, `<artifact>`, `<N>`, `<rubric-line>`):

```
Read specs/<featureId>/<artifact>.md and review it critically as an independent peer reviewer.

Requirements:
- Raise at least 5 concrete, actionable findings with severity (Critical / High / Medium / Low)
- Each finding: severity, description, exact location/reference in the artifact, improvement suggestion
- <rubric-line based on artifact type (see below)>
- If specs/<featureId>/reviews/<artifact>-review.md already exists, read it first and track resolution status of prior issues

Append the review as Round <N> directly to specs/<featureId>/reviews/<artifact>-review.md
(create the file if it does not exist; separate rounds with ---)

Use this format:
---
## Round <N> — <YYYY-MM-DD>
### Overall Assessment
{2-3 sentences}
### Findings
#### Finding 1 (<severity>): <title>
**Location**: ...
{description}
**Suggestion**: ...
### Summary
{top issues}

End the round with exactly one of these lines:
Consensus Status: NEEDS_REVISION
Consensus Status: MOSTLY_GOOD
Consensus Status: APPROVED
Consensus Status: BLOCKED
```

**Rubric line by artifact type**:
- **spec**: `Evaluate scope clarity, ambiguity, testability of requirements, and identification of edge cases`
- **research**: `Evaluate decision quality, alternatives considered, blocking risks, and completeness of technical investigation`
- **plan**: `Evaluate architecture soundness, implementation feasibility, sequencing logic, and risk identification`

### Step 2.7 — Invoke Provider Adapter

**Step 2.7a — Hard gate reminder** (inline, at point-of-invocation):

> ⚠️ ORCHESTRATOR GATE: Do not proceed past this point unless you are about to execute the terminal command below. Do not generate review content here.

**Step 2.7b — Invoke adapter via terminal**:

Pass the assembled prompt inline as the first positional argument. No temp files. No file content inlining. Codex reads the artifact files via its own workspace access and writes the review directly to the review file.

```bash
"$codex_script_path" \
  "<assembled prompt from Step 2.6>" \
  --file "specs/<featureId>/<artifact>.md" \
  --file "specs/<featureId>/reviews/<artifact>-review.md" \
  --reasoning high
  # Include: --session "<session_id>"  only if a valid session_id exists (Step 2.2)
  # For artifact=tasks: pass all four artifact files (see Step 5.3)
```

Use `$codex_script_path` resolved in Step 1.5 (not hardcoded). Do not construct a temp file — the prompt is a short rubric string (~1–2 KB) and fits inline.

**Step 2.7c — Parse stdout**: Capture `ask_codex.sh` stdout and extract:
- `session_id=<value>` — record for session reuse in future rounds
- `output_path=<path>` — path to codex's terminal summary (informational only; the review body is already in the review file)

If either line is absent, emit a warning but do not abort — codex may have written the review file successfully even if session tracking output is missing.

### Step 2.8 — Adapter Invocation Gate

This gate applies to ALL artifact types, including `tasks`.

Before proceeding to Part 3, the following must be true:

1. `ask_codex.sh` was executed via a terminal invocation — the shell command ran; you did not reason around it or simulate its output.
2. The review file (`specs/<featureId>/reviews/<artifact>-review.md`) exists and contains a new round written by codex (its mtime is ≥ when Step 2.7b began).

**If either check fails**:
- **ABORT immediately.** Do NOT generate review content. Do NOT proceed to Part 3.
- Emit: `[peer/review] ERROR: PROVIDER_UNAVAILABLE: adapter was not invoked via terminal or review file was not updated`
  → exit `1`

> Set `PEER_DEBUG=1` to surface full adapter stderr.

---

## Part 3: Consensus Extraction, State Persistence, and Reporting

Artifact mode only.

> Codex writes the review directly to the review file (as instructed in Step 2.6). Part 3 only reads back the consensus status and persists provider state.

### Step 3.1 — Read Consensus from Review File

After codex returns, read the consensus from the review file codex wrote:

```bash
grep -iE '^\*{0,2}Consensus Status\*{0,2}:\s*(NEEDS_REVISION|MOSTLY_GOOD|APPROVED|BLOCKED)' \
  "specs/<featureId>/reviews/<artifact>-review.md" | tail -1
```

- **If status found**: record `consensus_status`, mark round as normal.
- **If status not found**: the review file exists but has no status marker — record as `PARSE_FAILURE`. Append an error note manually:
  ```markdown
  ---
  ## Round N — YYYY-MM-DD [ERROR: PARSE_FAILURE]
  Codex wrote the review file but did not include a Consensus Status marker. Retry with same command.
  ```

### Step 3.2 — Persist Provider State (Atomic Write)

Write `provider-state.json` via temp file + atomic rename within the project directory:
   - Write updated JSON state to a temp file in the same directory (`provider-state.json.tmp.<pid>`)
   - Atomically rename temp file to `provider-state.json`

> **Note on file permissions**: `chmod 0600` is silently ignored on NTFS/FAT mounts. Do not verify or enforce Unix mode bits on `provider-state.json`. The mode invariant only applies on native Linux/macOS filesystems.

**State update matrix — merge-upsert `<provider>.review`**:

| Event | `rounds_in_session` | `last_persisted_round` |
|-------|---------------------|------------------------|
| Normal round written by Codex | increment by 1 | set to N |
| Error round appended (e.g., `PARSE_FAILURE`) | unchanged | set to N |
| Precondition failure (Part 1) | do NOT write state | — |

Merge fields: `session_id`, `updated_at` (now, ISO 8601), `session_started_at` (preserve from existing state; set to now only if new session), `rounds_in_session`, `context_reset_reason`, `last_persisted_round`.

Preserve all other provider/workflow keys in the JSON.

### Step 3.4 — Revise Artifact and Loop

**Emit round summary**:
```
[peer/review] artifact=<artifact> round=<N> review_file=<path> consensus=<status>
```

**Consensus loop**:

| Status | Action |
|--------|--------|
| `NEEDS_REVISION` | 1. Evaluate each finding; adopt valid ones and revise the artifact file directly. 2. Increment N. 3. Return to Step 2.6 for the next round — **do not wait for user input**. |
| `MOSTLY_GOOD` | 1. Apply minor revisions to the artifact. 2. Report improvements made. 3. Ask the user: “Round N complete — MOSTLY_GOOD. Run one more round to confirm? (y/n)”. If yes → return to Step 2.6. If no → report completion. |
| `APPROVED` | Report: how many rounds ran, which areas were improved, artifact path, review file path. Loop ends. |
| `BLOCKED` | **Halt immediately.** Report the blocking issue(s) to the user. Do NOT revise the artifact. Do NOT start another round. Human resolution is required before the review loop can continue. |

**Revision discipline**:
- Revise the artifact file in-place (overwrite, do not create a new file)
- Adopt findings that are correct and actionable; note in the revision summary which issues were adopted vs. rejected and why
- Do not make changes beyond what the findings call for (no "while I’m here" additions)
- After revising, briefly report: “Revised `<artifact>.md`: [list of changes made]” before proceeding to the next round

**Loop safety cap**: If `rounds_in_session` reaches `max_rounds_per_session` before terminal consensus, halt with:
```
[peer/review] WARN: max_rounds_per_session (<limit>) reached without terminal consensus. Last status: <status>. Resume with same command to continue in a new session.
```

All debug/verbose output gated by `PEER_DEBUG=1` env var.

---

## Part 4: Exit Codes

| Exit Code | Error Code | Condition |
|-----------|-----------|----------|
| 0 | — | Success |
| 1 | `PROVIDER_UNAVAILABLE` | Codex script not found or not executable |
| 2 | `PROVIDER_TIMEOUT` | Provider did not respond within `CODEX_TIMEOUT_SECONDS` |
| 3 | `PROVIDER_EMPTY_RESPONSE` | Adapter returned success but no review file or usable summary was produced |
| 4 | `SESSION_INVALID` | Session could not be resumed (handled internally with one retry) |
| 5 | `VALIDATION_ERROR` | Precondition failed |
| 6 | `UNIMPLEMENTED_PROVIDER` | Provider configured but no adapter guide present |
| 7 | `STATE_CORRUPTION` | `last_persisted_round` > review round count |
| 8 | `PARSE_FAILURE` | Consensus status marker absent from review file after codex ran |

---

## Part 5: User Story 2 — `artifact=tasks` Multi-Artifact Branch

> This section extends the `review` command for the `tasks` artifact type in artifact mode.
> Entry criterion: Parts 1–3 above are fully specified and stable.

### Step 5.1 — US2 Precondition: All Four Artifacts Required

When `artifact = tasks`, all four artifacts must exist AND be non-empty **before** invoking the provider:

| Artifact | Required Path |
|----------|---------------|
| `spec` | `specs/<featureId>/spec.md` |
| `research` | `specs/<featureId>/research.md` |
| `plan` | `specs/<featureId>/plan.md` |
| `tasks` | `specs/<featureId>/tasks.md` |

For each missing or empty artifact, collect its path. If any are missing:
- Emit for each missing artifact: `[peer/review] ERROR: VALIDATION_ERROR: missing artifact: specs/<featureId>/<artifact>.md`
- Emit all missing artifacts before halting (do not produce a partial review)
- Exit `5`
- Do NOT write or modify any review file, reviews/ directory, or provider-state.json

### Step 5.2 — US2 Size Guards

For `artifact = tasks`, each of the four artifact files must satisfy `file_size <= max_artifact_size_kb`. Since Codex reads the files itself, there is no combined prompt payload concern.

On size overflow:
- Emit: `[peer/review] ERROR: VALIDATION_ERROR: artifact size exceeds max_artifact_size_kb (<artifact>: <X> KB > <limit> KB)`
- Exit `5`

### Step 5.3 — US2 Prompt Assembly (Tasks Rubric)

Compose a short natural-language instruction string (same pattern as Step 2.6). Codex reads all four artifact files itself and writes the review directly to the review file.

**Template** (substitute `<featureId>`, `<N>`):

```
Read specs/<featureId>/spec.md, specs/<featureId>/research.md,
specs/<featureId>/plan.md, and specs/<featureId>/tasks.md.

Review tasks.md critically against the other three artifacts as an independent peer reviewer.

Requirements:
- Raise at least 5 concrete, actionable findings with severity (Critical / High / Medium / Low)
- Each finding: severity, description, exact location/reference, improvement suggestion
- If specs/<featureId>/reviews/tasks-review.md already exists, read it first and track resolution status of prior issues

Analysis dimensions:
1. Coverage: map functional requirements (from spec.md) to tasks; flag any FRs with no task
2. Sequencing: flag dependency order violations; evaluate Phase structure and Checkpoint gates
3. Test coverage: flag FRs and behaviors with no corresponding test task
4. Plan-task alignment: flag tasks not traceable to plan.md architecture/deliverables
5. Constitution alignment: flag tasks that violate monorepo conventions, immutability patterns, or file size limits

Append the review as Round <N> directly to specs/<featureId>/reviews/tasks-review.md
(create the file if it does not exist; separate rounds with ---)

Use this format:
---
## Round <N> — <YYYY-MM-DD>
### Overall Assessment
{2-3 sentences}
### Findings
#### Finding 1 (<severity>): <title>
**Location**: ...
{description}
**Suggestion**: ...
### Summary
{top issues}

End the round with exactly one of these lines:
Consensus Status: NEEDS_REVISION
Consensus Status: MOSTLY_GOOD
Consensus Status: APPROVED
Consensus Status: BLOCKED
```

Pass all four artifact files and the review file via `--file` flags (Step 2.7b):
```bash
"$codex_script_path" \
  "<assembled prompt>" \
  --file "specs/<featureId>/spec.md" \
  --file "specs/<featureId>/research.md" \
  --file "specs/<featureId>/plan.md" \
  --file "specs/<featureId>/tasks.md" \
  --file "specs/<featureId>/reviews/tasks-review.md" \
  --reasoning high
  # Include: --session "<session_id>"  only if valid session_id exists
```

### Step 5.4 — US2 Round Counting for `tasks` Reviews

The round counting for `tasks-review.md` follows the same rules as all other artifacts:
- Count using `grep -c '^## Round [0-9]' "$review_file"`
- Exclude `## Code Review Round` sections
- Prior context loading: include only `## Round [0-9]` sections (not Code Review Round sections)

---

## Invariants Summary

- **Append-only reviews**: No prior round in any review file is ever modified or deleted
- **Precondition isolation**: No file is created or modified when any artifact-mode precondition (Steps 1.1–1.7) fails
- **File delegation bypass**: Existing file-path targets are routed to the bundled `plan-review` skill without loading peer config, touching peer state, or writing peer review files; `--provider` is forwarded and `--feature` is ignored in this mode
- **Review file ownership**: Codex writes normal review rounds; Claude may append only the minimal `PARSE_FAILURE` error note when the provider omitted the terminal status marker
- **Claude revises artifacts**: After each `NEEDS_REVISION` round, Claude revises the artifact in-place before the next round
- **State write-order**: Codex writes review → Claude reads consensus → Claude writes provider-state.json (atomic rename)
- **Stdout metadata**: Adapter stdout may provide `session_id=` and `output_path=` metadata only; human-readable output goes to stderr
- **No temp files outside project**: All files written within the project directory or codex's runtime directory
