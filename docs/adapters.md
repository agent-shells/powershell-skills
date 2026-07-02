# Adapter Behavior

`powershell-skills` currently ships two agent adapters:

- Codex: `adapters/codex/powershell-command-runner/SKILL.md`
- Claude Code: `adapters/claude-code/powershell-command-runner/SKILL.md`

Both adapters point to the shared `core/` catalog and scripts. Adapter files should stay thin; reusable behavior belongs in `core/`.

## Codex

The global installer copies a self-contained skill to:

```text
%USERPROFILE%\.codex\skills\powershell-command-runner
```

The adapter description is written to trigger on Windows, PowerShell, Windows shell tasks, external CLI calls, `.ps1` execution, path handling, encoding-sensitive output, filesystem operations, and command failure debugging.

The Codex adapter also includes:

```text
adapters/codex/powershell-command-runner/agents/openai.yaml
```

That metadata enables implicit invocation on OpenAI-compatible agent surfaces that honor it.

## Claude Code

The global installer copies a self-contained skill to:

```text
%USERPROFILE%\.claude\skills\powershell-command-runner
```

The Claude Code adapter is written for personal skill discovery and can also be invoked directly:

```text
/powershell-command-runner
```

When installed globally, the installer rewrites core references to use `${CLAUDE_SKILL_DIR}/core` so the skill remains self-contained outside the repository.

## Refreshing Discovery

After installing or updating, restart the agent or start a new session so the skill index refreshes.

If automatic discovery does not happen in a current session, use an explicit prompt:

```text
Use $powershell-command-runner when working in Windows or PowerShell shell environments.
```

The goal is to improve first-pass command selection. The project cannot force every agent runtime to invoke a skill if that runtime does not support automatic or implicit skill discovery.
