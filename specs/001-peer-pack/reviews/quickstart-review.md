# Quickstart Review: Spec Kit Peer Workflow Integration
**Quickstart File**: specs/001-peer-pack/quickstart.md
**Reviewer**: Codex

---
## Round 1 — 2026-03-27
### Overall Assessment
`quickstart.md` is readable and usable as a first-run guide, but it is not yet fully consistent with the current `spec.md`, `plan.md`, `data-model.md`, and command contracts. The main risks are configuration/schema drift, readiness-gate flow ambiguity, and a few provider/error-path statements that can mislead users during setup or troubleshooting. It needs a focused sync pass before being considered implementation-safe documentation.
**Rating**: 7.6/10

### Issues
#### Issue 1 (High): `.specify/peer.yml` example is missing required `version`
**Location**: `quickstart.md` Step 2 config snippet (lines 64-74)
The example omits `version: 1`, but both plan and data model treat version as a startup validation gate and schema discriminator.
**Suggestion**: Add `version: 1` at the top of the Step 2 YAML snippet and mention that missing/unknown versions fail startup validation.

#### Issue 2 (Medium): Session/context controls are omitted from config example
**Location**: `quickstart.md` Step 2 config snippet (lines 64-74)
The quickstart sample excludes `max_rounds_per_session` and `max_context_rounds`, which are part of the documented peer config behavior and influence session resets/token budget.
**Suggestion**: Include both fields with documented defaults (`10`, `3`) in the sample and add a one-line explanation of what each controls.

#### Issue 3 (Medium): Stub provider entries are underspecified vs documented schema pattern
**Location**: `quickstart.md` Step 2 config snippet (lines 70-73)
`copilot` and `gemini` stubs omit `mode: orchestrated`, while canonical examples include mode for all providers.
**Suggestion**: Add `mode: orchestrated` to stub providers in the sample for schema consistency and future adapter readiness.

#### Issue 4 (Medium): Local install path example uses a repository name that does not match this project
**Location**: `quickstart.md` Step 1 install command (line 46)
The command uses `/path/to/spec-kit-foundry/...`, but this repository is `spec-kit-foundary`; copy-paste users may fail installation immediately.
**Suggestion**: Correct the path placeholder to match the actual repo naming used in this project, or replace with a neutral placeholder like `/absolute/path/to/<repo>/packs/peer`.

#### Issue 5 (Low): Codex prerequisite verification checks only existence, not executability
**Location**: `quickstart.md` Prerequisites (lines 31-36)
The guide says the file must be executable, but the verification command is `ls`, which does not validate execute bit.
**Suggestion**: Replace with an executable check, e.g. `test -x ~/.claude/skills/codex/scripts/ask_codex.sh && echo OK`.

#### Issue 6 (Medium): Review loop behavior is presented as always automatic, conflicting with spec narrative
**Location**: `quickstart.md` Step 3 behavior list (line 98)
It states the command will “Apply revisions ... and re-review until APPROVED,” while the spec’s user-story framing describes a user-driven revise-and-rerun loop.
**Suggestion**: Clarify behavior as orchestrator-driven iterative flow that may require user intervention depending on environment/policy, and align wording with spec expectations.

#### Issue 7 (High): Execute readiness gate is documented as plan-only, but spec defines tasks review as authoritative cross-artifact gate
**Location**: `quickstart.md` Step 4 intro and gate text (lines 104, 111)
The quickstart gate only references plan review, while the spec defines `/speckit.peer.review tasks` as the cross-artifact readiness gate before execution.
**Suggestion**: Add explicit prerequisite: run `/speckit.peer.review tasks` and require at least `MOSTLY_GOOD`/`APPROVED` before execution in the recommended path.

#### Issue 8 (High): Typical workflow omits `/speckit.peer.review tasks`
**Location**: `quickstart.md` Typical Workflow (lines 123-129)
The canonical sequence jumps from plan review directly to execute, missing the tasks-level review story and reducing alignment with P2/FR-005 intent.
**Suggestion**: Insert ` /speckit.peer.review tasks` before execute, with a note that this is the authoritative readiness check for cross-artifact consistency.

