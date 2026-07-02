param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Path = $null,
    [switch]$MustExist
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

$exists = $false
$fullPath = $null
$parent = $null
$unsafeReason = $null

if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-JsonResult @{
        status = "error"
        input_path = $Path
        exists = $false
        full_path = $null
        parent = $null
        use_literal_path = $true
        classification = "path-handling"
        unsafe_reason = "Path is required"
    } 1
}

try {
    $exists = Test-Path -LiteralPath $Path
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

if (-not $unsafeReason -and $MustExist -and -not $exists) {
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
