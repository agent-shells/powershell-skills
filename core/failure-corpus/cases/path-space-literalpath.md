# path-space-literalpath

- case_id: path-space-literalpath
- source: minimized-regression
- date: 2026-07-01
- agent_runtime: generic
- shell: PowerShell
- ps_version: 5.1-compatible
- symptom: Path with spaces is split or interpreted incorrectly.
- bad_command: `Get-Content C:\Projects\example path\file.txt`
- error_excerpt: `Cannot find path`
- root_cause: Path argument was not quoted and exact interpretation was not requested.
- safe_pattern: Use quoted paths and `-LiteralPath` for exact local paths.
- linked_pattern: `core/pattern-catalog/path-handling.md`
- regression_test: planned: `core/tests/run-smoke.ps1`
- status: classified
