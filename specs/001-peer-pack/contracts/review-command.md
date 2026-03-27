# Contract: `/speckit.peer.review`

**Pack**: `peer`
**Command**: `review`
**Version**: 1.0.0

---

## Invocation

```
/speckit.peer.review <artifact> [--provider <name>]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `artifact` | Yes | One of `spec`, `research`, `plan`, `tasks` |
| `--provider <name>` | No | Override the `default_provider` in `.specify/peer.yml` |

### Examples

```bash
# Review plan.md using the default provider
/speckit.peer.review plan

# Review spec.md using a specific provider
/speckit.peer.review spec --provider codex
```

---

## Preconditions

The following must be true before execution begins. If any precondition fails, the command must halt with a clear, actionable error message — no partial writes.

1. **Artifact file exists**: `specs/<featureId>/<artifact>.md` must be present and non-empty.
2. **Peer config exists**: `.specify/peer.yml` must exist at the project root.
3. **Provider is enabled**: The resolved provider (from `--provider` or `default_provider`) must be present in `.specify/peer.yml` and have `enabled: true`.
4. **Provider adapter exists**: A corresponding adapter guide must exist at `shared/providers/<provider>/adapter-guide.md`.
5. **Codex skill is installed** (if provider is `codex`): `~/.claude/skills/codex/scripts/ask_codex.sh` must exist and be executable.

---

## Execution Steps

1. **Resolve feature context**
   - Identify the current feature from the active Spec Kit branch (via `git branch --show-current` or the `FEATURE_ID` environment variable if set)
   - Derive artifact path: `specs/<featureId>/<artifact>.md`

2. **Read configuration**
   - Parse `.specify/peer.yml` to get `default_provider`
   - Apply `--provider` override if present
   - Validate the provider against the preconditions above

3. **Load provider state** (for session continuity)
   - Read `specs/<featureId>/reviews/provider-state.json` if it exists
   - Extract `sessions[provider][review].session_id` if present
   - If absent, note that this is a new session

4. **Determine round number**
   - Read `specs/<featureId>/reviews/<artifact>-review.md` if it exists
   - Count existing `## Round ` headings → `N = count + 1`
   - If the review file does not exist, `N = 1`

5. **Invoke provider as executor**
   - Construct the review prompt:
     - Instruct the executor to read `<artifact>` file in full
     - Instruct it to apply the artifact-type-specific rubric (from `shared/providers/<provider>/adapter-guide.md`)
     - Ask it to raise ≥ 10 issues with severity labels, then provide a `Consensus Status`
   - Invoke the provider via its adapter (for codex: `ask_codex.sh "<prompt>" --file <artifact-path> [--session <session_id>] --reasoning high`)
   - Retrieve `session_id` and `output_path` from the returned output

6. **Append round to review file**
   - Create `reviews/` directory if it does not exist
   - If review file exists, append `\n---\n` separator; otherwise create the file
   - Append the round:
     ```
     ## Round N — YYYY-MM-DD

     <provider output>

     Consensus Status: <extracted from output>
     ```

7. **Update provider state**
   - Upsert `sessions[provider][review] = { session_id, updated_at: now() }` in `provider-state.json`
   - Create the file if it does not exist (do not overwrite other provider entries)

8. **Evaluate and loop**
   - Read the `Consensus Status` from the appended round
   - If `NEEDS_REVISION`:
     - Apply revisions to the artifact file based on the review feedback
     - Re-invoke from Step 4 (next round number)
   - If `MOSTLY_GOOD`:
     - Apply minor revisions to the artifact file
     - Re-run one final round to confirm
   - If `APPROVED`:
     - Report completion: display round number and review file path to the user
     - Exit

---

## Outputs

| Output | Path | Description |
|--------|------|-------------|
| Review file | `specs/<featureId>/reviews/<artifact>-review.md` | Append-only; one or more rounds added |
| Provider state | `specs/<featureId>/reviews/provider-state.json` | Updated `review` session entry for the resolved provider |
| Revised artifact | `specs/<featureId>/<artifact>.md` | Updated if issues were found; unchanged if `APPROVED` on first round |

---

## Error Conditions

| Condition | Error Message |
|-----------|--------------|
| Artifact file not found | `Artifact '<name>' not found at specs/<feature>/<name>.md. Run /speckit-specify first.` |
| `.specify/peer.yml` missing | `peer.yml not found. Create .specify/peer.yml with default_provider and providers config. See quickstart.md.` |
| Provider disabled | `Provider '<name>' is disabled in .specify/peer.yml. Set enabled: true or choose a different provider.` |
| Provider not implemented | `Provider '<name>' has no adapter in shared/providers/<name>/. Only 'codex' is supported in v1.` |
| Codex skill not installed | `Codex skill not found at ~/.claude/skills/codex/scripts/ask_codex.sh. Install: https://skills.sh/oil-oil/codex/codex` |
| Provider returns no output | `Provider '<name>' returned no output for round N. Review aborted. Check provider state at reviews/provider-state.json.` |

---

## Artifact-Specific Review Rubrics

The executor applies a different rubric depending on the artifact type. These rubrics are embedded in the executor prompt (see `shared/providers/codex/adapter-guide.md` for the Codex-specific framing).

| Artifact | Rubric Focus |
|----------|-------------|
| `spec` | Story completeness, FR/SC coverage, missing edge cases, ambiguous acceptance criteria |
| `research` | Decision quality, alternatives considered, rationale strength, open questions missed |
| `plan` | Feasibility, constitution compliance, missing phases, complexity underestimation |
| `tasks` | Task granularity, ordering constraints, missing prerequisites, scope creep indicators |

---

## Invariants

- Review files are **append-only** — no round is ever edited after writing
- The `N` in `## Round N` is always 1-indexed and monotonically increasing within a review file
- Provider state is **merged**, never overwritten — other providers' sessions are preserved
- The command does **not** auto-hook into `specify` commands; it is always invoked explicitly by the user or orchestrator
