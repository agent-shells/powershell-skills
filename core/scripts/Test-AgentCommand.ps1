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
