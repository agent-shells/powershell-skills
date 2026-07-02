# Changelog

All notable changes to this project are documented here.

## v0.5 - Read-Only PowerShell Helper

Release date: 2026-07-02

- Added `core/scripts/Invoke-AgentPowerShell.ps1`.
- Added structured JSON execution for allowlisted read-only cmdlets.
- Added allowlist coverage for `Test-Path`, `Resolve-Path`, `Get-Item`, `Get-ChildItem`, `Get-Content`, `Get-Command`, `Get-Location`, `Get-Process`, `Get-Service`, and `Select-String`.
- Rejected aliases, functions, unknown cmdlets, unknown parameters, unsupported parameter shapes, and destructive risk.
- Kept `Invoke-AgentCommand.ps1` Application-only.
- Added smoke tests for read-only cmdlet success and policy rejection cases on Windows PowerShell 5.1 and PowerShell 7.
- Updated Codex and Claude Code adapters to route structured read-only cmdlet work to the new helper.
- Fixed Windows npm CLI dispatch so `doctor` and `update` handle npm's `.cmd` shim correctly.
- Published the package to the npm registry as `@agent-shells/powershell-skills`.

## v0.4 - npm Distribution and Install UX

Release date: 2026-07-02

- Added npm package metadata for `@agent-shells/powershell-skills`.
- Added `powershell-skills` CLI with:
  - `install codex`
  - `install claude-code`
  - `install all`
  - `doctor`
  - `update`
- Added JSON output support for install and doctor workflows.
- Added explicit update dry-run support so update actions can be inspected before execution.
- Added npm CLI smoke tests.
- Updated release verification to include package metadata, CLI files, and npm tests.

## v0.3 - Claude Code Adapter

Release date: 2026-07-02

- Added Claude Code personal skill adapter at `adapters/claude-code/powershell-command-runner/`.
- Added `scripts/install-claude-global.ps1` for self-contained installs under `~/.claude/skills/powershell-command-runner`.
- Bundled `core/` into the Claude Code install and rewrote references to `${CLAUDE_SKILL_DIR}/core`.
- Verified Claude Code in a real local session:
  - explicit `/powershell-command-runner` invocation works in normal mode
  - automatic skill loading works for a Windows path task
  - Claude Code used `Test-Path -LiteralPath` for a path containing a space and Chinese characters
- Fixed redirected UTF-8 verification so release checks pass in GitHub Actions when smoke tests are run through a parent PowerShell process.

## v0.2 - PowerShell Compatibility Matrix

Release date: 2026-07-02

- Added GitHub Actions CI on `windows-latest`.
- Added matrix coverage for Windows PowerShell 5.1 through `powershell.exe` and PowerShell 7 through `pwsh`.
- Parameterized smoke and release verification scripts with `-PowerShellExe`.
- Fixed helper compatibility differences across 5.1 and 7, including JSON shape handling and current-host helper invocation.
- Updated README compatibility and verification sections.

## v0.1 - Codex Skill Foundation

Release date: 2026-07-02

- Added Codex skill adapter at `adapters/codex/powershell-command-runner/`.
- Added shared execution contract, pattern catalog, helper scripts, and seed failure corpus.
- Added local Codex development install through `.agents/skills`.
- Added global Codex install through `~/.codex/skills/powershell-command-runner`.
- Added release verification script and smoke test suite.
- Established project safety boundary: no automatic telemetry, no failure upload, and no raw user context collection.
