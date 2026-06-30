# PowerShell Skills V0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first Codex-discoverable Windows and PowerShell command execution skill with core patterns, helper scripts, sanitized failure cases, smoke tests, and local install verification.

**Architecture:** Keep `core/` as the portable source of truth and `adapters/codex/powershell-command-runner/` as the first runtime adapter. Helper scripts emit JSON and tests validate representative Windows failure modes without relying on private state.

**Tech Stack:** Markdown, PowerShell 5.1-compatible scripts, Git, Codex agent skill metadata.

---

## File Structure

- Create: `core/execution-contract.md`  
  Compact execution contract for agents before Windows shell work.
- Create: `core/pattern-catalog/*.md`  
  One focused pattern file per taxonomy category.
- Create: `core/failure-corpus/schema.md`  
  Schema and lifecycle for sanitized failure cases.
- Create: `core/failure-corpus/cases/*.md`  
  Five initial sanitized cases.
- Create: `core/scripts/Test-AgentCommand.ps1`  
  JSON command discovery helper.
- Create: `core/scripts/Resolve-AgentPath.ps1`  
  JSON path validation and exact path helper.
- Create: `core/scripts/Classify-AgentFailure.ps1`  
  JSON failure classifier.
- Create: `core/scripts/Invoke-AgentCommand.ps1`  
  Structured command runner with timeout, cwd, env, risk, and JSON output.
- Create: `core/tests/run-smoke.ps1`  
  Smoke test harness for helpers and representative regression cases.
- Create: `adapters/codex/powershell-command-runner/SKILL.md`  
  Codex skill entrypoint with explicit implicit-trigger description.
- Create: `adapters/codex/powershell-command-runner/agents/openai.yaml`  
  Codex UI metadata and implicit invocation policy.
- Create: `scripts/install-codex-local.ps1`  
  Creates a repo-local `.agents/skills/powershell-command-runner` link for local Codex discovery.
- Create: `scripts/verify-v0.1.ps1`  
  Runs smoke tests and validates required files.

## Implementation Sequence

### Task 1: Core Documentation Scaffold

**Files:**
- Create: `core/execution-contract.md`
- Create: `core/pattern-catalog/shell-selection.md`
- Create: `core/pattern-catalog/path-handling.md`
- Create: `core/pattern-catalog/quoting.md`
- Create: `core/pattern-catalog/encoding.md`
- Create: `core/pattern-catalog/tool-discovery.md`
- Create: `core/pattern-catalog/powershell-parser.md`
- Create: `core/pattern-catalog/file-ops-safety.md`
- Create: `core/pattern-catalog/timeout-and-process.md`
- Create: `core/pattern-catalog/failure-retry.md`

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Path 'core\pattern-catalog' -Force | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Write `core/execution-contract.md`**

Create the file with this content:

```markdown
# Execution Contract

Use this contract before Windows shell work.

## Default Rules

- Prefer PowerShell syntax when the active shell is PowerShell.
- Treat paths, quoting, encoding, and command discovery as execution concerns.
- Use native PowerShell filesystem commands when they fit the task.
- Use `-LiteralPath` for exact local paths.
- Validate high-risk targets before acting.
- Do not repeat the same failed command shape.

## Risk Routing

- `normal`: run with standard quoting and cwd awareness.
- `high`: read the smallest matching pattern and use preflight checks.
- `destructive`: validate resolved absolute paths before execution.
- `diagnostic`: classify the failure before retrying.

## Helper Routing

- Command missing or uncertain: run `core/scripts/Test-AgentCommand.ps1`.
- Path contains spaces, non-ASCII characters, or exact matching matters: run `core/scripts/Resolve-AgentPath.ps1`.
- Repeated failure: run `core/scripts/Classify-AgentFailure.ps1`.
- Structured execution needed: run `core/scripts/Invoke-AgentCommand.ps1`.
```

- [ ] **Step 3: Write pattern catalog files**

Create each file with this template, replacing the title, trigger, safe shape, and failure signals exactly as shown below.

`core/pattern-catalog/shell-selection.md`:

```markdown
# Shell Selection

status: active

## Trigger

Use when a command may be written with Bash, cmd.exe, PowerShell, or WSL syntax.

## Safe Shape

- Check the active shell before borrowing syntax from another platform.
- In PowerShell, use cmdlets, semicolons, and PowerShell variable syntax.
- Do not use Bash-only syntax such as `&&`, `$()`, `rm -rf`, or unescaped forward assumptions unless the active shell supports it.

## Failure Signals

- `The token '&&' is not a valid statement separator`
- `The term 'rm' is not recognized`
- path separators or quoting copied from Bash fail in PowerShell
```

