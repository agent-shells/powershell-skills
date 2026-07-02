param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$CodexHome = $null,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

$SkillName = "powershell-command-runner"
$InstallMarkerName = ".powershell-skills-install.json"
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).ProviderPath
$SourceAdapter = Join-Path $RepoRoot "adapters\codex\$SkillName"
$SourceCore = Join-Path $RepoRoot "core"

function Write-JsonResult {
    param($Value, [int]$ExitCode)

    $Value | ConvertTo-Json -Depth 8 -Compress
    exit $ExitCode
}

function Get-DefaultCodexHome {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return [IO.Path]::GetFullPath($env:CODEX_HOME)
    }

    $userProfile = [Environment]::GetFolderPath("UserProfile")
    if ([string]::IsNullOrWhiteSpace($userProfile)) {
        $userProfile = $env:USERPROFILE
    }
    if ([string]::IsNullOrWhiteSpace($userProfile)) {
        throw "Unable to determine user profile for default Codex home"
    }

    return [IO.Path]::GetFullPath((Join-Path $userProfile ".codex"))
}

function Test-PathUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return ($normalizedPath.Equals($normalizedRoot, [StringComparison]::OrdinalIgnoreCase) -or $normalizedPath.StartsWith($normalizedRoot + "\", [StringComparison]::OrdinalIgnoreCase))
}

function Assert-RealDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to use reparse point directory: $Path"
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Path exists and is not a directory: $Path"
    }
}

function Assert-ManagedTargetOrEmpty {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$SkillsRoot
    )

    if (-not (Test-Path -LiteralPath $Target)) {
        return
    }
    if (-not (Test-PathUnder -Path $Target -Root $SkillsRoot)) {
        throw "Refusing to update target outside skills root: $Target"
    }

    $item = Get-Item -LiteralPath $Target -Force
    $isReparsePoint = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    $markerPath = Join-Path $Target $InstallMarkerName
    $hasMarker = Test-Path -LiteralPath $markerPath -PathType Leaf

    if ($hasMarker) {
        return
    }
    if ($Force) {
        return
    }

    if ($isReparsePoint) {
        throw "Target exists as an unmanaged reparse point. Re-run with -Force only if you intend to replace it: $Target"
    }

    throw "Target exists and is not managed by powershell-skills. Re-run with -Force only if you intend to replace it: $Target"
}

function Remove-ExistingTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$SkillsRoot
    )

    if (-not (Test-Path -LiteralPath $Target)) {
        return
    }
    if (-not (Test-PathUnder -Path $Target -Root $SkillsRoot)) {
        throw "Refusing to remove target outside skills root: $Target"
    }

    Remove-Item -LiteralPath $Target -Recurse -Force
}

if (-not (Test-Path -LiteralPath $SourceAdapter -PathType Container)) {
    Write-JsonResult @{
        status = "error"
        reason = "Source adapter not found"
        source = $SourceAdapter
    } 1
}

if (-not (Test-Path -LiteralPath $SourceCore -PathType Container)) {
    Write-JsonResult @{
        status = "error"
        reason = "Source core not found"
        source = $SourceCore
    } 1
}

try {
    if ([string]::IsNullOrWhiteSpace($CodexHome)) {
        $CodexHome = Get-DefaultCodexHome
    }
    else {
        $CodexHome = [IO.Path]::GetFullPath($CodexHome)
    }

    $SkillsRoot = Join-Path $CodexHome "skills"
    $Target = Join-Path $SkillsRoot $SkillName
    $Staging = Join-Path $SkillsRoot (".staging-$SkillName-" + [guid]::NewGuid().ToString("N"))

    Assert-RealDirectory -Path $CodexHome
    New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
    Assert-RealDirectory -Path $CodexHome

    Assert-RealDirectory -Path $SkillsRoot
    New-Item -ItemType Directory -Path $SkillsRoot -Force | Out-Null
    Assert-RealDirectory -Path $SkillsRoot

    $resolvedSkillsRoot = (Resolve-Path -LiteralPath $SkillsRoot).ProviderPath
    if (-not (Test-PathUnder -Path $Target -Root $resolvedSkillsRoot)) {
        throw "Resolved target escaped skills root: $Target"
    }

    Assert-ManagedTargetOrEmpty -Target $Target -SkillsRoot $resolvedSkillsRoot

    New-Item -ItemType Directory -Path $Staging -Force | Out-Null
    foreach ($sourceItem in @(Get-ChildItem -LiteralPath $SourceAdapter -Force)) {
        Copy-Item -LiteralPath $sourceItem.FullName -Destination $Staging -Recurse -Force
    }
    Copy-Item -LiteralPath $SourceCore -Destination (Join-Path $Staging "core") -Recurse -Force

    $skillPath = Join-Path $Staging "SKILL.md"
    $skillText = Get-Content -LiteralPath $skillPath -Raw
    $skillText = $skillText.Replace("../../../core", "core")
    Set-Content -LiteralPath $skillPath -Value $skillText -Encoding UTF8

    $marker = @{
        product = "powershell-skills"
        skill = $SkillName
        mode = "global-copy"
        source_repo = $RepoRoot
        installed_at = (Get-Date).ToUniversalTime().ToString("o")
        note = "Generated by scripts/install-codex-global.ps1. Re-run installer after git pull to update."
    }
    $marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Staging $InstallMarkerName) -Encoding UTF8

    Remove-ExistingTarget -Target $Target -SkillsRoot $resolvedSkillsRoot
    Move-Item -LiteralPath $Staging -Destination $Target

    Write-JsonResult @{
        status = "success"
        mode = "global-copy"
        codex_home = $CodexHome
        target = $Target
        source = $SourceAdapter
        note = "Restart Codex or start a new session so the global skill index refreshes."
    } 0
}
catch {
    if ($Staging -and (Test-Path -LiteralPath $Staging)) {
        Remove-Item -LiteralPath $Staging -Recurse -Force
    }
    Write-JsonResult @{
        status = "error"
        reason = $_.Exception.Message
    } 1
}
