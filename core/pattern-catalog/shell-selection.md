# Shell Selection

status: active

## Trigger

Use when a command may be written with Bash, cmd.exe, PowerShell, or WSL syntax.

## Safe Shape

- Check the active shell before borrowing syntax from another platform.
- In PowerShell, use cmdlets, semicolons, and PowerShell variable syntax.
- Do not use Bash-only syntax such as `&&`, `$()`, `rm -rf`, or unescaped forward assumptions unless the active shell supports it.

## Failure Signals

- `The token '&&' is not a valid statement separator`
- `The term 'rm' is not recognized`
- path separators or quoting copied from Bash fail in PowerShell
