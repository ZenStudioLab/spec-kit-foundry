# Research: Spec Kit Peer Workflow Integration

**Feature**: `001-peer-pack`
**Date**: 2026-03-27
**Status**: Revised — synchronized with `plan.md`, `data-model.md`, `quickstart.md`, and command contracts on 2026-03-27

**Authority Note**: This document records why the design choices were made. When examples here drift, the field-level schema and execution contract are authoritative in `data-model.md`, `contracts/`, and `plan.md`.

---

## Decision 1: Command File Format and Prompt Contract

**Decision**: Peer commands are Markdown files with YAML frontmatter for metadata, followed by Markdown prose that contains the full behavioral instruction set for the agent executing the command. Prompts embedded in those command files must treat artifact contents as opaque data, wrap them in the canonical delimiter pair `--- BEGIN ARTIFACT CONTENT ---` / `--- END ARTIFACT CONTENT ---`, and require deterministic terminal markers in provider responses (`Consensus Status:` or `Verdict:`).

**Rationale**: Existing Spec Kit skills (`plan-review`, `plan-execute`, `speckit-plan`) already use Markdown + frontmatter, so this keeps the extension aligned with established conventions. Adding canonical delimiters and required terminal markers hardens the prompt contract against prompt-injection drift and parse fragility, which matters for append-only review files and review/fix loops.

**Alternatives considered**:
- JSON schema-only command definition — rejected: behavioral instruction prose is part of the contract and does not fit cleanly in a schema-only format
- Pure YAML — rejected: multi-paragraph command behavior and examples are awkward to author and review in YAML-only files
- Free-form prompt bodies without canonical delimiters or terminal markers — rejected: increases prompt-template drift and makes status extraction unreliable across providers

**Impact**: `packs/peer/commands/review.md` and `packs/peer/commands/execute.md` use the standard frontmatter + Markdown layout, artifact bodies are always delimited the same way, and provider prompts must instruct the executor to end with parse-stable status lines.

---

## Decision 2: Provider State Schema (`provider-state.json`)

**Decision**: Provider state is a versioned JSON document stored at `specs/<feature>/reviews/provider-state.json`, keyed by provider and workflow. Each workflow entry stores session continuity, lifecycle, and reconciliation metadata needed for safe reuse and recovery.

```json
{
  "version": 1,
  "codex": {
    "review": {
      "session_id": "<opaque string from codex skill>",
      "updated_at": "2026-03-27T14:30:00Z",
      "session_started_at": "2026-03-27T14:00:00Z",
      "rounds_in_session": 3,
      "context_reset_reason": null,
      "last_persisted_round": 3
    },
    "execute": {
      "session_id": "<opaque string from codex skill>",
      "updated_at": "2026-03-27T15:00:00Z",
      "session_started_at": "2026-03-27T15:00:00Z",
      "rounds_in_session": 1,
      "context_reset_reason": null,
      "last_persisted_round": 1
    }
  }
}
```

**Rationale**: Review and execute sessions must stay independent so the executor does not mix critique history with implementation history. Versioning prevents silent schema drift, lifecycle fields support bounded session reuse, and `last_persisted_round` gives the command a way to detect safe-forward recovery versus unrecoverable state corruption.

**Alternatives considered**:
- Flat array of `{ provider, workflow, session_id }` — rejected: harder to update atomically and does not leave room for lifecycle/recovery metadata
- One file per provider per workflow — rejected: spreads runtime state across multiple files and makes inspection/recovery harder
- Persisting only `session_id` and `updated_at` — rejected: insufficient for bounded reuse, reconciliation, and corruption detection

**Impact**: `provider-state.json` is created on the first successful provider response and updated after each successful round. The authoritative field semantics live in `data-model.md` and the recovery rules live in `plan.md`.

---

## Decision 3: `.specify/peer.yml` Config Schema

**Decision**: Peer configuration is a versioned project-level YAML file stored at `.specify/peer.yml`. It declares the default provider, per-provider enablement/mode, and runtime limits for session reuse and context carry-forward.

