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
test -x ~/.claude/skills/codex/scripts/ask_codex.sh && echo "codex skill OK"
```

The file must exist and be executable for peer commands to function.

---

## Step 1: Install the Peer Pack

From your project root (or from the Spec Kit extension registry):

```bash
# Install from local path (development / monorepo use)
specify extension add peer --dev /absolute/path/to/<repo>/packs/peer

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
version: 1
default_provider: codex
max_rounds_per_session: 10
max_context_rounds: 3
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

Only `codex` is implemented in v1. Leave `copilot` and `gemini` as `enabled: false` — they are stubs reserved for future releases.
`max_rounds_per_session` bounds session drift; `max_context_rounds` controls how many prior rounds are sent as context each invocation.

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

Run peer commands from the target feature context so feature resolution is unambiguous.

The command will:
1. Load the artifact from `specs/<feature>/<artifact>.md`
2. Invoke Codex to produce a detailed review with severity-labelled issues
3. Append the round to `specs/<feature>/reviews/<artifact>-review.md`
4. Return a `Consensus Status` (`NEEDS_REVISION`, `MOSTLY_GOOD`, `APPROVED`, or `BLOCKED`)
5. If status is not acceptable, revise the artifact and re-run the same review command

---

## Step 4: Run Batch Execution

Once the plan review is `APPROVED` (or `MOSTLY_GOOD`), run the executor. For stronger cross-artifact safety, run `/speckit.peer.review tasks` first and resolve major findings before execution.

```bash
/speckit.peer.execute
```

The command will:
1. Verify the plan review has an approved round (readiness gate)
2. Optionally use the tasks review as a cross-artifact readiness checkpoint before execution
3. Read `plan.md` + `tasks.md` for context
4. Dispatch unchecked tasks to Codex in coherent batches
5. Have Codex mark `- [ ]` checkboxes as `- [x]` after each batch
6. Produce code review rounds and loop until `APPROVED`

All execution is performed by Codex. Claude orchestrates and code-reviews but **never writes implementation files**.

---

## Typical Workflow

```
1. /speckit-specify          → Create spec.md
2. /speckit.peer.review spec → Peer-review the spec (optional but recommended)
3. /speckit.plan             → Generate plan.md + tasks.md
4. /speckit.peer.review plan → Peer-review the plan (required before execute)
5. /speckit.peer.review tasks → Cross-artifact readiness gate before execute
6. /speckit.peer.execute     → Implement tasks with Codex
```

---

## Artifacts Produced

After a full peer review + execute cycle for a feature:

```
specs/<featureId>/
├── spec.md                       (reviewed, optionally revised)
├── research.md                   (reviewed, optionally revised)
├── plan.md                       (reviewed, optionally revised)
├── tasks.md                      (checkboxes completed by executor)
└── reviews/
    ├── spec-review.md            (if spec was reviewed)
    ├── research-review.md        (if research was reviewed)
    ├── tasks-review.md           (if tasks readiness was reviewed)
    ├── plan-review.md            (plan review rounds + code review rounds)
    └── provider-state.json       (session continuity per provider/workflow)
```

`provider-state.json` and any `*.bak.*` recovery files are runtime state and are typically ignored by VCS.

---

## Troubleshooting

**"peer.yml not found"**
→ Create `.specify/peer.yml` as shown in Step 2.

**"Codex skill not found at ~/.claude/skills/codex/scripts/ask_codex.sh"**
→ Run `skills install https://skills.sh/oil-oil/codex/codex` and re-try.

**"Plan has no approved review"**
→ Run `/speckit.peer.review plan` before `/speckit.peer.execute`. The readiness gate requires at least one `MOSTLY_GOOD` or `APPROVED` plan review round.

**"Tasks readiness not reviewed / not good enough"**
→ Run `/speckit.peer.review tasks` and address any `NEEDS_REVISION` or `BLOCKED` outcomes before execution.

**"Provider '<name>' is disabled in .specify/peer.yml"**
→ Set `enabled: true` for that provider, or use `default_provider: codex`.

**"Provider 'copilot' has no adapter"**
→ The provider is configured/enabled but unimplemented. In v1, use `codex`.

**"Provider output missing Consensus Status / Verdict"**
→ This is a parse-sensitive output failure. Keep the existing review history append-only, then re-run the same command (and same provider/session if applicable).

---

## Overriding the Provider

Use the `--provider` flag to override `default_provider` for a single invocation:

```bash
/speckit.peer.review plan --provider codex
/speckit.peer.execute --provider codex
```

In v1, provider selection is checked in order: configured → enabled → adapter implemented. `codex` is the only implemented adapter today. This flag is forward-compatible — once a new provider adapter lands and is enabled, it becomes usable without changing command shape.
