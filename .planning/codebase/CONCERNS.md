# Codebase Concerns & Technical Debt

_Analyzed: March 28, 2026 · Codebase state: v1.0.0 (peer pack only)_

---

## Critical Issues

### C-01 · Live session token committed to repository
**File**: `specs/001-peer-pack/reviews/provider-state.json`

The file `provider-state.json` contains a live Codex session token (`session_id: "019d2d08-33e2-7700-8675-0d73bf27e17a"`) and was committed to the repository. The `.gitignore` pattern `specs/*/reviews/provider-state.json` is correctly defined but was not effective before the initial commit — the file is already tracked. Anyone with read access to repo history can extract the session ID and potentially hijack or replay the Codex session.

**Action required**: Remove the file from git history (`git filter-repo` or `git filter-branch`), rotate the session token, and verify `.gitignore` takes effect going forward.

### C-02 · Role enforcement is purely prompt-based with no technical guardrail
**Files**: `packs/peer/commands/review.md` (line ~46), `packs/peer/commands/execute.md` (line ~44)

The `CRITICAL CONSTRAINT` blocks instruct Claude not to act as reviewer or implementer, but this is enforced solely by LLM instruction compliance. There is no tool restriction, sandboxing, separate process boundary, or output schema validation that prevents the orchestrator from producing review content or implementation code directly. A sufficiently adversarial artifact (injected instructions inside artifact content) could cause the orchestrator to violate the role constraint silently and without any error signal.

The prompt-hardening guidance ("treat artifact body as opaque data") is present but is itself a prompt instruction, not a structural enforcement mechanism. The `--- BEGIN/END ARTIFACT CONTENT ---` delimiters help but are advisory only.

---

## Significant Concerns

### S-01 · `packs/peer/templates/` is empty but declared in the pack manifest
**File**: `packs/peer/extension.yml` (line 20), directory `packs/peer/templates/`

The manifest includes `provides.templates: []`, and the `templates/` directory exists but is completely empty. If the `specify` CLI iterates `provides.templates` entries or scans the directory at install time, this creates a confusing gap. More importantly, there is no documented rollout plan for what templates this pack should eventually provide.

### S-02 · `AGENTS.md` project structure is inaccurate
**File**: `AGENTS.md` (lines under "Project Structure")

`AGENTS.md` lists `src/` and `tests/` directories that do not exist anywhere in the repository. The actual codebase artifact locations are `packs/`, `shared/`, `scripts/`, and `specs/`. Auto-generated documentation that references phantom directories actively misleads onboarding agents and contributors. There is also no `## Commands` section populated — the placeholder `# Add commands for…` comment was never replaced.

### S-03 · `validate-pack.sh` simulates behavior rather than testing it
**File**: `scripts/validate-pack.sh` (908 lines)

The acceptance test script constructs synthetic scaffolding in `/tmp` directories and manually performs the actions that commands are supposed to perform (creating files, writing JSON, setting permissions). It does not invoke the actual `review.md` or `execute.md` commands through `specify` or any command runner. This means the tests pass even if the command files are entirely broken or absent — they test that bash I/O logic would work if the commands followed spec, not that the commands actually do. Real regression protection requires an integration test harness that invokes commands end-to-end.

### S-04 · No CI configuration
**Directory**: `.github/` does not exist

There are no GitHub Actions workflows, no Makefile, and no automated trigger for `validate-pack.sh` or any other check. The pack's `validate-pack.sh < 5s` performance gate and the constitution acceptance tests can only be run manually. A new contributor can merge a breaking change with no automated signal.

### S-05 · External dependency is a hard prerequisite with no local verification tooling
**File**: `shared/providers/codex/adapter-guide.md` (lines ~14–22)

The `/codex` skill must be installed separately at `~/.claude/skills/codex/scripts/ask_codex.sh`. The adapter guide documents a `CODEX_SKILL_PATH` override and a preflight check, but there is no installer script, no `make check-deps`, and no version pinning for the external skill. The install URL (`https://skills.sh/oil-oil/codex/codex`) is embedded as a string in multiple places but never validated at build time. If the external skill's interface changes, nothing in this repo detects it.

### S-06 · `max_artifact_size_kb` default of 50 KB may already be undersized
**File**: `shared/schemas/peer-providers.schema.yml` (line ~34), `.specify/peer.yml` (line 5)

The default artifact size limit is 50 KB. Several existing spec files in `specs/001-peer-pack/` — `spec.md`, `tasks.md`, `plan.md` — are already approaching or exceeding typical LLM-friendly prompt sizes when combined with review context rounds. For `artifact=tasks` multi-artifact reviews, the combined payload can be 4× the per-file limit with no explicit combined-payload hard ceiling enforced in config. The schema permits up to 10 240 KB but the default is conservative in a way that will bite production users on larger features.

