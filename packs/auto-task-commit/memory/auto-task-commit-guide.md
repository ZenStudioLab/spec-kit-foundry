# Auto-Task-Commit Guide

**Pack**: `auto-task-commit` · **Version**: 1.0.0

This memory file is automatically injected when the `auto-task-commit` pack is installed. It defines mandatory commit behavior during `speckit.implement`. These rules apply whenever you are implementing tasks from a `tasks.md` file.

---

## Step 0 — Check enabled state

Before starting any `speckit.implement` run, check `.specify/auto-task-commit.yml`:

```bash
test -f .specify/auto-task-commit.yml
```

- If the file **does not exist**: pack is active (default). Proceed with all commit rules below.
- If the file **exists**, read the `enabled` field:
  - `enabled: true` (or key absent): pack is active. Proceed with all commit rules below.
  - `enabled: false`: **pack is suspended**. Skip all commit steps for this run. Do not stage or commit anything. You may inform the user: "auto-task-commit is disabled — use `/speckit.auto-task-commit.toggle on` to re-enable."

---

## Mandatory Rule: Commit on Task Completion

After you complete a task (mark a `- [ ]` checkbox as `- [x]` in `tasks.md`), you **MUST** run a git commit before proceeding to the next task. This rule is non-negotiable and cannot be skipped or deferred.

**Rule applies to**: every `speckit.implement` invocation when this pack is active.

---

## Step-by-Step: Committing After a Task

After marking a task complete, run these steps in order:

### Step 1 — Check for changes

```bash
git status --porcelain
```

- If the output is empty (nothing to commit): **skip this commit and continue to the next task**. Do not emit an error.
- If output is non-empty: proceed to Step 2.

### Step 2 — Stage all changes

```bash
git add -A
```

### Step 3 — Commit with generated message

```bash
git commit -m "<commit message>"
```

See [Commit Message Format](#commit-message-format) below.

**If the commit exits non-zero**: **halt immediately**. Do not proceed to the next task. Report the error to the user with the exact exit code and stderr output. Ask the user to resolve the issue before re-running `speckit.implement`.

---

## Commit Message Format

The commit message is auto-generated from the feature ID and the completed task's text.

**Format**: `feat(<featureId>): <taskText>`

| Token | Source | Example |
|-------|--------|---------|
| `<featureId>` | Directory name of `specs/<id>/` containing `tasks.md` | `001-peer-pack` |
| `<taskText>` | Text of the completed task line, stripped of the `- [x] ` prefix and trimmed | `add provider validation` |

**Examples**:

```
feat(001-peer-pack): add JWT authentication middleware
feat(002-auto-task-commit): validate config at startup
```

**Extracting `featureId`**: Derive it from the resolved path of `tasks.md`:

```
specs/001-peer-pack/tasks.md  →  featureId = "001-peer-pack"
```

**Extracting `taskText`**: Take the completed task line and strip the leading `- [x] ` prefix (including any leading whitespace and the checkbox marker). Trim trailing whitespace. Do not include sub-items or annotations.

### Custom Template (optional)

If `.specify/auto-task-commit.yml` exists and contains `commit_message_template`, use that template instead of the default format.

Template variables: `{featureId}`, `{taskText}`

Example config:

```yaml
commit_message_template: "chore({featureId}): {taskText}"
```

---

## Granularity Configuration

By default, one commit is made per completed task (per-task mode).

If `.specify/auto-task-commit.yml` exists and `granularity: batch` is set, defer commits until after all tasks in the current batch are complete:

| `granularity` | Commit timing |
|---------------|---------------|
| `task` (default) | After each individual `- [x]` tick |
| `batch` | After all tasks in the current batch are ticked |

**Batch commit message**: Use the last completed task's text, or summarize: `feat(<featureId>): implement <N> tasks`.

---

## Loading Configuration

At the start of each `speckit.implement` invocation, check for `.specify/auto-task-commit.yml`:

```bash
test -f .specify/auto-task-commit.yml
```

- If absent: use defaults (`enabled: true`, `granularity: task`, default commit message template).
- If present: parse YAML and apply `enabled`, `granularity`, and `commit_message_template` values.
- If the file exists but is malformed: warn the user and fall back to defaults. Do not halt on config parse failure.

---

## Summary: Commit Checklist per Task

After each task tick (`- [x]`), run this checklist:

1. Check `enabled` in `.specify/auto-task-commit.yml` → skip everything if `false`
2. `git status --porcelain` → skip if empty (nothing to commit)
3. `git add -A`
4. `git commit -m "feat(<featureId>): <taskText>"` (or configured template)
5. If non-zero exit → **halt**, report error, wait for user

**Never proceed to the next task if a commit failed.**
