# powershell-skills

PowerShell skills and guardrails for reliable Windows command execution by AI agents.

This project exists because general-purpose coding agents often handle Windows and PowerShell less smoothly than Linux or macOS shells. It helps agents choose safer PowerShell command shapes, avoid common Windows command failures, and recover from failures without repeating the same broken command.

## Release Status

- V0.1: Codex skill adapter, shared PowerShell execution contract, pattern catalog, helper scripts, failure corpus, local/global Codex installers, and release verification.
- V0.2: Windows PowerShell 5.1 and PowerShell 7 compatibility matrix with GitHub Actions CI.
- V0.3: Claude Code skill adapter and global Claude Code installer.

## Features

- Codex skill adapter: `adapters/codex/powershell-command-runner/SKILL.md`
  - Triggers on Windows, PowerShell, Windows shell tasks, file inspection, CLI calls, `.ps1` execution, path handling, encoding-sensitive output, filesystem operations, and command failure debugging.
  - Includes `agents/openai.yaml` with implicit invocation metadata for OpenAI-compatible agent surfaces.
- Claude Code skill adapter: `adapters/claude-code/powershell-command-runner/SKILL.md`
  - Uses Claude Code's personal skill path and automatic description-based triggering.
  - Supports direct invocation through `/powershell-command-runner`.
- Execution contract: `core/execution-contract.md`
  - Defines risk routing for `normal`, `high`, `destructive`, and `diagnostic` command work.
  - Requires target validation for destructive filesystem operations.
  - Prevents repeating the same failed command shape.
- Pattern catalog: `core/pattern-catalog/`
  - Covers shell selection, path handling, quoting, encoding, tool discovery, PowerShell parser traps, file operation safety, timeouts/process cleanup, and failure retry behavior.
- Helper scripts: `core/scripts/`
  - `Test-AgentCommand.ps1`: structured command discovery with JSON output.
  - `Resolve-AgentPath.ps1`: path resolution for spaces, non-ASCII names, and `-LiteralPath` usage.
  - `Classify-AgentFailure.ps1`: maps common error text to failure classes.
  - `Invoke-AgentCommand.ps1`: spec-driven Application command runner with JSON result output, cwd/env handling, UTF-8 stdout/stderr capture, timeout handling, process-tree cleanup, argument validation, and destructive-risk blocking.
- Failure corpus: `core/failure-corpus/`
  - Stores sanitized, minimized failure cases as evidence for future rules.
  - V0.1 includes seed cases for encoding, path spaces, parser traps, missing tools, and destructive-operation preflight.
- Verification suite:
  - `core/tests/run-smoke.ps1` runs behavioral smoke tests for helpers.
  - `scripts/verify-v0.1.ps1` checks the publishable repo layout, skill metadata, install path, smoke tests, and README release sections.
  - `.github/workflows/ci.yml` runs the verification suite on Windows PowerShell 5.1 and PowerShell 7.
- Installers:
  - `scripts/install-codex-global.ps1` installs a self-contained user-level Codex skill under `~/.codex/skills`.
  - `scripts/install-codex-local.ps1` installs a repo-local development skill under `.agents/skills`.
  - `scripts/install-claude-global.ps1` installs a self-contained user-level Claude Code skill under `~/.claude/skills`.

## Installation

V0.3 provides global Codex and Claude Code installs plus a repo-local Codex development install. It does not publish an npm package yet.

Recommended Codex global install:

```powershell
git clone https://github.com/agent-shells/powershell-skills.git
cd powershell-skills
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-codex-global.ps1
```

The global installer creates a self-contained copy at:

```text
%USERPROFILE%\.codex\skills\powershell-command-runner
```

It bundles the `core/` catalog inside the installed skill so relative references work from the global Codex skill directory. Restart Codex or start a new session after installation so the skill index refreshes.

Recommended Claude Code global install:

```powershell
git clone https://github.com/agent-shells/powershell-skills.git
cd powershell-skills
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-claude-global.ps1
```

The Claude Code installer creates a self-contained copy at:

```text
%USERPROFILE%\.claude\skills\powershell-command-runner
```

It bundles the `core/` catalog inside the installed skill and rewrites core references to `${CLAUDE_SKILL_DIR}/core`. Restart Claude Code or start a new session after installation so the personal skill index refreshes.

