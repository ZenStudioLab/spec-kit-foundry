# Quickstart: Spec Kit Peer Workflow Integration

**Pack**: `peer` · **Version**: 1.0.0

---

## Prerequisites

Before installing the peer pack, ensure the following are available:

### 1. Spec Kit (`specify` CLI)

The peer pack is an extension for Spec Kit. If you haven't initialized a Spec Kit project yet:

```bash
# Check if specify is available
specify --version
```

If `specify` is not installed, follow the Spec Kit setup guide for your project.

### 2. The `/codex` Skill

The peer pack uses Codex as its default review and execution provider. Install the skill once per machine:

```bash
# Install the codex skill
skills install https://skills.sh/oil-oil/codex/codex
```

Verify installation:
```bash
ls ~/.claude/skills/codex/scripts/ask_codex.sh
```

The file must exist and be executable for peer commands to function.

---

## Step 1: Install the Peer Pack

From your project root (or from the Spec Kit extension registry):

```bash
# Install from local path (development / monorepo use)
specify extension add peer --dev /path/to/spec-kit-foundry/packs/peer

# Install from registry (once published)
specify extension add speckit-peer
```

Verify:
```bash
specify extension list
# peer  1.0.0  commands: review, execute
```

---

## Step 2: Create Peer Configuration

Create `.specify/peer.yml` in your project root:

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

Only `codex` is implemented in v1. Leave `copilot` and `gemini` as `enabled: false` — they are stubs reserved for future releases.

---

## Step 3: Review Your First Artifact

Run a peer review on any Spec Kit artifact. Start with the spec once it exists:

```bash
/speckit.peer.review spec
```

Or review the plan after `/speckit.plan` has generated it:

```bash
/speckit.peer.review plan
```

The command will:
1. Load the artifact from `specs/<feature>/<artifact>.md`
2. Invoke Codex to produce a detailed review with severity-labelled issues
3. Append the round to `specs/<feature>/reviews/<artifact>-review.md`
4. Apply revisions to the artifact and re-review until `APPROVED`

---

## Step 4: Run Batch Execution

Once the plan is reviewed and `APPROVED` (or `MOSTLY_GOOD`), run the executor:

```bash
/speckit.peer.execute
```

The command will:
1. Verify the plan review has an approved round (readiness gate)
2. Read `plan.md` + `tasks.md` for context
3. Dispatch unchecked tasks to Codex in coherent batches
4. Have Codex mark `- [ ]` checkboxes as `- [x]` after each batch
5. Produce code review rounds and loop until `APPROVED`

All execution is performed by Codex. Claude orchestrates and code-reviews but **never writes implementation files**.

---

## Typical Workflow

```
1. /speckit-specify          → Create spec.md
2. /speckit.peer.review spec → Peer-review the spec (optional but recommended)
3. /speckit.plan             → Generate plan.md + tasks.md
4. /speckit.peer.review plan → Peer-review the plan (required before execute)
5. /speckit.peer.execute     → Implement tasks with Codex
```

---

## Artifacts Produced

After a full peer review + execute cycle for a feature:

```
specs/<featureId>/
├── spec.md                       (reviewed, revised)
├── plan.md                       (reviewed, revised)
├── tasks.md                      (checkboxes completed by executor)
└── reviews/
    ├── spec-review.md            (append-only, N rounds)
    ├── plan-review.md            (plan review rounds + code review rounds)
    └── provider-state.json       (session continuity per provider/workflow)
```

---

## Troubleshooting

**"peer.yml not found"**
→ Create `.specify/peer.yml` as shown in Step 2.

**"Codex skill not found at ~/.claude/skills/codex/scripts/ask_codex.sh"**
→ Run `skills install https://skills.sh/oil-oil/codex/codex` and re-try.

**"Plan has no approved review"**
→ Run `/speckit.peer.review plan` before `/speckit.peer.execute`. The readiness gate requires at least one `MOSTLY_GOOD` or `APPROVED` plan review round.

**"Provider 'copilot' has no adapter"**
→ Only `codex` is implemented in v1. Use `default_provider: codex` in peer.yml.

---

## Overriding the Provider

Use the `--provider` flag to override `default_provider` for a single invocation:

```bash
/speckit.peer.review plan --provider codex
/speckit.peer.execute --provider codex
```

In v1, any provider other than `codex` will fail the adapter check. This flag is forward-compatible — once a new provider adapter lands, it becomes usable without config changes.
