# Feature Specification: Spec Kit Peer Workflow Integration

**Feature Branch**: `001-peer-pack`
**Created**: 2026-03-27
**Status**: Draft
**Input**: User description: "Spec Kit Peer Workflow Integration"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adversarial Artifact Review (Priority: P1)

A developer working on a feature wants an independent critical review of one of their spec artifacts — spec, research, plan, or tasks — before moving to the next phase. They invoke `/speckit.peer.review <artifact>` naming the artifact they want reviewed. The peer agent examines the artifact against a rubric appropriate to its type, produces written feedback, and appends the round to a review file. If the artifact needs revision, the developer addresses the feedback and re-runs the command; each iteration adds a new round. The loop ends when the review resolves to `MOSTLY_GOOD` or `APPROVED`.

**Why this priority**: This is the primary value delivered by the `peer` pack. It replaces the informal practice of self-reviewing artifacts by introducing a structured adversarial pass backed by an AI provider. Without it, the extension has no purpose.

**Independent Test**: Can be fully tested by running `/speckit.peer.review plan` on a feature with an existing `plan.md` and verifying that a `plan-review.md` file is written to the `reviews/` subdirectory with at least one round and a status marker.

**Acceptance Scenarios**:

1. **Given** a feature with a valid `plan.md`, **When** the user runs `/speckit.peer.review plan`, **Then** the system writes `specs/<feature>/reviews/plan-review.md` containing at least one review round with a `NEEDS_REVISION`, `MOSTLY_GOOD`, or `APPROVED` status marker.
2. **Given** a review file already containing one round, **When** the user runs `/speckit.peer.review plan` again after making changes, **Then** the new round is appended to the existing file without overwriting previous rounds.
3. **Given** the user runs `/speckit.peer.review spec`, **Then** the review applies the spec rubric (scope, ambiguity, testability, missing edge cases), not the plan rubric.
4. **Given** the user runs `/speckit.peer.review tasks`, **Then** the system loads all four artifacts (spec.md, research.md, plan.md, tasks.md) before producing the cross-artifact readiness assessment.
5. **Given** a feature where `research.md` does not exist and the user runs `/speckit.peer.review tasks`, **Then** the system reports the missing artifact clearly and does not produce a partial review silently.

---

### User Story 2 - Cross-Artifact Readiness Gate (Priority: P2)

Before handing off to `/speckit.peer.execute`, a developer wants to verify the entire feature chain is consistent and complete. They run `/speckit.peer.review tasks`. The peer agent loads all four artifacts — spec, research, plan, and tasks — and produces a readiness assessment that flags missing coverage, dependency sequencing errors, missing test tasks, or plan-task misalignment. This is the authoritative gate before execution begins.

**Why this priority**: A tasks-level review is the strongest safeguard against wasted execution effort. It is the first command that requires all artifacts to be present, making it a natural quality gate. Without it, the execution story is incomplete.

**Independent Test**: Can be fully tested by running `/speckit.peer.review tasks` on a complete feature (all four artifacts present) and verifying that flagged issues accurately reflect genuine gaps introduced intentionally in the test fixture.

**Acceptance Scenarios**:

1. **Given** tasks that omit test coverage for a requirement, **When** the user runs `/speckit.peer.review tasks`, **Then** the review explicitly flags the missing test coverage.
2. **Given** tasks with an incorrect dependency order (Task B depends on Task A but is sequenced first), **When** the user runs `/speckit.peer.review tasks`, **Then** the review identifies the sequencing error.
3. **Given** a fully consistent and complete feature, **When** the user runs `/speckit.peer.review tasks`, **Then** the review returns `MOSTLY_GOOD` or `APPROVED` and does not mutate any source artifact files.

---

### User Story 3 - Orchestrated Batch Execution (Priority: P3)

A developer with an approved plan and tasks wants the peer agent to implement the feature in batches. They invoke `/speckit.peer.execute`. The extension reads the active feature's approved `plan.md` and `tasks.md`, selects the configured provider, and implements tasks in batches. After each batch it performs a review/fix loop. As tasks are completed, their checkboxes in `tasks.md` are marked. Execution progress and code review rounds are recorded in `reviews/code-review.md`.

**Why this priority**: Orchestrated execution is the payoff of the entire review chain but depends on P1 and P2 being solid first. A working implementation that is not yet fully polished is still deliverable.

**Independent Test**: Can be tested by running `/speckit.peer.execute` on a feature with approved `plan.md` and `tasks.md`, verifying that at least one task checkbox is checked off in `tasks.md` and at least one review round appears in `code-review.md`.

**Acceptance Scenarios**:

