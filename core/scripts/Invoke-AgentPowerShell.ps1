$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SpecPath = $null

function Set-AgentUtf8Output {
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [Console]::OutputEncoding = $utf8NoBom
        $script:OutputEncoding = $utf8NoBom
    }
    catch {}
}

Set-AgentUtf8Output

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
        [AllowNull()][string]$Cmdlet,
        [AllowNull()][string]$Reason,
        [object[]]$Output = @()
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
        cmdlet = $Cmdlet
        reason = $Reason
        output = @($Output)
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
        [AllowNull()][string]$Cmdlet = $null,
        [AllowNull()][string]$Reason = $null
    )

    if ([string]::IsNullOrEmpty($Reason)) { $Reason = $Message }
    $result = New-BaseResult -Status "error" -ChildExitCode $ChildExitCode -Stdout "" -Stderr $Message -DurationMs $DurationMs -Classification $Classification -TimedOut $TimedOut -TimeoutSeconds $TimeoutSeconds -Cwd $Cwd -Risk $Risk -Cmdlet $Cmdlet -Reason $Reason
    Write-JsonResult $result $ProcessExitCode
}

function Get-CurrentPowerShellHostPath {
    try {
        $currentProcess = Get-Process -Id $PID -ErrorAction Stop
        if ($currentProcess.Path -and (Test-Path -LiteralPath $currentProcess.Path -PathType Leaf)) {
            return [string]$currentProcess.Path
        }
    }
    catch {}

    return "powershell.exe"
}

function Classify-Text {
    param([AllowNull()][string]$Text, [int]$Code)

    if ($null -eq $Text) { $Text = "" }
    $classifier = Join-Path $ScriptRoot "Classify-AgentFailure.ps1"
    try {
        $raw = & (Get-CurrentPowerShellHostPath) -NoProfile -ExecutionPolicy Bypass -File $classifier -ErrorText $Text -ExitCode $Code 2>&1
        $json = ($raw | Out-String).Trim()
        if (-not $json) { return "unknown" }
        return ($json | ConvertFrom-Json).classification
    }
    catch {
        return "unknown"
    }
}

function Get-SpecProperty {
    param($Spec, [string]$Name)

    if ($Spec -is [System.Collections.IDictionary]) {
        if (-not $Spec.ContainsKey($Name)) { return $null }
        return $Spec[$Name]
    }

    $property = $Spec.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-SpecProperty {
    param($Spec, [string]$Name)

    if ($Spec -is [System.Collections.IDictionary]) {
        return $Spec.ContainsKey($Name)
    }

    return ($null -ne $Spec.PSObject.Properties[$Name])
}

function Test-JsonScalarOrArrayValue {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $true }
    if ($Value -is [pscustomobject]) { return $false }
    if ($Value -is [System.Collections.IDictionary]) { return $false }
    if ($Value -is [array]) {
        foreach ($item in $Value) {
            if (-not (Test-JsonScalarOrArrayValue -Value $item)) { return $false }
        }
    }
    return $true
}

function ConvertTo-ParameterValue {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [array]) {
        $items = @()
        foreach ($item in $Value) {
            if ($null -eq $item) {
                $items += $null
            }
            else {
                $items += $item
            }
        }
        return $items
    }
    return $Value
}

function ConvertTo-SerializableOutput {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return [string]$Value }
    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [int]) { return [int]$Value }
    if ($Value -is [long]) { return [long]$Value }
    if ($Value -is [double]) { return [double]$Value }
    if ($Value -is [decimal]) { return [decimal]$Value }

    $valueProperty = $Value.PSObject.Properties["Value"]
    if (-not $valueProperty) {
        $valueProperty = $Value.PSObject.Properties["value"]
    }
    if ($valueProperty -and $Value.PSObject.Properties["PSComputerName"]) {
        return $valueProperty.Value
    }

    $properties = [ordered]@{}
    foreach ($name in @("Name", "FullName", "Path", "ProviderPath", "PSPath", "CommandType", "Source", "Version", "Id", "ProcessName", "ServiceName", "DisplayName", "Status")) {
        $property = $Value.PSObject.Properties[$name]
        if ($property) {
            $properties[$name] = $property.Value
        }
    }

    if ($properties.Count -gt 0) {
        return [pscustomobject]$properties
    }

    return [string]$Value
}

