$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SpecPath = $null

function Test-KnownParameterName {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return $false }
    return ($Value -eq "-SpecPath")
}

for ($i = 0; $i -lt $args.Count; $i++) {
    $token = [string]$args[$i]
    if ($token -eq "-SpecPath") {
        if ($i + 1 -lt $args.Count -and -not (Test-KnownParameterName -Value ([string]$args[$i + 1]))) {
            $i++
            $SpecPath = [string]$args[$i]
        }
        else {
            $SpecPath = ""
        }
    }
    elseif ($null -eq $SpecPath) {
        $SpecPath = $token
    }
}

function Write-JsonResult {
    param($Value, [int]$ExitCode)

    $Value | ConvertTo-Json -Depth 12 -Compress
    exit $ExitCode
}

function New-BaseResult {
    param(
        [string]$Status,
        [int]$ChildExitCode,
        [string]$Stdout,
        [string]$Stderr,
        [int]$DurationMs,
        [AllowNull()][string]$Classification,
        [bool]$TimedOut,
        [int]$TimeoutSeconds,
        [AllowNull()][string]$Cwd,
        [string]$Risk,
        [AllowNull()][string]$Command
    )

    return @{
        status = $Status
        exit_code = $ChildExitCode
        stdout = $Stdout
        stderr = $Stderr
        duration_ms = $DurationMs
        classification = $Classification
        timed_out = $TimedOut
        timeout_seconds = $TimeoutSeconds
        cwd = $Cwd
        risk = $Risk
        command = $Command
    }
}

function Write-ErrorResult {
    param(
        [string]$Message,
        [string]$Classification,
        [int]$ChildExitCode = 1,
        [int]$ProcessExitCode = 1,
        [int]$DurationMs = 0,
        [bool]$TimedOut = $false,
        [int]$TimeoutSeconds = 0,
        [AllowNull()][string]$Cwd = $null,
        [string]$Risk = "normal",
        [AllowNull()][string]$Command = $null
    )

    $result = New-BaseResult -Status "error" -ChildExitCode $ChildExitCode -Stdout "" -Stderr $Message -DurationMs $DurationMs -Classification $Classification -TimedOut $TimedOut -TimeoutSeconds $TimeoutSeconds -Cwd $Cwd -Risk $Risk -Command $Command
    Write-JsonResult $result $ProcessExitCode
}

function ConvertTo-PSLiteral {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { $Value = "" }
    return "'" + ($Value -replace "'", "''") + "'"
}

function Classify-Text {
    param([AllowNull()][string]$Text, [int]$Code)

    if ($null -eq $Text) { $Text = "" }
    $classifier = Join-Path $ScriptRoot "Classify-AgentFailure.ps1"
    try {
        $raw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $classifier -ErrorText $Text -ExitCode $Code 2>&1
        $json = ($raw | Out-String).Trim()
        if (-not $json) { return "unknown" }
        return ($json | ConvertFrom-Json).classification
    }
    catch {
        return "unknown"
    }
}

function Test-CommandWithHelper {
    param([string]$Command)

    $helper = Join-Path $ScriptRoot "Test-AgentCommand.ps1"
    try {
        $raw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper -Command $Command 2>&1
        $helperExitCode = $LASTEXITCODE
        $json = ($raw | Out-String).Trim()
        if (-not $json) {
            return [pscustomobject]@{
                ExitCode = 1
                Data = [pscustomobject]@{
                    classification = "tool-discovery"
                    reason = "Command discovery produced no JSON"
                }
            }
        }
        return [pscustomobject]@{
            ExitCode = $helperExitCode
            Data = ($json | ConvertFrom-Json)
        }
    }
    catch {
        return [pscustomobject]@{
            ExitCode = 1
            Data = [pscustomobject]@{
                classification = "tool-discovery"
                reason = $_.Exception.Message
            }
        }
    }
}

