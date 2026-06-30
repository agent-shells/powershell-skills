# Path Handling

status: active

## Trigger

Use when paths may contain spaces, non-ASCII characters, wildcards, brackets, or deep directories.

## Safe Shape

- Prefer `Join-Path` for constructed paths.
- Quote path arguments.
- Use `-LiteralPath` when exact interpretation matters.
- Validate existence with `Test-Path -LiteralPath`.

## Failure Signals

- `Cannot find path`
- wildcard expansion affects the wrong target
- a path with spaces is split into several arguments
