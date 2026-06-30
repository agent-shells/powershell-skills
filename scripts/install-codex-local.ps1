param()

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).ProviderPath
$Source = Join-Path $RepoRoot "adapters\codex\powershell-command-runner"
$SkillsRoot = Join-Path $RepoRoot ".agents\skills"
$Target = Join-Path $SkillsRoot "powershell-command-runner"

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Source skill folder not found: $Source"
}

$Source = (Resolve-Path -LiteralPath $Source).ProviderPath

New-Item -ItemType Directory -Path $SkillsRoot -Force | Out-Null

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
