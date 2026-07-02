# Helper Scripts

The helper scripts live in `core/scripts/`. They are designed for agent use and return structured output where practical.

## Discovery and Diagnosis

- `Test-AgentCommand.ps1`: checks command availability and returns structured JSON.
- `Resolve-AgentPath.ps1`: resolves paths with spaces, non-ASCII names, and `-LiteralPath`-safe behavior.
- `Classify-AgentFailure.ps1`: maps common PowerShell and Windows command errors to failure classes.

## External Application Runner

`Invoke-AgentCommand.ps1` runs external applications from structured JSON specs.

It supports:

- explicit executable path or command name
- argument arrays
- working directory
- environment overrides
- UTF-8 stdout and stderr capture
- timeout handling
- process-tree cleanup
- JSON result output

It intentionally rejects PowerShell cmdlets, aliases, and functions. Use the read-only PowerShell helper for supported cmdlets.

## Read-Only PowerShell Helper

`Invoke-AgentPowerShell.ps1` runs a constrained set of read-only PowerShell cmdlets from structured JSON specs.

V0.5 allowlist:

- `Test-Path`
- `Resolve-Path`
- `Get-Item`
- `Get-ChildItem`
- `Get-Content`
- `Get-Command`
- `Get-Location`
- `Get-Process`
- `Get-Service`
- `Select-String`

It rejects aliases, functions, unknown cmdlets, unknown parameters, unsupported parameter shapes, and destructive risk.

## Runner Boundary

Use this split:

- external application or `.exe`: `Invoke-AgentCommand.ps1`
- allowlisted read-only cmdlet: `Invoke-AgentPowerShell.ps1`
- general PowerShell script logic: normal agent shell execution with the adapter guidance

The project does not provide a general-purpose destructive command runner.
