<!--
Sync Impact Report
==================
Version change: N/A → 1.0.0 (initial ratification)
Modified principles: N/A — initial creation
Added sections:
  - Core Principles (I–VI)
  - Technical Standards
  - Development Workflow
  - Governance
Removed sections: N/A
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ — Constitution Check gates populated
  - .specify/templates/spec-template.md ✅ — no structural changes required; principles
    referenced through Constitution Check in plan-template.md
  - .specify/templates/tasks-template.md ✅ — no structural changes required; pack
    lifecycle phases align with existing Phase 1–3 model
  - .specify/templates/agent-file-template.md ✅ — no agent-specific name conflicts; template
    already uses generic PROJECT NAME placeholder
Follow-up TODOs: None — all fields resolved from original-plan.md context
-->

# spec-kit-foundry Constitution

## Core Principles

### I. Pack Modularity

Every pack under `packs/` MUST be independently installable as a valid Spec Kit extension
payload using `--dev` or a release asset ZIP. Packs MUST NOT depend on sibling packs at
runtime; shared behavior MUST live in `shared/`. The root bundle is an assembled aggregate
and MUST NOT contain logic that does not originate in a pack. Pack boundaries are the
primary unit of design, testing, and release.

**Rationale**: Modularity guarantees that users who install only one pack receive a complete,
correct experience without side-effects from other packs. It also isolates the blast radius
when a single pack changes.

### II. Code Quality & Immutability

All shell scripts, YAML configurations, and template files MUST:

- Contain a single, clearly stated responsibility (high cohesion, low coupling).
- Use immutable data patterns — scripts MUST NOT mutate shared state in place;
  transformations MUST produce new output artifacts, never overwrite inputs.
- Stay focused: scripts ≤ 200 lines, YAML manifests ≤ 100 lines. Exceeding these limits
  requires explicit justification in the Complexity Tracking table of the relevant plan.
- Use explicit error handling — every failure path MUST exit non-zero and emit a
  human-readable message to stderr.

**Rationale**: Readable, immutable artifacts are easier to validate, diff, and review in
automated CI pipelines. Explicit errors surface issues at build time rather than silently
corrupting installs.

### III. Test-First (NON-NEGOTIABLE)

All new packs and features MUST follow Red-Green-Refactor:

1. Write validation/test scripts first (`scripts/validate-pack.sh` covers the scenario).
2. Confirm the test fails against a broken or absent artifact.
3. Implement until the test passes.
4. Refactor without breaking the test.

The following scenarios MUST be covered before any pack is merged to `main`:

- Root install via `--dev` succeeds and assembles the aggregate bundle cleanly.
- Each `packs/*` directory installs cleanly via `--dev`.
- Each release asset ZIP installs as the named pack without filename collisions.
- `peer` commands appear and execute correctly after install.
- Preset packs install only memory/templates and introduce no command conflicts.
- Unsupported providers fail with a clear, actionable error while leaving the Codex
  adapter fully functional.

**Rationale**: Spec Kit extensions are consumed by AI agents; silent install failures
produce subtle, hard-to-trace misbehavior. Test-first ensures correctness is verified
before distribution.

### IV. User Experience Consistency

All user-facing interfaces MUST be consistent across packs:

- Command names MUST follow the pattern `speckit.<pack>.<verb>`
  (e.g., `speckit.peer.review`, `speckit.peer.execute`).
- Install instructions MUST work identically for `--dev` (local path) and `--from`
  (remote ZIP) flows.
- Error messages MUST be actionable: state what failed, why, and how to resolve it.
- The README MUST document root install, per-pack install, `--dev` workflows, and pack
  type classifications in a single scannable reference table.
- Preset packs MUST NOT surface commands; they MUST surface only memory and templates.

**Rationale**: Inconsistent naming or install behavior forces users to re-read docs for
every pack. Consistency reduces cognitive load and eliminates a class of support requests.

### V. Performance & Reliability

Build and validation operations MUST meet these thresholds:

- `validate-pack.sh` for any single pack MUST complete in under 5 seconds on a standard
  developer machine.
- `build-all.sh` for the full foundry MUST complete in under 60 seconds.
- Release asset ZIPs MUST contain only the files belonging to that pack — zero cross-pack
  file leakage is permitted.
