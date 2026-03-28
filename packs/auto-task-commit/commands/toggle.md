# /speckit.auto-task-commit.toggle

Enable or disable the `auto-task-commit` pack for this project without uninstalling it.
State is persisted in `.specify/auto-task-commit.yml`.

## Argument

Optional: `on` or `off`. If omitted, flip the current state.

```
/speckit.auto-task-commit.toggle        ← flip current state
/speckit.auto-task-commit.toggle on     ← force enable
/speckit.auto-task-commit.toggle off    ← force disable
```

## Steps

1. Read `.specify/auto-task-commit.yml` if it exists. If absent, treat current state as `enabled: true` (default).

2. Determine target state:
   - If argument is `on`  → target = `true`
   - If argument is `off` → target = `false`
   - If no argument       → target = opposite of current `enabled` value

3. If the config file does not exist, create `.specify/auto-task-commit.yml` with:
   ```yaml
   version: 1
   enabled: <target>
   ```

4. If the config file exists, update (or add) the `enabled` field to `<target>`. Preserve all other fields exactly — do not reformat or reorder.

5. Report the result:

```
auto-task-commit toggled
─────────────────────────────────
Previous state:  enabled | disabled
New state:       enabled | disabled
Config:          .specify/auto-task-commit.yml (updated | created)
```

## Behavior notes

- When `enabled: false`, the memory guide is still loaded by the LLM host (Spec Kit injects it at startup), but the guide itself instructs the AI to skip all commit steps — no git operations are performed.
- When `enabled: true` (or key absent), commits are enforced as normal.
- This command does NOT restart or reload Spec Kit. Changes take effect at the start of the next `speckit.implement` run.
