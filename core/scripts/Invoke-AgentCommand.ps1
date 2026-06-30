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
        [AllowNull()][string]$Command,
        [AllowNull()][string]$Reason
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
        reason = $Reason
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
        [AllowNull()][string]$Command = $null,
        [AllowNull()][string]$Reason = $null
    )

    if ([string]::IsNullOrEmpty($Reason)) { $Reason = $Message }
    $result = New-BaseResult -Status "error" -ChildExitCode $ChildExitCode -Stdout "" -Stderr $Message -DurationMs $DurationMs -Classification $Classification -TimedOut $TimedOut -TimeoutSeconds $TimeoutSeconds -Cwd $Cwd -Risk $Risk -Command $Command -Reason $Reason
    Write-JsonResult $result $ProcessExitCode
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

function ConvertTo-WindowsArgument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { $Value = "" }
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashCount = 0

    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') {
            $backslashCount++
            continue
        }

        if ($ch -eq '"') {
            if ($backslashCount -gt 0) {
                [void]$builder.Append("\" * ($backslashCount * 2))
                $backslashCount = 0
            }
            [void]$builder.Append('\"')
            continue
        }

        if ($backslashCount -gt 0) {
            [void]$builder.Append("\" * $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($ch)
    }

    if ($backslashCount -gt 0) {
        [void]$builder.Append("\" * ($backslashCount * 2))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Join-WindowsArguments {
    param([string[]]$ArgumentValues)

    $quoted = @()
    foreach ($argumentValue in $ArgumentValues) {
        $quoted += ConvertTo-WindowsArgument -Value $argumentValue
    }
    return ($quoted -join " ")
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

function Test-CommandPathLike {
    param([string]$Command)

    return ([System.IO.Path]::IsPathRooted($Command) -or $Command.IndexOf('\') -ge 0 -or $Command.IndexOf('/') -ge 0)
}

function Resolve-PathLikeCommand {
    param([string]$Command, [AllowNull()][string]$Cwd)

    try {
        if ([System.IO.Path]::IsPathRooted($Command)) {
            $candidate = [System.IO.Path]::GetFullPath($Command)
        }
        else {
            $base = if ($Cwd) { $Cwd } else { (Get-Location).ProviderPath }
            $candidate = [System.IO.Path]::GetFullPath((Join-Path $base $Command))
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "Command path is invalid: $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "Command path not found: $candidate"
        }
    }

    try {
        $resolvedPath = (Resolve-Path -LiteralPath $candidate).Path
        $commandInfo = Get-Command -Name $resolvedPath -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "Command path discovery failed: $($_.Exception.Message)"
        }
    }

    if (-not $commandInfo -or $commandInfo.CommandType -ne [System.Management.Automation.CommandTypes]::Application) {
        $actualType = if ($commandInfo) { $commandInfo.CommandType.ToString() } else { "unknown" }
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "Only Application commands are supported in Invoke-AgentCommand.ps1 V0.1; command type was $actualType"
        }
    }

    return [pscustomobject]@{
        Success = $true
        FileName = $resolvedPath
        Classification = $null
        Reason = $null
    }
}

function Resolve-ApplicationCommand {
    param(
        [string]$Command,
        [AllowNull()][string]$Cwd,
        [bool]$EnvPathOverride
    )

    if ($Command.IndexOfAny([char[]]"*?[]") -ge 0) {
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "Command contains wildcard characters"
        }
    }

    if (Test-CommandPathLike -Command $Command) {
        return Resolve-PathLikeCommand -Command $Command -Cwd $Cwd
    }

    if ($EnvPathOverride) {
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "env PATH command discovery is not supported in Invoke-AgentCommand.ps1 V0.1; use an explicit command path"
        }
    }

    $commandCheck = Test-CommandWithHelper -Command $Command
    if ($commandCheck.ExitCode -ne 0 -or -not $commandCheck.Data.found) {
        $classification = if ($commandCheck.Data.classification) { [string]$commandCheck.Data.classification } else { "tool-discovery" }
        $reason = if ($commandCheck.Data.reason) { [string]$commandCheck.Data.reason } else { "Command discovery failed" }
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = $classification
            Reason = $reason
        }
    }

    if ($commandCheck.Data.command_type -ne "Application") {
        return [pscustomobject]@{
            Success = $false
            FileName = $null
            Classification = "tool-discovery"
            Reason = "Only Application commands are supported in Invoke-AgentCommand.ps1 V0.1; command type was $($commandCheck.Data.command_type)"
        }
    }

    $source = if ($commandCheck.Data.source) { [string]$commandCheck.Data.source } else { $Command }
    return [pscustomobject]@{
        Success = $true
        FileName = $source
        Classification = $null
        Reason = $null
    }
}

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Process)

    $messages = @()
    try {
        $taskkillOutput = & taskkill.exe /PID $Process.Id /T /F 2>&1
        if ($taskkillOutput) { $messages += (($taskkillOutput | Out-String).Trim()) }
        if ($LASTEXITCODE -ne 0 -and -not $Process.HasExited) {
            try { $Process.Kill() } catch {}
        }
    }
    catch {
        $messages += "taskkill failed: $($_.Exception.Message)"
        try { $Process.Kill() } catch {}
    }

    try { [void]$Process.WaitForExit(2000) } catch {}
    return (($messages | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n")
}

function Read-CompletedTaskText {
    param($Task)

    try {
        if ($Task.Wait(500)) { return [string]$Task.Result }
    }
    catch {
        return ""
    }
    return ""
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

if ($null -eq $spec -or $spec -is [array] -or $spec -isnot [pscustomobject]) {
    Write-ErrorResult -Message "Spec JSON must be an object" -Classification "unknown"
}

$riskValue = Get-SpecProperty -Spec $spec -Name "risk"
if ($null -eq $riskValue -or [string]::IsNullOrWhiteSpace([string]$riskValue)) {
    $risk = "normal"
}
elseif ($riskValue -is [array] -or $riskValue -is [pscustomobject]) {
    Write-ErrorResult -Message "risk must be one of: normal, high, diagnostic, destructive" -Classification "unknown"
}
else {
    $risk = ([string]$riskValue).Trim().ToLowerInvariant()
}

$allowedRisks = @("normal", "high", "diagnostic", "destructive")
if ($allowedRisks -notcontains $risk) {
    Write-ErrorResult -Message "risk must be one of: normal, high, diagnostic, destructive" -Classification "unknown" -Risk $risk
}

if ($risk -eq "destructive") {
    Write-ErrorResult -Message "Destructive command risk requires target validation outside Invoke-AgentCommand.ps1 V0.1" -Classification "destructive-op-risk" -Risk $risk
}

$timeout = 30
if (Test-SpecProperty -Spec $spec -Name "timeout_seconds") {
    $timeoutValue = Get-SpecProperty -Spec $spec -Name "timeout_seconds"
    if ($timeoutValue -is [array] -or $timeoutValue -is [pscustomobject]) {
        Write-ErrorResult -Message "timeout_seconds must be a positive integer" -Classification "timeout-and-process" -TimeoutSeconds 0 -Risk $risk
    }
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
    if ($null -eq $cwdValue -or $cwdValue -is [array] -or $cwdValue -is [pscustomobject] -or [string]::IsNullOrWhiteSpace([string]$cwdValue)) {
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

$envValues = @{}
$envPathOverride = $false
if (Test-SpecProperty -Spec $spec -Name "env") {
    $envValue = Get-SpecProperty -Spec $spec -Name "env"
    if ($null -eq $envValue -or $envValue -is [array] -or $envValue -isnot [pscustomobject]) {
        Write-ErrorResult -Message "env must be a JSON object" -Classification "unknown" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk
    }

    foreach ($prop in $envValue.PSObject.Properties) {
        if ([string]::IsNullOrWhiteSpace($prop.Name)) {
            Write-ErrorResult -Message "env variable names must not be empty" -Classification "unknown" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk
        }
        $envValues[$prop.Name] = if ($null -eq $prop.Value) { "" } else { [string]$prop.Value }
        if ($prop.Name -ieq "PATH") { $envPathOverride = $true }
    }
}

$commandValue = Get-SpecProperty -Spec $spec -Name "command"
$command = if ($null -eq $commandValue) { $null } else { [string]$commandValue }
if ([string]::IsNullOrWhiteSpace($command)) {
    Write-ErrorResult -Message "Spec command is required" -Classification "tool-discovery" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command
}

$resolvedCommand = Resolve-ApplicationCommand -Command $command -Cwd $cwd -EnvPathOverride $envPathOverride
if (-not $resolvedCommand.Success) {
    Write-ErrorResult -Message $resolvedCommand.Reason -Classification $resolvedCommand.Classification -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command -Reason $resolvedCommand.Reason
}

$commandArgs = @()
$argsValue = Get-SpecProperty -Spec $spec -Name "args"
if ($null -ne $argsValue) {
    foreach ($arg in @($argsValue)) {
        if ($null -eq $arg) {
            $commandArgs += ""
        }
        else {
            $commandArgs += [string]$arg
        }
    }
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = [string]$resolvedCommand.FileName
$psi.Arguments = Join-WindowsArguments -ArgumentValues $commandArgs
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
if ($cwd) { $psi.WorkingDirectory = $cwd }

foreach ($envName in $envValues.Keys) {
    $psi.EnvironmentVariables[$envName] = [string]$envValues[$envName]
}

$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    $proc = [Diagnostics.Process]::Start($psi)
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    if (-not $proc.WaitForExit($timeout * 1000)) {
        $killOutput = Stop-ProcessTree -Process $proc
        $timeoutStdout = Read-CompletedTaskText -Task $stdoutTask
        $timeoutStderr = Read-CompletedTaskText -Task $stderrTask
        $sw.Stop()

        $timeoutMessage = "TIMEOUT after ${timeout}s"
        if ([string]::IsNullOrEmpty($timeoutStderr)) {
            $timeoutStderr = $timeoutMessage
        }
        else {
            $timeoutStderr = $timeoutStderr.TrimEnd() + "`n" + $timeoutMessage
        }
        if (-not [string]::IsNullOrWhiteSpace($killOutput)) {
            $timeoutStderr = $timeoutStderr.TrimEnd() + "`n" + $killOutput
        }

        $timeoutResult = New-BaseResult -Status "error" -ChildExitCode 124 -Stdout $timeoutStdout -Stderr $timeoutStderr -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification "timeout-and-process" -TimedOut $true -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command -Reason $timeoutMessage
        Write-JsonResult $timeoutResult 1
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $sw.Stop()
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

$result = New-BaseResult -Status $status -ChildExitCode $exit -Stdout $stdout -Stderr $stderr -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification $classificationResult -TimedOut $false -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Command $command -Reason $null
if ($exit -eq 0) {
    Write-JsonResult $result 0
}

Write-JsonResult $result 1
