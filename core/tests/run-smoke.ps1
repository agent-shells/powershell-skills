param(
    [string]$PowerShellExe = "powershell.exe"
)

$ErrorActionPreference = "Stop"

function Set-AgentUtf8Output {
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [Console]::OutputEncoding = $utf8NoBom
        $script:OutputEncoding = $utf8NoBom
    }
    catch {}
}

Set-AgentUtf8Output

$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$ScriptsRoot = Join-Path $RepoRoot "core\scripts"

$PowerShellCommandInfo = Get-Command -Name $PowerShellExe -ErrorAction Stop
$PowerShellCommand = if ($PowerShellCommandInfo.Source) { [string]$PowerShellCommandInfo.Source } else { [string]$PowerShellCommandInfo.Definition }
if ([string]::IsNullOrWhiteSpace($PowerShellCommand)) {
    $PowerShellCommand = $PowerShellExe
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected=[$Expected] Actual=[$Actual]"
    }
}

function Invoke-ScriptJson {
    param(
        [string]$ScriptName,
        [string[]]$Arguments = @()
    )
    $scriptPath = Join-Path $ScriptsRoot $ScriptName
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) "Missing script: $scriptPath"
    $output = & $PowerShellCommand -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
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

function Write-JsonSpec {
    param($Value, [string]$Path)
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$workspace = New-TestWorkspace
try {
    $spacePath = Join-Path $workspace "space path"
    $unicodeName = "unicode-" + [char]0x4E2D + [char]0x6587
    $unicodePath = Join-Path $workspace $unicodeName
    New-Item -ItemType Directory -Path $spacePath -Force | Out-Null
    New-Item -ItemType Directory -Path $unicodePath -Force | Out-Null

    $commandResult = Invoke-ScriptJson "Test-AgentCommand.ps1" @("-Command", $PowerShellCommand)
    Assert-True ($commandResult.ExitCode -eq 0) "Selected PowerShell should be found"
    Assert-True ($commandResult.Data.found -eq $true) "Expected found=true for selected PowerShell"

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

    $classifyShellSelectionResult = Invoke-ScriptJson "Classify-AgentFailure.ps1" @("-ErrorText", "The token '&&' is not a valid statement separator in this version.")
    Assert-True ($classifyShellSelectionResult.ExitCode -eq 0) "classifier shell-selection case should exit 0"
    Assert-Equal $classifyShellSelectionResult.Data.classification "shell-selection" "Expected shell-selection classification"

    $classifyQuotingResult = Invoke-ScriptJson "Classify-AgentFailure.ps1" @("-ErrorText", "The string is missing the terminator: '.")
    Assert-True ($classifyQuotingResult.ExitCode -eq 0) "classifier quoting case should exit 0"
    Assert-Equal $classifyQuotingResult.Data.classification "quoting" "Expected quoting classification"

    $classifyOmittedResult = Invoke-ScriptJson "Classify-AgentFailure.ps1"
    Assert-True ($classifyOmittedResult.ExitCode -eq 0) "classifier omitted ErrorText should still exit 0"
    Assert-True ($classifyOmittedResult.Data.classification -eq "unknown") "Expected unknown classification for omitted ErrorText"

    $specPath = Join-Path $workspace "invoke-spec.json"
    Write-JsonSpec @{
        command = $PowerShellCommand
        args = @("-NoProfile", "-Command", 'Write-Output ok; Write-Output $PWD.Path; Write-Output $env:AGENT_SMOKE_VALUE')
        cwd = $workspace
        timeout_seconds = 15
        env = @{ AGENT_SMOKE_VALUE = "env-ok" }
        risk = "normal"
    } $specPath
    $invokeResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $specPath)
    Assert-True ($invokeResult.ExitCode -eq 0) "invoke command should exit 0"
    Assert-True ($invokeResult.Data.stdout -match "ok") "Expected stdout to contain ok"
    Assert-True ($invokeResult.Data.stdout -match [regex]::Escape($workspace)) "Expected stdout to contain working directory"
    Assert-True ($invokeResult.Data.stdout -match "env-ok") "Expected stdout to contain env override"
    Assert-True ($invokeResult.Data.exit_code -eq 0) "Expected child exit_code=0"
    Assert-True ($invokeResult.Data.duration_ms -ge 0) "Expected duration_ms field"

    $utf8Text = ([string]([char]0x4E2D) + [string]([char]0x6587) + [string]([char]0x8F93) + [string]([char]0x51FA))
    $utf8Command = "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Write-Output ([string]([char]0x4E2D)+[string]([char]0x6587)+[string]([char]0x8F93)+[string]([char]0x51FA))"
    $utf8SpecPath = Join-Path $workspace "utf8-stdout.json"
    Write-JsonSpec @{
        command = $PowerShellCommand
        args = @("-NoProfile", "-Command", $utf8Command)
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "normal"
    } $utf8SpecPath
    $utf8Result = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $utf8SpecPath)
    Assert-True ($utf8Result.ExitCode -eq 0) "UTF-8 stdout command should exit 0"
    Assert-True ($utf8Result.Data.stdout -match [regex]::Escape($utf8Text)) "Expected UTF-8 stdout to contain Chinese output"

    $destructiveSpecPath = Join-Path $workspace "destructive-spec.json"
    Write-JsonSpec @{
        command = $PowerShellCommand
        args = @("-NoProfile", "-Command", "Write-Output should-not-run")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "destructive"
    } $destructiveSpecPath
    $destructiveResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $destructiveSpecPath)
    Assert-True ($destructiveResult.ExitCode -eq 1) "destructive spec should be blocked"
    Assert-True ($destructiveResult.Data.classification -eq "destructive-op-risk") "Expected destructive-op-risk classification"

    $normalizedDestructiveSpecPath = Join-Path $workspace "normalized-destructive-spec.json"
    Write-JsonSpec @{
        command = $PowerShellCommand
        args = @("-NoProfile", "-Command", "Write-Output should-not-run")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = " destructive "
    } $normalizedDestructiveSpecPath
    $normalizedDestructiveResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $normalizedDestructiveSpecPath)
    Assert-True ($normalizedDestructiveResult.ExitCode -eq 1) "trimmed destructive risk should be blocked"
    Assert-Equal $normalizedDestructiveResult.Data.classification "destructive-op-risk" "Expected destructive-op-risk classification for normalized risk"
    Assert-Equal $normalizedDestructiveResult.Data.risk "destructive" "Expected normalized risk in result"

    $invalidRiskSpecPath = Join-Path $workspace "invalid-risk-spec.json"
    Write-JsonSpec @{
        command = $PowerShellCommand
        args = @("-NoProfile", "-Command", "Write-Output should-not-run")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "surprising"
    } $invalidRiskSpecPath
    $invalidRiskResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $invalidRiskSpecPath)
    Assert-True ($invalidRiskResult.ExitCode -eq 1) "invalid risk should exit 1"
    Assert-Equal $invalidRiskResult.Data.classification "unknown" "Expected unknown classification for invalid risk"

    $omittedSpecResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1"
    Assert-True ($omittedSpecResult.ExitCode -eq 1) "omitted SpecPath should exit 1"
    Assert-True ($omittedSpecResult.Data.classification -eq "path-handling") "Expected path-handling for omitted SpecPath"

    $emptySpecResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", "")
    Assert-True ($emptySpecResult.ExitCode -eq 1) "empty SpecPath should exit 1"
    Assert-True ($emptySpecResult.Data.classification -eq "path-handling") "Expected path-handling for empty SpecPath"

    $badJsonPath = Join-Path $workspace "bad-json.json"
    Set-Content -LiteralPath $badJsonPath -Value "{" -Encoding UTF8
    $badJsonResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $badJsonPath)
    Assert-True ($badJsonResult.ExitCode -eq 1) "bad JSON should exit 1"
    Assert-True ($badJsonResult.Data.classification -eq "unknown") "Expected unknown classification for bad JSON"

    $noCommandPath = Join-Path $workspace "no-command.json"
    Write-JsonSpec @{ args = @() } $noCommandPath
    $noCommandResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $noCommandPath)
    Assert-True ($noCommandResult.ExitCode -eq 1) "missing command should exit 1"
    Assert-True ($noCommandResult.Data.classification -eq "tool-discovery") "Expected tool-discovery for missing command"

    $wildcardCommandPath = Join-Path $workspace "wildcard-command.json"
    Write-JsonSpec @{ command = "power*"; args = @(); cwd = $workspace } $wildcardCommandPath
    $wildcardCommandResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $wildcardCommandPath)
    Assert-True ($wildcardCommandResult.ExitCode -eq 1) "wildcard command should exit 1"
    Assert-True ($wildcardCommandResult.Data.classification -eq "tool-discovery") "Expected tool-discovery for wildcard command"

    $aliasOnlyPath = Join-Path $workspace "alias-only.json"
    Write-JsonSpec @{ command = "gci"; args = @(); cwd = $workspace } $aliasOnlyPath
    $aliasOnlyResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $aliasOnlyPath)
    Assert-True ($aliasOnlyResult.ExitCode -eq 1) "alias-only command should exit 1"
    Assert-True ($aliasOnlyResult.Data.classification -eq "tool-discovery") "Expected tool-discovery for alias-only command"

    $cmdletCommandPath = Join-Path $workspace "cmdlet-command.json"
    Write-JsonSpec @{ command = "Get-ChildItem"; args = @(); cwd = $workspace } $cmdletCommandPath
    $cmdletCommandResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $cmdletCommandPath)
    Assert-True ($cmdletCommandResult.ExitCode -eq 1) "cmdlet command should exit 1"
    Assert-Equal $cmdletCommandResult.Data.classification "tool-discovery" "Expected tool-discovery for cmdlet command"
    Assert-True ($cmdletCommandResult.Data.stderr -match "Only Application commands are supported") "Expected Application-only reason for cmdlet command"

    $badTimeoutPath = Join-Path $workspace "bad-timeout.json"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", "-Command", "Write-Output should-not-run"); cwd = $workspace; timeout_seconds = 0 } $badTimeoutPath
    $badTimeoutResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $badTimeoutPath)
    Assert-True ($badTimeoutResult.ExitCode -eq 1) "invalid timeout should exit 1"
    Assert-True ($badTimeoutResult.Data.classification -eq "timeout-and-process") "Expected timeout-and-process for invalid timeout"

    $invalidEnvShapePath = Join-Path $workspace "invalid-env-shape.json"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", "-Command", "Write-Output should-not-run"); cwd = $workspace; timeout_seconds = 15; env = "abc" } $invalidEnvShapePath
    $invalidEnvShapeResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $invalidEnvShapePath)
    Assert-True ($invalidEnvShapeResult.ExitCode -eq 1) "invalid env shape should exit 1"
    Assert-Equal $invalidEnvShapeResult.Data.classification "unknown" "Expected unknown classification for invalid env shape"

    $emptyEnvNamePath = Join-Path $workspace "empty-env-name.json"
    $emptyEnv = @{}
    $emptyEnv[""] = "value"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", "-Command", "Write-Output should-not-run"); cwd = $workspace; timeout_seconds = 15; env = $emptyEnv } $emptyEnvNamePath
    $emptyEnvNameResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $emptyEnvNamePath)
    Assert-True ($emptyEnvNameResult.ExitCode -eq 1) "empty env variable name should exit 1"
    Assert-Equal $emptyEnvNameResult.Data.classification "unknown" "Expected unknown classification for empty env variable name"

    $equalsEnvNamePath = Join-Path $workspace "equals-env-name.json"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", "-Command", "Write-Output should-not-run"); cwd = $workspace; timeout_seconds = 15; env = @{ "BAD=NAME" = "value" } } $equalsEnvNamePath
    $equalsEnvNameResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $equalsEnvNamePath)
    Assert-True ($equalsEnvNameResult.ExitCode -eq 1) "env variable name containing equals should exit 1"
    Assert-Equal $equalsEnvNameResult.Data.classification "unknown" "Expected unknown classification for env name containing equals"
    Assert-True ($equalsEnvNameResult.Data.stdout -notmatch "should-not-run") "invalid env name command should not run"

    $argsShapeMessage = "args must be a JSON array of scalar values"

    $objectArgsPath = Join-Path $workspace "object-args.json"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @{ bad = "-Command"; payload = "Write-Output should-not-run" }; cwd = $workspace; timeout_seconds = 15; env = @{} } $objectArgsPath
    $objectArgsResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $objectArgsPath)
    Assert-True ($objectArgsResult.ExitCode -eq 1) "object args should exit 1"
    Assert-True ($objectArgsResult.Data.stdout -notmatch "should-not-run") "object args command should not run"
    Assert-True ($objectArgsResult.Data.stderr -match [regex]::Escape($argsShapeMessage)) "object args should report invalid args shape"

    $scalarArgsPath = Join-Path $workspace "scalar-args.json"
    Write-JsonSpec @{ command = $PowerShellCommand; args = "-NoProfile -Command Write-Output should-not-run"; cwd = $workspace; timeout_seconds = 15; env = @{} } $scalarArgsPath
    $scalarArgsResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $scalarArgsPath)
    Assert-True ($scalarArgsResult.ExitCode -eq 1) "scalar args should exit 1"
    Assert-True ($scalarArgsResult.Data.stdout -notmatch "should-not-run") "scalar args command should not run"
    Assert-True ($scalarArgsResult.Data.stderr -match [regex]::Escape($argsShapeMessage)) "scalar args should report invalid args shape"

    $nestedArgsPath = Join-Path $workspace "nested-args.json"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", @("-Command", "Write-Output should-not-run")); cwd = $workspace; timeout_seconds = 15; env = @{} } $nestedArgsPath
    $nestedArgsResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $nestedArgsPath)
    Assert-True ($nestedArgsResult.ExitCode -eq 1) "nested args should exit 1"
    Assert-True ($nestedArgsResult.Data.stdout -notmatch "should-not-run") "nested args command should not run"
    Assert-True ($nestedArgsResult.Data.stderr -match [regex]::Escape($argsShapeMessage)) "nested args should report invalid args shape"

    $stdoutFailurePath = Join-Path $workspace "stdout-failure.json"
    Write-JsonSpec @{ command = "cmd.exe"; args = @("/c", "echo Cannot find path smoke& exit /b 3"); cwd = $workspace; timeout_seconds = 15 } $stdoutFailurePath
    $stdoutFailureResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $stdoutFailurePath)
    Assert-True ($stdoutFailureResult.ExitCode -eq 1) "failing command should exit 1"
    Assert-True ($stdoutFailureResult.Data.exit_code -eq 3) "Expected child exit_code=3"
    Assert-True ($stdoutFailureResult.Data.classification -eq "path-handling") "Expected classification from stdout fallback"

    # Wall-clock and JSON duration include PowerShell startup, WMI, stream closing, and taskkill overhead.
    $timeoutWallClockLimitMs = 7000
    $timeoutDurationLimitMs = $timeoutWallClockLimitMs
    $nestedChildSleepSeconds = 12

    $timeoutPath = Join-Path $workspace "timeout.json"
    $powerShellCommandLiteral = "'" + ($PowerShellCommand -replace "'", "''") + "'"
    $nestedSleepCommand = "Start-Process -FilePath $powerShellCommandLiteral -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds $nestedChildSleepSeconds') -NoNewWindow -Wait"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", "-Command", $nestedSleepCommand); cwd = $workspace; timeout_seconds = 1 } $timeoutPath
    $timeoutWatch = [Diagnostics.Stopwatch]::StartNew()
    $timeoutResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $timeoutPath)
    $timeoutWatch.Stop()
    Assert-True ($timeoutResult.ExitCode -eq 1) "timeout command should exit 1"
    Assert-True ($timeoutResult.Data.exit_code -eq 124) "Expected timeout exit_code=124"
    Assert-True ($timeoutResult.Data.classification -eq "timeout-and-process") "Expected timeout-and-process classification"
    Assert-True ($timeoutWatch.ElapsedMilliseconds -lt $timeoutWallClockLimitMs) "timeout should not wait for nested ${nestedChildSleepSeconds}s child sleep; elapsed=$($timeoutWatch.ElapsedMilliseconds)ms"
    Assert-True ($timeoutResult.Data.duration_ms -lt $timeoutDurationLimitMs) "timeout duration_ms should include bounded cleanup; duration_ms=$($timeoutResult.Data.duration_ms)"

    $earlyExitTimeoutPath = Join-Path $workspace "early-exit-timeout.json"
    $earlyExitCommand = "Start-Process -FilePath $powerShellCommandLiteral -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds $nestedChildSleepSeconds') -NoNewWindow"
    Write-JsonSpec @{ command = $PowerShellCommand; args = @("-NoProfile", "-Command", $earlyExitCommand); cwd = $workspace; timeout_seconds = 1 } $earlyExitTimeoutPath
    $earlyExitWatch = [Diagnostics.Stopwatch]::StartNew()
    $earlyExitResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $earlyExitTimeoutPath)
    $earlyExitWatch.Stop()
    Assert-True ($earlyExitResult.ExitCode -eq 1) "early-exit child handle timeout should exit 1"
    Assert-True ($earlyExitResult.Data.exit_code -eq 124) "Expected early-exit timeout exit_code=124"
    Assert-True ($earlyExitResult.Data.timed_out -eq $true) "Expected early-exit timeout timed_out=true"
    Assert-Equal $earlyExitResult.Data.classification "timeout-and-process" "Expected early-exit timeout classification"
    Assert-True ($earlyExitWatch.ElapsedMilliseconds -lt $timeoutWallClockLimitMs) "early-exit timeout should not wait for nested ${nestedChildSleepSeconds}s child sleep; elapsed=$($earlyExitWatch.ElapsedMilliseconds)ms"
    Assert-True ($earlyExitResult.Data.duration_ms -lt $timeoutDurationLimitMs) "early-exit timeout duration_ms should be bounded; duration_ms=$($earlyExitResult.Data.duration_ms)"

    $argvEchoScript = Join-Path $workspace "echo-argv.ps1"
    Set-Content -LiteralPath $argvEchoScript -Value '$args | ConvertTo-Json -Compress' -Encoding UTF8
    $argvSpecPath = Join-Path $workspace "argv-roundtrip.json"
    $expectedArgv = @("", "space arg", 'a"b', 'json:{"x":"y z"}', "C:\path with space\")
    Write-JsonSpec @{
        command = $PowerShellCommand
        args = @("-NoProfile", "-File", $argvEchoScript) + $expectedArgv
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "normal"
    } $argvSpecPath
    $argvResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $argvSpecPath)
    Assert-True ($argvResult.ExitCode -eq 0) "argv round-trip command should exit 0"
    $actualArgvJson = $argvResult.Data.stdout | ConvertFrom-Json
    $actualArgv = @()
    foreach ($actualArgvItem in $actualArgvJson) { $actualArgv += [string]$actualArgvItem }
    Assert-Equal $actualArgv.Count $expectedArgv.Count "Expected argv item count to round-trip"
    for ($i = 0; $i -lt $expectedArgv.Count; $i++) {
        Assert-Equal $actualArgv[$i] $expectedArgv[$i] "Expected argv[$i] to round-trip"
    }

    $cwdCommandPath = Join-Path $workspace "hello-agent-review.cmd"
    Set-Content -LiteralPath $cwdCommandPath -Value @("@echo off", "echo cwd-relative-ok") -Encoding ASCII
    $cwdRelativeSpecPath = Join-Path $workspace "cwd-relative.json"
    Write-JsonSpec @{ command = ".\hello-agent-review.cmd"; args = @(); cwd = $workspace; timeout_seconds = 15; env = @{} } $cwdRelativeSpecPath
    $cwdRelativeResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $cwdRelativeSpecPath)
    Assert-True ($cwdRelativeResult.ExitCode -eq 0) "cwd-relative Application command should exit 0"
    Assert-True ($cwdRelativeResult.Data.stdout -match "cwd-relative-ok") "Expected cwd-relative command output"

    $pathToolDir = Join-Path $workspace "path-tools"
    New-Item -ItemType Directory -Path $pathToolDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $pathToolDir "path-only-agent.cmd") -Value @("@echo off", "echo path-only") -Encoding ASCII
    $pathOverrideSpecPath = Join-Path $workspace "path-override.json"
    Write-JsonSpec @{ command = "path-only-agent.cmd"; args = @(); cwd = $workspace; timeout_seconds = 15; env = @{ PATH = "$pathToolDir;$env:PATH" } } $pathOverrideSpecPath
    $pathOverrideResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $pathOverrideSpecPath)
    Assert-True ($pathOverrideResult.ExitCode -eq 1) "PATH override discovery should be explicit in V0.1"
    Assert-Equal $pathOverrideResult.Data.classification "tool-discovery" "Expected tool-discovery for PATH override command discovery"
    Assert-True ($pathOverrideResult.Data.stderr -match "PATH") "Expected PATH override rejection reason"

    Write-Output "[OK] smoke tests passed"
}
finally {
    if (Test-Path -LiteralPath $workspace) {
        Remove-Item -LiteralPath $workspace -Recurse -Force
    }
}
