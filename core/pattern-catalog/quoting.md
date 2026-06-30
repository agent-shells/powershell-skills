# Quoting

status: active

## Trigger

Use when commands contain nested quotes, inline scripts, JSON, or paths with spaces.

## Safe Shape

- Prefer argument arrays or structured command specs over large shell strings.
- Use single quotes for literal PowerShell strings.
- Escape single quotes inside single-quoted strings by doubling them.
- Move complex inline code into a script file when quoting becomes fragile.

## Failure Signals

- `Unexpected token`
- unterminated string errors
- arguments merge or split unexpectedly
