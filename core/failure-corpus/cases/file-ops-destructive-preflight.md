# file-ops-destructive-preflight

- case_id: file-ops-destructive-preflight
- source: minimized-regression
- date: 2026-07-01
- agent_runtime: generic
- shell: PowerShell
- ps_version: 5.1-compatible
- symptom: Recursive delete can target the wrong directory when paths are computed or wildcarded.
- bad_command: `Remove-Item $target -Recurse -Force`
- error_excerpt: destructive command without resolved target verification
- root_cause: Destructive operation ran without validating the resolved absolute path.
- safe_pattern: Resolve target, verify it is inside the intended workspace, then use `-LiteralPath`.
- linked_pattern: `core/pattern-catalog/file-ops-safety.md`
- regression_test: planned: `core/tests/run-smoke.ps1`
- status: classified
