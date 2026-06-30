# tool-discovery-missing-rg

- case_id: tool-discovery-missing-rg
- source: minimized-regression
- date: 2026-07-01
- agent_runtime: generic
- shell: PowerShell
- ps_version: 5.1-compatible
- symptom: Agent assumes `rg` exists and retries a missing executable.
- bad_command: `rg MARKER C:\Projects\example`
- error_excerpt: `The term 'rg' is not recognized`
- root_cause: Tool availability was not checked before execution.
- safe_pattern: Run `Get-Command rg` or `Test-AgentCommand.ps1` before relying on `rg`.
- linked_pattern: `core/pattern-catalog/tool-discovery.md`
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
