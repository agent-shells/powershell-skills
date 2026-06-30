# Execution Contract

Use this contract before Windows shell work.

## Default Rules

- Prefer PowerShell syntax when the active shell is PowerShell.
- Treat paths, quoting, encoding, and command discovery as execution concerns.
- Use native PowerShell filesystem commands when they fit the task.
- Use `-LiteralPath` for exact local paths.
- Validate high-risk targets before acting.
- Do not repeat the same failed command shape.

## Risk Routing

- `normal`: run with standard quoting and cwd awareness.
- `high`: read the smallest matching pattern and use preflight checks.
- `destructive`: validate resolved absolute paths before execution.
- `diagnostic`: classify the failure before retrying.

## Helper Routing

- Command missing or uncertain: run `core/scripts/Test-AgentCommand.ps1`.
- Path contains spaces, non-ASCII characters, or exact matching matters: run `core/scripts/Resolve-AgentPath.ps1`.
- Repeated failure: run `core/scripts/Classify-AgentFailure.ps1`.
- Structured execution needed: run `core/scripts/Invoke-AgentCommand.ps1`.