1. **Given** approved `plan.md` and `tasks.md`, **When** the user runs `/speckit.peer.execute`, **Then** tasks are implemented in batches, each batch is followed by a code review round appended to `code-review.md`, and completed task checkboxes are updated in `tasks.md`.
2. **Given** a previously interrupted execution session, **When** the user re-runs `/speckit.peer.execute`, **Then** already-completed tasks are not re-executed.
3. **Given** a persisted provider session in `provider-state.json`, **When** `/speckit.peer.execute` is invoked for a subsequent round, **Then** the stored session is reused rather than starting a new one.
4. **Given** the stored session in `provider-state.json` is expired or invalid, **When** `/speckit.peer.execute` runs, **Then** a new session is started automatically without user intervention.

---

### User Story 4 - Provider Selection and Failure Isolation (Priority: P4)

A developer configures which AI provider backs the peer commands via `.specify/peer.yml`. In v1, only the Codex adapter is implemented. If they attempt to switch to a reserved but unimplemented provider (e.g., `--provider gemini`), the system fails clearly without disrupting the default Codex path.

**Why this priority**: Provider isolation is a correctness requirement; the extension works without multi-provider support in v1, making this the lowest priority while still being required to prevent silent failures.

**Independent Test**: Can be tested by invoking any peer command with `--provider gemini` and verifying a clear error message identifying the unimplemented adapter, then re-running with the default to confirm it still works.

**Acceptance Scenarios**:

1. **Given** `.specify/peer.yml` sets `default_provider: codex`, **When** any peer command is run without `--provider`, **Then** the Codex adapter is used.
2. **Given** the user runs any peer command with `--provider codex`, **Then** the Codex adapter is used regardless of `.specify/peer.yml`.
3. **Given** the user runs any peer command with `--provider gemini`, **Then** the system outputs a clear error message stating the adapter is not yet implemented and exits without performing any review or execution.
4. **Given** a request to an unsupported provider fails, **Then** no review files are written and the existing review history is not modified.

---

### Edge Cases

- What happens when a required artifact is missing for `/speckit.peer.review tasks` (e.g., `research.md` does not exist)?
- What happens when the review loop repeatedly returns `NEEDS_REVISION` — is there a maximum round limit per session?
- How does the system handle a `/speckit.peer.execute` session interrupted mid-batch: are partial file writes preserved or rolled back?
- What happens when `provider-state.json` contains a session ID from a different feature or provider?
- What happens when a tasks review reveals the spec itself is wrong — which artifact takes precedence?
- What happens when the user invokes the same peer command twice concurrently?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to invoke `/speckit.peer.review` with any of four artifact targets: `spec`, `research`, `plan`, `tasks`.
- **FR-002**: Each review invocation MUST produce or update a review file at `specs/<feature>/reviews/<artifact>-review.md`.
- **FR-003**: Review rounds MUST be append-only; rounds are separated by `---` and new rounds are appended at the end of the file; no previous round may be overwritten or deleted.
- **FR-004**: Each artifact review round MUST conclude with a `Consensus Status:` line using one of: `NEEDS_REVISION`, `MOSTLY_GOOD`, or `APPROVED`. Each code review round (produced by `/speckit.peer.execute`) MUST conclude with a `Verdict:` line using one of: `NEEDS_FIX` or `APPROVED`.
- **FR-005**: `/speckit.peer.review tasks` MUST load all four artifacts (spec.md, research.md, plan.md, tasks.md) before producing its assessment; any missing artifact MUST be reported clearly before review proceeds.
- **FR-006**: Each artifact type MUST be reviewed against a type-specific rubric: spec (scope, ambiguity, testability, missing edge cases), research (decision quality, alternatives, unresolved blockers), plan (architecture, feasibility, sequencing), tasks (coverage, dependency order, missing test tasks, constitution alignment).
- **FR-007**: `/speckit.peer.execute` MUST read the active feature's approved `plan.md` and `tasks.md` before beginning execution.
- **FR-008**: `/speckit.peer.execute` MUST implement tasks in batches and perform a review/fix loop after each batch.
- **FR-009**: `/speckit.peer.execute` MUST mark completed task checkboxes in `tasks.md` and MUST NOT re-execute already-completed tasks on re-invocation.
- **FR-010**: `/speckit.peer.execute` MUST append code review rounds to `specs/<feature>/reviews/plan-review.md`, the same file used by `/speckit.peer.review plan`; artifact review rounds use the heading `## Round N — YYYY-MM-DD` while code review rounds use `## Code Review Round N — YYYY-MM-DD` to distinguish them within the shared file.
- **FR-011**: Provider selection MUST be configurable via `default_provider` in `.specify/peer.yml` and overridable per-invocation via `--provider <name>`.
- **FR-012**: Requesting a provider whose adapter is not implemented MUST produce a clear human-readable error message identifying the provider by name and exit without performing any review or code changes.
- **FR-013**: Provider session state MUST be persisted in `specs/<feature>/reviews/provider-state.json` keyed by provider and workflow type to enable session reuse across rounds.
- **FR-014**: The extension MUST NOT install any mandatory auto-hooks; any workflow nudge hooks added in future versions MUST be marked optional.
- **FR-015**: All peer commands MUST operate without modifying or disrupting the existing Spec Kit core lifecycle (specify, plan, tasks, implement).

