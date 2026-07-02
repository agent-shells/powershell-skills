# Security Model

`powershell-skills` is designed to improve command reliability without collecting private command context or bypassing workspace controls.

## Non-Goals

The project does not:

- upload failures automatically
- collect telemetry
- run periodic background collection
- bypass Codex, Claude Code, OS, GitHub, npm, or workspace permission rules
- provide an automated destructive command runner
- accept raw logs, tokens, private paths, private repository names, or secrets into the failure corpus

## Destructive Operations

Destructive operations require validation outside the runner.

Examples include:

- recursive delete
- broad move or overwrite
- cleanup based on computed paths
- commands that mutate repositories, credentials, services, or user profiles

Helpers may classify, warn, or reject risky shapes, but they do not make destructive operations safe by themselves.

## Failure Corpus

The failure corpus is evidence for future rules. Cases must be:

- sanitized
- minimized
- reproducible without private context
- reviewed before merge

Do not submit raw command history or project logs.

## Contribution Review

Changes that affect command execution, install paths, update behavior, or failure corpus policy should be reviewed as security-sensitive. New rules should be backed by a minimal case and a test when practical.
