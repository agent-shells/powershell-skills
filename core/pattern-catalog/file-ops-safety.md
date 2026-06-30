# File Operations Safety

status: active

## Trigger

Use for copy, move, delete, overwrite, archive extraction, or recursive operations.

## Safe Shape

- Resolve and validate absolute target paths first.
- Use `-LiteralPath` for exact source paths.
- Keep recursive delete and broad overwrite in `destructive` risk.
- Never combine PowerShell enumeration with another shell for deletion.

## Failure Signals

- operation affects the wrong path
- wildcard expands unexpectedly
- recursive operation target was not verified
