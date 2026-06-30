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

## Acceptance Criteria

V0.1 is acceptable only if it can be installed, discovered, and verified in Codex on Windows.

Required outcomes:

- Codex can discover the Codex adapter skill without the human explicitly naming PowerShell.
- The skill description clearly targets Windows, PowerShell, shell command execution, file inspection, external CLI invocation, script writing, and command failure debugging.
- Normal low-risk shell commands keep low overhead and do not require helper scripts by default.
- High-risk commands have a documented route to a pattern or helper script.
- Destructive filesystem operations require explicit target validation and exact path handling.
- Repeated command failures route to failure classification instead of repeating the same command shape.
- Helper scripts can be run directly on Windows PowerShell 5.1 where practical.
- At least one smoke test passes for each initial helper script.
- At least five sanitized failure cases exist and link to taxonomy categories.
- Tests cover paths with spaces, non-ASCII paths, UTF-8 output, missing command discovery, and one parser-boundary failure.

Measured signals:

- Agent retry count should decrease on covered regression tasks.
- Parser-boundary and quoting failures should be classified rather than retried blindly.
- Destructive operations should be blocked or marked unsafe until path validation succeeds.
- Chinese and space-containing paths should be handled in smoke tests.

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

### Structured Command Spec

`Invoke-AgentCommand.ps1` should prefer a structured command spec over a large arbitrary shell string.

Initial JSON input shape:

```json
{
  "command": "git",
  "args": ["status", "--short"],
  "cwd": "C:\\Users\\example\\project",
  "timeout_seconds": 30,
  "env": {
    "PYTHONIOENCODING": "utf-8"
  },
  "risk": "normal"
}
```

Fields:

- `command`: executable or PowerShell command name. Required.
- `args`: argument array. Default: empty array.
- `cwd`: working directory. Optional. When provided, validate it before execution.
- `timeout_seconds`: positive integer timeout. Default: 30.
- `env`: environment overrides for the child process. Default: empty object.
- `risk`: one of `normal`, `high`, `destructive`, or `diagnostic`.

Initial JSON output shape:

```json
{
  "status": "success",
  "exit_code": 0,
  "stdout": "",
  "stderr": "",
  "duration_ms": 123,
  "classification": null
}
```

Failure output should use `status: "error"` and include `classification` when a known failure category is detected.

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

### V0.1 Install And Verify Flow

The first install path is local Codex discovery:

1. Create the Codex adapter skill under `adapters/codex/powershell-command-runner/`.
2. Symlink or copy that skill folder into a Codex-discoverable location during local validation.
3. Restart Codex only if automatic skill discovery does not pick up the new skill.
4. Verify discovery by checking that the skill appears in the available skills list or can be explicitly invoked.
5. Run helper script smoke tests from the repository root.
6. Run one agent-facing prompt test that asks for a Windows file or shell task without mentioning PowerShell.

V0.1 should document the exact local install command once the folder layout exists.

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
raw -> sanitized -> minimized -> classified -> tested -> promoted or rejected -> deprecated
```

A case can be promoted only if it satisfies:

- reproduced or clearly evidenced
- sanitized
- not already covered by an existing pattern
- general enough to affect more than one task
- testable without private state

Case states:

- `raw`: captured from a real session and not safe to commit.
- `sanitized`: secrets, private paths, private repo names, and usernames removed.
- `minimized`: reduced to the smallest command and environment that reproduces the issue.
- `classified`: assigned to one taxonomy category and optionally linked to a pattern.
- `tested`: covered by a regression test or smoke test.
- `promoted`: changed a pattern, script, or adapter instruction.
- `rejected`: too specific, unreproducible, unsafe to share, or already covered.
- `deprecated`: superseded by a runtime change, script change, or better pattern.

Run periodic compression:

- merge near-duplicate cases
- fold several similar cases into one pattern
- move stale patterns to `deprecated`
- keep `SKILL.md` concise

Compression should happen before major releases and whenever a pattern catalog file becomes hard to scan.

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

## Safety Model

This project helps agents execute shell commands, so safety must be explicit.

Rules:

- Do not design helper scripts to bypass Codex, Claude Code, or host runtime permission models.
- Do not encourage agents to pass large arbitrary command strings when structured command specs are practical.
- Treat recursive delete, recursive move, broad overwrite, archive extraction, and commands affecting paths outside the workspace as high risk or destructive.
- Require `Test-Path`, resolved absolute target paths, and exact path handling before destructive filesystem operations.
- Prefer `-LiteralPath` for exact local paths and avoid wildcard expansion unless the pattern is intentional.
- Keep failure corpus entries sanitized before commit.
- Do not store secrets, tokens, private URLs, private usernames, raw home paths, or proprietary file contents in test cases.
- When a command fails because of permission, lock, antivirus, execution policy, or host sandboxing, classify it rather than trying increasingly broad workarounds.

Safety and flow must stay balanced: normal commands should stay lightweight, but high-risk commands should slow down for validation.

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

Initial test matrix:

```text
PowerShell: Windows PowerShell 5.1, PowerShell 7 when available
Paths: simple path, path with spaces, non-ASCII path, deep path
Commands: built-in cmdlet, external executable present, external executable missing
Encoding: ASCII output, UTF-8 output, Chinese output
Risk: normal, high-risk file operation, destructive file operation
Failure: parser-boundary, quoting, missing tool, bad path, timeout
```

V0.1 does not need exhaustive cross-product testing. It needs representative smoke tests in each row above.

## Competitor Baseline

`windows-agent-guardrails` is the direct baseline. It validates the problem and provides a useful static guardrail shape, but it does not provide the full target experience:

- no execution wrapper
- no failure corpus promotion process
- no regression harness
- no runtime adapter split
- no hook or command interception layer

This project should not compete by adding more prose rules. It should compete by turning experience into compact patterns, tested helper scripts, and adapter-specific runtime behavior.

## Why This Is Not Just `windows-agent-guardrails`

This project should treat `windows-agent-guardrails` as a baseline, not as a template to clone.

The difference is the operating model:

- `windows-agent-guardrails` primarily gives static guardrail prose and pattern references.
- This project adds a failure corpus lifecycle so experience can be accumulated without bloating runtime context.
- This project adds helper scripts so fragile repeated behavior can become deterministic.
- This project adds adapter boundaries so Codex, Claude Code, and generic agent skills can share core knowledge while using runtime-specific integration points.
- This project adds regression tests and smoke tests as release gates.

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
