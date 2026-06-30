param()

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).ProviderPath
$Source = Join-Path $RepoRoot "adapters\codex\powershell-command-runner"
$AgentsRoot = Join-Path $RepoRoot ".agents"
$SkillsRoot = Join-Path $RepoRoot ".agents\skills"
$Target = Join-Path $SkillsRoot "powershell-command-runner"

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Path -Force
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-RealDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-ReparsePoint -Path $Path) {
        throw "Path exists and is a reparse point, refusing repo-local install parent: $Path"
    }
    if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Path exists and is not a directory: $Path"
    }
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

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Source skill folder not found: $Source"
}

$Source = (Resolve-Path -LiteralPath $Source).ProviderPath

Assert-RealDirectory -Path $AgentsRoot
New-Item -ItemType Directory -Path $AgentsRoot -Force | Out-Null
Assert-RealDirectory -Path $AgentsRoot

Assert-RealDirectory -Path $SkillsRoot
New-Item -ItemType Directory -Path $SkillsRoot -Force | Out-Null
Assert-RealDirectory -Path $SkillsRoot

$resolvedAgentsRoot = (Resolve-Path -LiteralPath $AgentsRoot).ProviderPath
$resolvedSkillsRoot = (Resolve-Path -LiteralPath $SkillsRoot).ProviderPath
if (-not (Test-PathUnder -Path $resolvedSkillsRoot -Root $resolvedAgentsRoot)) {
    throw "Resolved skills root escaped repo-local .agents: $resolvedSkillsRoot"
}

if (Test-Path -LiteralPath $Target) {
    $item = Get-Item -LiteralPath $Target -Force
    if (-not (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Target exists and is not a link: $Target"
    }
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        throw "Target exists and is not a directory link: $Target"
    }
    [System.IO.Directory]::Delete($Target)
}

New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null

@{
    status = "success"
    source = $Source
    target = $Target
    note = "Start Codex from the repository root so repo-local .agents skills are discoverable."
} | ConvertTo-Json -Depth 5
