# auto-task-commit

## What This Is

A standalone Spec Kit pack for spec-kit-foundary that enforces a git commit after each individual task (or batch) is completed during `speckit.implement`. When installed, it injects a provider-agnostic instruction guide that any Spec Kit-supported LLM will follow to commit changes after marking each task checkbox as done. No new commands or workflow changes are required from the user.

## Core Value

Every completed task produces an atomic, traceable git commit — no implementation state is lost between tasks.

## Requirements

### Validated

- ✓ Pack extension model (`extension.yml` manifest, memory injection via `provides.memory`) — existing
- ✓ Spec Kit CLI integration (`specify extension add`) — existing
- ✓ Shared schema pattern (`shared/schemas/`) — existing
- ✓ `validate-pack.sh` acceptance test framework — existing
- ✓ Provider adapter abstraction model — existing

### Active

- [ ] `packs/auto-task-commit/extension.yml` — pack manifest declaring memory injection
- [ ] `packs/auto-task-commit/memory/auto-task-commit-guide.md` — provider-agnostic instruction file enforcing git commit after each task
- [ ] `.specify/auto-task-commit.yml` config support — `granularity: task|batch`, `commit_message_template`
- [ ] `shared/schemas/auto-task-commit.schema.yml` — YAML schema for config validation
- [ ] Halt-on-failure enforcement when `git commit` exits non-zero
- [ ] Configurable granularity: per-task (default) or per-batch
- [ ] Auto-generated commit messages: `feat(<featureId>): <task text>`
- [ ] `scripts/validate-auto-task-commit.sh` — acceptance tests
- [ ] Distribution as `auto-task-commit.zip` (parallel to `peer.zip`)
- [ ] README.md updated with new pack entry

### Out of Scope

- Modifying the peer pack's execute command — separate concerns
- git push — commit only, not push
- Non-git VCS — git only in v1
- Commit signing/GPG — not in scope for v1
- CI/CD enforcement — local-only in v1
- Claude-specific syntax in the memory guide — must be provider-agnostic

## Context

spec-kit-foundary already ships the `peer` pack. The `auto-task-commit` pack follows the exact same structural pattern: `extension.yml` + `memory/*.md`. The key difference is this pack provides no user-invoked commands — it solely injects a persistent memory rule that is automatically active whenever the pack is installed.

The memory guide must be written in provider-agnostic Markdown so it works with any LLM that Spec Kit supports (not just Claude). The git commit is a plain shell command any capable provider can invoke.

The pack targets the base `speckit.implement` command (not `speckit.peer.execute`, which is Codex-specific and already handles its own code-review loop).

## Constraints

- **Tech stack**: Bash 5+, YAML 1.2, Markdown only — no new language runtimes
- **Provider-agnostic**: Memory guide must not reference Claude or any specific LLM
- **Follows peer pack patterns**: `extension.yml` schema_version 1.0, same directory layout
- **No bundled external deps**: The pack assumes git is installed; no other prerequisites beyond Spec Kit

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Memory injection (not wrapper command) | Provider-agnostic; no user workflow change required | — Pending |
| Per-task default granularity | Maximum traceability; configurable to per-batch | — Pending |
| Halt on commit failure | Strict enforcement; no silent state gaps | — Pending |
| Auto-generate commit message from task text + featureId | No user input needed; readable git history | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions

---
*Last updated: 2026-03-28 after initialization*
