# /speckit.auto-task-commit.status

Report the current configuration of the `auto-task-commit` pack for this project.

## Steps

1. Look for `.specify/auto-task-commit.yml` in the project root.

2. If the file exists, read it and report：
   - `granularity` (value found, or "task" default if key absent)
   - `commit_message_template` (value found, or default if key absent)
   - Confirm: "Config file found at .specify/auto-task-commit.yml"

3. If the file does not exist, report:
   - `granularity: task` (default)
   - `commit_message_template: feat({featureId}): {taskText}` (default)
   - Confirm: "No config file found — using defaults"

4. In both cases, confirm that the memory guide is active:
   - "auto-task-commit is active: git commits will be created after each task during speckit.implement"

## Output format

```
auto-task-commit status
─────────────────────────────────
Config:       .specify/auto-task-commit.yml (found | not found — using defaults)
Granularity:  task | batch
Template:     feat({featureId}): {taskText}
Status:       active — commits enforced after each speckit.implement task
```
