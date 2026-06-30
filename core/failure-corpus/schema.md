# Failure Corpus Schema

Cases are evidence. They are not runtime instructions.

## Lifecycle

`raw -> sanitized -> minimized -> classified -> tested -> promoted or rejected -> deprecated`

## Required Fields

- `case_id`
- `source`
- `date`
- `agent_runtime`
- `shell`
- `ps_version`
- `symptom`
- `bad_command`
- `error_excerpt`
- `root_cause`
- `safe_pattern`
- `linked_pattern`
- `regression_test`
- `status`

## Sanitization Rules

- Remove secrets, tokens, private URLs, private usernames, and private repository names.
- Replace home directories with `C:\Users\example`.
- Replace project paths with `C:\Projects\example`.
- Keep the failure shape intact.