function Get-SpecProperty {
    param($Spec, [string]$Name)

    $property = $Spec.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-SpecProperty {
    param($Spec, [string]$Name)

    return ($null -ne $Spec.PSObject.Properties[$Name])
}

if ([string]::IsNullOrWhiteSpace($SpecPath)) {
    Write-ErrorResult -Message "SpecPath is required" -Classification "path-handling"
}

try {
    $specExists = Test-Path -LiteralPath $SpecPath -PathType Leaf
}
catch {
    Write-ErrorResult -Message ("SpecPath is invalid: " + $_.Exception.Message) -Classification "path-handling"
}

if (-not $specExists) {
    Write-ErrorResult -Message "Spec file not found: $SpecPath" -Classification "path-handling"
}

try {
    $specText = Get-Content -LiteralPath $SpecPath -Raw
    $spec = $specText | ConvertFrom-Json
}
catch {
    Write-ErrorResult -Message ("Failed to read or parse spec JSON: " + $_.Exception.Message) -Classification "unknown"
}

if ($null -eq $spec -or $spec -is [array]) {
    Write-ErrorResult -Message "Spec JSON must be an object" -Classification "unknown"
}

$riskValue = Get-SpecProperty -Spec $spec -Name "risk"
$risk = if ($null -eq $riskValue -or [string]::IsNullOrWhiteSpace([string]$riskValue)) { "normal" } else { [string]$riskValue }

if ($risk -eq "destructive") {
    Write-ErrorResult -Message "Destructive command risk requires target validation outside Invoke-AgentCommand.ps1 V0.1" -Classification "destructive-op-risk" -Risk $risk
}

$timeout = 30
if (Test-SpecProperty -Spec $spec -Name "timeout_seconds") {
    $timeoutValue = Get-SpecProperty -Spec $spec -Name "timeout_seconds"
    $timeoutText = if ($null -eq $timeoutValue) { "" } else { [string]$timeoutValue }
    $parsedTimeout = 0
    if (-not [int]::TryParse($timeoutText, [ref]$parsedTimeout) -or $parsedTimeout -le 0) {
        Write-ErrorResult -Message "timeout_seconds must be a positive integer" -Classification "timeout-and-process" -TimeoutSeconds 0 -Risk $risk
    }
    $timeout = $parsedTimeout
}

$cwd = $null
if (Test-SpecProperty -Spec $spec -Name "cwd") {
    $cwdValue = Get-SpecProperty -Spec $spec -Name "cwd"
    if ($null -eq $cwdValue -or [string]::IsNullOrWhiteSpace([string]$cwdValue)) {
        Write-ErrorResult -Message "Working directory is invalid" -Classification "path-handling" -TimeoutSeconds $timeout -Risk $risk
    }

    try {
        if (-not (Test-Path -LiteralPath ([string]$cwdValue) -PathType Container)) {
            Write-ErrorResult -Message "Working directory not found: $cwdValue" -Classification "path-handling" -TimeoutSeconds $timeout -Risk $risk
        }
        $cwd = (Resolve-Path -LiteralPath ([string]$cwdValue)).Path
    }
    catch {
        Write-ErrorResult -Message ("Working directory is invalid: " + $_.Exception.Message) -Classification "path-handling" -TimeoutSeconds $timeout -Risk $risk
    }
}

$commandValue = Get-SpecProperty -Spec $spec -Name "command"
$command = if ($null -eq $commandValue) { $null } else { [string]$commandValue }
if ([string]::IsNullOrWhiteSpace($command)) {
    Write-ErrorResult -Message "Spec command is required" -Classification "tool-discovery" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command
}

$commandCheck = Test-CommandWithHelper -Command $command
if ($commandCheck.ExitCode -ne 0 -or -not $commandCheck.Data.found) {
    $classification = if ($commandCheck.Data.classification) { [string]$commandCheck.Data.classification } else { "tool-discovery" }
    $reason = if ($commandCheck.Data.reason) { [string]$commandCheck.Data.reason } else { "Command discovery failed" }
    Write-ErrorResult -Message $reason -Classification $classification -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command
}

$args = @()
$argsValue = Get-SpecProperty -Spec $spec -Name "args"
if ($null -ne $argsValue) {
    foreach ($arg in @($argsValue)) {
        if ($null -eq $arg) {
            $args += ""
        }
        else {
            $args += [string]$arg
        }
    }
}

$commandParts = @("&", (ConvertTo-PSLiteral $command))
foreach ($arg in $args) {
    $commandParts += (ConvertTo-PSLiteral $arg)
}
$invokeText = $commandParts -join " "
$commandText = @"
$invokeText
`$agentCommandSucceeded = `$?
`$agentLastExitCode = `$global:LASTEXITCODE
if (`$null -ne `$agentLastExitCode) { exit `$agentLastExitCode }
if (`$agentCommandSucceeded) { exit 0 }
exit 1
"@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell.exe"
$psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encoded"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
if ($cwd) { $psi.WorkingDirectory = $cwd }

$envValue = Get-SpecProperty -Spec $spec -Name "env"
if ($null -ne $envValue) {
    foreach ($prop in $envValue.PSObject.Properties) {
        $psi.EnvironmentVariables[$prop.Name] = if ($null -eq $prop.Value) { "" } else { [string]$prop.Value }
    }
}

$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    $proc = [Diagnostics.Process]::Start($psi)
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    if (-not $proc.WaitForExit($timeout * 1000)) {
        try { $proc.Kill() } catch {}
        try { $proc.WaitForExit() } catch {}
        $sw.Stop()

        $timeoutStdout = ""
        $timeoutStderr = ""
        try { $timeoutStdout = $stdoutTask.Result } catch {}
        try { $timeoutStderr = $stderrTask.Result } catch {}
        if ([string]::IsNullOrEmpty($timeoutStderr)) { $timeoutStderr = "TIMEOUT after ${timeout}s" }

        $timeoutResult = New-BaseResult -Status "error" -ChildExitCode 124 -Stdout $timeoutStdout -Stderr $timeoutStderr -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification "timeout-and-process" -TimedOut $true -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command
        Write-JsonResult $timeoutResult 1
    }

    $sw.Stop()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exit = $proc.ExitCode
}
catch {
    $sw.Stop()
    $message = $_.Exception.Message
    $classification = Classify-Text -Text $message -Code 1
    Write-ErrorResult -Message $message -Classification $classification -DurationMs ([int]$sw.ElapsedMilliseconds) -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command
}

$status = if ($exit -eq 0) { "success" } else { "error" }
$classificationResult = $null
if ($exit -ne 0) {
    $failureText = (($stderr, $stdout) | Where-Object { -not [string]::IsNullOrEmpty($_) }) -join "`n"
    $classificationResult = Classify-Text -Text $failureText -Code $exit
}

$result = New-BaseResult -Status $status -ChildExitCode $exit -Stdout $stdout -Stderr $stderr -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification $classificationResult -TimedOut $false -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command
if ($exit -eq 0) {
    Write-JsonResult $result 0
}

Write-JsonResult $result 1