```yaml
version: 1
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

**Rationale**: Provider choice is a project concern, not a pack-release concern. Versioning enables validation and future migration. `max_rounds_per_session` and `max_context_rounds` solve different prompt-engineering problems: bounded conversational drift versus bounded token growth. Reserved provider entries remain useful because they let validation distinguish disabled, unimplemented, and unknown providers.

**Alternatives considered**:
- Environment variables only — rejected: not portable across machines or CI and too easy to misconfigure silently
- Embedding provider config in `extension.yml` — rejected: provider choice is project-local runtime configuration, not pack metadata
- Per-user global config — rejected: peer workflows need per-project defaults and per-project validation

**Impact**: Users create `.specify/peer.yml` once per project. Validation rules and bounds live in `plan.md`, `data-model.md`, and the shared schema file; this research decision records why those fields exist.

---

## Decision 4: Review File Format, Status Taxonomy, and Shared File Convention

**Decision**: Review history is append-only Markdown with `---` separators. Artifact review rounds use `## Round N — YYYY-MM-DD` and end with `Consensus Status: NEEDS_REVISION | MOSTLY_GOOD | APPROVED | BLOCKED`. Code review rounds from `/speckit.peer.execute` use `## Code Review Round N — YYYY-MM-DD` and end with `Verdict: NEEDS_FIX | APPROVED`. The plan artifact and code-review history share `specs/<feature>/reviews/plan-review.md`; references to `reviews/code-review.md` in earlier spec narrative are historical wording, and FR-010 plus the command contracts are authoritative.

**Rationale**: Markdown remains the best fit for human-readable review history, while the separate round headings give the command deterministic counters. Sharing `plan-review.md` keeps the review story in one place and matches the existing `plan-review` / `plan-execute` workflow pattern. Adding `BLOCKED` clarifies when an artifact cannot be meaningfully reviewed, while keeping code-review verdicts distinct from artifact-review consensus.

**Alternatives considered**:
- Separate `reviews/code-review.md` for execute rounds — rejected: splits related history and conflicts with the shared-file convention now used by the feature docs
- Structured JSON review history — rejected: worse for human inspection and would add a second review artifact format in v1
- Reusing the same heading/status set for artifact and code review — rejected: conflates readiness review with implementation review

**Impact**: `specs/<feature>/reviews/<artifact>-review.md` is used for `spec`, `research`, and `tasks`; `specs/<feature>/reviews/plan-review.md` is shared by plan review and code review. Failure-path/error-round conventions are documented separately as part of the failure-mode decision and the data model.

---

## Decision 5: Codex Dependency Model and Discovery Order

**Decision**: The Codex executor remains an external prerequisite installed independently from `https://skills.sh/oil-oil/codex/codex`. Discovery order is `CODEX_SKILL_PATH` override first, then the default path `~/.claude/skills/codex/scripts/ask_codex.sh`. Overrides are validated for existence, readability, and executability before use.

**Rationale**: The `/codex` skill is maintained independently and should not be vendored by the peer pack. Supporting an override path improves portability across machines and local environments without weakening safety, provided the override is validated and warnings redact the home path by default.

**Alternatives considered**:
- Bundle `ask_codex.sh` inside `packs/peer/` — rejected: creates version skew and duplicates upstream maintenance
- Auto-install via `extension.yml` hooks — rejected: not supported by Spec Kit and would add side effects to installation
- Default-path only, with no override — rejected: too brittle across nonstandard local setups

**Impact**: `peer-guide.md`, `quickstart.md`, and the command files must document the prerequisite clearly, support the validated override path, and fail with an actionable install/remediation message when discovery fails.

---

## Decision 6: `extension.yml` Structure for the `peer` Pack

**Decision**: The `peer` pack uses a standard Spec Kit extension manifest with `id: peer`, `provides.commands: [review, execute]`, `provides.memory: [memory/peer-guide.md]`, `provides.templates: []`, and `hooks: []`.

```yaml
id: peer
name: Spec Kit Peer
version: 1.0.0
provides:
  commands:
    - review
    - execute
  memory:
    - memory/peer-guide.md
  templates: []
hooks: []
```