`core/pattern-catalog/path-handling.md`:

```markdown
# Path Handling

status: active

## Trigger

Use when paths may contain spaces, non-ASCII characters, wildcards, brackets, or deep directories.

## Safe Shape

- Prefer `Join-Path` for constructed paths.
- Quote path arguments.
- Use `-LiteralPath` when exact interpretation matters.
- Validate existence with `Test-Path -LiteralPath`.

## Failure Signals

- `Cannot find path`
- wildcard expansion affects the wrong target
- a path with spaces is split into several arguments
```

`core/pattern-catalog/quoting.md`:

```markdown
# Quoting

status: active

## Trigger

Use when commands contain nested quotes, inline scripts, JSON, or paths with spaces.

## Safe Shape

- Prefer argument arrays or structured command specs over large shell strings.
- Use single quotes for literal PowerShell strings.
- Escape single quotes inside single-quoted strings by doubling them.
- Move complex inline code into a script file when quoting becomes fragile.

## Failure Signals

- `Unexpected token`
- unterminated string errors
- arguments merge or split unexpectedly
```

`core/pattern-catalog/encoding.md`:

```markdown
# Encoding

status: active

## Trigger

Use when output, paths, or inline code may contain non-ASCII text.

## Safe Shape

- For Python output, set `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1`.
- Prefer UTF-8 output where the tool supports it.
- Keep tests for Chinese output and paths.

## Failure Signals

- mojibake
- Unicode encode or decode exceptions
- non-ASCII output disappears or is replaced
```

`core/pattern-catalog/tool-discovery.md`:

```markdown
# Tool Discovery

status: active

## Trigger

Use before depending on an external executable such as `git`, `rg`, `python`, `node`, `pandoc`, or `ffmpeg`.

## Safe Shape

- Run `Get-Command <name>` before the main command when tool availability matters.
- Capture source path and version when available.
- Use a native PowerShell fallback when the external tool is absent and the task is simple.

## Failure Signals

- `The term '<name>' is not recognized`
- executable path is not the expected one
- repeated retries call a missing executable
```

`core/pattern-catalog/powershell-parser.md`:

```markdown
# PowerShell Parser

status: active

## Trigger

Use when generating pipelines, script blocks, logical operators, or inline PowerShell.

## Safe Shape

- Assign statement output to a variable before piping when the parser rejects a direct shape.
- Wrap cmdlet calls in parentheses before using `-and` or `-or`.
- Prefer multi-line `.ps1` files for complex logic.

## Failure Signals

- `An empty pipe element is not allowed`
- `Unexpected token`
- `A positional parameter cannot be found that accepts argument`
```

`core/pattern-catalog/file-ops-safety.md`:

```markdown
# File Operations Safety

status: active

## Trigger

Use for copy, move, delete, overwrite, archive extraction, or recursive operations.

## Safe Shape

- Resolve and validate absolute target paths first.
- Use `-LiteralPath` for exact source paths.
- Keep recursive delete and broad overwrite in `destructive` risk.
- Never combine PowerShell enumeration with another shell for deletion.

## Failure Signals

- operation affects the wrong path
- wildcard expands unexpectedly
- recursive operation target was not verified
```

`core/pattern-catalog/timeout-and-process.md`:

```markdown
# Timeout And Process

status: active

## Trigger

Use for commands that may hang, spawn child processes, or produce large output.

## Safe Shape

- Set an explicit timeout for helper-managed execution.
- Capture stdout, stderr, exit code, and duration.
- Classify timeout separately from command failure.

## Failure Signals

- command never returns
- stdout and stderr are lost
- exit code is not available
```

`core/pattern-catalog/failure-retry.md`:

```markdown
# Failure Retry

status: active

## Trigger

Use after one command failure or before retrying a similar command.

## Safe Shape

- Classify the failure before retrying.
- Change the command shape after a parser, quoting, path, or encoding failure.
- Stop after the second failed shape and report the blocker.

## Failure Signals

- same command text is retried unchanged
- shell mismatch persists after the first error
- missing tool is called repeatedly
```

- [ ] **Step 4: Verify documentation files exist**

Run:

```powershell
$required = @(
  'core\execution-contract.md',
  'core\pattern-catalog\shell-selection.md',
  'core\pattern-catalog\path-handling.md',
  'core\pattern-catalog\quoting.md',
  'core\pattern-catalog\encoding.md',
  'core\pattern-catalog\tool-discovery.md',
  'core\pattern-catalog\powershell-parser.md',
  'core\pattern-catalog\file-ops-safety.md',
  'core\pattern-catalog\timeout-and-process.md',
  'core\pattern-catalog\failure-retry.md'
)
$missing = $required | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }
if ($missing) { throw "Missing files: $($missing -join ', ')" }
Write-Output "[OK] core docs exist"
```

