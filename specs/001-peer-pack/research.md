# Research: Spec Kit Peer Workflow Integration

**Feature**: `001-peer-pack`
**Date**: 2026-03-27
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## Decision 1: Command File Format for Spec Kit Extensions

**Decision**: Markdown files with YAML frontmatter for metadata, followed by Markdown prose that contains the full behavioral instruction set for the AI agent executing the command.

**Rationale**: All existing Spec Kit skills (`plan-review`, `plan-execute`, `speckit-plan`) use this format. The YAML frontmatter carries `name`, `description`, and `compatibility` fields consumed by the `specify` CLI when indexing the extension. The prose body is the instruction contract read by the AI agent at invocation time. This pattern is already established and users are familiar with it.

**Alternatives considered**:
- JSON schema-only command definition — rejected: cannot encode behavioral prose instructions in a type-safe schema without losing expressiveness; AI agents benefit from natural-language instruction blocks
- Pure YAML — rejected: YAML does not handle multi-paragraph instruction prose ergonomically; existing tooling parses YAML frontmatter + Markdown body

**Impact**: Command files at `packs/peer/commands/review.md` and `packs/peer/commands/execute.md` will follow the `---\n<yaml frontmatter>\n---\n\n<markdown instructions>` format.

---

## Decision 2: Provider State Schema (`provider-state.json`)

**Decision**: Nested JSON object keyed by provider → workflow → `{ session_id, updated_at }`.

```json
{
  "codex": {
    "review": {
      "session_id": "<opaque string from codex skill>",
      "updated_at": "2026-03-27T14:30:00Z"
    },
    "execute": {
      "session_id": "<opaque string from codex skill>",
      "updated_at": "2026-03-27T15:00:00Z"
    }
  }
}
```

**Rationale**: Separating by provider and workflow allows review and execute sessions to maintain independent conversation threads with Codex. This matches the codex skill's `--session <id>` resumption mechanism — each workflow type started a distinct conversation; mixing them would cause context contamination. The `updated_at` timestamp allows staleness detection without querying the provider.

**Alternatives considered**:
- Flat array of `{ provider, workflow, session_id }` — rejected: requires linear search; harder to read/write atomically per workflow
- One file per provider per workflow (e.g., `codex-review-session.txt`) — rejected: proliferates files in `reviews/`; harder to inspect at a glance; not portable to future providers that may have multiple session identifiers

**Impact**: `specs/<feature>/reviews/provider-state.json` is created on first successful Codex invocation and updated after every subsequent round.

---

## Decision 3: `.specify/peer.yml` Config Schema

**Decision**: Top-level YAML with a `default_provider` string and a `providers` map of adapter config objects. Matches the schema already sketched in `docs/original-plan.md`.

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

**Rationale**: Project-level config (not pack-level) allows the provider preference to apply to all peer commands uniformly. Storing it in `.specify/` alongside other Spec Kit config keeps it co-located with the project's extension configuration. The stub entries for Copilot/Gemini are required by FR-012 — their presence allows the `--provider` flag validation to distinguish "not configured" from "configured but not implemented".

**Alternatives considered**:
- Environment variables only — rejected: not portable across machines/CI; not discoverable
- Embedding in `extension.yml` — rejected: `extension.yml` is pack-scoped and versioned per release; provider configuration is project-scoped user preference that should not change with pack versions
- Per-user global config — rejected: production workflows often need per-project provider selection; project-level config is the right scope

**Impact**: Users create `.specify/peer.yml` once per project. The peer command files validate its presence and read `default_provider` at invocation time.

---

## Decision 4: Review File Format and Shared File Convention

