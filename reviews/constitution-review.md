# Constitution Review: spec-kit-foundry

**Constitution File**: `.specify/memory/constitution.md`
**Source Plan**: `docs/original-plan.md`
**Reviewer**: Codex

---

## Round 1 — 2026-03-26

### Overall Assessment

The constitution captures the spirit of the original plan adequately at the principle
level, but it collapses or omits several precise technical commitments from
`docs/original-plan.md` that are needed to make governance executable. The most critical
gaps are: (1) the "remote per-pack install uses release assets, not repo archive ZIPs"
distinction is absorbed into a generic UX principle and never stated as an architectural
rule; (2) the full test scenario set is reduced from 8 enumerated cases to 6, losing the
tagged-archive ZIP install scenario and the per-release-asset ZIP scenario as distinct
obligations; (3) the repo-level pack index YAML and provider config schema are buried in
Technical Standards with no enforcement mechanism connecting them to the governance
principles. Additionally, `spec-template.md`, `tasks-template.md`, and
`agent-file-template.md` show no constitution-specific propagation, relying on implicit
alignment that has never been verified. `README.md` is entirely absent.

**Rating**: 5/10

---

### Coverage Matrix

| Original Plan Commitment | Constitution Coverage | Template Coverage | Status | Notes |
|---|---|---|---|---|
| Published GitHub multi-pack hub, not a single extension repo | Implicit in Pack Modularity (I) | None | Partially Covered | Never stated explicitly; governance silent on repo structure as a constraint |
| Repo root is all-in-one installable aggregate bundle | Development Workflow §5 release checklist only | None | Partially Covered | Not a principle; not gated in Constitution Check |
| Every `packs/*` dir independently installable with `--dev` | Principle I | plan-template.md Constitution Check (I) | Fully Covered | |
| Remote per-pack install uses release asset ZIPs, NOT repo archive | Absent | None | Missing | Critical architectural constraint from plan; entirely absent from constitution |
| Pack model: `peer`, `gates`, `preset-zen`, `preset-strict`, `foundry` | Development Workflow §5 (asset names only) | None | Partially Covered | Named as release artifact list; never established as a governance constraint |
| Preset packs are memory/template-only, no commands | Principle IV bullet + Principle I | plan-template.md | Fully Covered | |
| Provider model: Codex first, Copilot/Gemini reserved/unimplemented | Principles V + VI | plan-template.md (VI gate) | Fully Covered | |
| `shared/providers/`, `shared/prompts/`, `shared/schemas/` directories | Technical Standards (schema reference) | None | Partially Covered | Only `shared/schemas/providers.yml` mentioned; `providers/` and `prompts/` absent |
| Build scripts: `validate-pack.sh`, `build-pack.sh`, `build-all.sh` | V (timing), Workflow §3-4 | None | Partially Covered | `build-pack.sh` never mentioned anywhere in constitution |
| `.github/workflows/release.yml` release workflow | Workflow §5 | None | Partially Covered | Named but with no governance obligations on what the workflow MUST do |
| Repo-level pack index YAML | Technical Standards (last paragraph) | None | Partially Covered | Defined as a constraint on `build-all.sh` but no enforcement hook in principles |
| Provider config schema (`shared/schemas/providers.yml`) | Technical Standards | None | Partially Covered | Referenced but schema structure not validated against original plan's YAML example |
| Release asset set: `foundry.zip`, `peer.zip`, `gates.zip`, `preset-zen.zip`, `preset-strict.zip` | Workflow §5 | None | Partially Covered | Listed in workflow step only; not a principle-level invariant |
| Test scenario 1: root `--dev` install | Principle III bullet 1 | None | Fully Covered | |
| Test scenario 2: root tagged archive ZIP install | **Absent** | None | **Missing** | Dropped from test obligation set in Principle III |
| Test scenario 3: each `packs/*` `--dev` install | Principle III bullet 2 | None | Fully Covered | |
| Test scenario 4: each release asset ZIP install | **Absent** | None | **Missing** | Collapsed into bullet 3 ("without filename collisions") — not the same requirement |
| Test scenario 5: `peer` commands working after install | Principle III bullet 4 | None | Fully Covered | |
| Test scenario 6: preset isolation / no command conflicts | Principle III bullet 5 | None | Fully Covered | |
| Test scenario 7: aggregate union / no filename collisions | Principle III bullet 3 + Principle V | None | Fully Covered | |
| Test scenario 8: unsupported provider failure isolation | Principle III bullet 6 + Principle V | None | Fully Covered | |
| Spec Kit `extension.yml` `provides.commands/memory/templates` | Technical Standards manifest block | None | Fully Covered | |
| `hooks` optional field | Technical Standards manifest block | None | Fully Covered | |
| `agents/` directory for agent variants | Absent | None | Missing | Mentioned in original plan repo layout; no governance coverage |
| README MUST document install methods and pack type table | Principle IV bullet | None | Partially Covered | README does not exist; constitution mandates it but has no enforcement |
| `build-pack.sh` individual pack build script | Absent | None | Missing | One of the three required scripts; never referenced |

---

### Issues

#### Issue 1 (Critical): Remote per-pack install model omitted

**Location**: Principle I, Principle IV, Technical Standards, Development Workflow

**Problem**: The original plan dedicates an entire section ("Install Model") to the
distinction that remote per-pack installs MUST use release asset ZIPs, not repo archive
ZIPs, because "GitHub archive ZIPs expose the whole repo root." This is an architectural
constraint with direct security and correctness implications. The constitution never
states this constraint.

**Evidence**: `docs/original-plan.md` §"Install Model": "Remote per-pack install should
use **release assets**, not the repo archive... because GitHub archive ZIPs expose the
whole repo root." This is a non-negotiable distribution rule, not a UX preference.

**Suggestion**: Add an explicit sub-rule to Principle I: "Remote per-pack installation
MUST target release asset ZIPs. Repo archive ZIPs MUST only be used for the root
all-in-one `foundry` install. Distributing a pack subdirectory via repo archive exposes
the entire repo root and is prohibited."

---

#### Issue 2 (Critical): Test scenarios 2 and 4 are missing from Principle III

**Location**: Principle III — mandatory scenario list (6 bullets)

**Problem**: The original plan defines 8 test scenarios. The constitution covers 6. The
two suppressed scenarios are materially distinct:
- Scenario 2: "Root install from tagged GitHub archive ZIP works as the all-in-one path."
  This tests a different code path than `--dev` (scenario 1); a bug in ZIP packaging
  would be invisible if only `--dev` is tested.
- Scenario 4: "Each release asset ZIP installs as the named pack." This tests the
  per-pack remote install path. It is entirely absent; bullet 3 only checks for filename
  collisions inside a ZIP, not that the ZIP installs correctly as a named pack.

