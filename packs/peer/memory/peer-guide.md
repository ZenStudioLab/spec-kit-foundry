# Peer Workflow Reference Guide

**Pack**: `peer` · **Version**: 1.0.0

This memory file is injected into agent context when the `peer` pack is installed. It provides a quick reference for when and how to use peer commands during a Spec Kit workflow.

---

## Commands Overview

| Command | Purpose |
|---------|---------|
| `/speckit.peer.review <target>` | Run adversarial review on a Spec Kit artifact, or delegate an explicit file path to `/plan-review` |
| `/speckit.peer.execute` | Implement pending tasks in batches with code review after each batch |

---

## When to Use Each Command

### `/speckit.peer.review`

Use `/speckit.peer.review` when you want an AI adversary to challenge your artifact before you advance to the next workflow step.

**Use cases**:
- After writing `spec.md` → `/speckit.peer.review spec`
- After `/speckit.research` → `/speckit.peer.review research`
- After `/speckit.plan` → `/speckit.peer.review plan`
- After `/speckit.tasks` → `/speckit.peer.review tasks` *(cross-artifact check — loads all four artifacts)*
- For a standalone plan or design file outside `specs/` → `/speckit.peer.review path/to/file.md` *(delegates to `/plan-review`; no peer review file/state is created)*

### `/speckit.peer.execute`

Use `/speckit.peer.execute` when:
- `plan.md` has been reviewed and has status `APPROVED` or `MOSTLY_GOOD`
- `tasks.md` has been reviewed and has status `APPROVED` or `MOSTLY_GOOD`
- There are unchecked tasks remaining in `tasks.md`

The command implements tasks in batches and appends a code-review round to `plan-review.md` after each batch.

---

## Typical Workflow (Six Steps)

```
1. /speckit-specify      → write spec.md
2. /speckit.peer.review spec    → review spec; revise until APPROVED/MOSTLY_GOOD
3. /speckit.plan         → generate plan.md
4. /speckit.peer.review plan    → review plan; revise until APPROVED/MOSTLY_GOOD
5. /speckit.tasks        → generate tasks.md
   /speckit.peer.review tasks   → cross-artifact readiness check
6. /speckit.peer.execute → implement in batches; code review each batch
```

---

## Artifact Review Rubrics

### `spec`
- **Scope clarity**: Are all requirements bounded and unambiguous?
- **Ambiguity**: Are there undefined terms, vague requirements, or missing acceptance criteria?
- **Testability**: Can each requirement be verified with a concrete test?
- **Edge cases**: Are boundary conditions and failure modes identified?

### `research`
- **Decision quality**: Are technology/approach choices well-justified?
- **Alternatives**: Were viable alternatives evaluated before selecting an approach?
- **Blockers**: Are there unresolved dependencies, risks, or open questions that block implementation?
- **Completeness**: Are all technical constraints and third-party dependencies documented?

### `plan`
- **Architecture soundness**: Is the design coherent and internally consistent?
- **Implementation feasibility**: Can the described approach be implemented as specified?
- **Sequencing**: Are phases and dependencies in a logical and safe order?
- **Risk identification**: Are known risks, constraints, and mitigation strategies explicit?

### `tasks`
- **Coverage**: Does every functional requirement (FR) map to at least one task?
- **Dependency order**: Are task dependencies correctly sequenced (no task depends on an incomplete prerequisite)?
- **Missing tests**: Does every non-trivial feature or behavior have a corresponding test task?
- **Constitution alignment**: Do tasks adhere to pack modularity, code quality, and simplicity principles?

---

## Consensus Status Definitions

### Artifact Reviews (`/speckit.peer.review`)

| Status | Meaning | Recommended Action |
|--------|---------|-------------------|
| `NEEDS_REVISION` | Significant gaps, contradictions, or blockers found | Revise artifact; rerun review |
| `MOSTLY_GOOD` | Minor issues; overall direction is sound | Apply minor revisions; may proceed |
| `APPROVED` | Artifact meets quality gates | Proceed to next workflow step |
| `BLOCKED` | A blocker exists that must be resolved before proceeding | Stop; address blocker explicitly |

### Code Reviews (`/speckit.peer.execute`)

| Status | Meaning | Recommended Action |
|--------|---------|-------------------|
| `NEEDS_FIX` | Implementation issues found in this batch | Dispatch fix instructions; re-review |
| `APPROVED` | Batch implementation meets plan constraints | Advance to next batch |

---

## Session Continuity

Provider session state is persisted in `specs/<featureId>/reviews/provider-state.json`, keyed by provider name and workflow type (`review` or `execute`).

- Sessions are reused across rounds to maintain conversation context
- Sessions reset automatically when `max_rounds_per_session` is reached (default: `10`)
- `provider-state.json` is a runtime state file — it MUST be listed in `.gitignore` and NOT committed to version control

---

## Troubleshooting Quick Reference

| Problem | Likely Cause | Resolution |
|---------|-------------|-----------|
| `peer.yml not found` | `.specify/peer.yml` missing | Create `.specify/peer.yml` with `version: 1` and a `providers` map |
| `codex skill not found` | `/codex` skill not installed | Install from `https://skills.sh/oil-oil/codex/codex` |
| `plan-review not found` | File-path delegation target used but `/plan-review` is unavailable | Install or enable the host `/plan-review` skill before using file-path targets |
| `Plan has no approved review` | `/speckit.peer.review plan` not run or not approved | Run `/speckit.peer.review plan` and address feedback until `APPROVED` or `MOSTLY_GOOD` |
| `Tasks readiness is not approved` | `/speckit.peer.review tasks` not run or not approved | Run `/speckit.peer.review tasks` and address feedback until `APPROVED` or `MOSTLY_GOOD` |
| `UNIMPLEMENTED_PROVIDER` | `--provider gemini` (or other stub provider) | Only `codex` is implemented in v1; use default provider or `--provider codex` |
| `PARSE_FAILURE` | Provider response missing terminal status marker | Retry the command; if persistent, check `PEER_DEBUG=1` output |
| `STATE_CORRUPTION` | `last_persisted_round > review round count` | Manual recovery required: delete or repair `provider-state.json`; do not auto-recover |
| Nothing to execute | All tasks already checked in `tasks.md` | All tasks complete; no action needed |
