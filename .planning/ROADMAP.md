# Roadmap: auto-task-commit

## Overview

Three phases: define the spec and contracts, implement the pack files, then validate and ship as a distributable ZIP alongside the peer pack.

## Phases

- [ ] **Phase 1: Spec & Contracts** - Author and peer-review the full specification before writing any pack files
- [ ] **Phase 2: Pack Implementation** - Build the installable pack (extension.yml, memory guide, config schema)
- [ ] **Phase 3: Tests & Distribution** - Write acceptance tests, build ZIP, update docs

## Phase Details

### Phase 1: Spec & Contracts
**Goal**: Define and peer-review the complete specification for the `auto-task-commit` pack before writing any implementation files.
**Depends on**: Nothing (first phase)
**Requirements**: R-01, R-02, R-03, R-04, R-05, R-06, R-07, R-08, R-09, R-10, R-11
**Success Criteria** (what must be TRUE):
  1. `specs/002-auto-task-commit/spec.md` exists and is peer-reviewed APPROVED
  2. `specs/002-auto-task-commit/data-model.md` defines config shape and commit message format
  3. `specs/002-auto-task-commit/contracts/memory-guide-contract.md` specifies the provider-agnostic memory instruction contract
  4. `specs/002-auto-task-commit/contracts/config-schema-contract.md` documents the YAML config schema
**Plans**: TBD

### Phase 2: Pack Implementation
**Goal**: Ship working, installable pack files that enforce git commits after each task during `speckit.implement`.
**Depends on**: Phase 1
**Requirements**: R-01, R-02, R-03, R-04, R-05, R-06, R-07, R-10, R-11
**Success Criteria** (what must be TRUE):
  1. `packs/auto-task-commit/extension.yml` is valid and loadable by `specify`
  2. `packs/auto-task-commit/memory/auto-task-commit-guide.md` instructs any LLM to commit after each task (per-task default, per-batch configurable)
  3. `shared/schemas/auto-task-commit.schema.yml` validates `.specify/auto-task-commit.yml` config
  4. Installing the pack and running `speckit.implement` results in one git commit per completed task
**Plans**: TBD

### Phase 3: Tests & Distribution
**Goal**: Validated, distributable pack ready for release alongside the peer pack.
**Depends on**: Phase 2
**Requirements**: R-08, R-09
**Success Criteria** (what must be TRUE):
  1. `scripts/validate-auto-task-commit.sh` has T-01..T-06+ test cases and all pass
  2. `auto-task-commit.zip` is buildable and installable via `specify extension add`
  3. `README.md` packs table includes `auto-task-commit` entry
**Plans**: TBD
