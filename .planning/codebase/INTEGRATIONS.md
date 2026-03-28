# External Integrations

## Spec Kit (`specify` CLI)

- **Type**: CLI (host runtime)
- **Purpose**: The `specify` CLI is the host that loads and manages pack extensions. It reads `packs/peer/extension.yml` to register the two peer commands (`speckit.peer.review`, `speckit.peer.execute`) and injects `memory/peer-guide.md` into the active AI context at session start. All user-facing commands are invoked through `specify` (e.g., `specify run speckit.peer.review spec`).
- **Location**: System-installed CLI; version constraint `>=0.1.0` declared in `packs/peer/extension.yml` under `requires.speckit_version`
- **Interface**: Pack registration is declarative — `extension.yml` lists command files and memory files; `specify` resolves them at load time. Commands are Markdown instruction files that `specify` passes to the active AI provider as context. No programmatic API surface is used by this pack.
- **Error handling**: If the `specify` CLI is absent or the version is below `0.1.0`, the extension will not load. The pack itself does not handle this; it is a precondition enforced by the installer/user.

---

## Codex Skill (`ask_codex.sh`)

- **Type**: Shell script (external AI executor)
- **Purpose**: Provides all AI-generated review content and implementation work. The peer commands (`review`, `execute`) are prohibited from generating review feedback or code themselves — all such output must come exclusively from the Codex skill. It acts as the **provider** role in the orchestrator/provider split.
- **Location**: Default: `~/.claude/skills/codex/scripts/ask_codex.sh`; overridable via `CODEX_SKILL_PATH` environment variable. Install source: `https://skills.sh/oil-oil/codex/codex`. **Not bundled** — must be installed separately before any peer command will function.
- **Interface**: Invoked as a shell subprocess:
  ```bash
  ask_codex.sh "<prompt>" --file <artifact-path> [--session <session_id>] --reasoning high
  ```
  - `--file`: absolute path to the primary artifact
  - `--session`: omit on first call; include to resume a conversation
  - `--reasoning high`: always required for peer invocations
  - Stdout contract: exactly two lines — `session_id=<value>` and `output_path=<path>`; any deviation is treated as `PARSE_FAILURE` (exit `8`)
  - Stderr: human-readable output; passed through to caller
- **Script discovery order**:
  1. `CODEX_SKILL_PATH` env var (if set, must be readable and executable)
  2. Default path `~/.claude/skills/codex/scripts/ask_codex.sh`
  - A warning is emitted when the env-var override is used (path redacted unless `PEER_DEBUG=1`)
- **Error handling**:

  | Exit Code | Error Code | Condition |
  |-----------|-----------|----------|
  | `1` | `PROVIDER_UNAVAILABLE` | Script not found, not readable, or not executable |
  | `2` | `PROVIDER_TIMEOUT` | No response within `CODEX_TIMEOUT_SECONDS` (default 60 s, max 600 s); no retry in v1 |
  | `3` | `PROVIDER_EMPTY_RESPONSE` | Success exit but `output_path` is absent or empty |
  | `4` | `PROVIDER_ERROR` | Non-zero exit for any other provider-side failure |
  | `8` | `PARSE_FAILURE` | Stdout does not match the two-line contract |

  On any error, peer commands emit `[peer/<command>] ERROR: <ERROR_CODE>: <message>` to stderr and abort. There is **no fallback** — if the provider is unavailable, the command halts.

---

## Claude / GitHub Copilot (Orchestrator)

- **Type**: Ambient AI (in-process orchestrator)
- **Purpose**: Acts as the **orchestrator** role in both peer commands. Claude reads the Markdown command spec files (`commands/review.md`, `commands/execute.md`) and the injected memory file (`memory/peer-guide.md`) as instructions. It resolves feature IDs, loads config, assembles prompts, invokes the Codex provider via terminal, reads provider output, updates artifacts, loops on consensus status, and persists state — but generates no review content or implementation code itself.
- **Location**: Ambient in the VS Code / GitHub Copilot environment; no installation step within this project
- **Interface**: Instruction-driven — command specs are Markdown documents that function as detailed procedural instructions. Claude executes shell commands (to call `ask_codex.sh`), reads/writes files (artifact files, `reviews/*.md`, `provider-state.json`, `.specify/peer.yml`), and follows the step-by-step procedures defined in each command file. The memory file (`peer-guide.md`) is injected by Spec Kit at the start of each session to prime the orchestrator role.
- **Error handling**: Claude is expected to surface all provider errors as structured stderr messages (`[peer/<command>] ERROR: <ERROR_CODE>: <message>`) and halt on unrecoverable errors. It must never silently fall back to generating review or implementation content inline when a provider call fails.

---

## GitHub Releases (Distribution)

- **Type**: Cloud artifact store (distribution channel)
- **Purpose**: Hosts the installable `peer.zip` archive so users can install the pack into their Spec Kit projects without cloning the repository.
- **Location**: GitHub Releases on this repository (e.g., `https://github.com/<org>/spec-kit-foundary/releases`)
- **Interface**: Users install via the `specify` CLI's install mechanism, pointing at the release artifact URL or tag. The release artifact is a zip file containing the `packs/peer/` directory tree.
- **Error handling**: Download failures are handled by the Spec Kit installer, not by this pack. The pack itself has no runtime dependency on GitHub Releases — it is a one-time install step only.
