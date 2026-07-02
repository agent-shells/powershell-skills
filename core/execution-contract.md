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

These are the intended helper routes. During incremental development, if a helper script is not present yet, use the corresponding pattern file instead.

- Command missing or uncertain: run `core/scripts/Test-AgentCommand.ps1`; if unavailable, use `core/pattern-catalog/tool-discovery.md`.
- Path contains spaces, non-ASCII characters, or exact matching matters: run `core/scripts/Resolve-AgentPath.ps1`; if unavailable, use `core/pattern-catalog/path-handling.md`.
- Repeated failure: run `core/scripts/Classify-AgentFailure.ps1`; if unavailable, use `core/pattern-catalog/failure-retry.md`.
- Structured Application execution needed: run `core/scripts/Invoke-AgentCommand.ps1`; if unavailable, use the smallest matching pattern file in `core/pattern-catalog/`.
- Structured read-only PowerShell cmdlet execution needed: run `core/scripts/Invoke-AgentPowerShell.ps1`; do not use it for aliases, functions, non-allowlisted cmdlets, unknown parameters, free-form scripts, or destructive risk.
