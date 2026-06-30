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