- The aggregate build MUST produce zero filename collisions; `build-all.sh` MUST fail
  loudly and non-zero when a collision is detected.

Provider reliability:

- The Codex adapter MUST remain functional regardless of the enabled/disabled state of
  other provider adapters.
- Provider initialization failures MUST be isolated to the failing provider and MUST NOT
  crash or degrade unrelated pack features.

**Rationale**: Fast, predictable tooling keeps the development loop tight. Collision
detection prevents silent overwrite bugs from escaping into the aggregate bundle.

### VI. Simplicity & YAGNI

Contributions MUST NOT add abstraction, configuration, or generalization for hypothetical
future requirements:

- Copilot and Gemini provider adapters are intentionally reserved in config and MUST
  remain unimplemented until a concrete, approved use case exists.
- New packs MUST NOT be added to the foundry without an approved spec documenting a
  concrete user need.
- The `shared/` directory MUST contain only utilities actively consumed by two or more
  packs; single-use utilities belong in the pack that uses them.

**Rationale**: Unused code is a maintenance liability and a confusion vector for
contributors and the AI agents consuming these packs. Every abstraction MUST earn its place.

## Technical Standards

All extension manifests (`extension.yml`) MUST conform to this structure:

```yaml
# Required fields
id: <pack-id>       # must match the directory name under packs/
name: <human name>
version: <semver>
provides:
  commands: []      # list of command IDs; empty list for preset packs
  memory: []        # list of memory file paths relative to the pack root
  templates: []     # list of template file paths relative to the pack root
# Optional
hooks: []           # before_*/after_* hook definitions
```

Provider configuration MUST use the schema defined in `shared/schemas/providers.yml`.
The `default_provider` field MUST always resolve to an enabled adapter; `build-all.sh`
MUST validate this constraint at build time.

The pack index at the repo root MUST be kept in sync with the actual directories under
`packs/`. `build-all.sh` MUST fail if the index references a non-existent pack directory
or if a pack directory is absent from the index.

## Development Workflow

1. **Design**: Open a spec in `specs/` documenting the pack's user stories and acceptance
   scenarios before writing any script or YAML.
2. **Constitution Check** (GATE — required before Phase 0 research and re-checked after
   Phase 1 design):
   - Does this pack have a single, clearly stated responsibility? (Principle I)
   - Are test scenarios defined for all mandatory install/behavior cases? (Principle III)
   - Do all command names follow `speckit.<pack>.<verb>`? (Principle IV)
   - Does this pack introduce any unused abstraction or unimplemented provider stub
     beyond what is already reserved? (Principle VI)
3. **Validate first**: Run `scripts/validate-pack.sh <pack-dir>` before opening a PR.
4. **Build verification**: Run `scripts/build-all.sh` locally to confirm zero collisions
   before pushing a release branch.
5. **Release checklist**: Every tagged release MUST produce all named release assets
   (`foundry.zip`, `peer.zip`, `gates.zip`, `preset-zen.zip`, `preset-strict.zip`) via
   the `.github/workflows/release.yml` GitHub Actions workflow.

## Governance

This constitution supersedes all other documented practices for the spec-kit-foundry
project. When conflicts arise between this document and other guidance (READMEs, inline
comments, PR descriptions), this constitution takes precedence.

**Amendment procedure**:

- PATCH bumps (wording, clarifications): any maintainer may merge after one reviewer
  approval.
- MINOR bumps (new principle or section added): requires a spec documenting the rationale
  and a completed impact assessment against existing packs.
- MAJOR bumps (removal or redefinition of an existing principle): requires consensus from
  all active maintainers plus a written migration plan for affected packs.

**Versioning policy**: Follows semantic versioning. The version line MUST be updated on
every amendment. `LAST_AMENDED_DATE` MUST be set to the merge date of the amending PR.

**Compliance review**: Every PR touching `packs/`, `scripts/`, `shared/`, or any
`extension.yml` MUST include a Constitution Check section verifying adherence to
Principles I–VI. PRs that cannot satisfy a principle MUST document the exception in a
Complexity Tracking table with justification.

**Version**: 1.0.0 | **Ratified**: 2026-03-26 | **Last Amended**: 2026-03-26