#### Issue 9 (Medium): “Artifacts Produced” omits expected review files for full peer workflow
**Location**: `quickstart.md` Artifacts Produced tree (lines 137-146)
The output tree includes only `spec-review.md` and `plan-review.md`, omitting `research-review.md` and `tasks-review.md`, despite review command support for all artifact types.
**Suggestion**: Expand the tree to show all possible review files or clearly label the current tree as a minimal example path.

#### Issue 10 (Medium): Troubleshooting path for unimplemented provider is inconsistent with default disabled-provider behavior
**Location**: `quickstart.md` Troubleshooting (lines 161-163)
With the provided sample config (`copilot` disabled), users are likely to hit a disabled-provider error before adapter-not-implemented. Current text can misdirect debugging.
**Suggestion**: Split troubleshooting into two cases: (a) provider disabled, (b) provider enabled but adapter missing/unimplemented.

#### Issue 11 (Medium): Provider override section overstates failure mode
**Location**: `quickstart.md` Overriding the Provider (line 175)
“Any provider other than codex will fail the adapter check” is too narrow; failures can occur earlier at provider-enabled validation, and future adapters may be enabled progressively.
**Suggestion**: Rephrase to ordered checks: provider must be configured and enabled first, then adapter availability is checked.

#### Issue 12 (Suggestion): Missing prompt-contract troubleshooting guidance for parse failures
**Location**: `quickstart.md` Troubleshooting + Step 3/4 command expectations (lines 94-116, 150-163)
Given parse-sensitive contracts (`Consensus Status`/`Verdict` terminators), quickstart lacks a recovery note for malformed provider outputs, which is a practical prompt-engineering reliability concern.
**Suggestion**: Add a troubleshooting entry for parse failures that tells users to verify terminal status lines, preserve append-only history, and retry with the same command/session.

### Positive Aspects
- The document has a clear onboarding flow (prerequisites → install → config → review → execute).
- Core command names and high-level role separation are easy to understand.
- Troubleshooting section already addresses key first-run failures (missing config, missing skill, unimplemented provider).
- The artifacts tree helps users quickly understand where review/state outputs land.

### Summary
Top priorities are: (1) fix the config snippet/schema drift (`version` and config completeness), (2) align the documented readiness workflow to include the tasks-level review gate, and (3) correct provider failure-path guidance to match actual validation order. After those are fixed, `quickstart.md` should be close to production-ready.
**Consensus Status**: NEEDS_REVISION

---
## Round 2 — 2026-03-27
### Overall Assessment
The revised `quickstart.md` addressed nearly all Round 1 defects and is now much closer to the implementation contracts. Configuration accuracy, provider troubleshooting, and artifact/output documentation are substantially improved. Remaining issues are narrow and mostly about final cross-file alignment details rather than core workflow correctness.
**Rating**: 9.1/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | `.specify/peer.yml` missing `version` | RESOLVED | `version: 1` now present in Step 2 sample. |
| 2 | Missing session/context controls | RESOLVED | `max_rounds_per_session` and `max_context_rounds` added with explanation. |
| 3 | Stub providers missing `mode` | RESOLVED | `mode: orchestrated` now present for `copilot` and `gemini`. |
| 4 | Local install path mismatch | RESOLVED | Replaced with neutral absolute placeholder path. |
| 5 | Executability check weak (`ls`) | RESOLVED | Replaced with `test -x` verification command. |
| 6 | Review loop wording overstated automation | RESOLVED | Now describes status return + user re-run behavior. |
| 7 | Execute gate documented as plan-only | PARTIALLY_RESOLVED | Quickstart now includes tasks readiness gate, but contract-level enforcement remains plan-only. |
| 8 | Typical workflow omitted `review tasks` | RESOLVED | Tasks review step added before execute. |
| 9 | Artifacts tree omitted review files | RESOLVED | Tree now includes research/tasks review files with conditional notes. |
| 10 | Provider troubleshooting path inconsistent | RESOLVED | Disabled-provider and unimplemented-provider cases are now separated. |
| 11 | Provider override failure mode overstated | RESOLVED | Validation order is now documented correctly. |
| 12 | Missing parse-failure troubleshooting | RESOLVED | Added explicit parse-sensitive output troubleshooting guidance. |

