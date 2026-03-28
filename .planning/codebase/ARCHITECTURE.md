# Architecture Overview

## System Design

spec-kit-foundry is a multi-pack hub for the Spec Kit (`specify` CLI). It provides installable extensions ("packs") that augment Spec Kit projects with adversarial peer review and orchestrated batch task execution. The system is entirely local — no HTTP services, no servers. All coordination happens through the Claude (Orchestrator) ↔ shell script ↔ external AI provider (Executor/Reviewer) pipeline.

The central abstraction is the **pack**: a self-contained directory installable via `specify extension add`. Packs ship Claude-readable instruction files (`.md`) that define command behavior, plus optional persistent memory files injected into Claude's context.

## Core Components

### Pack: `packs/peer/`
The primary installable unit. Contains:
- **`extension.yml`** — Pack manifest declaring commands and metadata for the `specify` CLI.
- **`commands/review.md`** — Instruction file for the `/speckit.peer.review` command. Defines the multi-round adversarial review loop that Claude orchestrates.
- **`commands/execute.md`** — Instruction file for the `/speckit.peer.execute` command. Defines batch task dispatch to an AI provider, with code-review gating between rounds.
- **`memory/peer-guide.md`** — Persistent memory injected into Claude's context when the pack is active; encodes behavioral constraints and role separation rules.
- **`templates/`** — Reserved directory for future output templates.

### Provider Adapters: `shared/providers/`
Each supported AI provider (codex, copilot, gemini) has an adapter guide at `shared/providers/<name>/adapter-guide.md`. In v1 only `codex` is implemented. The adapter guide is the binding contract describing how to invoke the provider's shell script, what arguments to pass, and how to interpret its output.

### Schema: `shared/schemas/peer-providers.schema.yml`
JSON Schema (YAML format) for the user-facing `.specify/peer.yml` configuration file. Defines valid provider names, required fields, and option shapes.

### Validation Script: `scripts/validate-pack.sh`
Bash acceptance-test runner. Verifies pack structural integrity and behavioral contracts without requiring a live Spec Kit installation.

### State File: `specs/<featureId>/reviews/provider-state.json`
Per-feature JSON file persisting provider session state (e.g., Codex `session_id`) across multi-round review and execution loops. Enables continuity between separate CLI invocations.

### Specification Artifacts: `specs/<featureId>/`
Human-authored feature specifications (spec, plan, tasks, research, quickstart, data-model, contracts, checklists). These are the primary inputs consumed by the review and execute commands.

## Data Flow

### Review Flow (`/speckit.peer.review <artifact>`)
```
User invokes command
  → Claude reads commands/review.md
  → Claude validates .specify/peer.yml config and reads provider-state.json
  → Claude invokes ask_codex.sh via terminal with artifact content
  → Codex produces review output (APPROVED / CHANGES_REQUESTED / BLOCKED)
  → Claude reads Codex output
  → If CHANGES_REQUESTED: Claude revises artifact, persists state, loops
  → If APPROVED or BLOCKED: loop terminates, final state written to provider-state.json
```

### Execute Flow (`/speckit.peer.execute`)
```
User invokes command
  → Claude reads commands/execute.md
  → Claude validates that plan.md and tasks.md have passing reviews
  → Claude reads task list, groups tasks into batches
  → For each batch:
      → Claude dispatches batch to Codex via ask_codex.sh
      → Codex implements tasks, returns implementation
      → Claude runs code-review loop (may invoke review command internally)
      → On pass: mark tasks complete, persist state
      → On fail: surface blocking issues to user
  → Continues until all tasks complete or a BLOCKED state is reached
```

### Provider Invocation
All provider calls are made via shell script (e.g., `~/.claude/skills/codex/scripts/ask_codex.sh`). Claude constructs the invocation arguments per the adapter guide, runs the script in the terminal, and parses structured output. This keeps provider I/O fully observable and testable.

## Key Design Decisions

### Strict Role Separation (Orchestrator vs. Executor)
Claude never writes implementation or review content. Claude's role is purely orchestration: reading instruction files, constructing inputs, invoking scripts, routing outputs, managing state, and deciding loop continuation. All content production is delegated to the external provider. This is a hard constraint enforced in `memory/peer-guide.md` and the command files themselves.

### Command Files as Natural-Language Programs
Commands are `.md` files, not code. This makes them readable, diffable, and editable without tooling. Claude interprets them at runtime. The tradeoff is that correctness depends on Claude's instruction-following fidelity rather than a parser.

### Pack Installability via `specify extension add`
Packs are designed to be consumed by the `specify` CLI without requiring repository access beyond the pack directory. The `extension.yml` manifest is the only integration point with the host CLI.

### Provider Abstraction Layer
The schema and adapter-guide pattern separates user configuration (`.specify/peer.yml`) from invocation implementation. Adding a new provider requires only a new `adapter-guide.md` and schema entry — no changes to command files.

### Local-Only, No Network Services
The system intentionally avoids HTTP services or daemon processes. All state is file-based. This maximizes portability, simplifies debugging, and eliminates server lifecycle concerns.

### Session Continuity via `provider-state.json`
Rather than re-establishing provider context on every invocation, session IDs are persisted per-feature. This enables multi-round reviews to maintain conversational context with the provider.

## Constraints

- **Claude must not produce content** (implementation or review text) — only orchestrate.
- **Provider invocation is always via shell script** — never via direct API calls from Claude.
- **Pack structure must conform to `extension.yml` manifest** — commands declared there must exist as `.md` files.
- **`.specify/peer.yml` must validate against `peer-providers.schema.yml`** before any command executes.
- **`provider-state.json` is the single source of truth for session state** — no in-memory state survives between Claude sessions.
- **Only `codex` provider is implemented in v1** — other provider entries in schema are reserved.
- **No server or daemon** — all workflows are synchronous CLI invocations.
- **The `ask_codex.sh` script is an external prerequisite** — it must be installed separately from this repository.