**Decision**: Append-only Markdown with `---` round separators. Artifact review rounds use `## Round N — YYYY-MM-DD` headings with `Consensus Status: NEEDS_REVISION | MOSTLY_GOOD | APPROVED`. Code review rounds from `/speckit.peer.execute` use `## Code Review Round N — YYYY-MM-DD` with `Verdict: NEEDS_FIX | APPROVED`. Both types share `reviews/plan-review.md` for the plan artifact (matching the `plan-execute` skill's convention of appending code review rounds to the same file as plan review rounds).

**Rationale**: Directly inherited from the `plan-review` and `plan-execute` SKILL.md contracts already in use. Reusing the established format means users who are familiar with those skills transition to `peer` commands with zero learning overhead. Sharing the file for plan + code review keeps all review history for a feature colocated and readable in chronological order.

**Alternatives considered**:
- Separate `reviews/code-review.md` for execute rounds — rejected: splits review history; user must read two files to understand the full review arc of a feature
- Structured JSON review rounds — rejected: not human-readable inline; AI agents produce and consume Markdown naturally; existing skills use Markdown

**Impact**: `specs/<feature>/reviews/<artifact>-review.md` for spec, research, tasks artifacts. `specs/<feature>/reviews/plan-review.md` for both plan review and code review rounds.

---

## Decision 5: Codex Skill Dependency Model (External vs Bundled)

**Decision**: External prerequisite. Users install the `/codex` skill independently from `https://skills.sh/oil-oil/codex/codex`. The peer pack does not vendor or bundle it.

**Rationale**: The codex skill is a standalone, independently maintained tool targeting many projects. Bundling it would create a version-skew problem — spec-kit-foundry releases would need to track codex skill updates. The skill's invocation contract (script path, `session_id` output, `--session` flag) is stable and documented. An external prerequisite with a one-line install is the correct coupling model.

**Alternatives considered**:
- Bundle `ask_codex.sh` inside `packs/peer/` — rejected: creates duplicate maintenance; divergence from upstream would cause silent behavioral differences; violates the peer pack's single-responsibility boundary
- Auto-install via `extension.yml` hooks — rejected: Spec Kit's install model doesn't support nested dependency installation; would require intrusive changes to the CLI

**Impact**: The `peer-guide.md` memory file and quickstart.md must document the prerequisite install step clearly. The `review.md` / `execute.md` command files must fail clearly with an actionable error if the codex script is not found at the expected path.

---

## Decision 6: `extension.yml` Structure for the `peer` Pack

**Decision**: Standard Spec Kit extension manifest with `id: peer`, `provides.commands: [review, execute]`, empty `provides.memory` and `provides.templates` lists (populated if the optional preset additions are implemented in a future version), and no mandatory `hooks`.

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

**Rationale**: Matches the manifest schema required by the constitution's Technical Standards section. No hooks in v1 (all commands are user-invoked explicitly per FR-014). Memory file `peer-guide.md` is included to inject the peer workflow reference into agent context on install.

**Alternatives considered**:
- Including `before_specify` / `after_plan` suggestion hooks — deferred to a future version; including them now would mean evaluating hook condition logic before the orchestration model is proven working
- Omitting `memory` entirely — rejected: the peer-guide.md memory file gives agents the context to understand when and how to invoke peer commands without reading the full command files

**Impact**: `packs/peer/extension.yml` is the single source of truth for what the pack provides. `build-all.sh` assembles the root aggregate from this manifest.

---

## Resolved Clarifications

All six decisions above were knowable from existing skill files, the original-plan.md, constitution.md, and the spec.md. No external research was required. All NEEDS CLARIFICATION items from Technical Context are fully resolved:

| Item | Resolution |
|------|-----------|
| Command file format | Markdown + YAML frontmatter (matches existing skills) |
| Provider state schema | Nested JSON by provider → workflow |
| Peer config schema | `.specify/peer.yml` YAML (matches original-plan.md) |
| Review file format | Append-only Markdown (matches plan-review/plan-execute) |
| Codex dependency model | External prerequisite, install from skills.sh |
| extension.yml shape | Standard Spec Kit manifest, constitution Technical Standards |