### Key Entities

- **Artifact**: A named feature document — one of `spec`, `research`, `plan`, or `tasks` — located in the active feature's specs directory.
- **Review Round**: A single iteration of feedback appended to a review file, identified by round number, date, and a status marker (`NEEDS_REVISION`, `MOSTLY_GOOD`, or `APPROVED`).
- **Review File**: An append-only markdown file accumulating all review rounds for a given artifact. For the `plan` artifact and code execution, a single shared file is used (`reviews/plan-review.md`): artifact review rounds are headed `## Round N — YYYY-MM-DD`; code review rounds from `/speckit.peer.execute` are headed `## Code Review Round N — YYYY-MM-DD`. Other artifact review files follow the pattern `reviews/<artifact>-review.md`.
- **Provider**: An AI agent adapter (Codex in v1; Copilot and Gemini reserved as stubs) responsible for executing review and implementation tasks.
- **Provider State**: A JSON file at `specs/<feature>/reviews/provider-state.json` persisting session identifiers per provider and workflow type. For the Codex adapter, this stores the `session_id` value returned by the Codex skill script after each invocation, enabling multi-turn session continuity via `--session <id>`.
- **Peer Config**: A project-level configuration file at `.specify/peer.yml` declaring the default provider and which adapters are enabled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can invoke `/speckit.peer.review plan` and receive written feedback in a review file within a single prompt turn, with zero manual file manipulation required.
- **SC-002**: 100% of review rounds are preserved across multiple invocations — no prior round is overwritten in any scenario.
- **SC-003**: All five core test scenarios pass after a fresh `--dev` install of the `peer` pack: (1) review for each of the four artifact types produces an output file, (2) execute with session reuse skips completed tasks, (3) default provider is used when no flag is given, (4) `--provider codex` override works, (5) an unimplemented provider request fails with a clear error.
- **SC-004**: Requesting an unimplemented provider returns a human-readable error message identifying the provider by name and does not write or modify any review file.
- **SC-005**: Re-invoking `/speckit.peer.execute` on a partially-completed feature resumes from the next incomplete task — 0% of already-completed tasks are re-executed.
- **SC-006**: `/speckit.peer.review tasks` correctly identifies at least one genuine gap (missing test coverage or sequencing error) when such a gap is deliberately present in a test fixture.

## Assumptions

- V1 delivers only the Codex adapter; Copilot and Gemini entries in `.specify/peer.yml` are configuration stubs and do not require implementation.
- The core Spec Kit lifecycle (specify → plan → tasks → implement) is not modified by this extension; the peer pack is purely additive.
- Users invoke all peer commands explicitly; no peer workflow step is triggered automatically or blocks the standard workflow.
- If a provider session expires, automatic fallback to a new session is acceptable with no data loss for completed review rounds.
- **Execution model**: The peer workflow follows an orchestrator/executor split. The orchestrating agent (the one running the peer commands — typically Claude) directs, reviews, and iterates; the executor agent (the configured provider) implements and fixes. Any capable LLM pair is acceptable for this split. Codex is the recommended executor for review and implementation tasks because of its rational, strict evaluation style and code-focused reasoning, but the design does not mandate a specific orchestrator or preclude other executor adapters.
- **Codex adapter dependency**: The `peer` pack's Codex adapter requires the `/codex` skill to be installed. Users who do not already have it must install it before Codex-backed commands will work. The skill is available at: `https://skills.sh/oil-oil/codex/codex`. The `peer` pack does not bundle or vendor the codex skill; it is an explicit external prerequisite.
- The Codex adapter invokes the codex skill script at `~/.claude/skills/codex/scripts/ask_codex.sh`. Each call returns a `session_id` (stored in `provider-state.json`) and an `output_path` (the response file). Subsequent rounds pass `--session <id>` to resume the conversation thread, ensuring the executor retains prior review history without re-reading the entire codebase.
- For `/speckit.peer.execute`, the executor is responsible for updating task checkboxes in `tasks.md` (`- [ ]` → `- [x]`) at the end of each completed batch, upon instruction from the orchestrating command.
- Template additions for the optional preset (Decision Gaps, Open Questions, Coverage Notes sections) are out of scope for v1.
- The `peer` command namespace does not conflict with any existing Spec Kit core commands.
- A single active feature context is resolvable when peer commands are run; the Spec Kit feature selection mechanism handles disambiguation.
