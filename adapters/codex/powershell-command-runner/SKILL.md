---
name: powershell-command-runner
description: Use whenever Codex is operating on Windows, PowerShell, or Windows shell tasks and is about to run shell commands, inspect files, invoke external CLIs, write or run .ps1 scripts, handle Windows paths, process non-ASCII output, perform filesystem operations, or debug command failures. Trigger even when the user did not explicitly mention PowerShell.
---

# PowerShell Command Runner

Use this skill to make Windows shell execution boring and reliable.

## Start Here

Read `../../../core/execution-contract.md` before high-risk Windows shell work.

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
- Check external tools with `../../../core/scripts/Test-AgentCommand.ps1` before relying on them in high-risk commands.
- Check exact paths with `../../../core/scripts/Resolve-AgentPath.ps1` when spaces, non-ASCII characters, or destructive operations are involved.
- Classify repeated failures with `../../../core/scripts/Classify-AgentFailure.ps1`.
- Use `../../../core/scripts/Invoke-AgentCommand.ps1` when structured stdout, stderr, exit code, timeout, cwd, or environment handling matters.

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

## Stop Rules

- Do not repeat the same failed command shape.
- Do not run destructive filesystem commands without resolved target validation.
- Do not use a helper script to bypass host permission or sandbox rules.
- Do not commit raw private failure logs to the corpus.