**Rationale**: This matches the manifest schema expected by Spec Kit, keeps the peer workflow self-describing on install, and preserves FR-014 by avoiding mandatory hooks in v1. The memory file is intentionally part of v1 because it teaches the orchestrator when and how to use the peer commands.

**Alternatives considered**:
- Omitting `memory` in v1 — rejected: hides important workflow guidance from the agent context and conflicts with the intended install experience
- Adding `before_*` / `after_*` hooks in v1 — rejected: introduces intrusive behavior before the orchestration model is proven

**Impact**: `packs/peer/extension.yml` remains the single manifest source of truth for the pack, and `build-all.sh` can assemble the aggregate bundle from this manifest without special cases.

---

## Decision 7: Failure-Mode Handling and Recovery Policy

**Decision**: v1 is fail-fast for configuration and contract violations (`VALIDATION_ERROR`, `UNIMPLEMENTED_PROVIDER`, `PROVIDER_EMPTY_RESPONSE`, `PARSE_FAILURE`, `STATE_CORRUPTION`) and only auto-recovers from local, bounded cases that can be proven safe: starting a fresh provider session when a prior one is invalid/expired, reclaiming stale locks after ownership checks, and resuming from `last_persisted_round + 1` when the review file safely leads the state file. Provider timeouts do not auto-retry in v1.

**Rationale**: Silent healing is dangerous in an append-only review system because duplicate rounds and mismatched session state are worse than a visible failure. Bounded local recovery is acceptable when the system can prove the next action is safe; external-provider ambiguity is not. This keeps operator mental models simple and testable.

**Alternatives considered**:
- Blanket retries for all provider failures — rejected: can duplicate writes and hide provider/session bugs
- Treat every failure as recoverable — rejected: unsafe for corrupted state and parse-invalid outputs
- Ignore recovery entirely — rejected: forces users to hand-edit clearly recoverable local state issues

**Impact**: `plan.md`, `data-model.md`, and `scripts/validate-pack.sh` must cover timeout handling, stale-lock recovery, orphan-round recovery, and state corruption as explicit test cases rather than incidental implementation details.

---

## Decision 8: v1 Output Format Strategy

**Decision**: v1 keeps human-readable Markdown review output as the only provider-facing review format. Machine-readability comes from strict heading conventions, deterministic terminal markers, and the adapter stdout contract (`session_id=` followed by `output_path=`). A dedicated `--format json` mode is deferred to v2 and should only be added when at least two real automation consumers require it or the feature is promoted from a documented backlog trigger.

**Rationale**: Human-readable review history is the primary v1 value. Adding a versioned JSON response format now would increase surface area, testing burden, and migration cost without a demonstrated consumer. The strict terminal markers already give the orchestrator enough structure for v1 parsing.

**Alternatives considered**:
- JSON-only output in v1 — rejected: raises implementation and compatibility cost too early
- Dual Markdown + JSON output in v1 — rejected: duplicates contracts and increases drift risk before automation demand is proven

**Impact**: Contracts and prompts must stay disciplined about headings, status lines, and stdout behavior. If automation needs increase, this decision provides the explicit trigger for revisiting machine-readable output.

---

## Resolved Clarifications

All decisions above were derived from existing local materials: `docs/original-plan.md`, `spec.md`, `plan.md`, `data-model.md`, `quickstart.md`, and the command contracts. No external research was required.

| Item | Resolution |
|------|-----------|
| Command file format | Markdown + YAML frontmatter, plus canonical artifact delimiters and deterministic terminal markers |
| Provider state schema | Versioned JSON keyed by provider and workflow, with lifecycle and recovery metadata |
| Peer config schema | Versioned `.specify/peer.yml` with provider config plus session/context limits |
| Review file format | Append-only Markdown, shared `plan-review.md` for plan + code review, explicit status taxonomy |
| Codex dependency model | External prerequisite with validated override path and deterministic discovery order |
| extension.yml shape | Standard Spec Kit manifest with commands, memory, no templates, and no mandatory hooks |
| Failure-mode policy | Fail-fast for unsafe states, bounded auto-recovery for stale locks/expired sessions/orphan rounds |
| v1 output strategy | Human-readable Markdown retained in v1; JSON deferred behind explicit adoption trigger |
