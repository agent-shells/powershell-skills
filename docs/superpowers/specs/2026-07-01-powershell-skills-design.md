# PowerShell Skills Design

## Goal

Build an agent-facing Windows and PowerShell execution enhancement package that helps general-purpose coding agents run commands on Windows with fewer retries, fewer shell-shape mistakes, and a smoother experience closer to Linux and macOS terminal work.

The human user installs the package. The primary user is the agent.

The first supported adapter is Codex, but the product goal is not Codex-only. The core knowledge, scripts, failure corpus, and tests must remain portable enough to support Claude Code, Cline, OpenCode, and other terminal-capable agents later.

## Non-Goals

- Do not create a human PowerShell tutorial.
- Do not maintain a growing flat list of one-off rules.
- Do not copy an existing static guardrail skill with only minor wording changes.
- Do not require the human user to explicitly say "use PowerShell" before the guidance matters.
- Do not attempt to solve all Windows automation domains such as Outlook, browser control, or desktop automation in the first version.

## Design Principle

Experience can grow without letting runtime context grow.

Failures should flow through this pipeline:

```text
real failure -> minimized case -> taxonomy -> pattern or helper -> regression test -> compact skill update
```

Cases may accumulate indefinitely. The active skill instructions should stay small and route the agent to the smallest relevant pattern or script.

## Architecture

```text
powershell-skills/
  core/
    execution-contract.md
    pattern-catalog/
      shell-selection.md
      path-handling.md
      quoting.md
      encoding.md
      tool-discovery.md
      powershell-parser.md
      file-ops-safety.md
      timeout-and-process.md
      failure-retry.md
    scripts/
      Invoke-AgentCommand.ps1
      Test-AgentCommand.ps1
      Resolve-AgentPath.ps1
      Classify-AgentFailure.ps1
    failure-corpus/
      cases/
      minimized/
      schema.md
    tests/
  adapters/
    codex/
      powershell-command-runner/
        SKILL.md
        agents/openai.yaml
    claude-code/
      hooks/
      SKILL.md
    generic-agent-skills/
      SKILL.md
  docs/
    superpowers/specs/
```

## Components

### Core Execution Contract

`core/execution-contract.md` contains the few rules that should apply before most Windows shell work:

- Detect the current shell and prefer PowerShell syntax when the active environment is PowerShell.
- Treat path handling, quoting, encoding, and tool discovery as first-class execution concerns.
- Use native PowerShell operations for filesystem tasks unless another tool is clearly required.
- Use preflight checks for high-risk commands.
- Stop repeating the same failed command shape.
- Escalate from normal command to pattern, helper script, or failure classifier based on risk.

### Pattern Catalog

The pattern catalog stores abstract reusable patterns, not incident logs. Each pattern should have:

- purpose
- trigger
- safe command shape
- when to call a helper script
- common failure signals
- related regression cases
- status: `active`, `experimental`, or `deprecated`

Patterns are promoted from failure cases only when they are frequent, reproducible, abstractable, and testable.

### Helper Scripts

Scripts handle deterministic and fragile work that agents frequently rewrite incorrectly:

- `Test-AgentCommand.ps1`: discover commands, executable path, version, and availability.
- `Resolve-AgentPath.ps1`: normalize exact Windows paths and recommend `-LiteralPath` usage.
- `Invoke-AgentCommand.ps1`: run commands with structured stdout, stderr, exit code, timeout, working directory, and environment handling.
- `Classify-AgentFailure.ps1`: classify failures into shell mismatch, parser boundary, quoting, path, encoding, missing tool, permission, timeout, or destructive-op risk.

Scripts should emit JSON where practical so agents can consume results reliably.

### Failure Corpus

The corpus is the memory of the project, but it is not loaded by default into agent context.

Each case should be minimized and sanitized:

```text
case_id:
source:
date:
agent_runtime:
shell:
ps_version:
symptom:
bad_command:
error_excerpt:
root_cause:
safe_pattern:
linked_pattern:
regression_test:
status:
```

No raw secrets, tokens, private repo names, private usernames, or sensitive paths should be committed.

