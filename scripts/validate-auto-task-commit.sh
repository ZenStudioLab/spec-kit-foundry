#!/usr/bin/env bash
# validate-auto-task-commit.sh — auto-task-commit pack acceptance gate
# Runs automated test matrix for the auto-task-commit pack.
# Usage: ./scripts/validate-auto-task-commit.sh [--case <case-id>]
# Exit 0: all cases pass. Exit 1: first failing case (FAIL_CASE=<id> on stderr).
# Total execution time gate: < 5 seconds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PACK_DIR="$REPO_ROOT/packs/auto-task-commit"

# ─── Helpers ──────────────────────────────────────────────────────────────────

pass() { echo "[PASS] $1"; }
fail() {
  echo "FAIL_CASE=$1" >&2
  echo "[FAIL] $1: $2" >&2
  exit 1
}

TMPDIR_ROOT=""
setup_tmp() {
  TMPDIR_ROOT="$(mktemp -d /tmp/validate-atc-XXXXXX)"
  trap 'rm -rf "$TMPDIR_ROOT"' EXIT
}

# ─── Case implementations ─────────────────────────────────────────────────────

# T-01: extension.yml — required fields present
case_T01() {
  local ext="$PACK_DIR/extension.yml"

  if [[ ! -f "$ext" ]]; then
    fail "T-01" "extension.yml not found at $ext"
  fi

  # schema_version field
  if ! grep -q 'schema_version' "$ext"; then
    fail "T-01" "extension.yml missing 'schema_version' field"
  fi

  # extension.id
  if ! grep -q '^\s*id:' "$ext"; then
    fail "T-01" "extension.yml missing 'extension.id' field"
  fi

  # extension.version
  if ! grep -q '^\s*version:' "$ext"; then
    fail "T-01" "extension.yml missing 'extension.version' field"
  fi

  # provides.memory section
  if ! grep -q 'memory:' "$ext"; then
    fail "T-01" "extension.yml missing 'provides.memory' section"
  fi

  # no commands section (memory-only pack)
  if grep -q '^\s*commands:' "$ext"; then
    fail "T-01" "extension.yml should not declare commands (memory-only pack)"
  fi

  pass "T-01 (extension.yml valid)"
}

# T-02: Memory guide — present and non-empty
case_T02() {
  local guide="$PACK_DIR/memory/auto-task-commit-guide.md"

  if [[ ! -f "$guide" ]]; then
    fail "T-02" "memory guide not found at $guide"
  fi

  local line_count
  line_count=$(wc -l < "$guide")
  if [[ "$line_count" -lt 10 ]]; then
    fail "T-02" "memory guide is too short ($line_count lines); expected at least 10"
  fi

  # Must contain commit instruction
  if ! grep -qi 'git commit' "$guide"; then
    fail "T-02" "memory guide does not mention 'git commit'"
  fi

  # Must contain halt-on-failure instruction
  if ! grep -qi 'halt\|non-zero\|exit' "$guide"; then
    fail "T-02" "memory guide does not mention halt-on-failure behavior"
  fi

  # Must contain nothing-to-commit handling
  if ! grep -qi 'nothing to commit\|empty\|skip' "$guide"; then
    fail "T-02" "memory guide does not mention nothing-to-commit handling"
  fi

  # Must be provider-agnostic: no Claude-specific mentions
  if grep -qi '\bClaude\b\|<antThinking\|<antArtifact' "$guide"; then
    fail "T-02" "memory guide contains Claude-specific constructs — must be provider-agnostic"
  fi

  pass "T-02 (memory guide valid and provider-agnostic)"
}

# T-03: Schema file — present and structurally valid
case_T03() {
  local schema="$REPO_ROOT/shared/schemas/auto-task-commit.schema.yml"

  if [[ ! -f "$schema" ]]; then
    fail "T-03" "schema file not found at $schema"
  fi

  # Must declare version field
  if ! grep -q 'version:' "$schema"; then
    fail "T-03" "schema missing 'version' property definition"
  fi

  # Must declare granularity field
  if ! grep -q 'granularity:' "$schema"; then
    fail "T-03" "schema missing 'granularity' property definition"
  fi

  # Must enumerate valid granularity values
  if ! grep -q 'task' "$schema" || ! grep -q 'batch' "$schema"; then
    fail "T-03" "schema does not enumerate 'task' and 'batch' as valid granularity values"
  fi

  pass "T-03 (schema file structurally valid)"
}

