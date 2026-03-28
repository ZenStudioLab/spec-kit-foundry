# Project Structure

## Directory Layout

```
spec-kit-foundary/
├── AGENTS.md                          # Development guidelines (auto-generated from feature plans)
├── README.md                          # Project overview and usage
│
├── packs/                             # Installable Spec Kit extension packs
│   └── peer/                          # The "peer" pack (adversarial review + batch execution)
│       ├── extension.yml              # Pack manifest for `specify extension add`
│       ├── commands/                  # Claude-readable instruction files (one per command)
│       │   ├── review.md              # /speckit.peer.review command definition
│       │   └── execute.md             # /speckit.peer.execute command definition
│       ├── memory/                    # Persistent memory files injected into Claude's context
│       │   └── peer-guide.md          # Behavioral rules and role-separation constraints
│       └── templates/                 # (Reserved for output templates — currently empty)
│
├── shared/                            # Cross-pack shared resources
│   ├── providers/                     # Provider adapter contracts
│   │   └── codex/
│   │       └── adapter-guide.md       # Codex invocation contract (args, output format)
│   └── schemas/
│       └── peer-providers.schema.yml  # YAML schema for .specify/peer.yml config file
│
├── scripts/
│   └── validate-pack.sh               # Bash acceptance-test runner for pack integrity
│
├── specs/                             # Feature specification artifacts (per-feature directories)
│   └── 001-peer-pack/                 # Spec artifacts for the peer pack feature
│       ├── spec.md                    # Feature specification
│       ├── plan.md                    # Implementation plan
│       ├── tasks.md                   # Granular task list
│       ├── research.md                # Research findings
│       ├── quickstart.md              # User quickstart guide
│       ├── data-model.md              # Data model description
│       ├── checklists/
│       │   └── requirements.md        # Requirements checklist
│       ├── contracts/
│       │   ├── execute-command.md     # Behavioral contract for /speckit.peer.execute
│       │   └── review-command.md      # Behavioral contract for /speckit.peer.review
│       └── reviews/                   # Review artifacts and provider session state
│           ├── data-model-review.md
│           ├── execute-command-review.md
│           ├── plan-review.md
│           ├── quickstart-review.md
│           ├── research-review.md
│           ├── review-command-review.md
│           ├── tasks-review.md
│           └── provider-state.json    # Persisted Codex session_id for multi-round continuity
│
├── docs/                              # Project-level documentation
│   ├── original-plan.md               # Initial project plan
│   └── plans/
│       └── refining-agent-for-codex-invocation.md
│   └── reviews/
│       └── refining-agent-for-codex-invocation-review.md
│
└── reviews/
    └── constitution-review.md         # Top-level constitution / design review
```

## Key Files

| File | Role |
|------|------|
| `packs/peer/extension.yml` | Pack manifest. Declares the pack name, version, and the commands it exposes to the `specify` CLI. This is the integration point with the host tool. |
| `packs/peer/commands/review.md` | Defines the complete behavior of `/speckit.peer.review`. Claude reads this at invocation time. Encodes the multi-round adversarial review loop, termination conditions (APPROVED/BLOCKED), and state persistence logic. |
| `packs/peer/commands/execute.md` | Defines the complete behavior of `/speckit.peer.execute`. Encodes batch task dispatch, code-review gating between rounds, and continuation/termination logic. |
| `packs/peer/memory/peer-guide.md` | Injected into Claude's persistent memory when the pack is active. Contains the critical role-separation constraint: Claude orchestrates, never produces content. |
| `shared/providers/codex/adapter-guide.md` | The binding contract between command files and the Codex shell script. Specifies argument format, expected output structure, and error handling. |
| `shared/schemas/peer-providers.schema.yml` | Validates the user's `.specify/peer.yml` at command startup. Prevents misconfigured providers from causing silent failures. |
| `scripts/validate-pack.sh` | Bash acceptance-test runner. Checks pack structural correctness (manifest, command files, memory files) without requiring a live `specify` install. |
| `specs/001-peer-pack/reviews/provider-state.json` | Runtime state file. Stores the Codex `session_id` so multi-round review/execute loops can resume without re-establishing provider context. |

## Module Responsibilities

### `packs/peer/` — The Peer Pack
The sole deliverable of this repository in v1. Responsible for:
- Declaring itself as a valid Spec Kit extension (via `extension.yml`).
- Defining the orchestration logic for adversarial review (`review.md`) and batch execution (`execute.md`) as natural-language programs for Claude.
- Injecting persistent behavioral constraints into Claude's context (`peer-guide.md`).

### `shared/providers/` — Provider Adapter Layer
Responsible for defining the invocation contracts between generic command logic and specific AI provider tooling. Decouples "what the command wants to do" from "how to invoke a specific provider". Adding support for a new provider (e.g., copilot, gemini) requires only a new subdirectory here plus a schema update.

### `shared/schemas/` — Configuration Schema
Responsible for formally defining what a valid `.specify/peer.yml` looks like. Enables upfront validation before any provider is invoked, surfacing configuration errors early.

### `scripts/` — Tooling & Validation
Responsible for pack acceptance testing. Ensures new pack versions or structural changes don't violate the expected layout before publishing or installation.

### `specs/<featureId>/` — Specification Artifacts
Responsible for housing the complete lifecycle of a feature: from research and spec through plan, tasks, contracts, and reviews. Also owns the runtime `provider-state.json` for that feature's review/execute sessions. These are inputs to the workflow, not outputs.

### `docs/` — Project Documentation
Responsible for higher-level narrative documentation: original plans, refinement proposals, and their associated reviews. Distinct from `specs/` (which are feature-scoped) and `packs/` (which are deliverables).

## Entry Points

### User-Facing Commands (via `specify` CLI after `specify extension add peer`)
- **`/speckit.peer.review <artifact-path>`** — Initiates or resumes an adversarial review loop for a single artifact. Defined in `packs/peer/commands/review.md`.
- **`/speckit.peer.execute`** — Initiates or resumes batch task execution for the current feature. Defined in `packs/peer/commands/execute.md`.

### Validation Entry Point
- **`scripts/validate-pack.sh`** — Run directly via Bash to validate pack structure. Used in CI or pre-install verification.

### External Prerequisite
- **`~/.claude/skills/codex/scripts/ask_codex.sh`** — Not part of this repository. Must be installed separately from https://skills.sh/oil-oil/codex/codex. This script is the sole mechanism by which Claude invokes the Codex provider. All provider I/O flows through it.