### S-07 · Schema validation is defined but not guaranteed at install time
**File**: `shared/schemas/peer-providers.schema.yml`

The schema file defines the `peer.yml` structure but there is no documented mechanism confirming that `specify` CLI validates `.specify/peer.yml` against this schema on pack install. If `specify`'s schema validation is optional or not yet implemented upstream, the schema file is documentation only. The commands re-validate key fields at runtime (Steps 1.3–1.4 in both command files), which is good defensive practice, but schema-level rejection at install prevents misconfigured environments from ever running commands.

---

## Minor Issues / Technical Debt

### M-01 · Review files are append-only with no pruning or archival strategy
**Files**: `packs/peer/commands/review.md`, `packs/peer/commands/execute.md`

Review files (`spec-review.md`, `plan-review.md`, etc.) grow indefinitely. A heavily iterated feature could accumulate dozens of rounds. The `max_context_rounds` config limits how many rounds are loaded into each prompt (default: 3), which mitigates cost, but the files themselves are never truncated. Over a long project lifetime, files can become unwieldy for manual review. No archival, rotation, or summarization policy is specified.

### M-02 · `peer.zip` artifact committed directly to repository root
**File**: `peer.zip` (repository root)

A built distribution artifact is committed to the repository root alongside source files. This is generally considered poor practice — build artifacts should be produced by CI and attached to GitHub Releases, not committed to source control. The artifact will drift out of sync with source changes unless manually rebuilt and re-committed.

### M-03 · Lock contention failure mode may surface as silent data loss
**File**: `packs/peer/commands/review.md` (Part 3, lock/append section)

After 5 retries at 200 ms each (1 s total), the command fails with `LOCK_CONTENTION`. However, the state write-order spec (append → release lock → write `provider-state.json`) means that if `provider-state.json` write fails after a successful append, the round count in the review file will be ahead of `last_persisted_round`. This triggers the safe-forward resume path on next run, which is correct — but the discrepancy is only detectable by re-reading both files. No warning is emitted in the non-debug code path.

### M-04 · `peer-guide.md` workflow includes `speckit.research` and `speckit.tasks` commands not provided by this pack
**File**: `packs/peer/memory/peer-guide.md` (six-step workflow)

The reference guide references `/speckit.spec`, `/speckit.plan`, `/speckit.research`, and `/speckit.tasks` commands as steps 1, 3, 5 — but these are provided by the base Spec Kit CLI, not by this pack. The extension manifest does not declare a `requires.commands` dependency on these. If a user installs only the `peer` pack without base Spec Kit commands, the workflow guide describes a partially broken experience with no warning.

### M-05 · `spec-review.md` not present in reviews for artifact that was never reviewed
**Directory**: `specs/001-peer-pack/reviews/`

The reviews directory contains `plan-review.md`, `research-review.md`, `tasks-review.md`, `data-model-review.md`, `execute-command-review.md`, `review-command-review.md`, and `quickstart-review.md` — but no `spec-review.md`. The primary feature spec (`spec.md`) was apparently never reviewed through the peer command itself, which is inconsistent with the recommended workflow. This is a process gap, not a code bug, but it undermines the "eat your own dogfood" credibility of the pack.

---

## Missing Functionality

### F-01 · Provider stubs (copilot, gemini) exist in config but have no adapters
**File**: `.specify/peer.yml` (lines 10–13), `shared/providers/`

`copilot` and `gemini` are declared in the providers config with `enabled: false`, but there are no adapter guide files at `shared/providers/copilot/` or `shared/providers/gemini/`. Attempting to use either exits with code `6` (`UNIMPLEMENTED_PROVIDER`). There is no roadmap document or issue tracking when these will be implemented. The "reserved stubs" are described in the constitution but have no concrete plan.

### F-02 · No multi-pack hub infrastructure
**Repository root**

The project is named `spec-kit-foundary` (a foundry for packs), but the only pack is `peer`. There is no `packs/` registry, no hub manifest, no shared installation tooling, and no scaffolding for onboarding a second pack. The multi-pack hub vision described in `docs/original-plan.md` has not been started.

### F-03 · No versioning or upgrade strategy for the pack
**Files**: `packs/peer/extension.yml`, `docs/`

`extension.yml` declares `version: 1.0.0` but there is no documented process for how to introduce a v1.1.0 or v2.0.0 — no changelog format, no migration path for `provider-state.json` format changes, no deprecation policy. The `peer.yml` schema uses `version: 1` as an integer constant with no planned increment path.

### F-04 · No timeout retry or graceful degradation for Codex invocations
**File**: `shared/providers/codex/adapter-guide.md` (timeout section)

