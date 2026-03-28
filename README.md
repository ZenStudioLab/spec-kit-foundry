# spec-kit-foundry

A multi-pack hub for [Spec Kit](https://github.com/oil-oil/spec-kit) — installable extensions that add adversarial peer review, orchestrated batch execution, and workflow helpers to any Spec Kit project.

## Packs

| Pack | Type | Commands | Status |
|------|------|----------|--------|
| `peer` | commands | `/speckit.peer.review`, `/speckit.peer.execute` | v1.0.0 |
| `auto-task-commit` | memory | — | v1.0.0 |

---

## peer pack

Adds adversarial AI peer review and Codex-orchestrated batch task execution to your Spec Kit workflow.

### Commands

**`/speckit.peer.review <artifact>`**
Submits a Spec Kit artifact to a Codex peer reviewer. Appends a structured review round (issues, severity labels, consensus status) to `specs/<feature>/reviews/<artifact>-review.md`.

Supported artifacts: `spec`, `research`, `plan`, `tasks`

**`/speckit.peer.execute`**
Verifies plan and tasks reviews are approved, then dispatches unchecked `tasks.md` checkboxes to Codex in coherent batches. Each batch is followed by a code review loop. Claude orchestrates; Codex implements.

### Typical workflow

```
/speckit-specify              → create spec.md
/speckit.peer.review spec     → peer-review the spec (optional)
/speckit.plan                 → generate plan.md + tasks.md
/speckit.peer.review plan     → peer-review the plan (required before execute)
/speckit.peer.review tasks    → cross-artifact readiness gate (recommended)
/speckit.peer.execute         → implement tasks with Codex
```

---

## auto-task-commit pack

Enforces an atomic `git commit` after every completed task during `speckit.implement`. Installed as a memory-only pack — no commands required. Works with any LLM provider.

When the pack is active, the injected memory guide instructs the implementing AI to:
- Run `git status` → `git add -A` → `git commit` after each `- [x]` tick
- Auto-generate the commit message: `feat(<featureId>): <taskText>`
- Skip gracefully if there is nothing to commit
- Halt if `git commit` exits non-zero, and wait for user resolution

### Configuration (optional)

Create `.specify/auto-task-commit.yml` in your project root:

```yaml
version: 1
granularity: task    # or "batch" — default: task
commit_message_template: "feat({featureId}): {taskText}"   # optional
```

| Field | Default | Description |
|-------|---------|-------------|
| `granularity` | `task` | `task` = commit after each checkbox; `batch` = commit after each group |
| `commit_message_template` | `feat({featureId}): {taskText}` | Custom template with `{featureId}` and `{taskText}` tokens |

If the file is absent, defaults apply. If it is malformed, the pack warns and continues with defaults.

### Typical workflow

```
/speckit.implement            → implement tasks; pack auto-commits after each one
git log --oneline             → one commit per task, each with a feat() message
```

---

## Prerequisites

**1. Spec Kit CLI**
```bash
specify --version
```

**2. Codex skill** (required for `peer` pack only)
```bash
skills install https://skills.sh/oil-oil/codex/codex
test -x ~/.claude/skills/codex/scripts/ask_codex.sh && echo "OK"
```

---

## Installation

### Install the peer pack

**From a tagged release:**
```bash
specify extension add peer --from https://github.com/ZenStudioLab/spec-kit-foundary/releases/download/v1.0.0/peer.zip
```

**From local clone (dev / monorepo):**
```bash
specify extension add peer --dev /path/to/spec-kit-foundary/packs/peer
```

Verify:
```bash
specify extension list
# peer  1.0.0  commands: review, execute
```

### Install the auto-task-commit pack

**From a tagged release:**
```bash
specify extension add auto-task-commit --from https://github.com/ZenStudioLab/spec-kit-foundary/releases/download/v1.0.0/auto-task-commit.zip
```

**From local clone (dev / monorepo):**
```bash
specify extension add auto-task-commit --dev /path/to/spec-kit-foundary/packs/auto-task-commit
```

Verify:
```bash
specify extension list
# auto-task-commit  1.0.0  memory: auto-task-commit-guide.md
```

### Configure the peer pack in your project

Create `.specify/peer.yml` in the project root:

```yaml
version: 1
default_provider: codex
max_rounds_per_session: 10
max_context_rounds: 3
max_artifact_size_kb: 50

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

`copilot` and `gemini` are reserved stubs — only `codex` is implemented in v1.

---

## Artifacts produced

After a full peer review + execute cycle:

```
specs/<featureId>/
├── spec.md
├── research.md
├── plan.md
├── tasks.md                      ← checkboxes completed by Codex
└── reviews/
    ├── spec-review.md
    ├── research-review.md
    ├── plan-review.md
    ├── tasks-review.md
    └── provider-state.json       ← runtime, VCS-ignored
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `peer.yml not found` | Create `.specify/peer.yml` as shown above |
| `Codex skill not found` | Run `skills install https://skills.sh/oil-oil/codex/codex` |
| `Plan has no approved review` | Run `/speckit.peer.review plan` first |
| `Tasks readiness not approved` | Run `/speckit.peer.review tasks` and resolve findings |
| `Provider 'x' is disabled` | Set `enabled: true` in `peer.yml` or use `default_provider: codex` |
| `auto-task-commit: commit failed` | Resolve the git conflict or error, then re-run `speckit.implement` |
| `auto-task-commit: malformed config` | Fix `.specify/auto-task-commit.yml` — defaults are used until corrected |
