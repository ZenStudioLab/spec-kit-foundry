# Roadmap

## Phase 1 — Spec & Contracts

**Goal:** Define and peer-review the complete specification for the `auto-task-commit` pack before writing any pack files.

**Requirements:** R-01, R-02, R-03, R-04, R-05, R-06, R-07, R-08, R-09, R-10, R-11

**Plans:** TBD

**Deliverables:**
- `specs/002-auto-task-commit/spec.md`
- `specs/002-auto-task-commit/data-model.md`
- `specs/002-auto-task-commit/contracts/memory-guide-contract.md`
- `specs/002-auto-task-commit/contracts/config-schema-contract.md`
- Peer reviews APPROVED for spec artifacts

---

## Phase 2 — Pack Implementation

**Goal:** Ship working, installable pack files that enforce git commits after each task during `speckit.implement`.

**Requirements:** R-01, R-02, R-03, R-04, R-05, R-06, R-07, R-10, R-11

**Plans:** TBD

**Deliverables:**
- `packs/auto-task-commit/extension.yml`
- `packs/auto-task-commit/memory/auto-task-commit-guide.md`
- `shared/schemas/auto-task-commit.schema.yml`
- Default config template for `.specify/auto-task-commit.yml`

---

## Phase 3 — Tests & Distribution

**Goal:** Validated, distributable pack ready for release alongside the peer pack.

**Requirements:** R-08, R-09

**Plans:** TBD

**Deliverables:**
- `scripts/validate-auto-task-commit.sh` (T-01..T-06+)
- `auto-task-commit.zip`
- Updated `README.md` (packs table)
- Updated `AGENTS.md`

---
*Last updated: 2026-03-28 after initialization*
