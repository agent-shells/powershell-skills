param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Command = $null
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

function Write-JsonResult {
    param($Value, [int]$ExitCode)
    $Value | ConvertTo-Json -Depth 8 -Compress
    exit $ExitCode
}

if ([string]::IsNullOrWhiteSpace($Command)) {
    Write-JsonResult @{
        status = "error"
        command = $Command
        found = $false
        source = $null
        command_type = $null
        version = $null
        classification = "tool-discovery"
        reason = "Command is required"
    } 1
}

if ($Command.IndexOfAny([char[]]"*?[]") -ge 0) {
    Write-JsonResult @{
        status = "error"
        command = $Command
        found = $false
        source = $null
        command_type = $null
        version = $null
        classification = "tool-discovery"
        reason = "Command contains wildcard characters"
    } 1
}

$commandMatches = @(Get-Command -Name $Command -All -ErrorAction SilentlyContinue)
$found = $commandMatches |
    Where-Object { $_.CommandType -eq [System.Management.Automation.CommandTypes]::Application } |
    Select-Object -First 1

if (-not $found) {
    $found = $commandMatches |
        Where-Object { $_.CommandType -ne [System.Management.Automation.CommandTypes]::Alias } |
        Select-Object -First 1
}

if (-not $found) {
    $alias = $commandMatches |
        Where-Object { $_.CommandType -eq [System.Management.Automation.CommandTypes]::Alias } |
        Select-Object -First 1

    if ($alias) {
        Write-JsonResult @{
            status = "error"
            command = $Command
            found = $false
            source = [string]$alias.Source
            command_type = $alias.CommandType.ToString()
            version = $null
            classification = "tool-discovery"
            reason = "Only alias match found"
            alias_target = [string]$alias.Definition
        } 1
    }

    Write-JsonResult @{
        status = "error"
        command = $Command
        found = $false
        source = $null
        command_type = $null
        version = $null
        classification = "tool-discovery"
        reason = "Command not found"
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
    source = [string]$found.Source
    command_type = $found.CommandType.ToString()
    version = $version
    classification = $null
} 0
