# Technology Stack

## Runtime & Languages

| Language | Version | Purpose |
|----------|---------|---------|
| Bash | 5+ | Acceptance test runner (`scripts/validate-pack.sh`); script discovery and invocation of the Codex skill (`ask_codex.sh`) from within command prompts |
| YAML 1.2 | — | Pack manifest (`packs/peer/extension.yml`), provider config (`.specify/peer.yml`), JSON schema for peer providers (`shared/schemas/peer-providers.schema.yml`) |
| Markdown | — | Command instruction files (`commands/review.md`, `commands/execute.md`), memory injection file (`memory/peer-guide.md`), adapter guide (`shared/providers/codex/adapter-guide.md`), all spec and doc files |

There is **no compiled language, no interpreted language runtime (Python/Node/Ruby/etc.), and no package manager** in this project.

## Key Dependencies

| Dependency | Version / Source | Purpose |
|------------|-----------------|---------|
| `specify` CLI (Spec Kit) | `>=0.1.0` | Host CLI that loads and executes pack extensions; reads `extension.yml`, registers commands, and injects memory files |
| `/codex` skill (`ask_codex.sh`) | External; install from `https://skills.sh/oil-oil/codex/codex` | AI executor invoked as a shell subprocess for all review and execution work; **not bundled** with this pack |
| Claude / GitHub Copilot | — (ambient in VS Code / API) | Acts as the orchestrator role when `/speckit.peer.review` or `/speckit.peer.execute` commands are executed; reads the Markdown command specs and dispatches provider calls |

## Development Tools

| Tool | Purpose |
|------|---------|
| `scripts/validate-pack.sh` | Bash acceptance test runner; executes test cases T-01 and above against isolated `mktemp` directories; exits `0` on all-pass, `1` on first failure; total execution gate < 5 seconds |
| `set -euo pipefail` | Strict Bash error mode used in `validate-pack.sh` to catch unset variables and pipe failures |
| `mktemp -d` | Creates isolated tmpdir per test case; auto-cleaned via `trap ... EXIT` |
| YAML schema (`peer-providers.schema.yml`) | Documents and enforces the structure of `.specify/peer.yml`; validated at command preflight via peer command logic (not a separate linter binary) |

No external linters, formatters, or CI toolchain configuration files are present in the repository at this time.

## Distribution

| Mechanism | Details |
|-----------|---------|
| GitHub Releases | The `peer` pack is distributed as a `peer.zip` archive attached to a GitHub Release on this repository |
| Install target | Users download and install via the `specify install` command (or equivalent Spec Kit mechanism) pointing at the release artifact |
| Pack manifest | `packs/peer/extension.yml` (schema_version `"1.0"`, id: `peer`, version: `1.0.0`) declares provided commands and memory files; Spec Kit reads this on installation |

## Constraints & Versions

| Constraint | Detail |
|------------|--------|
| Bash 5+ required | Scripts use `[[ ]]`, `set -euo pipefail`, `BASH_SOURCE`, and other Bash 4.x/5.x features; POSIX `sh` is not sufficient |
| Spec Kit `>=0.1.0` | Declared in `extension.yml` `requires.speckit_version`; lower versions are unsupported |
| Codex skill is an external prerequisite | `ask_codex.sh` must be installed separately before any peer command will function; the pack does not vendor or install it |
| `CODEX_TIMEOUT_SECONDS` | Integer `10–600`, default `60` s; controls provider timeout; set as environment variable |
| `max_artifact_size_kb` | Default `50 KB`, max `10240 KB`; enforced at command preflight to prevent oversized prompts |
| `max_rounds_per_session` | Default `10`; triggers context reset (new session) after this many rounds |
| `max_context_rounds` | Default `3`; number of prior review rounds passed as context on each provider invocation |
| Provider support in v1 | Only `orchestrated` mode is supported; provider IDs are limited to `codex`, `copilot`, `gemini` |