Expected: `[OK] core docs exist`

- [ ] **Step 5: Commit**

Run:

```powershell
git add core/execution-contract.md core/pattern-catalog
git commit -m "Add core execution contract and patterns"
```

Expected: commit succeeds.

### Task 2: Failure Corpus Schema And Initial Cases

**Files:**
- Create: `core/failure-corpus/schema.md`
- Create: `core/failure-corpus/cases/ps-parser-foreach-pipeline.md`
- Create: `core/failure-corpus/cases/path-space-literalpath.md`
- Create: `core/failure-corpus/cases/encoding-python-utf8.md`
- Create: `core/failure-corpus/cases/tool-discovery-missing-rg.md`
- Create: `core/failure-corpus/cases/file-ops-destructive-preflight.md`

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Path 'core\failure-corpus\cases' -Force | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Write schema**

Create `core/failure-corpus/schema.md`:

```markdown
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
```

- [ ] **Step 3: Write five initial cases**

Create the five case files with these contents.

`core/failure-corpus/cases/ps-parser-foreach-pipeline.md`:

```markdown
# ps-parser-foreach-pipeline

- case_id: ps-parser-foreach-pipeline
- source: local-codex-session
- date: 2026-07-01
- agent_runtime: Codex
- shell: PowerShell
- ps_version: unknown
- symptom: Parser error when piping directly after a `foreach` statement.
- bad_command: `$rows = foreach ($x in $items) { [pscustomobject]@{ name=$x } } | Format-Table`
- error_excerpt: `An empty pipe element is not allowed.`
- root_cause: PowerShell parser boundary between a statement block and a pipeline.
- safe_pattern: Assign statement output to a variable, then pipe the variable.
- linked_pattern: `core/pattern-catalog/powershell-parser.md`
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
```

`core/failure-corpus/cases/path-space-literalpath.md`:

```markdown
# path-space-literalpath

- case_id: path-space-literalpath
- source: minimized-regression
- date: 2026-07-01
- agent_runtime: generic
- shell: PowerShell
- ps_version: 5.1-compatible
- symptom: Path with spaces is split or interpreted incorrectly.
- bad_command: `Get-Content C:\Projects\example path\file.txt`
- error_excerpt: `Cannot find path`
- root_cause: Path argument was not quoted and exact interpretation was not requested.
- safe_pattern: Use quoted paths and `-LiteralPath` for exact local paths.
- linked_pattern: `core/pattern-catalog/path-handling.md`
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
```

`core/failure-corpus/cases/encoding-python-utf8.md`:

```markdown
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
```

`core/failure-corpus/cases/tool-discovery-missing-rg.md`:

```markdown
# tool-discovery-missing-rg

- case_id: tool-discovery-missing-rg
- source: minimized-regression
- date: 2026-07-01
- agent_runtime: generic
- shell: PowerShell
- ps_version: 5.1-compatible
- symptom: Agent assumes `rg` exists and retries a missing executable.
- bad_command: `rg MARKER C:\Projects\example`
- error_excerpt: `The term 'rg' is not recognized`
- root_cause: Tool availability was not checked before execution.
- safe_pattern: Run `Get-Command rg` or `Test-AgentCommand.ps1` before relying on `rg`.
- linked_pattern: `core/pattern-catalog/tool-discovery.md`
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
```

`core/failure-corpus/cases/file-ops-destructive-preflight.md`:

```markdown
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
- regression_test: `core/tests/run-smoke.ps1`
- status: tested
```

- [ ] **Step 4: Verify corpus coverage count**

Run:

```powershell
$cases = Get-ChildItem -LiteralPath 'core\failure-corpus\cases' -Filter '*.md' -File
if ($cases.Count -lt 5) { throw "Expected at least 5 cases, found $($cases.Count)" }
Write-Output "[OK] $($cases.Count) failure cases"
```

Expected: `[OK] 5 failure cases`

- [ ] **Step 5: Commit**

Run:

```powershell
git add core/failure-corpus
git commit -m "Add failure corpus schema and seed cases"
```

Expected: commit succeeds.

### Task 3: Smoke Test Harness

**Files:**
- Create: `core/tests/run-smoke.ps1`

- [ ] **Step 1: Create test directory**

Run:

