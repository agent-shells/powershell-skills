# ps-parser-foreach-pipeline

- case_id: ps-parser-foreach-pipeline
- source: local-codex-session
- date: 2026-07-01
- agent_runtime: Codex
- shell: PowerShell
- ps_version: unknown
- symptom: Parser error when piping directly after a `foreach` statement.
- bad_command: `$rows = foreach ($x in $items) { [pscustomobject]@{ name=$x } } | Format-Table`
- error_excerpt: `An empty pipe element is not allowed.`
- root_cause: PowerShell parser boundary between a statement block and a pipeline.
- safe_pattern: Assign statement output to a variable, then pipe the variable.
- linked_pattern: `core/pattern-catalog/powershell-parser.md`
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