### Adapters

The Codex adapter is first because it is immediately testable in this workspace.

The Codex `SKILL.md` should trigger when Codex is operating in a Windows, PowerShell, or Windows shell environment and is about to run shell commands, inspect files, invoke external CLIs, write scripts, handle paths, or debug command failures. It should not require the user to mention PowerShell explicitly.

The Claude Code adapter is a later layer. It may include hooks that block or rewrite unsafe command shapes before execution.

The generic adapter should track the open agent skills shape and avoid runtime-specific metadata.

## Execution Flow

1. Classify command risk:
   - normal command
   - high-risk command
   - destructive command
   - repeated failure
2. For normal commands, apply the execution contract and keep overhead low.
3. For high-risk commands, route to the smallest relevant pattern.
4. For destructive commands, require explicit target validation and safe path handling.
5. For repeated failures, run or emulate failure classification before trying another command shape.
6. When a new stable failure pattern appears, add a sanitized corpus case first, then decide whether it deserves pattern or script changes.

## Maintenance Model

Do not add a new rule for every new failure.

Use this promotion path:

```text
case -> minimized case -> linked taxonomy category -> regression test -> pattern/script update if justified
```

A case can be promoted only if it satisfies:

- reproduced or clearly evidenced
- sanitized
- not already covered by an existing pattern
- general enough to affect more than one task
- testable without private state

Run periodic compression:

- merge near-duplicate cases
- fold several similar cases into one pattern
- move stale patterns to `deprecated`
- keep `SKILL.md` concise

## Taxonomy

Initial categories:

- `shell-selection`
- `path-handling`
- `quoting`
- `encoding`
- `tool-discovery`
- `powershell-parser`
- `file-ops-safety`
- `execution-policy`
- `timeout-and-process`
- `failure-retry`

This taxonomy is allowed to evolve, but changes should be deliberate because it anchors the corpus, patterns, and tests.

## Testing

Testing should prove behavior, not just validate Markdown.

Initial regression targets:

- paths containing spaces
- paths containing non-ASCII characters
- deep paths and Windows path length pressure
- missing `rg` fallback
- UTF-8 Python output from PowerShell
- `foreach` statement output followed by formatting
- `Test-Path` and `-LiteralPath` exact path handling
- recursive delete preflight
- timeout and exit code capture

Useful metrics:

- fewer repeated identical command failures
- fewer parser errors
- lower retry count per task
- correct helper-script invocation for high-risk cases
- destructive operations blocked until path validation succeeds
- Chinese and space-containing paths handled correctly

## Competitor Baseline

`windows-agent-guardrails` is the direct baseline. It validates the problem and provides a useful static guardrail shape, but it does not provide the full target experience:

- no execution wrapper
- no failure corpus promotion process
- no regression harness
- no runtime adapter split
- no hook or command interception layer

This project should not compete by adding more prose rules. It should compete by turning experience into compact patterns, tested helper scripts, and adapter-specific runtime behavior.

## Version Scope

### V0.1

- Codex adapter
- compact `SKILL.md`
- core execution contract
- first pattern catalog categories
- first helper script skeletons with representative tests
- first sanitized failure cases from known local examples

### V0.2

- richer failure classifier
- stricter destructive-op preflight
- more Windows regression cases
- install and validation flow for Codex

### V0.3

- Claude Code adapter and hook experiment
- generic agent skills packaging
- broader community failure corpus workflow

## V0.1 Defaults

- Keep the repository name `powershell-skills`; use clearer names for individual adapters and skills.
- Keep helper scripts compatible with Windows PowerShell 5.1 where practical, because many Windows machines still expose it by default. Document any PowerShell 7-only behavior explicitly.
- Make `Invoke-AgentCommand.ps1` accept a structured command spec first. Avoid encouraging agents to pass large arbitrary shell strings when a safer structured shape is available.
- Keep adapter-specific behavior thin in V0.1. If adapter logic grows beyond metadata, skill wording, and small launch wrappers, move it toward a plugin or hook layer in a later version.
