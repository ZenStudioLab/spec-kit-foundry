# Testing

## Test Strategy

No external test framework. All tests are pure Bash using hand-rolled assertions (`pass` / `fail` helpers). The strategy is acceptance-level integration testing: each test case creates an isolated filesystem fixture, simulates the steps a command would perform, and verifies the observable outcomes (files created, state contents, exit codes, error messages).

**Key principles:**
- Isolation first: every test case gets its own `mktemp -d` subdirectory; no shared state between cases.
- Simulate, don't invoke: tests replicate the logic of command steps rather than executing the actual CLI (which depends on the external `specify` runtime). This keeps the gate fast and CI-free.
- Fail fast: first failure exits immediately with `FAIL_CASE=<id>` on stderr and a `[FAIL]` line on stderr; all subsequent cases are skipped.
- Time-bounded: the entire suite must complete in < 5 seconds.

---

## Test Runner

**File:** `scripts/validate-pack.sh`

```bash
./scripts/validate-pack.sh              # run all cases
./scripts/validate-pack.sh --case T-03  # run a single case by id
```

**Exit behaviour:**
- `0` — all cases passed.
- `1` — first failing case; `FAIL_CASE=<id>` written to stderr.

**Output format:**
- `[PASS] <id> (<description>)` — printed to stdout on success.
- `FAIL_CASE=<id>` + `[FAIL] <id>: <reason>` — printed to stderr on failure.

**Temp dir management:** a single `TMPDIR_ROOT` is created via `setup_tmp()` at the start of each run and cleaned up by a `trap 'rm -rf "$TMPDIR_ROOT"' EXIT` registered immediately after creation.

**Dependency:** `python3` is required on `PATH` for JSON parsing within test cases (no `jq` dependency).

---

## Test Structure

Cases are defined as `case_T<NN>()` functions in `validate-pack.sh`. Multi-part cases use suffixes (e.g. `case_T06` contains sub-cases `T-06a` and `T-06b`).

Each case follows this pattern:
```
1. Create isolated tmpdir under $TMPDIR_ROOT/<TNN>
2. Set up minimal filesystem fixture (mkdir, cat > file, chmod, etc.)
3. Assert a pre-condition (file does NOT exist, flag is unset, etc.)
4. Simulate the command behaviour being tested
5. Assert the expected post-condition with pass/fail
```

### Current test matrix

| ID | Description |
|----|-------------|
| T-01 | First-run state init: `reviews/` and `provider-state.json` created; mode is 0600 |
| T-02 | Session reuse: `session_id` readable from state for round 2+; `rounds_in_session < max_rounds_per_session` |
| T-03 | Missing `peer.yml` → exit 5; error includes `VALIDATION_ERROR` and install instructions |
| T-04 | Disabled provider (`enabled: false`) → exit 5; error includes enable instructions |
| T-05 | Unimplemented provider (no adapter guide) → exit 6; `UNIMPLEMENTED_PROVIDER` in message; no side-effect files created |
| T-06a | `provider-state.json` missing `version` field → backup created; file reinitialised to `{"version":1}` |
| T-06b | Unparseable `provider-state.json` JSON → fail-fast (parse error); no backup created |

---

## Test Coverage

### Covered
- State lifecycle: creation on first run, permissions (chmod 600), session reuse, version-mismatch reinit, unparseable-JSON fail-fast.
- Config validation: missing `peer.yml`, disabled provider, unimplemented provider.
- Error message contracts: exit codes 5, 6, 8; `ERROR_CODE` token presence; actionable instructions in messages.
- Side-effect isolation: verifies that error paths do not create unwanted files/directories.

### Not covered
- Exit code 1 (provider unavailable / network failure).
- Exit code 7 (artifact too large).
- `speckit.peer.execute` command path (task batch loop, checkbox transitions, `tasks.md` updates).
- `speckit.peer.review` full review lifecycle (multi-round appended review, `APPROVED` verdict).
- Context reset logic (`rounds_in_session >= max_rounds_per_session` → new session).
- `--case` flag parsing within the runner itself.
- `max_artifact_size_kb` enforcement.
- `max_context_rounds` window slicing.
- Schema validation of `peer.yml` against `peer-providers.schema.yml`.
- YAML front matter parsing of command files.
- `extension.yml` structural validation.
- `copilot` and `gemini` provider adapter paths (no adapter guides exist yet).

---

## Running Tests

```bash
# Run the full suite
./scripts/validate-pack.sh

# Run a single case (useful during development)
./scripts/validate-pack.sh --case T-03

# Confirm suite completes within the 5-second gate
time ./scripts/validate-pack.sh
```

**Prerequisites:**
- Bash 5+
- `python3` on `PATH` (standard on Linux/macOS)
- Run from the repository root or any directory (paths are derived from `BASH_SOURCE[0]`)

---

## Gaps & Recommendations

### Missing coverage (high priority)
1. **Execute command tests** — the `speckit.peer.execute` batch loop, checkbox transition verification, and code-review round appending are completely untested.
2. **Review command tests** — full multi-round review lifecycle (`APPROVED`/`REJECTED` verdicts, append-only behavior, context window slicing) has no test cases.
3. **Exit code 1 and 7** — provider unavailable and artifact-too-large paths have no tests.
4. **Schema validation gate** — `peer.yml` is read and parsed in tests, but its fields are never validated against `peer-providers.schema.yml`.
5. **Context reset** — session expiry and the new-session reinit path are not exercised.

### Structural suggestions
- **`--case` coverage**: add a meta-test or CI check that all defined `case_T<NN>` functions are reachable via the `--case` dispatch table.
- **Fixture files**: extract common fixtures (valid `peer.yml`, minimal `provider-state.json`) into a `tests/fixtures/` directory to reduce duplication across cases.
- **Error message contract tests**: create a dedicated case for each `ERROR_CODE` enum value to lock in the exact message format as a regression guard.
- **CI integration**: add a `.github/workflows/validate.yml` (or equivalent) running `./scripts/validate-pack.sh` on push/PR — currently no CI configuration exists.
- **`jq` vs `python3`**: standardise on one JSON tool; if `python3` is acceptable as a dependency, document it explicitly in the README; otherwise switch to `jq` which is more commonly available in CI images.
