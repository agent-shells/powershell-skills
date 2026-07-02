# Architecture

The repository is split into adapters, shared core behavior, scripts, tests, and release docs.

```text
adapters/codex/powershell-command-runner/       Codex skill adapter
adapters/claude-code/powershell-command-runner/ Claude Code skill adapter
bin/powershell-skills.js                        npm CLI
core/execution-contract.md                      shared command execution rules
core/pattern-catalog/                           reusable Windows and PowerShell patterns
core/scripts/                                   helper scripts
core/failure-corpus/                            sanitized failure evidence
core/tests/run-smoke.ps1                        helper behavior smoke tests
docs/                                           public project docs
scripts/install-codex-global.ps1                Codex global installer
scripts/install-codex-local.ps1                 Codex repo-local installer
scripts/install-claude-global.ps1               Claude Code global installer
scripts/verify-v0.1.ps1                         release verification
tests/npm-cli-smoke.js                          npm CLI smoke tests
```

## Boundaries

- `core/` contains reusable behavior and must not depend on one agent surface.
- `adapters/` contain agent-specific skill instructions and metadata.
- `scripts/` contain install and release workflows.
- `bin/` contains the npm command-line wrapper.
- `docs/releases/` contains release notes.

PowerShell scripts remain the source of truth. npm is a distribution and UX layer, not a replacement runtime.

## Adding a New Adapter

When adding a new agent surface:

1. Add a thin adapter under `adapters/<agent>/powershell-command-runner/`.
2. Reference shared material from `core/`.
3. Add an installer only if the agent has a stable user-level skill path.
4. Extend `powershell-skills doctor` only after the install path is clear.
5. Add verification before documenting the adapter as supported.

Avoid copying the full pattern catalog into each adapter. Reusable rules should stay in `core/`.
