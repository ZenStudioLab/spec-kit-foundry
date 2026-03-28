# Requirements

## Vision

A Spec Kit pack that enforces atomic git commits at every task completion boundary during `speckit.implement`, without requiring the user to change their workflow or learn new commands. The pack works across all Spec Kit-supported LLM providers via provider-agnostic memory injection.

## Must-Have (v1)

- [ ] **R-01** Pack installable via `specify extension add auto-task-commit`
- [ ] **R-02** Memory guide injected automatically when pack is active (via `provides.memory` in extension.yml)
- [ ] **R-03** Guide instructs any LLM to run `git add -A && git commit -m "..."` after each task checkbox is ticked during `speckit.implement`
- [ ] **R-04** Commit message format: `feat(<featureId>): <task text>` (feature ID and task text extracted from context)
- [ ] **R-05** Execution halts if `git commit` exits non-zero; error surfaced to user
- [ ] **R-06** Granularity configurable via `.specify/auto-task-commit.yml`: `task` (default) or `batch`
- [ ] **R-07** Config validated against `shared/schemas/auto-task-commit.schema.yml`
- [ ] **R-08** Acceptance tests in `scripts/validate-auto-task-commit.sh` (T-01 through T-06+)
- [ ] **R-09** Pack distributable as `auto-task-commit.zip`

## Should-Have (v1 if time permits)

- [ ] **R-10** `commit_message_template` in config allows custom format strings
- [ ] **R-11** Guide includes "nothing to commit" handling: skip gracefully if no staged changes

## Out of Scope

- git push — **R-OOS-01** — commit only; push is a separate decision
- Non-git VCS — **R-OOS-02** — git only in v1
- Commit signing/GPG — **R-OOS-03** — not in scope for v1
- Claude-specific syntax in memory guide — **R-OOS-04** — must be provider-agnostic
- Modifying peer pack's execute command — **R-OOS-05** — separate concerns

---
*Last updated: 2026-03-28 after initialization*