$AllowedCmdlets = @{
    "Test-Path" = @("LiteralPath", "Path", "PathType", "IsValid")
    "Resolve-Path" = @("LiteralPath", "Path", "Relative")
    "Get-Item" = @("LiteralPath", "Path", "Force")
    "Get-ChildItem" = @("LiteralPath", "Path", "Force", "Name", "File", "Directory")
    "Get-Content" = @("LiteralPath", "Path", "Raw", "TotalCount", "Encoding")
    "Get-Command" = @("Name", "CommandType", "Module")
    "Get-Location" = @()
    "Get-Process" = @("Name", "Id")
    "Get-Service" = @("Name", "DisplayName")
    "Select-String" = @("LiteralPath", "Path", "Pattern", "SimpleMatch", "CaseSensitive", "Quiet")
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
    Write-ErrorResult -Message "Destructive command risk is not allowed in Invoke-AgentPowerShell.ps1 read-only mode" -Classification "destructive-op-risk" -Risk $risk
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

$cmdletValue = Get-SpecProperty -Spec $spec -Name "cmdlet"
if ($null -eq $cmdletValue -or $cmdletValue -is [array] -or $cmdletValue -is [pscustomobject] -or [string]::IsNullOrWhiteSpace([string]$cmdletValue)) {
    Write-ErrorResult -Message "Spec cmdlet is required" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk
}

$cmdletName = ([string]$cmdletValue).Trim()
if ($cmdletName -notmatch '^[A-Za-z][A-Za-z0-9-]*$') {
    Write-ErrorResult -Message "Cmdlet name must be a simple command name without wildcards, module qualification, or path separators" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $cmdletName
}

try {
    $commandInfo = Get-Command -Name $cmdletName -ErrorAction Stop | Select-Object -First 1
}
catch {
    Write-ErrorResult -Message "Cmdlet was not found: $cmdletName" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $cmdletName
}

if ($commandInfo.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
    Write-ErrorResult -Message "Aliases are not accepted in Invoke-AgentPowerShell.ps1 read-only mode; use the canonical cmdlet name" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $cmdletName
}

if ($commandInfo.CommandType -ne [System.Management.Automation.CommandTypes]::Cmdlet) {
    Write-ErrorResult -Message "Only allowlisted cmdlets are accepted in Invoke-AgentPowerShell.ps1 read-only mode; command type was $($commandInfo.CommandType)" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $cmdletName
}

$canonicalCmdlet = [string]$commandInfo.Name
if (-not $AllowedCmdlets.ContainsKey($canonicalCmdlet)) {
    Write-ErrorResult -Message "Cmdlet is not in the read-only allowlist: $canonicalCmdlet" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet
}

$parameters = @{}
if (Test-SpecProperty -Spec $spec -Name "parameters") {
    $parameterValue = Get-SpecProperty -Spec $spec -Name "parameters"
    if ($null -eq $parameterValue -or $parameterValue -is [array] -or $parameterValue -isnot [pscustomobject]) {
        Write-ErrorResult -Message "parameters must be a JSON object" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet
    }

    $allowedParameters = @($AllowedCmdlets[$canonicalCmdlet])
    foreach ($prop in $parameterValue.PSObject.Properties) {
        $parameterName = [string]$prop.Name
        if ([string]::IsNullOrWhiteSpace($parameterName) -or $parameterName.StartsWith("-")) {
            Write-ErrorResult -Message "Parameter names must be bare names without leading dashes" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet
        }
        if ($allowedParameters -notcontains $parameterName) {
            Write-ErrorResult -Message "Parameter is not allowed for ${canonicalCmdlet}: $parameterName" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet
        }
        if (-not (Test-JsonScalarOrArrayValue -Value $prop.Value)) {
            Write-ErrorResult -Message "Parameter values must be JSON scalars or arrays of scalars" -Classification "read-only-policy" -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet
        }
        $parameters[$parameterName] = ConvertTo-ParameterValue -Value $prop.Value
    }
}

$jobScript = {
    param(
        [string]$InnerCmdletName,
        [hashtable]$InnerParameters,
        [AllowNull()][string]$InnerCwd
    )

    $ErrorActionPreference = "Stop"
    if (-not [string]::IsNullOrWhiteSpace($InnerCwd)) {
        Set-Location -LiteralPath $InnerCwd
    }
    & $InnerCmdletName @InnerParameters
}

$sw = [Diagnostics.Stopwatch]::StartNew()
$job = $null
try {
    $job = Start-Job -ScriptBlock $jobScript -ArgumentList $canonicalCmdlet, $parameters, $cwd
    $completed = Wait-Job -Job $job -Timeout $timeout
    if ($null -eq $completed) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        $sw.Stop()
        $message = "TIMEOUT after ${timeout}s"
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        $timeoutResult = New-BaseResult -Status "error" -ChildExitCode 124 -Stdout "" -Stderr $message -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification "timeout-and-process" -TimedOut $true -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet -Reason $message
        Write-JsonResult $timeoutResult 1
    }

    $jobErrors = @()
    $rawOutput = @(Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable jobErrors)
    $sw.Stop()

    $reason = $null
    if ($job.State -ne "Completed") {
        $reason = if ($job.ChildJobs.Count -gt 0 -and $job.ChildJobs[0].JobStateInfo.Reason) { [string]$job.ChildJobs[0].JobStateInfo.Reason.Message } else { "PowerShell job did not complete successfully: $($job.State)" }
    }
    if ($jobErrors.Count -gt 0) {
        $errorText = (($jobErrors | ForEach-Object { $_.ToString() }) -join "`n")
        if ([string]::IsNullOrWhiteSpace($reason)) { $reason = $errorText } else { $reason = $reason + "`n" + $errorText }
    }

    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $job = $null

    if (-not [string]::IsNullOrWhiteSpace($reason)) {
        $classification = Classify-Text -Text $reason -Code 1
        $errorResult = New-BaseResult -Status "error" -ChildExitCode 1 -Stdout (($rawOutput | Out-String).TrimEnd()) -Stderr $reason -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification $classification -TimedOut $false -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet -Reason $reason -Output @()
        Write-JsonResult $errorResult 1
    }

    $serializableOutput = @()
    foreach ($item in $rawOutput) {
        $serializableOutput += ConvertTo-SerializableOutput -Value $item
    }
    $stdout = ($rawOutput | Out-String).TrimEnd()
    $successResult = New-BaseResult -Status "success" -ChildExitCode 0 -Stdout $stdout -Stderr "" -DurationMs ([int]$sw.ElapsedMilliseconds) -Classification $null -TimedOut $false -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet -Reason $null -Output $serializableOutput
    Write-JsonResult $successResult 0
}
catch {
    if ($sw.IsRunning) { $sw.Stop() }
    if ($job) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    $message = $_.Exception.Message
    $classification = Classify-Text -Text $message -Code 1
    Write-ErrorResult -Message $message -Classification $classification -DurationMs ([int]$sw.ElapsedMilliseconds) -TimeoutSeconds $timeout -Cwd $cwd -Risk $risk -Cmdlet $canonicalCmdlet
}