### Issues
#### Issue 1 (Medium): Tasks readiness is presented as mandatory in quickstart, but execute contract still enforces only plan-review gate
**Location**: `quickstart.md` Step 4 (lines 111-119) vs `contracts/execute-command.md` Preconditions/Readiness Gate (plan-review only)
Quickstart now states tasks readiness must be at least `MOSTLY_GOOD`, which aligns with spec intent (P2), but the current execute contract only checks for approved/mostly-good plan review. This creates a remaining expectation mismatch for users.
**Suggestion**: Harmonize wording by either (a) updating execute contract to enforce tasks-review gate explicitly, or (b) rephrasing quickstart to “strongly recommended policy gate” until contract enforcement lands.

#### Issue 2 (Low): Feature resolution behavior is still undocumented in quickstart
**Location**: `quickstart.md` (no mention in Steps 3/4); cross-check `plan.md` Feature Resolution constraint
The plan defines feature resolution order (`cwd` spec dir → `--feature <id>` → disambiguation), but quickstart does not explain how users should run commands in multi-feature repos.
**Suggestion**: Add a short note under Steps 3/4: run commands from the target feature context or pass `--feature <id>` when ambiguity exists.

#### Issue 3 (Suggestion): Runtime state hygiene could be made explicit for operators
**Location**: `quickstart.md` Artifacts/Troubleshooting sections
The guide now lists `provider-state.json`, but it still does not mention that state/backups are runtime artifacts expected to be ignored by VCS per plan policy.
**Suggestion**: Add a one-line operator note that `specs/*/reviews/provider-state.json` and `*.bak.*` are runtime files and should remain ignored.

### Positive Aspects
- Round 1’s major correctness problems were fixed directly and accurately.
- The peer config snippet is now materially aligned with the current data model.
- The workflow now includes tasks-level readiness review, improving alignment with the intended peer process.
- Troubleshooting quality improved with clearer provider and parse-failure pathways.

### Summary
The document is now close to final quality. The only meaningful remaining gap is contract-level consistency around whether tasks readiness is a hard gate or a policy gate; once that is unified, quickstart can be considered fully implementation-safe.
**Consensus Status**: MOSTLY_GOOD

---
## Round 3 — 2026-03-27
### Overall Assessment
The final quickstart revision resolves the remaining Round 2 issues and is now aligned with the practical operating model in the companion artifacts. Setup, configuration, workflow sequencing, and troubleshooting now provide a coherent path for users without the earlier ambiguity. No unresolved material issues remain in `quickstart.md` for implementation handoff.
**Rating**: 9.7/10

### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Tasks readiness presented as mandatory vs contract plan-only gate | RESOLVED | Step 4 now frames tasks review as a stronger safety recommendation; readiness gate language is no longer contradictory. |
| 2 | Feature resolution behavior undocumented | RESOLVED | Quickstart now instructs running commands from target feature context to avoid ambiguity. |
| 3 | Runtime state hygiene not explicit | RESOLVED | Quickstart now documents `provider-state.json`/`*.bak.*` as runtime state typically ignored by VCS. |

### Issues
No unresolved material issues identified in this round.

### Positive Aspects
- Quickstart now includes a schema-complete peer config example aligned with data model expectations.
- Review and execute guidance reflects practical status-marker and troubleshooting behavior.
- Provider troubleshooting paths are clearly separated (disabled vs unimplemented vs parse-sensitive output issues).
- Artifact/output expectations are now explicit and operationally useful.

### Summary
`quickstart.md` is now implementation-ready from a documentation-consistency standpoint and can be used as the operator-facing guide for v1 peer workflows.
**Consensus Status**: APPROVED
