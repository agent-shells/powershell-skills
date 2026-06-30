# encoding-python-utf8

- case_id: encoding-python-utf8
- source: minimized-regression
- date: 2026-07-01
- agent_runtime: generic
- shell: PowerShell
- ps_version: 5.1-compatible
- symptom: Non-ASCII Python output may fail or display incorrectly.
- bad_command: `python -c "print('non-ascii text')"`
- error_excerpt: `UnicodeEncodeError` or mojibake
- root_cause: Windows default encoding may not match expected UTF-8 output.
- safe_pattern: Set `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1` when Python emits non-ASCII text.
- linked_pattern: `core/pattern-catalog/encoding.md`
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
