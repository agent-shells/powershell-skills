# Tool Discovery

status: active

## Trigger

Use before depending on an external executable such as `git`, `rg`, `python`, `node`, `pandoc`, or `ffmpeg`.

## Safe Shape

- Run `Get-Command <name>` before the main command when tool availability matters.
- Capture source path and version when available.
- Use a native PowerShell fallback when the external tool is absent and the task is simple.

## Failure Signals

- `The term '<name>' is not recognized`
- executable path is not the expected one
- repeated retries call a missing executable