**Evidence**: `docs/original-plan.md` §"Test Plan" items 2 and 4.

**Suggestion**: Add both as distinct mandatory bullets in Principle III:
- "Root install from a tagged GitHub archive ZIP installs the aggregate bundle cleanly
  (distinct from `--dev` path)."
- "Each release asset ZIP (`peer.zip`, `gates.zip`, `preset-zen.zip`, `preset-strict.zip`)
  installs as the correctly named pack via `--from`."

---

#### Issue 3 (High): `build-pack.sh` is entirely absent

**Location**: Development Workflow §3-4, Technical Standards, Sync Impact Report

**Problem**: The original plan lists three build scripts: `validate-pack.sh`,
`build-pack.sh`, and `build-all.sh`. The constitution references only `validate-pack.sh`
and `build-all.sh`. `build-pack.sh` — which builds/zips a single pack into a release
asset — is never mentioned. This creates a gap: there is no governance obligation on how
individual pack ZIPs are produced, which directly undermines the release asset integrity
requirements.

**Evidence**: `docs/original-plan.md` §"Repo Layout" lists `scripts/build-pack.sh`;
§"Release and Publishing" step 3 ("zip each pack as its own installable artifact")
requires per-pack zip logic.

**Suggestion**: Reference `build-pack.sh` in Development Workflow §4 and in the release
checklist in §5. Add a Technical Standards rule: "`build-pack.sh <pack-id>` MUST produce
a ZIP containing only files under `packs/<pack-id>/`, rooted at the pack directory, and
MUST be verifiable by `validate-pack.sh`."

---

#### Issue 4 (High): Named pack enumeration is absent from governance principles

**Location**: Principle I, Technical Standards

**Problem**: The original plan names the four concrete packs (`peer`, `gates`,
`preset-zen`, `preset-strict`) and the root bundle (`foundry`) explicitly. The
constitution only names them in the Workflow §5 release checklist as artifact names.
There is no governance principle establishing these as the canonical V1 pack set, meaning
future contributors have no constitutional basis to challenge a PR that adds or renames a
pack without a spec.

**Evidence**: `docs/original-plan.md` §"Pack Design" names all four packs with their
purpose, type, and contents. The "Important Interfaces" section includes the pack index
YAML showing all four by ID and type.

**Suggestion**: Add a statement to Principle I or Technical Standards: "The V1 foundry
comprises exactly these packs: `peer` (commands), `gates` (workflow), `preset-zen`
(preset), `preset-strict` (preset), and the root `foundry` aggregate. Adding, removing,
or renaming a pack requires a MINOR constitution amendment."

---

#### Issue 5 (High): `shared/providers/` and `shared/prompts/` are missing from Technical Standards

**Location**: Technical Standards — "Provider configuration MUST use the schema..."

**Problem**: The original plan defines `shared/` as containing three subdirectories:
`providers/codex/`, `prompts/`, and `schemas/`. The constitution only references
`shared/schemas/providers.yml`. The `providers/` and `prompts/` directories — where
provider adapter code and reusable prompt definitions live — have no governance coverage.
The Codex adapter implementation is mentioned in `providers/codex/` in the plan but has
no constitutional home.

**Evidence**: `docs/original-plan.md` §"Repo Layout": `shared/providers/codex/`,
`shared/prompts/`, `shared/schemas/`.

**Suggestion**: Expand Technical Standards to include: "The `shared/` directory MUST
maintain three canonical subdirectories: `providers/<adapter-id>/` for adapter
implementations, `prompts/` for reusable prompt libraries, and `schemas/` for YAML
schemas (including `providers.yml`). The Codex adapter MUST reside in
`shared/providers/codex/`."

---

#### Issue 6 (High): Repo-level pack index has no enforcement principle

**Location**: Technical Standards — last paragraph

**Problem**: The pack index is mentioned as a liveness constraint on `build-all.sh`, but
there is no principle establishing the index as a required artifact or specifying its
schema. A contributor could delete the index without violating any principle; the
constitution only says `build-all.sh` MUST validate it, not that the index MUST exist
with a specific schema.

**Evidence**: `docs/original-plan.md` §"Important Interfaces" provides the required YAML
structure for the pack index with `id`, `type`, and `path` fields per entry.

**Suggestion**: Move the pack index requirement into Technical Standards as a first-class
schema: "A `packs.yml` (or equivalent) pack index MUST exist at the repo root with
entries of the form `{id, type, path}` for every pack. Permitted `type` values are
`commands`, `workflow`, and `preset`. The index MUST be updated as part of any PR that
adds or removes a pack."

---

#### Issue 7 (High): Constitutional enforcement of `README.md` with no README in existence

**Location**: Principle IV — "The README MUST document..."

**Problem**: The constitution mandates that a README MUST exist and MUST document root
install, per-pack install, `--dev` workflows, and pack type classifications. However, no
`README.md` exists in the repository. The Sync Impact Report marks `agent-file-template.md`
as ✅ updated without verifying it, and does not flag the missing README as a follow-up
TODO. This is an internal inconsistency: the constitution creates a compliance obligation
that the project immediately violates upon ratification.

**Evidence**: `file_search` for `README.md` returns no results. Sync Impact Report says
"Follow-up TODOs: None."

**Suggestion**: Either (a) create a skeleton `README.md` as part of constitution
ratification, or (b) add a TODO in the Sync Impact Report: "README.md does not yet exist;
Principle IV is unmet until it is created. This is an open compliance gap." Also add to
Development Workflow: "README.md MUST be created and kept current before any pack is
merged to `main`."

---

#### Issue 8 (Medium): `agents/` directory has no governance coverage

**Location**: Entire constitution

**Problem**: The original plan repo layout includes `agents/` for "optional prebuilt
agent variants later." The constitution never references this directory. This is an
intentional v1 placeholder in the plan; its governance status is undefined — contributors
do not know whether adding content to `agents/` requires a spec, a constitution amendment,
or neither.

**Evidence**: `docs/original-plan.md` §"Repo Layout": `agents/   # optional prebuilt
agent variants later`.

**Suggestion**: Add a one-sentence note in Technical Standards or Principle VI: "The
`agents/` directory is reserved for future prebuilt agent variants. No content SHOULD be
added to it without an approved spec; adding the first agent variant requires a MINOR
amendment."

---

#### Issue 9 (Medium): Sync Impact Report makes false ✅ claims

**Location**: HTML comment Sync Impact Report at the top of `.specify/memory/constitution.md`

