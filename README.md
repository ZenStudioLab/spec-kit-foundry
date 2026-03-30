# spec-kit-foundry

A multi-pack hub for [Spec Kit](https://github.com/oil-oil/spec-kit) — installable extensions that add adversarial peer review, orchestrated batch execution, and workflow helpers to any Spec Kit project.

## Packs

| Pack | Type | Commands | Status |
|------|------|----------|--------|
| `peer` | commands | `/speckit.peer.review`, `/speckit.peer.execute` | v1.0.0 |

---

## peer pack

Adds adversarial AI peer review and Codex-orchestrated batch task execution to your Spec Kit workflow.

### Commands

**`/speckit.peer.review <target>`**
If `<target>` is `spec`, `research`, `plan`, or `tasks`, submits that Spec Kit artifact to a Codex peer reviewer and appends a structured review round (issues, severity labels, consensus status) to `specs/<feature>/reviews/<artifact>-review.md`.

If `<target>` is an existing file path, the command delegates to `/plan-review <file>` instead of running the peer pack artifact workflow.

In file-path delegation mode, `--provider` and `--feature` are ignored.

Supported artifact targets: `spec`, `research`, `plan`, `tasks`

Example file-path delegation:
```bash
/speckit.peer.review docs/plans/refining-agent-for-codex-invocation.md
```

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

## Prerequisites

**1. Spec Kit CLI**
```bash
specify --version
```

**2. Codex skill** (once per machine)
```bash
skills install https://skills.sh/oil-oil/codex/codex
test -x ~/.claude/skills/codex/scripts/ask_codex.sh && echo "OK"
```

**3. `/plan-review` availability** (only for explicit file-path targets)

File-path delegation relies on an existing `/plan-review` skill or command in the host environment. The `peer` pack does not bundle it.

---

## Installation

### Install just the peer pack

**From a tagged release:**
```bash
specify extension add --from https://github.com/ZenStudioLab/spec-kit-foundary/releases/download/v1.0.0/peer.zip
```

**From local clone (dev / monorepo):**
```bash
specify extension add --dev /path/to/spec-kit-foundary/packs/peer
```

Verify:
```bash
specify extension list
# peer  1.0.0  commands: review, execute
```

### Configure in your project

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
| `plan-review not found` | Install or enable the host `/plan-review` skill before using file-path targets |
| `Plan has no approved review` | Run `/speckit.peer.review plan` first |
| `Tasks readiness not approved` | Run `/speckit.peer.review tasks` and resolve findings |
| `Provider 'x' is disabled` | Set `enabled: true` in `peer.yml` or use `default_provider: codex` |
| `Provider 'copilot' has no adapter` | Use `codex` — copilot/gemini are unimplemented in v1 |

---

## Repo layout

```
packs/
  peer/
    extension.yml               ← pack manifest
    commands/
      review.md                 ← /speckit.peer.review instruction file
      execute.md                ← /speckit.peer.execute instruction file
    memory/
      peer-guide.md             ← workflow reference (injected by Spec Kit)
shared/
  providers/
    codex/
      adapter-guide.md          ← Codex invocation contract
  schemas/
    peer-providers.schema.yml   ← validation schema for peer.yml
scripts/
  validate-pack.sh              ← 14-case acceptance gate (< 5 s)
```

---

## Development

Run the acceptance gate tests:

```bash
bash scripts/validate-pack.sh
# [PASS] All 14 base artifact/execute matrix cases passed
```

Delegated file-path review is validated separately because it depends on a host-provided `/plan-review` skill/command and must assert the absence of peer-state writes.

Run a single case:
```bash
bash scripts/validate-pack.sh --case T-10a
```