```powershell
New-Item -ItemType Directory -Path 'core\tests' -Force | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Write smoke test harness**

Create `core/tests/run-smoke.ps1`:

```powershell
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$ScriptsRoot = Join-Path $RepoRoot "core\scripts"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-ScriptJson {
    param(
        [string]$ScriptName,
        [string[]]$Arguments = @()
    )
    $scriptPath = Join-Path $ScriptsRoot $ScriptName
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) "Missing script: $scriptPath"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    $exit = $LASTEXITCODE
    $json = ($output | Out-String).Trim()
    if (-not $json) { throw "No JSON output from $ScriptName" }
    $data = $json | ConvertFrom-Json
    [pscustomobject]@{ ExitCode = $exit; Data = $data; Raw = $json }
}

function New-TestWorkspace {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("powershell-skills-smoke-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

$workspace = New-TestWorkspace
try {
    $spacePath = Join-Path $workspace "space path"
    $unicodeName = "unicode-" + [char]0x4E2D + [char]0x6587
    $unicodePath = Join-Path $workspace $unicodeName
    New-Item -ItemType Directory -Path $spacePath -Force | Out-Null
    New-Item -ItemType Directory -Path $unicodePath -Force | Out-Null

    $commandResult = Invoke-ScriptJson "Test-AgentCommand.ps1" @("-Command", "powershell.exe")
    Assert-True ($commandResult.ExitCode -eq 0) "powershell.exe should be found"
    Assert-True ($commandResult.Data.found -eq $true) "Expected found=true for powershell.exe"

    $missingResult = Invoke-ScriptJson "Test-AgentCommand.ps1" @("-Command", "definitely-missing-powershell-skills-tool")
    Assert-True ($missingResult.ExitCode -eq 1) "missing command should exit 1"
    Assert-True ($missingResult.Data.classification -eq "tool-discovery") "Expected tool-discovery classification"

    $pathResult = Invoke-ScriptJson "Resolve-AgentPath.ps1" @("-Path", $spacePath, "-MustExist")
    Assert-True ($pathResult.ExitCode -eq 0) "space path should resolve"
    Assert-True ($pathResult.Data.exists -eq $true) "Expected exists=true for space path"
    Assert-True ($pathResult.Data.use_literal_path -eq $true) "Expected literal path recommendation"

    $unicodeResult = Invoke-ScriptJson "Resolve-AgentPath.ps1" @("-Path", $unicodePath, "-MustExist")
    Assert-True ($unicodeResult.ExitCode -eq 0) "unicode path should resolve"
    Assert-True ($unicodeResult.Data.exists -eq $true) "Expected exists=true for unicode path"

    $classifyResult = Invoke-ScriptJson "Classify-AgentFailure.ps1" @("-ErrorText", "An empty pipe element is not allowed.")
    Assert-True ($classifyResult.ExitCode -eq 0) "classifier should exit 0"
    Assert-True ($classifyResult.Data.classification -eq "powershell-parser") "Expected powershell-parser classification"

    $specPath = Join-Path $workspace "invoke-spec.json"
    @{
        command = "powershell.exe"
        args = @("-NoProfile", "-Command", "Write-Output ok")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "normal"
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $specPath -Encoding UTF8
    $invokeResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $specPath)
    Assert-True ($invokeResult.ExitCode -eq 0) "invoke command should exit 0"
    Assert-True ($invokeResult.Data.stdout -match "ok") "Expected stdout to contain ok"

    $destructiveSpecPath = Join-Path $workspace "destructive-spec.json"
    @{
        command = "powershell.exe"
        args = @("-NoProfile", "-Command", "Write-Output should-not-run")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "destructive"
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destructiveSpecPath -Encoding UTF8
    $destructiveResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $destructiveSpecPath)
    Assert-True ($destructiveResult.ExitCode -eq 1) "destructive spec should be blocked"
    Assert-True ($destructiveResult.Data.classification -eq "destructive-op-risk") "Expected destructive-op-risk classification"

    Write-Output "[OK] smoke tests passed"
}
finally {
    if (Test-Path -LiteralPath $workspace) {
        Remove-Item -LiteralPath $workspace -Recurse -Force
    }
}
```

- [ ] **Step 3: Run harness before helper scripts exist**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File core\tests\run-smoke.ps1
```

Expected: FAIL with a message containing `Missing script`.

- [ ] **Step 4: Commit**

Run:

```powershell
git add core/tests/run-smoke.ps1
git commit -m "Add smoke test harness"
```

Expected: commit succeeds.

### Task 4: Command Discovery And Path Helpers

**Files:**
- Create: `core/scripts/Test-AgentCommand.ps1`
- Create: `core/scripts/Resolve-AgentPath.ps1`
- Test: `core/tests/run-smoke.ps1`

- [ ] **Step 1: Create scripts directory**

Run:

```powershell
New-Item -ItemType Directory -Path 'core\scripts' -Force | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Write `Test-AgentCommand.ps1`**

Create `core/scripts/Test-AgentCommand.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$ErrorActionPreference = "Stop"

function Write-JsonResult {
    param($Value, [int]$ExitCode)
    $Value | ConvertTo-Json -Depth 8 -Compress
    exit $ExitCode
}

$found = Get-Command -Name $Command -ErrorAction SilentlyContinue
if (-not $found) {
    Write-JsonResult @{
        status = "error"
        command = $Command
        found = $false
        source = $null
        command_type = $null
        version = $null
        classification = "tool-discovery"
    } 1
}

$version = $null
if ($found.Version) {
    $version = $found.Version.ToString()
}

Write-JsonResult @{
    status = "success"
    command = $Command
    found = $true
    source = $found.Source
    command_type = $found.CommandType.ToString()
    version = $version
    classification = $null
} 0
```

- [ ] **Step 3: Write `Resolve-AgentPath.ps1`**

Create `core/scripts/Resolve-AgentPath.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [switch]$MustExist
)

$ErrorActionPreference = "Stop"

function Write-JsonResult {
    param($Value, [int]$ExitCode)
    $Value | ConvertTo-Json -Depth 8 -Compress
    exit $ExitCode
}

$exists = Test-Path -LiteralPath $Path
$fullPath = $null
$parent = $null
$unsafeReason = $null

try {
    if ($exists) {
        $fullPath = (Resolve-Path -LiteralPath $Path).Path
    } else {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    $parent = Split-Path -Parent $fullPath
}
catch {
    $unsafeReason = $_.Exception.Message
}

if ($MustExist -and -not $exists) {
    Write-JsonResult @{
        status = "error"
        input_path = $Path
        exists = $false
        full_path = $fullPath
        parent = $parent
        use_literal_path = $true
        classification = "path-handling"
        unsafe_reason = "Path does not exist"
    } 1
}

$status = if ($unsafeReason) { "error" } else { "success" }
$exitCode = if ($unsafeReason) { 1 } else { 0 }

Write-JsonResult @{
    status = $status
    input_path = $Path
    exists = $exists
    full_path = $fullPath
    parent = $parent
    use_literal_path = $true
    classification = if ($unsafeReason) { "path-handling" } else { $null }
    unsafe_reason = $unsafeReason
} $exitCode
```

- [ ] **Step 4: Run smoke tests and confirm partial failure**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File core\tests\run-smoke.ps1
```

Expected: FAIL with a message containing `Missing script` for `Classify-AgentFailure.ps1`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add core/scripts/Test-AgentCommand.ps1 core/scripts/Resolve-AgentPath.ps1
git commit -m "Add command discovery and path helpers"
```

Expected: commit succeeds.

### Task 5: Failure Classifier And Structured Runner

**Files:**
- Create: `core/scripts/Classify-AgentFailure.ps1`
- Create: `core/scripts/Invoke-AgentCommand.ps1`
- Test: `core/tests/run-smoke.ps1`

- [ ] **Step 1: Write `Classify-AgentFailure.ps1`**

Create `core/scripts/Classify-AgentFailure.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$ErrorText,
    [int]$ExitCode = 1
)

$ErrorActionPreference = "Stop"

function Get-Classification {
    param([string]$Text)
    if ($Text -match 'An empty pipe element is not allowed|Unexpected token|positional parameter') { return "powershell-parser" }
    if ($Text -match 'Cannot find path|does not exist|Could not find a part of the path') { return "path-handling" }
    if ($Text -match 'not recognized as (the name of )?(a cmdlet|an internal or external command)|is not recognized') { return "tool-discovery" }
    if ($Text -match 'UnicodeEncodeError|UnicodeDecodeError|encoding|codec') { return "encoding" }
    if ($Text -match 'Access is denied|UnauthorizedAccess|permission') { return "permission" }
    if ($Text -match 'TIMEOUT|timed out|timeout') { return "timeout-and-process" }
    if ($Text -match 'Remove-Item|recursive delete|destructive') { return "destructive-op-risk" }
    return "unknown"
}

$classification = Get-Classification -Text $ErrorText
@{
    status = "success"
    exit_code = $ExitCode
    classification = $classification
    error_excerpt = $ErrorText
} | ConvertTo-Json -Depth 8 -Compress
exit 0
```

- [ ] **Step 2: Write `Invoke-AgentCommand.ps1`**

Create `core/scripts/Invoke-AgentCommand.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$SpecPath
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-JsonResult {
    param($Value, [int]$ExitCode)
    $Value | ConvertTo-Json -Depth 12 -Compress
    exit $ExitCode
}

function ConvertTo-PSLiteral {
    param([string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

function Classify-Text {
    param([string]$Text, [int]$Code)
    $classifier = Join-Path $ScriptRoot "Classify-AgentFailure.ps1"
    $raw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $classifier -ErrorText $Text -ExitCode $Code
    return (($raw | Out-String).Trim() | ConvertFrom-Json).classification
}

if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
    Write-JsonResult @{
        status = "error"
        exit_code = 1
        stdout = ""
        stderr = "Spec file not found: $SpecPath"
        duration_ms = 0
        classification = "path-handling"
    } 1
}

$spec = Get-Content -LiteralPath $SpecPath -Raw | ConvertFrom-Json
if (-not $spec.command) {
    Write-JsonResult @{
        status = "error"
        exit_code = 1
        stdout = ""
        stderr = "Spec command is required"
        duration_ms = 0
        classification = "unknown"
    } 1
}

$risk = if ($spec.risk) { [string]$spec.risk } else { "normal" }
if ($risk -eq "destructive") {
    Write-JsonResult @{
        status = "error"
        exit_code = 1
        stdout = ""
        stderr = "Destructive command risk requires target validation outside Invoke-AgentCommand.ps1 V0.1"
        duration_ms = 0
        classification = "destructive-op-risk"
    } 1
}

if ($spec.cwd) {
    if (-not (Test-Path -LiteralPath ([string]$spec.cwd) -PathType Container)) {
        Write-JsonResult @{
            status = "error"
            exit_code = 1
            stdout = ""
            stderr = "Working directory not found: $($spec.cwd)"
            duration_ms = 0
            classification = "path-handling"
        } 1
    }
}

$cmdCheck = Get-Command -Name ([string]$spec.command) -ErrorAction SilentlyContinue
if (-not $cmdCheck) {
    Write-JsonResult @{
        status = "error"
        exit_code = 1
        stdout = ""
        stderr = "Command not found: $($spec.command)"
        duration_ms = 0
        classification = "tool-discovery"
    } 1
}

$args = @()
if ($spec.args) {
    foreach ($arg in $spec.args) {
        $args += [string]$arg
    }
}

$commandParts = @("&", (ConvertTo-PSLiteral ([string]$spec.command)))
foreach ($arg in $args) {
    $commandParts += (ConvertTo-PSLiteral $arg)
}
$commandText = $commandParts -join " "
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))

$hostExe = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell.exe" }
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $hostExe
$psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encoded"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
if ($spec.cwd) { $psi.WorkingDirectory = [string]$spec.cwd }
if ($spec.env) {
    foreach ($prop in $spec.env.PSObject.Properties) {
        $psi.EnvironmentVariables[$prop.Name] = [string]$prop.Value
    }
}

$timeout = if ($spec.timeout_seconds) { [int]$spec.timeout_seconds } else { 30 }
$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = [Diagnostics.Process]::Start($psi)
$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()
if (-not $proc.WaitForExit($timeout * 1000)) {
    $proc.Kill()
    $sw.Stop()
    Write-JsonResult @{
        status = "error"
        exit_code = 124
        stdout = ""
        stderr = "TIMEOUT after ${timeout}s"
        duration_ms = [int]$sw.ElapsedMilliseconds
        classification = "timeout-and-process"
    } 1
}
$sw.Stop()
$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result
$exit = $proc.ExitCode
$status = if ($exit -eq 0) { "success" } else { "error" }
$classification = $null
if ($exit -ne 0) {
    $classification = Classify-Text -Text $stderr -Code $exit
}

Write-JsonResult @{
    status = $status
    exit_code = $exit
    stdout = $stdout
    stderr = $stderr
    duration_ms = [int]$sw.ElapsedMilliseconds
    classification = $classification
} $(if ($exit -eq 0) { 0 } else { 1 })
```

- [ ] **Step 3: Run smoke tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File core\tests\run-smoke.ps1
```

Expected: `[OK] smoke tests passed`

- [ ] **Step 4: Commit**

Run:

```powershell
git add core/scripts/Classify-AgentFailure.ps1 core/scripts/Invoke-AgentCommand.ps1 core/tests/run-smoke.ps1
git commit -m "Add failure classifier and structured runner"
```

Expected: commit succeeds.

### Task 6: Codex Adapter Skill

**Files:**
- Create: `adapters/codex/powershell-command-runner/SKILL.md`
- Create: `adapters/codex/powershell-command-runner/agents/openai.yaml`

- [ ] **Step 1: Create adapter directories**

Run:

```powershell
New-Item -ItemType Directory -Path 'adapters\codex\powershell-command-runner\agents' -Force | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Write Codex `SKILL.md`**

Create `adapters/codex/powershell-command-runner/SKILL.md`:

```markdown
---
name: powershell-command-runner
description: Use whenever Codex is operating on Windows, PowerShell, or Windows shell tasks and is about to run shell commands, inspect files, invoke external CLIs, write or run .ps1 scripts, handle Windows paths, process non-ASCII output, perform filesystem operations, or debug command failures. Trigger even when the user did not explicitly mention PowerShell.
---

# PowerShell Command Runner

Use this skill to make Windows shell execution boring and reliable.

## Start Here

Read `../../../core/execution-contract.md` before high-risk Windows shell work.

Classify command risk:

- `normal`: simple read-only commands, git status, directory listings, version checks.
- `high`: external CLIs, paths with spaces or non-ASCII characters, archives, generated scripts, encoding-sensitive output.
- `destructive`: recursive delete, recursive move, broad overwrite, commands outside the current workspace.
- `diagnostic`: a command failed once and needs a changed shape.

## Default Behavior

- Keep normal commands lightweight.
- Use PowerShell syntax in PowerShell sessions.
- Prefer native PowerShell file commands for file operations.
- Prefer `-LiteralPath` when exact path handling matters.
- Check external tools with `../../../core/scripts/Test-AgentCommand.ps1` before relying on them in high-risk commands.
- Check exact paths with `../../../core/scripts/Resolve-AgentPath.ps1` when spaces, non-ASCII characters, or destructive operations are involved.
- Classify repeated failures with `../../../core/scripts/Classify-AgentFailure.ps1`.
- Use `../../../core/scripts/Invoke-AgentCommand.ps1` when structured stdout, stderr, exit code, timeout, cwd, or environment handling matters.

## Pattern Routing

- Shell mismatch: `../../../core/pattern-catalog/shell-selection.md`
- Paths: `../../../core/pattern-catalog/path-handling.md`
- Quoting: `../../../core/pattern-catalog/quoting.md`
- Encoding: `../../../core/pattern-catalog/encoding.md`
- Tool discovery: `../../../core/pattern-catalog/tool-discovery.md`
- Parser traps: `../../../core/pattern-catalog/powershell-parser.md`
- File operation safety: `../../../core/pattern-catalog/file-ops-safety.md`
- Timeout and process handling: `../../../core/pattern-catalog/timeout-and-process.md`
- Repeated failure: `../../../core/pattern-catalog/failure-retry.md`

## Stop Rules

- Do not repeat the same failed command shape.
- Do not run destructive filesystem commands without resolved target validation.
- Do not use a helper script to bypass host permission or sandbox rules.
- Do not commit raw private failure logs to the corpus.
```

- [ ] **Step 3: Write `agents/openai.yaml`**

Create `adapters/codex/powershell-command-runner/agents/openai.yaml`:

```yaml
interface:
  display_name: "PowerShell Command Runner"
  short_description: "Safer Windows and PowerShell command execution for Codex."
  default_prompt: "Use this skill when working in Windows or PowerShell shell environments."
policy:
  allow_implicit_invocation: true
```

- [ ] **Step 4: Validate frontmatter fields**

Run:

```powershell
$skill = Get-Content -Raw 'adapters\codex\powershell-command-runner\SKILL.md'
if ($skill -notmatch 'name:\s*powershell-command-runner') { throw 'Missing skill name' }
if ($skill -notmatch 'description:.*Windows') { throw 'Description does not target Windows' }
if ($skill -notmatch 'Trigger even when the user did not explicitly mention PowerShell') { throw 'Description trigger is too weak' }
Write-Output '[OK] codex skill metadata'
```

Expected: `[OK] codex skill metadata`

- [ ] **Step 5: Commit**

Run:

```powershell
git add adapters/codex/powershell-command-runner
git commit -m "Add Codex PowerShell command runner skill"
```

Expected: commit succeeds.

### Task 7: Local Install And V0.1 Verification

**Files:**
- Create: `scripts/install-codex-local.ps1`
- Create: `scripts/verify-v0.1.ps1`

- [ ] **Step 1: Create scripts directory**

Run:

```powershell
New-Item -ItemType Directory -Path 'scripts' -Force | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Write local install script**

Create `scripts/install-codex-local.ps1`:

```powershell
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$Source = Join-Path $RepoRoot "adapters\codex\powershell-command-runner"
$SkillsRoot = Join-Path $RepoRoot ".agents\skills"
$Target = Join-Path $SkillsRoot "powershell-command-runner"

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Source skill folder not found: $Source"
}

New-Item -ItemType Directory -Path $SkillsRoot -Force | Out-Null

if (Test-Path -LiteralPath $Target) {
    $item = Get-Item -LiteralPath $Target -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Target exists and is not a link: $Target"
    }
    Remove-Item -LiteralPath $Target -Force
}

New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null

@{
    status = "success"
    source = $Source.Path
    target = $Target
    note = "Start Codex from the repository root so repo-local .agents skills are discoverable."
} | ConvertTo-Json -Depth 5
```

- [ ] **Step 3: Write verification script**

Create `scripts/verify-v0.1.ps1`:

```powershell
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")

function Assert-Path {
    param([string]$Path, [string]$Type)
    $full = Join-Path $RepoRoot $Path
    if ($Type -eq "Leaf") {
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Missing file: $Path" }
    } else {
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw "Missing directory: $Path" }
    }
}

$files = @(
    'core\execution-contract.md',
    'core\scripts\Test-AgentCommand.ps1',
    'core\scripts\Resolve-AgentPath.ps1',
    'core\scripts\Classify-AgentFailure.ps1',
    'core\scripts\Invoke-AgentCommand.ps1',
    'core\tests\run-smoke.ps1',
    'adapters\codex\powershell-command-runner\SKILL.md',
    'adapters\codex\powershell-command-runner\agents\openai.yaml'
)
foreach ($file in $files) { Assert-Path $file "Leaf" }
Assert-Path 'core\pattern-catalog' "Container"
Assert-Path 'core\failure-corpus\cases' "Container"

$caseCount = (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'core\failure-corpus\cases') -Filter '*.md' -File).Count
if ($caseCount -lt 5) { throw "Expected at least 5 failure cases, found $caseCount" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'core\tests\run-smoke.ps1')
if ($LASTEXITCODE -ne 0) { throw "Smoke tests failed" }

Write-Output "[OK] V0.1 verification passed"
```

- [ ] **Step 4: Run local install**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\install-codex-local.ps1
```

Expected: JSON with `status` equal to `success`.

- [ ] **Step 5: Run V0.1 verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify-v0.1.ps1
```

Expected: `[OK] V0.1 verification passed`

- [ ] **Step 6: Commit**

Run:

```powershell
git add scripts/install-codex-local.ps1 scripts/verify-v0.1.ps1 .agents/skills/powershell-command-runner
git commit -m "Add local Codex install and verification"
```

Expected: commit succeeds if `.agents/skills/powershell-command-runner` is a trackable junction or link. If Git cannot track the junction reliably, add `.agents/` to `.gitignore`, commit the install scripts only, and state that repo-local install artifacts are generated.

### Task 8: Final Release Gate

**Files:**
- Modify: `.gitignore` if `.agents/` must be generated rather than tracked.
- Modify: `docs/superpowers/specs/2026-07-01-powershell-skills-design.md` only if implementation uncovers a spec mismatch.

- [ ] **Step 1: Run all verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify-v0.1.ps1
git status --short
```

Expected:

```text
[OK] V0.1 verification passed
```

`git status --short` should be empty after the final commit.

- [ ] **Step 2: Check no red-flag text exists**

Run:

```powershell
$pattern = 'TO' + 'DO|TB' + 'D|FIX' + 'ME|place' + 'holder|implement la' + 'ter'
Select-String -Path (Get-ChildItem -Recurse -File | Select-Object -ExpandProperty FullName) -Pattern $pattern -CaseSensitive:$false
```

Expected: no matches.

- [ ] **Step 3: Confirm Codex-facing skill trigger**

Run:

```powershell
$description = Select-String -Path 'adapters\codex\powershell-command-runner\SKILL.md' -Pattern '^description:' | Select-Object -First 1
if ($description.Line -notmatch 'Windows' -or $description.Line -notmatch 'shell commands' -or $description.Line -notmatch 'Trigger even when') {
    throw 'Skill description does not meet trigger requirements'
}
Write-Output '[OK] trigger description'
```

Expected: `[OK] trigger description`

- [ ] **Step 4: Final commit**

Run:

```powershell
git add .
git commit -m "Complete powershell skills v0.1"
```

Expected: commit succeeds or reports that there is nothing to commit.