**Problem**: The Sync Impact Report marks four templates as ✅ updated:
- `spec-template.md` ✅ — "no structural changes required" — but the template has no
  pack-specific acceptance scenario structure, no mention of preset vs. command pack
  distinction, and no constitution-specific guidance. The claim of alignment is
  unverified.
- `tasks-template.md` ✅ — "pack lifecycle phases align" — but the template uses generic
  Python/web patterns (`src/models/`, `tests/integration/test_[name].py`) with no
  pack-aware structure. Alignment is assumed, not verified.
- `agent-file-template.md` ✅ — "no agent-specific name conflicts" — but the template
  still uses `[PROJECT NAME]` placeholder and "Auto-generated from all feature plans,"
  neither of which reflect spec-kit-foundry's pack-centric structure.

**Evidence**: Reviewing the actual template files shows no pack-specific content was
added during constitution ratification.

**Suggestion**: Correct the Sync Impact Report to reflect the actual status:
`spec-template.md ⚠ pending`, `tasks-template.md ⚠ pending`,
`agent-file-template.md ⚠ pending`. Add follow-up TODOs for each.

---

#### Issue 10 (Medium): Performance thresholds in Principle V are invented constraints

**Location**: Principle V — "validate-pack.sh MUST complete in under 5 seconds" and
"build-all.sh MUST complete in under 60 seconds"

**Problem**: The original plan contains no performance requirements for build or
validation scripts. These specific thresholds (5 s, 60 s) were invented by the
constitution authoring process without grounding in the plan. As governance, they create
compliance obligations that future contributors will struggle to justify or appeal, and
may be wrong for CI environments with slow runners.

**Evidence**: `docs/original-plan.md` §"Release and Publishing" and §"Test Plan" contain
zero performance budget statements for tooling.

**Suggestion**: Either (a) remove these thresholds entirely and reframe V as "Build and
validation operations MUST complete reliably and fail fast with actionable errors," or
(b) clearly mark them as provisional: "Target thresholds (to be validated against actual
CI runner performance): validate-pack.sh < 5 s per pack, build-all.sh < 60 s."

---

#### Issue 11 (Medium): YAML manifest schema is stricter than original plan

**Location**: Technical Standards — extension manifest YAML block

**Problem**: The constitution mandates `provides.commands` as a list of command IDs,
`provides.memory` as memory file paths, and `provides.templates` as template file paths.
The original plan's manifest example only specifies `provides.commands`,
`provides.memory`, `provides.templates` as top-level keys without enforcing that
`commands` must be an ID list vs. a descriptor list, and without mandating
`version: <semver>` as a required field. The constitution adds `version: <semver>` as a
required manifest field that the original plan does not require.

**Evidence**: `docs/original-plan.md` §"Important Interfaces": manifest fields listed are
`provides.commands`, `provides.memory`, `provides.templates`, `hooks` (optional) — no
`version` field.

**Suggestion**: Reconcile by either (a) removing `version` from the required manifest
fields and documenting it as optional/recommended, or (b) explicitly note the deliberate
addition: "The constitution adds `version: <semver>` as a required field beyond the
original plan to enable release tooling to validate pack versions independently."

---

#### Issue 12 (Low): Amendment approval threshold undefined

**Location**: Governance — "MAJOR bumps... requires consensus from all active maintainers"

**Problem**: "All active maintainers" is undefined. The project has no maintainer list,
no definition of "active," and no quorum rule. For a multi-contributor open-source
project, this creates an unresolvable governance deadlock if one maintainer becomes
inactive.

**Evidence**: No `MAINTAINERS.md` or equivalent file exists in the repository.

