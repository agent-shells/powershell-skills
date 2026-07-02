# Security Policy

## Supported Versions

Security fixes are accepted on `main`. The latest tagged release is the supported release line.

| Version | Supported |
| --- | --- |
| v0.3.x | Yes |
| v0.2.x | No, upgrade to v0.3.x |
| v0.1.x | No, upgrade to v0.3.x |

## Reporting a Vulnerability

Open a private security report through GitHub if available, or open a minimal public issue that does not include secrets or exploitable private details.

Do not include:

- credentials, tokens, API keys, cookies, or private keys
- raw logs from private projects
- private repository names
- private filesystem paths
- customer data
- proprietary source code

## Security Boundaries

This project must not:

- bypass Codex, Claude Code, OS, shell, GitHub, or workspace permission rules
- add automatic failure upload, telemetry, scheduled collection, or raw context submission
- execute destructive filesystem operations without explicit target validation
- hide command execution from the agent surface or user permission model

## Maintainer Response

Maintainers should triage security reports by impact:

- `critical`: credential exposure, privilege bypass, destructive execution without validation
- `high`: command injection, unsafe path handling, unsafe default install/update behavior
- `medium`: privacy leak in docs, logs, examples, or failure corpus
- `low`: hardening or documentation-only issues

Accepted fixes should include a regression test when practical.