Repo-local development install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-codex-local.ps1
```

The local installer creates this junction:

```text
.agents\skills\powershell-command-runner -> adapters\codex\powershell-command-runner
```

Use the repo-local install when developing the skill from this checkout. Use the global install when you want Codex to discover the skill from other Windows projects.

## Triggering

The adapters are designed to be used by agents, not by humans typing special commands before every task.

The global install places the skill in Codex's user-level skill directory. Future Codex sessions can discover it outside this repository. The skill front matter says to use it whenever Codex is operating on Windows, PowerShell, Windows shell tasks, external CLIs, Windows paths, encoding-sensitive output, filesystem operations, or command failure debugging. The OpenAI adapter metadata also enables implicit invocation:

```yaml
policy:
  allow_implicit_invocation: true
```

If automatic discovery does not happen in a current session, restart Codex or start a new session. If a given agent surface still does not honor implicit invocation, use this explicit prompt:

```text
Use $powershell-command-runner when working in Windows or PowerShell shell environments.
```

Claude Code discovers the skill from `~/.claude/skills/powershell-command-runner/SKILL.md`. Its description is written to trigger automatically for Windows, PowerShell, Windows paths, external CLI, encoding, filesystem, timeout, and command-failure work. It can also be invoked directly:

```text
/powershell-command-runner
```

## Compatibility

The core scripts are tested on both Windows PowerShell 5.1 and PowerShell 7 through GitHub Actions on `windows-latest`.

- Windows PowerShell 5.1: verified through `powershell.exe`.
- PowerShell 7: verified through `pwsh`.
- Helper scripts avoid PowerShell 7-only syntax.
- `Invoke-AgentCommand.ps1` can run either PowerShell host as an Application command when it is explicitly requested.

## Verification

Run the smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\core\tests\run-smoke.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\core\tests\run-smoke.ps1 -PowerShellExe pwsh
```

Expected result:

```text
[OK] smoke tests passed
```

Run the release verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1 -PowerShellExe pwsh
```

Expected result:

```text
[OK] release verification passed
```

Verify global installation on the current machine:

```powershell
Test-Path "$env:USERPROFILE\.codex\skills\powershell-command-runner\SKILL.md"
Test-Path "$env:USERPROFILE\.claude\skills\powershell-command-runner\SKILL.md"
```

Expected result:

```text
True
True
```

## Current Limits

- Supported adapters are Codex and Claude Code. Other agent adapters are not implemented yet.
- No npm package, installer package, or auto-update channel exists yet. Update by pulling the repo and re-running the relevant global installer.
- `Invoke-AgentCommand.ps1` V0.1 runs Application commands only. It intentionally rejects PowerShell cmdlets, functions, and aliases. Use normal PowerShell syntax directly for cmdlets.
- Destructive command execution is not automated. Destructive risk requires explicit validation outside the runner.
- There is no failure-experience upload feature, no automatic telemetry, no periodic collection, and no upload of user command context.
- Open-source developer contributions are welcome through normal reviewed issues and pull requests.
- The failure corpus accepts only maintainer-reviewed, sanitized, minimized cases. Raw logs, secrets, private paths, private repository names, and tokens do not belong in the corpus.
- This project does not bypass Codex, OS, shell, GitHub, or workspace permission rules.

## Project Layout

```text
adapters/codex/powershell-command-runner/  Codex skill adapter
adapters/claude-code/powershell-command-runner/ Claude Code skill adapter
core/execution-contract.md                 Shared execution rules
core/pattern-catalog/                      Reusable PowerShell/Windows failure patterns
core/scripts/                              JSON-oriented helper scripts
core/failure-corpus/                       Sanitized failure evidence and schema
core/tests/run-smoke.ps1                   Helper behavior smoke tests
.github/workflows/ci.yml                   Windows PowerShell 5.1 and PowerShell 7 CI
scripts/install-codex-global.ps1           Global Codex skill install
scripts/install-codex-local.ps1            Repo-local Codex skill install
scripts/install-claude-global.ps1          Global Claude Code skill install
scripts/verify-v0.1.ps1                    V0.1 release verification
```

## Roadmap

- Add a packaged distribution channel after the global installer proves stable.
- Add adapters for other agent surfaces without duplicating the core catalog.
- Promote repeated failure cases into tests before adding new rules.
