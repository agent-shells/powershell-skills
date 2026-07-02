---
name: powershell-command-runner
description: Use when Claude Code is operating on Windows, PowerShell, Windows shell tasks, external CLIs, .ps1 scripts, Windows paths, encoding-sensitive output, filesystem operations, process timeouts, or command failures. Trigger even when the user did not explicitly mention PowerShell.
---

# PowerShell Command Runner

Use this skill before running commands in Windows or PowerShell environments.

## Start Here

Read `../../../core/execution-contract.md` before high-risk Windows shell work.

This source adapter depends on the repo layout: keep `core/` at `../../../core`. The global Claude Code installer rewrites these references to `${CLAUDE_SKILL_DIR}/core` and bundles `core/` inside the installed skill.

Classify command risk:

- `normal`: simple read-only commands, git status, directory listings, version checks.
- `high`: external CLIs, paths with spaces or non-ASCII characters, archives, generated scripts, encoding-sensitive output.
- `destructive`: recursive delete, recursive move, broad overwrite, commands outside the current workspace.
- `diagnostic`: a command failed once and needs a changed shape.

## Default Behavior

- Keep normal commands lightweight.
- Use PowerShell syntax in PowerShell sessions.
- Prefer native PowerShell file commands for file operations.
- Prefer `-LiteralPath` when exact path handling matters.
- Follow Claude Code permission prompts; do not use this skill to bypass tool, OS, workspace, or user approval rules.
- Check external tools with `../../../core/scripts/Test-AgentCommand.ps1` before relying on them in high-risk commands, or whenever availability or source is uncertain.
- Check exact paths with `../../../core/scripts/Resolve-AgentPath.ps1` when spaces, non-ASCII characters, or destructive operations are involved.
- Classify repeated failures with `../../../core/scripts/Classify-AgentFailure.ps1`.
- Use `../../../core/scripts/Invoke-AgentCommand.ps1` when structured stdout, stderr, exit code, timeout, cwd, or environment handling matters.
- `Invoke-AgentCommand.ps1` runs Application commands only. Do not use it for PowerShell cmdlets, functions, or aliases; use normal PowerShell directly for cmdlets.

## Pattern Routing

- Shell mismatch: `../../../core/pattern-catalog/shell-selection.md`
- Paths: `../../../core/pattern-catalog/path-handling.md`
- Quoting: `../../../core/pattern-catalog/quoting.md`
- Encoding: `../../../core/pattern-catalog/encoding.md`
- Tool discovery: `../../../core/pattern-catalog/tool-discovery.md`
- Parser traps: `../../../core/pattern-catalog/powershell-parser.md`
- File operation safety: `../../../core/pattern-catalog/file-ops-safety.md`
- Timeout and process handling: `../../../core/pattern-catalog/timeout-and-process.md`
- Repeated failure: `../../../core/pattern-catalog/failure-retry.md`

## Claude Code Invocation

Claude Code discovers this personal skill from `~/.claude/skills/powershell-command-runner/SKILL.md` and may load it automatically when the description matches the current task. It can also be invoked directly with `/powershell-command-runner`.

Do not require the human user to say "use PowerShell" before applying these rules. If the session is on Windows, or a command will touch PowerShell, Windows paths, process control, encoding, or filesystem behavior, apply the skill proactively.

## Stop Rules

- Do not repeat the same failed command shape.
- After the second failed command shape, stop and report the blocker unless new evidence changes the diagnosis.
- Do not run destructive filesystem commands without resolved target validation.
- Do not use helper scripts to bypass Claude Code permissions, OS permissions, or workspace restrictions.
- Do not upload, auto-record, or commit raw private failure logs.