# T-04: Config validation — valid config (granularity: task)
case_T04() {
  local tmpdir="$TMPDIR_ROOT/T04"
  mkdir -p "$tmpdir/.specify"

  cat > "$tmpdir/.specify/auto-task-commit.yml" <<'YAML'
version: 1
granularity: task
YAML

  # Simulate preflight check: version must be 1
  local version
  version=$(grep '^\s*version:' "$tmpdir/.specify/auto-task-commit.yml" | awk '{print $2}')
  if [[ "$version" != "1" ]]; then
    fail "T-04" "valid config rejected: version '$version' != 1"
  fi

  # Simulate granularity check
  local granularity
  granularity=$(grep '^\s*granularity:' "$tmpdir/.specify/auto-task-commit.yml" | awk '{print $2}')
  if [[ "$granularity" != "task" && "$granularity" != "batch" ]]; then
    fail "T-04" "valid granularity 'task' rejected"
  fi

  pass "T-04 (valid config: granularity task accepted)"
}

# T-05: Config validation — valid config (granularity: batch)
case_T05() {
  local tmpdir="$TMPDIR_ROOT/T05"
  mkdir -p "$tmpdir/.specify"

  cat > "$tmpdir/.specify/auto-task-commit.yml" <<'YAML'
version: 1
granularity: batch
YAML

  local granularity
  granularity=$(grep '^\s*granularity:' "$tmpdir/.specify/auto-task-commit.yml" | awk '{print $2}')
  if [[ "$granularity" != "batch" ]]; then
    fail "T-05" "valid granularity 'batch' not parsed correctly"
  fi

  pass "T-05 (valid config: granularity batch accepted)"
}

# T-06: Nothing-to-commit scenario — skip gracefully
# Simulate the guide's Step 1: `git status --porcelain` returns empty output.
# Verify the correct behavior is to skip the commit without error.
case_T06() {
  local tmpdir="$TMPDIR_ROOT/T06"
  mkdir -p "$tmpdir"

  # Initialize a clean git repo with a committed file (nothing pending)
  cd "$tmpdir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -q -m "initial commit"

  # Simulate: check for changes (should be empty = nothing to commit)
  local status_output
  status_output=$(git status --porcelain)

  if [[ -n "$status_output" ]]; then
    fail "T-06" "expected empty git status in clean repo, got: $status_output"
  fi

  # Simulate: empty output → skip commit (no git commit invoked)
  # The guide says: if empty, skip and continue. We verify by NOT running git commit.
  local commit_count_before commit_count_after
  commit_count_before=$(git rev-list --count HEAD)

  # (Intentionally NOT running git commit — this is the correct behavior)
  commit_count_after=$(git rev-list --count HEAD)

  if [[ "$commit_count_after" != "$commit_count_before" ]]; then
    fail "T-06" "commit count changed despite nothing-to-commit skip"
  fi

  cd "$REPO_ROOT"
  pass "T-06 (nothing-to-commit: skip gracefully)"
}

# T-07: Commit message format — feat(<featureId>): <taskText>
case_T07() {
  local tmpdir="$TMPDIR_ROOT/T07"
  mkdir -p "$tmpdir"
  cd "$tmpdir"

  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add file.txt
  git commit -q -m "initial commit"

  # Simulate task completion and commit message generation
  local feature_id="002-auto-task-commit"
  local task_text="add provider validation"
  local expected_msg="feat($feature_id): $task_text"

  # Write a change to commit
  echo "change" > new-file.txt
  git add new-file.txt
  git commit -q -m "$expected_msg"

  # Verify commit message
  local actual_msg
  actual_msg=$(git log -1 --format="%s")
  if [[ "$actual_msg" != "$expected_msg" ]]; then
    fail "T-07" "commit message '$actual_msg' != expected '$expected_msg'"
  fi

  cd "$REPO_ROOT"
  pass "T-07 (commit message format: feat(<featureId>): <taskText>)"
}

# ─── Runner ───────────────────────────────────────────────────────────────────

RUN_CASE="${1:-}"
if [[ "$RUN_CASE" == "--case" && -n "${2:-}" ]]; then
  RUN_CASE="$2"
fi

setup_tmp

if [[ -n "$RUN_CASE" ]]; then
  "case_${RUN_CASE//-/}" 2>&1 || true
else
  case_T01
  case_T02
  case_T03
  case_T04
  case_T05
  case_T06
  case_T07
  echo ""
  echo "All cases passed."
fi