**Suggestion**: Define "active maintainer" (e.g., "any contributor who has merged a PR
in the last 6 months") or reference a `MAINTAINERS.md` file that the project MUST
maintain. Alternatively, define a minimum quorum (e.g., "at least 2 active maintainers").

---

#### Issue 13 (Low): `.specify/templates/commands/` absence not addressed

**Location**: Sync Impact Report, constitution-process compliance

**Problem**: The Spec Kit constitution workflow (SKILL.md) explicitly requires reviewing
"command files in `.specify/templates/commands/*.md`." No such directory exists in this
project. The Sync Impact Report does not acknowledge this absence or justify it. Since
`init-options.json` shows `ai_skills: false`, it is plausible the commands directory is
intentionally absent, but this should be explicitly stated.

**Evidence**: `list_dir(.specify/templates)` shows no `commands/` subdirectory.
`init-options.json` has `"ai_skills": false`.

**Suggestion**: Add a note to the Sync Impact Report: "`.specify/templates/commands/` is
absent because `ai_skills: false` in `init-options.json`. Constitution-process step 4
(command file review) is N/A for this project."

---

#### Issue 14 (Suggestion): Development Workflow §2 Constitution Check is incomplete

**Location**: Development Workflow §2 — Constitution Check bullet list

**Problem**: The inline Development Workflow Constitution Check (4 bullets) is less
comprehensive than the plan-template.md Constitution Check (6 checklist items). Principle
II (immutability/error handling), Principle IV (error message quality), and Principle V
(performance/collision detection) are checked in plan-template.md but absent from the
inline workflow check. A contributor reading only the constitution would not know to
verify those principles at the design gate.

**Evidence**: Compare `Development Workflow §2` (4 bullets: I, III, IV, VI) against
`plan-template.md` Constitution Check (6 checkboxes: I, II, III, IV, V, VI).

**Suggestion**: Add bullets for Principle II ("Do scripts stay within size limits and use
immutable patterns?") and Principle V ("Will build and validation meet performance
thresholds and zero-collision requirements?") to the inline Constitution Check in §2.

---

### Positive Aspects

- Principle I's statement that "shared behavior MUST live in `shared/`" and that "pack
  boundaries are the primary unit of design, testing, and release" faithfully distills the
  isolation model from the original plan.
- Principle VI correctly encodes the original plan's explicit "reserved but unimplemented"
  distinction for Copilot/Gemini adapters, avoiding the common failure mode of marking
  them TODO and then implementing them prematurely.
- The `extension.yml` manifest schema in Technical Standards is more actionable than the
  original plan's example because it clarifies that `commands: []` (empty list) is the
  correct preset encoding, not the absence of the key.
- The amendment versioning policy (PATCH/MINOR/MAJOR) maps cleanly to the types of
  changes this project will encounter and is at the right granularity for a small
  contributor team.
- The plan-template.md Constitution Check update is the single most valuable template
  propagation from this ratification: it gives future plan authors a concrete gate before
  they begin research.

---

### Summary

- **Top issue**: The remote per-pack install constraint (release asset ZIPs, not repo
  archive ZIPs) is absent from the constitution entirely, despite being a primary
  architectural rule in the original plan.
- **Second issue**: Two of the eight original test scenarios (tagged-archive ZIP install +
  per-release-asset ZIP install) are missing from Principle III, leaving gaps that would
  allow broken distribution paths to ship undetected.
- **Third issue**: The Sync Impact Report falsely marks three templates as ✅ updated when
  no pack-specific content was propagated to them.

**Consensus Status**: NEEDS_REVISION

---

## Round 2 — 2026-03-26

### Overall Assessment

Round 2 materially improves source fidelity at the constitution text level. The revised
constitution explicitly fixes most of the high-value Round 1 omissions: the remote
release-asset install rule is now stated, the missing test scenarios are restored,
`build-pack.sh` is governed, the V1 pack set is enumerated, `shared/providers/` and
`shared/prompts/` are covered, the pack index is elevated to a first-class requirement,
`agents/` is reserved explicitly, the commands-directory N/A case is acknowledged, and
the Sync Impact Report no longer falsely claims that the generic templates were updated.

That said, the revision still does not reach consensus. It now admits several propagation
gaps but leaves them unremediated, and it introduces new governance problems of its own:
(1) multiple newly mandated repo artifacts are still absent and not fully tracked as open
compliance gaps, (2) Principle II still contains invented and weakly enforceable
constraints, (3) Principle IV now conflicts with Principle I by claiming `--dev` and
`--from` install instructions "work identically" despite the constitution's own
distinction between repo-archive and release-asset flows, and (4) the new maintainer
quorum language creates a bootstrap deadlock for MAJOR amendments. The constitution is
closer to the source plan, but it is still not internally stable enough to ratify without
another revision.

**Rating**: 7/10

---

### Coverage Matrix

| Original Plan Commitment | Constitution Coverage | Template Coverage | Status | Notes |
|---|---|---|---|---|
| Published GitHub multi-pack hub, not a single extension repo | Still implicit, not stated in a principle | None | Partially Covered | Repo-hub framing remains in `docs/original-plan.md`, but the constitution still does not say this explicitly |
| Repo root is all-in-one installable aggregate bundle | Principle I + Workflow §6 root bundle language | None | Fully Covered | Now stated clearly enough as an aggregate bundle |
| Every `packs/*` dir independently installable with `--dev` | Principle I + Principle III | plan-template.md only | Fully Covered | |
| Remote per-pack install uses release asset ZIPs, NOT repo archive | Principle I remote install model | plan-template.md only | Fully Covered | Round 1 critical gap fixed |
| Pack model: `peer`, `gates`, `preset-zen`, `preset-strict`, `foundry` | Principle I V1 pack enumeration | None | Fully Covered | Round 1 gap fixed |
| Preset packs are memory/template-only, no commands | Principles IV + Technical Standards | plan-template.md only | Fully Covered | |
| Provider model: Codex first, Copilot/Gemini reserved/unimplemented | Principle VI + Technical Standards | plan-template.md only | Fully Covered | |
| `shared/providers/`, `shared/prompts/`, `shared/schemas/` directories | Technical Standards shared directory layout | None | Fully Covered | Round 1 gap fixed |
| Build scripts: `validate-pack.sh`, `build-pack.sh`, `build-all.sh` | Technical Standards + Workflow §3-4 | None | Fully Covered | Text coverage fixed, repo artifacts still absent |
| `.github/workflows/release.yml` release workflow | Workflow §6 | None | Partially Covered | Constitution requires it, but repository does not contain it |
| Repo-level pack index YAML | Technical Standards `packs.yml` section | None | Partially Covered | Constitution covers it, but repository does not contain it |
| README MUST document install methods and pack type table | Principle IV + Workflow §5 | None | Partially Covered | Now acknowledged as an open gap, but still unresolved |
| Test scenarios 1-8 | Principle III | plan-template.md only | Fully Covered | Round 1 omissions fixed |
| `agents/` directory reserved for future variants | Principle VI + Technical Standards note | None | Fully Covered | Round 1 gap fixed |
| Template propagation from constitution into spec/tasks/agent templates | Sync Impact Report acknowledges pending | spec-template.md / tasks-template.md / agent-file-template.md still generic | Missing | Gap now admitted but not remediated |

---

### Previous Round Tracking

| Round 1 Issue | Round 2 Status | Notes |
|---|---|---|
| 1. Remote per-pack install model omitted | Resolved | Principle I now states release-asset ZIPs for remote per-pack install and forbids repo-archive use for packs |
| 2. Test scenarios 2 and 4 missing | Resolved | Principle III now restores both tagged-archive root install and per-release-asset ZIP install |
| 3. `build-pack.sh` absent | Resolved | Technical Standards and Workflow now require `build-pack.sh` |
| 4. Named V1 pack enumeration absent | Resolved | Principle I now enumerates the V1 pack set explicitly |
| 5. `shared/providers/` and `shared/prompts/` missing | Resolved | Technical Standards now defines all three canonical `shared/` subdirectories |
| 6. Repo-level pack index lacked enforcement principle | Resolved | Technical Standards now requires a pack index and ties it to `build-all.sh` |
| 7. README obligation existed with no README / no follow-up TODO | Partially Resolved | The gap is now acknowledged, but `README.md` still does not exist |
| 8. `agents/` directory had no governance coverage | Resolved | Principle VI now reserves `agents/` and gates first use |
| 9. Sync Impact Report made false ✅ claims | Resolved | The three generic templates are now correctly marked pending |
| 10. Performance thresholds were invented constraints | Mostly Resolved | Thresholds are now explicitly provisional/advisory, though Principle V still adds non-source targets |
| 11. Manifest schema was stricter than the plan | Partially Resolved | `version` is now optional in-repo but still required for standalone release ZIPs without source-plan backing |
| 12. Amendment approval threshold undefined | Resolved, New Risk Introduced | "Active maintainer" and quorum are now defined, but the bootstrap logic creates a new deadlock issue |
| 13. `.specify/templates/commands/` absence not addressed | Resolved | Sync Impact Report now marks it N/A because `ai_skills=false` |
| 14. Workflow Constitution Check incomplete | Resolved | Workflow now includes Principles II and V gates inline |

---

### Issues

#### Issue 1 (Critical): Newly mandated baseline artifacts are still absent, and most are not tracked as open compliance gaps

**Location**: Sync Impact Report, Technical Standards, Development Workflow

**Problem**: The revised constitution now mandates several concrete repo artifacts as
existing requirements: `README.md`, root `extension.yml`, `packs.yml`,
`scripts/validate-pack.sh`, `scripts/build-pack.sh`, `scripts/build-all.sh`, and
`.github/workflows/release.yml`. The repository still contains only `.specify/`,
`.claude/commands/`, `docs/`, and `reviews/`. The Sync Impact Report acknowledges only
the missing README and pending template propagation, leaving the remaining missing MUST
artifacts untracked. This means the constitution claims a ratified baseline that the repo
does not currently satisfy.

**Evidence**: The current tree contains no `README.md`, no `extension.yml`, no
`packs.yml`, no `scripts/`, and no `.github/workflows/release.yml`. Technical Standards
and Workflow §§3-6 now say these artifacts MUST exist.

**Suggestion**: Either create the baseline artifacts as part of this ratification, or add
an explicit follow-up TODO for each missing MUST artifact and state that constitutional
compliance is not yet achieved until the baseline repo layout exists.

---

#### Issue 2 (High): Template propagation gaps are acknowledged but still materially unresolved

**Location**: Sync Impact Report; `.specify/templates/spec-template.md`;
`.specify/templates/tasks-template.md`; `.specify/templates/agent-file-template.md`

**Problem**: Round 2 correctly stops pretending these templates were updated, but it still
leaves them generic and structurally mismatched to the constitution. The constitution is
now pack-centric and install-path-centric; the templates remain generic feature/web-app
scaffolds. This is not a cosmetic gap. It means future specs and task lists will still be
generated without the pack lifecycle, release-asset validation, or pack-type distinctions
the constitution now requires.

**Evidence**: `spec-template.md` still has generic user stories with no prompt to capture
the 8 mandatory install/test scenarios or pack type. `tasks-template.md` still assumes
`src/`, `backend/`, `frontend/`, and Python test paths. `agent-file-template.md` remains
generic `[PROJECT NAME]` scaffolding with no pack-oriented structure.

**Suggestion**: Update the three templates now, or at minimum add an explicit blocker in
Governance or Workflow stating that constitution ratification is incomplete until these
templates propagate Principles I, III, IV, and VI into generated artifacts.

---

#### Issue 3 (High): README compliance gap remains open despite now being a constitutional MUST

**Location**: Principle IV; Development Workflow §5; Sync Impact Report TODOs

**Problem**: The revision acknowledges that `README.md` does not exist, but the gap is
still open. This is not a minor follow-up. The original plan explicitly required the
README to explain root install, per-pack install, `--dev` workflows, and pack type
classification. The constitution now repeats that obligation and even says no pack may be
merged before it exists. Ratifying the constitution without the README leaves the project
in immediate self-violation.

**Evidence**: `docs/original-plan.md` explicitly requires a README. The repo still has no
`README.md`. Development Workflow §5 says this is an "open compliance gap until
`README.md` is created."

**Suggestion**: Treat README creation as part of the same amendment, not a later cleanup.
If that is out of scope, downgrade the ratification claim and mark the repo as
non-compliant pending documentation completion.

---

#### Issue 4 (Medium): Principle II still introduces unsourced line-count limits as constitutional law

**Location**: Principle II — "scripts ≤ 200 lines, YAML manifests ≤ 100 lines"

**Problem**: The original plan never sets file-length ceilings. Round 1 flagged invented
constraints, and Round 2 only softened the performance budgets; it did not revisit these
size caps. These limits are now hard governance rules despite no source-plan basis and no
evidence that they fit this project. They also invite superficial file-splitting to
satisfy governance instead of improving design.

**Evidence**: `docs/original-plan.md` specifies layout, install model, release assets, and
tests, but contains no file-length requirements for scripts or YAML.

**Suggestion**: Move file-length heuristics out of the constitution and into contributor
guidance, or explicitly label them as deliberate governance additions beyond the original
plan with justification.

---

#### Issue 5 (Medium): Principle II's "immutable data patterns" rule is a category error for YAML and template files

**Location**: Principle II — "All shell scripts, YAML configurations, and template files MUST... use immutable data patterns"

**Problem**: The immutability rule is written as though YAML files and templates are
runtime data structures. They are not. A template file cannot meaningfully "use immutable
data patterns" in the same sense as a script. As written, the rule is not auditable and
will produce arbitrary interpretation during reviews.

**Evidence**: Principle II applies the same immutability test to shell scripts, YAML
configs, and template files without defining what immutable behavior means for static text
artifacts.

**Suggestion**: Narrow the immutability rule to build/assembly scripts and describe the
actual invariant: generated outputs must not destructively overwrite pack source inputs.
Remove YAML/template-file immutability language unless a precise, testable definition is
added.

---

#### Issue 6 (Medium): MAJOR amendment governance now has a bootstrap deadlock

**Location**: Governance — active maintainer definition; amendment procedure

**Problem**: The new governance text defines a minimum quorum of 2 active maintainers for
MAJOR votes, but then says that until `MAINTAINERS.md` exists, the project owner acts as
sole maintainer. Those two statements together mean a MAJOR amendment is impossible in the
current repository state. Round 1's ambiguity is gone, but the replacement rule is
self-blocking.

**Evidence**: Governance says "A minimum quorum of 2 active maintainers is required for
MAJOR votes" and also "Until `MAINTAINERS.md` is created, the project owner acts as sole
maintainer." The repo does not contain `MAINTAINERS.md`.

**Suggestion**: Add a bootstrap exception such as: "Before `MAINTAINERS.md` exists, the
project owner may approve MAJOR amendments with one external reviewer," or require
creation of `MAINTAINERS.md` before this governance section takes effect.

---

#### Issue 7 (Medium): Principle IV contradicts Principle I by claiming `--dev` and `--from` flows work "identically"

**Location**: Principle IV — "Install instructions MUST work identically for `--dev` and `--from` flows"; Principle I remote install model

**Problem**: Principle I correctly distinguishes local pack-subdirectory installs,
root archive installs, and remote per-pack release-asset installs. Principle IV then says
install instructions must work "identically" for `--dev` and `--from` flows. That is too
strong and internally inconsistent. The flows are intentionally different in transport,
artifact shape, and root semantics.

**Evidence**: `docs/original-plan.md` gives different commands for local `--dev`,
root archive `--from`, and per-pack release-asset `--from` installs. Principle I now
encodes the same distinction.

**Suggestion**: Replace "identically" with "consistently" or "predictably," and specify
the real invariant: equivalent packs should install with analogous naming and behavior,
while respecting their distinct artifact sources.

---

#### Issue 8 (Medium): The constitution still does not resolve the source plan's ambiguity about what the root `foundry` bundle contains

**Location**: Principle I V1 pack enumeration; `docs/original-plan.md` "foundry root bundle"

**Problem**: The original plan says the root bundle includes `peer`, `gates`, and "one
default preset, or all presets if you want a true kitchen-sink bundle." The revised
constitution enumerates the V1 pack set but never states whether `foundry` includes one
default preset or both presets. That source choice remains ungoverned, which matters for
aggregate bundle assembly and release expectations.

**Evidence**: `docs/original-plan.md` leaves the preset composition of the aggregate
bundle open. Principle I says `foundry` is an aggregate assembled from the named packs but
does not commit to the preset-selection rule.

**Suggestion**: Add an explicit V1 rule for aggregate composition: either define one
default preset, define that both presets ship in `foundry`, or state that the choice is a
release-time policy documented in README and release notes.

---

#### Issue 9 (Low): `packs.yml` is a newly invented filename, not a sourced plan requirement

**Location**: Technical Standards — "A `packs.yml` file MUST exist at the repo root"

**Problem**: The original plan requires a repo-level pack index and shows YAML shape, but
it does not name the file. The revised constitution hard-codes `packs.yml` as the only
acceptable filename. That is stricter than the source and adds a governance obligation for
no documented reason.

**Evidence**: `docs/original-plan.md` says "Add a repo-level pack index for
build/release tooling" and then shows YAML, but does not prescribe a file name.

**Suggestion**: Reword this as "`packs.yml` (or equivalent documented pack index file)"
unless there is a specific tooling dependency that requires the exact filename.

---

#### Issue 10 (Low): Build-time validation of `default_provider` is an unsourced implementation rule

**Location**: Technical Standards — Provider configuration paragraph

**Problem**: The source plan gives a provider-config schema example and says Codex is the
implemented provider while others remain reserved. The revised constitution goes further by
requiring `build-all.sh` to validate that `default_provider` resolves to an enabled
adapter. That may be a sensible implementation rule, but it is not sourced from the plan
and is not framed as a deliberate constitutional addition.

**Evidence**: `docs/original-plan.md` shows:
`default_provider: codex` with enabled/disabled provider entries, but it does not state
that `build-all.sh` must validate that relationship.

**Suggestion**: Either justify this as an intentional governance addition for release
correctness, or move it to implementation docs/tests instead of constitutional text.

---

#### Issue 11 (Low): The new mandatory spec-in-`specs/` workflow is stricter than the source plan and is not marked as an additive governance choice

**Location**: Development Workflow §1

**Problem**: The original plan says nothing about opening a spec in `specs/` before
writing any script or YAML. The revised constitution now mandates that process step for
all pack work. That may be desirable, but it is a process invention, not a source-plan
derivation, and the document does not label it as such.

**Evidence**: `docs/original-plan.md` defines repository layout, install model, release
workflow, and tests, but contains no `specs/` process requirement.

**Suggestion**: Mark this as an explicit governance enhancement beyond the original plan,
or soften it to "SHOULD" unless the project intends to require formal specs for every
change.

---

#### Issue 12 (Low): The manifest `version` rule still exceeds the source plan

**Location**: Technical Standards — extension manifest YAML block

**Problem**: Round 2 improves the earlier overreach by making `version` optional for
in-repo development, but it still makes `version` required for standalone release asset
ZIPs. The source plan never says pack manifests need a version field at all. This is a
smaller issue than Round 1, but it remains an additive rule with no stated rationale.

**Evidence**: `docs/original-plan.md` lists manifest fields as `id`, `name`,
`provides.commands`, `provides.memory`, `provides.templates`, and optional `hooks`.

**Suggestion**: Either remove the requirement from the constitution or add one sentence
explaining why standalone release artifacts need manifest versioning.

---

### Positive Aspects

- The highest-risk Round 1 fidelity gaps are genuinely fixed: the remote release-asset
  rule, missing test scenarios, `build-pack.sh`, named pack enumeration, shared directory
  layout, and pack index are now present in the constitution text.
- The Sync Impact Report is materially more honest in Round 2. It now acknowledges the
  missing commands directory as N/A, the README gap as open, and the three generic
  templates as pending rather than pretending they were updated.
- Principle III is now much closer to the original plan's actual distribution surface. It
  no longer collapses ZIP-install scenarios into generic collision checks.
- The inline Constitution Check in Development Workflow now covers Principles II and V,
  closing the Round 1 mismatch between the constitution and `plan-template.md`.
- The `agents/` directory is no longer governance-silent; contributors now have an
  explicit rule that first use requires an approved spec and a MINOR amendment.

---

### Summary

- **Top issue**: The constitution now mandates a baseline repository structure that still
  does not exist, and most of those missing MUST artifacts are not tracked as open
  compliance gaps.
- **Second issue**: The revision acknowledges template propagation debt but still leaves
  `spec-template.md`, `tasks-template.md`, and `agent-file-template.md` structurally
  misaligned with the ratified constitution.
- **Third issue**: New governance text introduced fresh problems, especially the MAJOR
  amendment bootstrap deadlock and the contradiction between Principle I's differentiated
  install model and Principle IV's "identical" install-instructions claim.

**Consensus Status**: NEEDS_REVISION

---

## Round 3 — 2026-03-26

### Overall Assessment

Round 3 is a genuine improvement. The constitution is now substantially closer to
`docs/original-plan.md` and materially more internally coherent than it was in Rounds 1
and 2. The Round 2 text-level problems were mostly handled well: Principle II no longer
turns line-count heuristics into constitutional law, the immutability rule is now scoped
to build/assembly scripts, Principle IV no longer contradicts Principle I about install
flows, the foundry aggregate composition is now explicit, the pack-index filename is
softened, provider-default validation is clearly marked as an intentional governance
addition, the spec-in-`specs/` workflow is downgraded to a deliberate SHOULD-level
practice, the manifest `version` field is no longer required, and the MAJOR-amendment
bootstrap deadlock is fixed.

What remains is narrower and less severe. The main open problems are now about
executability and propagation: the constitution accurately tracks baseline repo gaps, but
the repository is still nowhere near that baseline; Workflow §0 creates a bootstrap
sequence that is directionally correct but still ambiguous; and the generic
`spec-template.md`, `tasks-template.md`, and `agent-file-template.md` have still not been
propagated to the pack-centric governance model. Those are real issues, but they no
longer outweigh the substantial fidelity and consistency gains. This constitution is now
mostly good governance text, though not yet fully approved as a complete executable
system for this repository.

**Rating**: 8.5/10

---

### Coverage Matrix

| Original Plan Commitment | Constitution Coverage | Template Coverage | Status | Notes |
|---|---|---|---|---|
| Published GitHub multi-pack hub, not a single extension repo | Still implicit rather than principle-level | None | Partially Covered | The repo-hub framing from the plan summary is still not stated directly as a constitutional invariant |
| Repo root is all-in-one installable aggregate bundle | Principle I + Workflow §6 | None | Fully Covered | Aggregate-bundle model is now clear |
| Root bundle generated from selected packs and committed so repo-root install works | Principle I aggregate rule + Principle III root install tests | None | Partially Covered | Buildability is covered; the "generated and committed" requirement remains implicit |
| Every `packs/*` dir independently installable with `--dev` | Principle I + Principle III | plan-template.md only | Fully Covered | |
| Remote per-pack install uses release asset ZIPs, NOT repo archive | Principle I remote install model | plan-template.md only | Fully Covered | |
| Pack model: `peer`, `gates`, `preset-zen`, `preset-strict`, `foundry` | Principle I V1 enumeration | None | Fully Covered | |
| Foundry aggregate composition | Principle I explicit composition rule | None | Fully Covered | Round 2 ambiguity resolved by choosing the "all presets" interpretation permitted by the source plan |
| Preset packs are memory/template-only, no commands | Principles IV + Technical Standards | plan-template.md only | Fully Covered | |
| Provider model: Codex first, Copilot/Gemini reserved/unimplemented | Principle VI + Technical Standards | plan-template.md only | Fully Covered | |
| `shared/providers/`, `shared/prompts/`, `shared/schemas/` directories | Technical Standards shared layout | None | Fully Covered | |
| Build scripts: `validate-pack.sh`, `build-pack.sh`, `build-all.sh` | Technical Standards + Workflow §§3-4 | None | Fully Covered (Repo Gap Open) | Governance coverage is good; artifacts are still absent from the repository |
| `.github/workflows/release.yml` release workflow | Workflow §6 + Sync Impact Report baseline gaps | None | Fully Covered (Repo Gap Open) | Now tracked honestly as a missing MUST artifact |
| Repo-level pack index YAML | Technical Standards + Sync Impact Report baseline gaps | None | Fully Covered (Repo Gap Open) | |
| README MUST document install methods and pack type table | Principle IV + Workflow §5 + Sync Impact Report baseline gaps | None | Fully Covered (Repo Gap Open) | |
| Test scenarios 1-8 | Principle III | plan-template.md only | Fully Covered | |
| `agents/` directory reserved for future variants | Principle VI | None | Fully Covered | |
| Template propagation from constitution into spec/tasks/agent templates | Sync Impact Report + Workflow §0 blocker note | spec-template.md / tasks-template.md / agent-file-template.md still generic | Partially Covered | Tracked as a blocker, but not remediated |

---

### Previous Round Tracking

| Round 2 Issue | Round 3 Status | Notes |
|---|---|---|
| 1. Baseline artifacts were absent and not fully tracked | Mostly Resolved | The gaps are now comprehensively tracked in the Sync Impact Report, but the artifacts are still absent |
| 2. Template propagation gaps were acknowledged but unresolved | Still Open | Still pending in all three generic templates |
| 3. README compliance gap remained open | Still Open | Now tracked honestly as a baseline gap, but `README.md` still does not exist |
| 4. Principle II line-count ceilings were unsourced constitutional law | Resolved | Demoted to non-constitutional contributor guidance |
| 5. Principle II immutability rule was a category error for YAML/templates | Resolved | Narrowed to build/assembly scripts and destructive overwrite prevention |
| 6. MAJOR amendment governance had a bootstrap deadlock | Resolved | Bootstrap exception now makes MAJOR amendments possible pre-`MAINTAINERS.md` |
| 7. Principle IV contradicted Principle I with "identical" install flows | Resolved | Rewritten around equivalent behavior rather than identical commands/artifacts |
| 8. Foundry aggregate composition was underspecified | Resolved | Principle I now explicitly defines V1 composition |
| 9. `packs.yml` was an invented mandatory filename | Resolved | Softened to `packs.yml` or equivalent documented filename |
| 10. Build-time `default_provider` validation was unsourced | Resolved | Recast as a SHOULD-level deliberate governance addition |
| 11. Mandatory specs/ workflow was stricter than the source plan | Resolved | Softened to SHOULD and explicitly labeled as additive governance |
| 12. Manifest `version` rule exceeded the source plan | Resolved | `version` is now recommended rather than required |

---

### Issues

#### Issue 1 (High): The repository is still non-compliant with the constitution's own baseline requirements

**Location**: Sync Impact Report baseline compliance gaps; Development Workflow §0

**Problem**: The governance text now accurately lists the missing MUST artifacts, but the
repository still lacks nearly all of them. That means the constitution is much more
truthful than before, yet the project remains immediately non-compliant with the standard
it ratifies.

**Evidence**: The current tree still contains only `.specify/`, `.claude/commands/`,
`docs/`, and `reviews/`. It does not contain `README.md`, root `extension.yml`,
`packs.yml`, `scripts/`, `packs/`, `.github/workflows/release.yml`, or
`shared/providers/codex/`.

**Suggestion**: Keep the baseline gap list, but add a short status line in Governance or
Workflow explicitly stating that the repository is in bootstrap mode until those artifacts
exist and that ordinary pack-development rules apply only after bootstrap completion.

---

#### Issue 2 (Medium): Workflow §0 still leaves bootstrap sequencing ambiguous

**Location**: Development Workflow §0

**Problem**: The workflow says the repository MUST satisfy all baseline compliance gaps
before any pack work begins. That is directionally correct, but it is not operationally
precise because creating the missing packs, scripts, shared directories, and root bundle
is itself the first unit of work.

**Evidence**: Workflow §0 requires baseline compliance first, while the baseline gaps list
includes `packs/peer/`, `packs/gates/`, `packs/preset-zen/`, `packs/preset-strict/`,
`scripts/*.sh`, and root `extension.yml`.

**Suggestion**: Define an explicit "Bootstrap Phase" exception: baseline creation work is
allowed under a setup spec, and all other workflow gates apply fully only after the
bootstrap phase lands.

---

#### Issue 3 (Medium): The Constitution Check still re-hardens advisory size heuristics

**Location**: Development Workflow §2; Principle II

**Problem**: Principle II now correctly says script/YAML size limits are advisory only.
Workflow §2 still asks "Are scripts ≤ 200 lines and manifests ≤ 100 lines, or are
exceptions justified?" That wording treats the heuristic as if a formal exception process
still exists, which quietly reintroduces a rule Principle II just removed.

**Evidence**: Principle II calls the limits "Contributor guidance (non-constitutional)."
Workflow §2 still frames them as a gate question with exceptions needing justification.

**Suggestion**: Reword the Workflow §2 bullet to match Principle II exactly, for example:
"Are scripts and manifests still reasonably sized for review, with any large artifacts
called out for extra scrutiny?" Remove "exceptions justified."

---

#### Issue 4 (Medium): Template propagation remains the largest unresolved governance gap

**Location**: Sync Impact Report template section; Development Workflow §0

**Problem**: The constitution now correctly identifies template propagation as a blocker,
but the blocker is still real. Future generated specs and tasks will still default to the
generic project scaffolds unless the templates are actually updated.

**Evidence**: `spec-template.md`, `tasks-template.md`, and `agent-file-template.md`
remain generic, and the Sync Impact Report still marks all three as pending.

**Suggestion**: Treat template propagation as the first post-constitution work item and
track it in the recommended setup spec rather than leaving it as an open-ended TODO.

---

#### Issue 5 (Medium): `spec-template.md` still does not encode the pack-specific scenario model

**Location**: `.specify/templates/spec-template.md`

**Problem**: The constitution now requires eight specific install/distribution scenarios
plus pack-type distinctions, but the feature-spec template still contains only generic
user-story scaffolding. A contributor using the template would receive no prompt to state
whether the work affects root installs, per-pack installs, release assets, presets, or
provider isolation.

**Evidence**: `spec-template.md` has generic acceptance scenarios and edge cases, but no
pack type field, no install-path checklist, and no prompt for the mandatory 8 scenario
set.

**Suggestion**: Add a pack-oriented section to the template: affected pack(s), pack type,
install paths touched, and a checklist for the mandatory distribution/test scenarios.

---

#### Issue 6 (Medium): `tasks-template.md` still assumes generic app development rather than pack lifecycle work

**Location**: `.specify/templates/tasks-template.md`

**Problem**: The task template still assumes `src/`, `backend/`, `frontend/`, and Python
test paths. That is misaligned with this project's actual governance target, which is a
multi-pack extension repo with pack directories, build scripts, shared provider assets,
and release artifacts.

**Evidence**: `tasks-template.md` still centers on models/services/endpoints and Python
test paths like `tests/contract/test_[name].py`, rather than `packs/<id>/`,
`scripts/build-pack.sh`, `packs.yml`, or release asset validation work.

**Suggestion**: Replace the generic sample phases with pack-repo phases: bootstrap,
single-pack work, shared/provider updates, root aggregate rebuild, release-asset
verification, and README/update tasks.

---

#### Issue 7 (Low): `agent-file-template.md` is still generic and not pack-aware

**Location**: `.specify/templates/agent-file-template.md`

**Problem**: The agent-file template remains a generic project summary shell. It still
does not reflect the pack taxonomy, root aggregate model, shared directory layout, or
release workflow that now define the repository constitutionally.

**Evidence**: The template still contains `[PROJECT NAME]`, "Active Technologies," generic
"Commands," and no sections for packs, shared adapters, install modes, or release assets.

**Suggestion**: Add pack-centric sections such as V1 pack inventory, aggregate bundle
rules, remote install model, and baseline required artifacts.

---

#### Issue 8 (Low): The "published GitHub multi-pack hub" framing is still not explicit governance text

**Location**: Entire constitution; `docs/original-plan.md` Summary

**Problem**: The source plan opens by saying this should be a published GitHub project
that acts as a multi-pack hub, not a single extension repo. The constitution now implies
that structure strongly, but it still never states it plainly as a project-level rule.

**Evidence**: `docs/original-plan.md` Summary uses that exact framing. The constitution
describes packs, aggregate bundle, and release assets, but never states "this project is
a multi-pack hub."

**Suggestion**: Add one sentence near the top of Principle I or Governance clarifying
that `spec-kit-foundry` is a multi-pack distribution hub rather than a single-pack repo.

---

#### Issue 9 (Low): The root aggregate's "generated and committed" property remains implicit

**Location**: Principle I; Development Workflow §6; `docs/original-plan.md` Repo Layout rules

**Problem**: The source plan does not just require the root bundle to exist; it says the
root bundle is generated from selected packs and committed so repo-root install works.
The constitution now tests root installs and requires aggregate build behavior, but it
still does not explicitly say the assembled root bundle artifacts must be committed.

**Evidence**: `docs/original-plan.md` says the root bundle is "generated from selected
packs and committed so repo-root install works." The constitution covers assembly and root
install validation, but not the committed-artifact requirement directly.

**Suggestion**: Add one short rule under Principle I or Workflow §6: the assembled root
bundle files required for repo-root install must be committed in the repository.

---

#### Issue 10 (Low): The README gap is now honestly tracked, but still unresolved in the repository

**Location**: Principle IV; Development Workflow §5; Sync Impact Report baseline gaps

**Problem**: This is no longer a hidden problem, but it is still a real one. The
constitution requires a scannable README covering install modes and pack types, and the
repository still lacks that file.

**Evidence**: The baseline compliance gap list still names `README.md` as "HIGHEST
PRIORITY," and the repo tree still has no `README.md`.

**Suggestion**: Make README creation part of the bootstrap phase and place it ahead of
any pack implementation work.

---

#### Issue 11 (Low): The provisional performance targets remain an additive governance choice

**Location**: Principle V

**Problem**: Principle V is much safer than in prior rounds because the targets are now
explicitly advisory. Even so, the original plan still does not provide these numbers, so
they remain a constitution-level addition rather than a sourced requirement.

**Evidence**: `docs/original-plan.md` still contains no timing targets for
`validate-pack.sh` or `build-all.sh`.

**Suggestion**: This is acceptable if kept advisory, but one sentence in the rationale
could make the provenance even clearer: these are local governance targets, not source
plan requirements.

---

### Positive Aspects

- Round 3 resolves the most important Round 2 governance-text issues rather than merely
  rephrasing them. Principle II, Principle IV, the manifest version rule, the pack-index
  filename, the spec workflow strictness, and the MAJOR-amendment bootstrap logic are all
  materially better.
- The foundry aggregate composition is now explicit and defensible. Choosing the
  all-presets interpretation is within the source plan's allowed V1 options and removes a
  real ambiguity from the prior draft.
- The Sync Impact Report is now much more rigorous. It no longer just acknowledges the
  README gap; it inventories the full set of missing MUST artifacts and treats template
  propagation as a governance blocker.
- The provider-default validation rule is now handled correctly as an intentional
  governance addition rather than smuggling itself in as if it came directly from the
  source plan.
- The constitution is now internally much more coherent. The clearest Round 2
  contradiction, around install-flow equivalence, is gone.

---

### Summary

- **Top issue**: The remaining problems are no longer major source-fidelity failures; the
  biggest gap is that the repository still has not been bootstrapped to the constitution's
  required baseline.
- **Second issue**: Template propagation is still incomplete, especially in
  `spec-template.md`, `tasks-template.md`, and `agent-file-template.md`, so the
  governance model is not yet flowing through generated artifacts.
- **Third issue**: One internal inconsistency remains in Workflow §2, which still treats
  advisory file-size heuristics as though they require formal exceptions.

**Consensus Status**: MOSTLY_GOOD
