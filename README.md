# powershell-skills

PowerShell skills and guardrails for reliable Windows command execution by AI agents.

[![npm version](https://img.shields.io/npm/v/@agent-shells/powershell-skills.svg)](https://www.npmjs.com/package/@agent-shells/powershell-skills)
[![CI](https://github.com/agent-shells/powershell-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/agent-shells/powershell-skills/actions/workflows/ci.yml)

General-purpose coding agents often run Windows and PowerShell less smoothly than Linux or macOS shells. This project gives agents a small, tested runtime aid: agent-facing skills, safe command shapes, compatibility checks, and helper scripts that reduce common Windows command failures.

## Installation

Install from npm:

```powershell
npm install -g @agent-shells/powershell-skills
powershell-skills install all
powershell-skills doctor
```

Update explicitly:

```powershell
powershell-skills update
```

Install only one adapter:

```powershell
powershell-skills install codex
powershell-skills install claude-code
```

GitHub install is still supported for unreleased branches or tags:

```powershell
npm install -g github:agent-shells/powershell-skills#v0.5.1
```

## Features

- Codex adapter for user-level skill discovery under `~/.codex/skills`.
- Claude Code adapter for personal skill discovery under `~/.claude/skills`.
- `powershell-skills` CLI for install, update, and doctor workflows.
- Shared execution contract, pattern catalog, and sanitized failure corpus.
- PowerShell helper scripts for path resolution, command discovery, failure classification, external application execution, and read-only cmdlet execution.
- `Invoke-AgentPowerShell.ps1` for structured, allowlisted, read-only cmdlets.
- Windows PowerShell 5.1 and PowerShell 7 verification through GitHub Actions CI.

## Triggering

The adapters are written for agents, not for humans to prefix every command manually.

- Codex discovers `powershell-command-runner` from `~/.codex/skills`.
- Claude Code discovers `powershell-command-runner` from `~/.claude/skills`.
- Both adapters describe Windows, PowerShell, path handling, encoding, filesystem, timeout, and command-failure tasks as trigger cases.

If a current agent session has not refreshed its skill index, restart the agent or start a new session. Details are in [adapter behavior](docs/adapters.md).

## Compatibility

The project is tested on:

- Windows PowerShell 5.1 through `powershell.exe`.
- PowerShell 7 through `pwsh`.
- Node.js 18+ for the npm CLI wrapper.

The npm layer is distribution and install UX. PowerShell scripts remain the compatibility source of truth. See [compatibility and verification](docs/compatibility.md).

## Commands

```powershell
powershell-skills install codex
powershell-skills install claude-code
powershell-skills install all
powershell-skills doctor
powershell-skills update
```

Use `powershell-skills doctor` after install or update to check package files, PowerShell hosts, npm, and installed skill locations.

## Verification

Run local checks:

```powershell
npm test
npm pack --dry-run
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-v0.1.ps1 -PowerShellExe pwsh
```

Expected result:

```text
[OK] npm CLI smoke tests passed
[OK] release verification passed
```

## Docs

| Topic | Document |
| --- | --- |
| Agent adapters and auto-trigger behavior | [docs/adapters.md](docs/adapters.md) |
| Helper scripts and runners | [docs/helpers.md](docs/helpers.md) |
| PowerShell 5.1 / 7 compatibility | [docs/compatibility.md](docs/compatibility.md) |
| Architecture and repository layout | [docs/architecture.md](docs/architecture.md) |
| Security model and contribution boundaries | [docs/security-model.md](docs/security-model.md) |
| Field-test notes | [docs/field-tests/README.md](docs/field-tests/README.md) |

## Release Notes

- [v0.1](docs/releases/v0.1.md): Codex skill foundation.
- [v0.2](docs/releases/v0.2.md): PowerShell 5.1 / 7 compatibility matrix and CI.
- [v0.3](docs/releases/v0.3.md): Claude Code adapter.
- [v0.4](docs/releases/v0.4.md): npm distribution, update, doctor, and install UX.
- [v0.5](docs/releases/v0.5.md): read-only PowerShell cmdlet helper.
- [v0.5.1](docs/releases/v0.5.1.md): README and documentation polish.

## Contributing and Security

- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

This project accepts normal reviewed issues and pull requests. It does not include automatic telemetry, automatic failure upload, periodic collection, or upload of user command context.

## Current Limits

- Supported adapters are Codex and Claude Code.
- Updates are explicit; there is no background auto-update service.
- `Invoke-AgentCommand.ps1` runs external applications only.
- `Invoke-AgentPowerShell.ps1` is read-only and allowlist-based; it is not a general PowerShell script runner.
- Destructive command execution is not automated and requires validation outside the runner.
- The failure corpus accepts only maintainer-reviewed, sanitized, minimized cases.