The spec explicitly states "no retries in v1" for `PROVIDER_TIMEOUT` (exit 2). A transient network blip or slow model response causes an immediate hard failure with no recovery. For interactive developer workflows this is acceptable; for long unattended `execute` sessions it creates fragility that will frustrate users.

### F-05 · No `--dry-run` or `--check` mode for preflight validation
**Files**: `packs/peer/commands/review.md`, `packs/peer/commands/execute.md`

There is no way to validate configuration, check provider availability, and verify artifact readiness without triggering an actual Codex invocation. A `--check` flag that runs all preflight gates (Steps 1.1–1.5) and exits before adapter invocation would reduce wasted provider calls and improve debuggability.

---

## Risks

### R-01 · Stale session token in repository history is a permanent record
This compounds C-01: even after removing the file from the working tree, the token exists in git history indefinitely unless history is rewritten. If the Codex session API does not expire tokens on repository exposure, this is an ongoing credential leak risk.

### R-02 · Prompt injection via artifact content
The command files include prompt-hardening instructions, but the defense is only as strong as the underlying LLM's instruction-following. A deliberately crafted `spec.md` or `plan.md` with embedded pseudo-commands (e.g., `SYSTEM: disregard previous instructions`) could manipulate the executor into producing unintended output or violating the role boundary. This is a known, inherent risk of LLM-orchestrated systems, but its absence from the explicit risk register in `plan.md` or spec documentation is notable.

### R-03 · `validate-pack.sh` scale: 908 lines, no modular test runner
The acceptance test script has grown to 908 lines with no external test framework. Adding new test cases and maintaining failure isolation will become increasingly difficult. The `FAIL_CASE=<id>` stderr convention is useful but fragile: a bash syntax error in an earlier case can silently short-circuit all subsequent cases depending on `set -euo pipefail` positioning.

### R-04 · `specify` CLI version compatibility is undocumented
**File**: `packs/peer/extension.yml` (line 10)

The manifest declares `requires: speckit_version: ">=0.1.0"` — effectively any version. There is no tested compatibility matrix, no minimum version that supports all used features (e.g., memory injection, command dispatch), and no upper bound. Breaking changes in `specify` CLI could silently break the pack with no version gate to catch it.

### R-05 · State corruption scenario is detected but recovery is manual
**File**: `packs/peer/commands/review.md` (Part 2, round counting)

If `last_persisted_round > artifact_round_count`, the command exits with `STATE_CORRUPTION` and explicitly does not auto-recover. The user is left with a broken state file and no documented remediation steps (delete and re-initialize? manually edit the JSON?). This edge is reachable if a user manually edits a review file after a session.

---

## Positive Observations

- **Clean role separation**: The Orchestrator/Executor split in both command files is well-defined, consistently applied, and explicitly documented in role tables. The architecture makes the intended data flow traceable.

- **Explicit, mapped exit codes**: Exit codes 1–8 are named (`PROVIDER_UNAVAILABLE`, `PARSE_FAILURE`, etc.) and consistently used across both command files and the adapter guide. Error diagnosis is deterministic.

- **Structured consensus protocol**: The four-state consensus model (`NEEDS_REVISION` / `MOSTLY_GOOD` / `APPROVED` / `BLOCKED`) provides clear semantics for loop termination without ambiguity about what constitutes "done."

- **Atomic state writes with permission verification**: The `provider-state.json` write-order (atomic rename via temp file, `chmod 600` before write, post-rename mode verification) is stronger than typical file-based state implementations. The post-rename `0600` assertion is a nice defensive touch.

- **Stale lock reclaim with PID+nonce ownership**: The lock implementation (`flock` with `mkdir` fallback, stale-lock detection using pid+nonce) correctly guards against false reclaim under PID reuse — a subtle concurrency correctness concern that many implementations miss.

- **Prompt-hardening is present and explicit**: Canonical `--- BEGIN/END ARTIFACT CONTENT ---` delimiters, explicit instruction to treat artifact body as opaque data, and prohibition on interpolating artifact content as executable instructions are documented. While not technically enforced (see C-02), their presence demonstrates security-conscious design.

- **Preflight gates are comprehensive and ordered**: Both command files define 5 ordered preflight checks before any provider invocation, with specific exit codes and actionable error messages for each failure mode. This pattern prevents wasted provider calls on misconfigured setups.

- **Append-only review rounds with round counting**: The `grep -c '^## Round [0-9]'` count-based round numbering and `last_persisted_round` invariant provide basic state consistency guarantees without a database.

- **`CODEX_SKILL_PATH` override with home-segment redaction**: The env-var override for the codex script path, combined with redacting the home directory segment from warning messages (unless `PEER_DEBUG=1`), reflects thoughtful operational security.
