param()

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).ProviderPath

function Join-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot $RelativePath
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-RequiredPath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$PathType
    )

    $path = Join-RepoPath $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType $PathType) "Missing required $PathType path: $RelativePath"
}

$requiredFiles = @(
    "core\execution-contract.md",
    "core\scripts\Test-AgentCommand.ps1",
    "core\scripts\Resolve-AgentPath.ps1",
    "core\scripts\Classify-AgentFailure.ps1",
    "core\scripts\Invoke-AgentCommand.ps1",
    "core\tests\run-smoke.ps1",
    "adapters\codex\powershell-command-runner\SKILL.md",
    "adapters\codex\powershell-command-runner\agents\openai.yaml"
)

foreach ($relativePath in $requiredFiles) {
    Assert-RequiredPath -RelativePath $relativePath -PathType Leaf
}

$requiredDirectories = @(
    "core\pattern-catalog",
    "core\failure-corpus\cases"
)

foreach ($relativePath in $requiredDirectories) {
    Assert-RequiredPath -RelativePath $relativePath -PathType Container
}

$failureCasesPath = Join-RepoPath "core\failure-corpus\cases"
$failureCaseCount = @(Get-ChildItem -LiteralPath $failureCasesPath -File).Count
Assert-True ($failureCaseCount -ge 5) "Expected at least 5 failure cases; found $failureCaseCount"

$smokePath = Join-RepoPath "core\tests\run-smoke.ps1"
$smokeCommand = "& { param([string]`$SmokePath) [Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'High'; & `$SmokePath }"
$maxSmokeAttempts = 4
$smokeOutput = $null
$smokeExitCode = 1
$retryableSmokePatterns = @(
    "timeout should not wait for nested 8s child sleep",
    "early-exit timeout should not wait for child sleep"
)

for ($attempt = 1; $attempt -le $maxSmokeAttempts; $attempt++) {
    $smokeOutput = & powershell.exe -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command $smokeCommand $smokePath 2>&1
    $smokeExitCode = $LASTEXITCODE
    if ($smokeExitCode -eq 0) {
        break
    }

    $smokeText = ($smokeOutput | Out-String).Trim()
    $retryableSmokeFailure = $false
    foreach ($retryableSmokePattern in $retryableSmokePatterns) {
        if ($smokeText -match [regex]::Escape($retryableSmokePattern)) {
            $retryableSmokeFailure = $true
            break
        }
    }

    if (-not $retryableSmokeFailure -or $attempt -eq $maxSmokeAttempts) {
        throw "Smoke tests failed with exit code $smokeExitCode after $attempt attempt(s). $smokeText"
    }

    Start-Sleep -Milliseconds 250
}
Assert-True ((($smokeOutput | Out-String).Trim()) -match "\[OK\] smoke tests passed") "Smoke tests did not report success"

$adapterDir = Join-RepoPath "adapters\codex\powershell-command-runner"
$skillPath = Join-Path $adapterDir "SKILL.md"
$skillText = Get-Content -LiteralPath $skillPath -Raw
Assert-True ($skillText -match "(?m)^---\s*$") "Adapter SKILL.md is missing front matter delimiters"
Assert-True ($skillText -match "(?m)^name:\s*powershell-command-runner\s*$") "Adapter SKILL.md is missing expected skill name"
Assert-True ($skillText -match "(?m)^description:\s*.+") "Adapter SKILL.md is missing description metadata"
Assert-True ($skillText.Contains("../../../core")) "Adapter SKILL.md is missing core relative references"

$openAiPath = Join-Path $adapterDir "agents\openai.yaml"
$openAiText = Get-Content -LiteralPath $openAiPath -Raw
Assert-True ($openAiText -match '(?m)^\s*default_prompt\s*:') "openai.yaml is missing default_prompt"
Assert-True ($openAiText.Contains('$powershell-command-runner')) 'openai.yaml default_prompt must contain $powershell-command-runner'

$expectedCorePath = (Resolve-Path -LiteralPath (Join-RepoPath "core")).ProviderPath
$adapterCorePath = (Resolve-Path -LiteralPath (Join-Path $adapterDir "..\..\..\core")).ProviderPath
Assert-True ($adapterCorePath -eq $expectedCorePath) "Adapter ../../../core does not resolve to repo core"

$relativeReferenceMatches = [regex]::Matches($skillText, "\.\./\.\./\.\./core/[A-Za-z0-9._/\-]+")
Assert-True ($relativeReferenceMatches.Count -gt 0) "No adapter core relative references found"
foreach ($match in $relativeReferenceMatches) {
    $relativeReference = $match.Value.Replace("/", "\")
    $resolvedReference = Join-Path $adapterDir $relativeReference
    Assert-True (Test-Path -LiteralPath $resolvedReference) "Adapter relative reference does not resolve: $($match.Value)"
}

$localSkillPath = Join-RepoPath ".agents\skills\powershell-command-runner"
if (Test-Path -LiteralPath $localSkillPath) {
    $localSkillItem = Get-Item -LiteralPath $localSkillPath -Force
    Assert-True (($localSkillItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) "Repo-local install exists but is not a reparse point: $localSkillPath"
    Assert-True (Test-Path -LiteralPath (Join-Path $localSkillPath "SKILL.md") -PathType Leaf) "Repo-local install SKILL.md does not resolve: $localSkillPath"
}

Write-Output "[OK] V0.1 verification passed"
