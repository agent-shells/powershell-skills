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

function Join-ProcessArguments {
    param([string[]]$Arguments)

    $quoted = @()
    foreach ($argument in $Arguments) {
        $quoted += ConvertTo-WindowsArgument -Value $argument
    }
    return ($quoted -join " ")
}

function Invoke-ProcessCapture {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [string[]]$Arguments = @(),
        [AllowNull()][string]$WorkingDirectory = $null
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FileName
    $startInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $startInfo.WorkingDirectory = $WorkingDirectory
    }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
    $process.Dispose()

    return [pscustomobject]@{
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

function Normalize-PathForCompare {
    param([Parameter(Mandatory = $true)][string]$Path)

    $normalized = $Path.Trim()
    if ($normalized.StartsWith("\??\")) {
        $normalized = $normalized.Substring(4)
    }
    if ($normalized.StartsWith("\\?\")) {
        $normalized = $normalized.Substring(4)
    }
    return [IO.Path]::GetFullPath($normalized).TrimEnd('\')
}

function Get-ReparsePointTarget {
    param([Parameter(Mandatory = $true)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    $targetProperty = $item.PSObject.Properties["Target"]
    if ($targetProperty -and $targetProperty.Value) {
        $targetValues = @($targetProperty.Value)
        if ($targetValues.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$targetValues[0])) {
            return [string]$targetValues[0]
        }
    }

    $fsutilResult = Invoke-ProcessCapture -FileName "fsutil.exe" -Arguments @("reparsepoint", "query", $Path)
    if ($fsutilResult.ExitCode -ne 0) {
        throw "Unable to query reparse point target for $Path. stdout=[$($fsutilResult.Stdout)] stderr=[$($fsutilResult.Stderr)]"
    }

    $fsutilText = ($fsutilResult.Stdout + "`n" + $fsutilResult.Stderr)
    $printNameMatch = [regex]::Match($fsutilText, "(?m)^\s*Print Name:\s*(.+?)\s*$")
    if ($printNameMatch.Success) {
        return $printNameMatch.Groups[1].Value
    }

    $substituteNameMatch = [regex]::Match($fsutilText, "(?m)^\s*Substitute Name:\s*(.+?)\s*$")
    if ($substituteNameMatch.Success) {
        return $substituteNameMatch.Groups[1].Value
    }

    throw "Unable to parse reparse point target for $Path. Output: $fsutilText"
}

function Invoke-InstallJson {
    param(
        [Parameter(Mandatory = $true)][string]$InstallScript,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    $result = Invoke-ProcessCapture -FileName "powershell.exe" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $InstallScript) -WorkingDirectory $WorkingDirectory
    if ($result.ExitCode -ne 0) {
        throw "Install script failed with exit code $($result.ExitCode).`nSTDOUT:`n$($result.Stdout)`nSTDERR:`n$($result.Stderr)"
    }

    $jsonText = $result.Stdout.Trim()
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw "Install script produced no JSON output"
    }

    try {
        $data = $jsonText | ConvertFrom-Json
    }
    catch {
        throw "Install script produced invalid JSON: $jsonText"
    }

    Assert-True ($data.status -eq "success") "Install script JSON status was not success: $jsonText"
    return $data
}

function Test-IsolatedInstall {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("powershell-skills-verify-" + [guid]::NewGuid().ToString("N"))
    $tempTarget = Join-Path $tempRoot ".agents\skills\powershell-command-runner"

    try {
        New-Item -ItemType Directory -Path (Join-Path $tempRoot "scripts") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot "adapters\codex") -Force | Out-Null

        Copy-Item -LiteralPath (Join-RepoPath "scripts\install-codex-local.ps1") -Destination (Join-Path $tempRoot "scripts\install-codex-local.ps1")
        Copy-Item -LiteralPath (Join-RepoPath "adapters\codex\powershell-command-runner") -Destination (Join-Path $tempRoot "adapters\codex\powershell-command-runner") -Recurse
        Copy-Item -LiteralPath (Join-RepoPath "core") -Destination (Join-Path $tempRoot "core") -Recurse

        $installScript = Join-Path $tempRoot "scripts\install-codex-local.ps1"
        [void](Invoke-InstallJson -InstallScript $installScript -WorkingDirectory $tempRoot)
        [void](Invoke-InstallJson -InstallScript $installScript -WorkingDirectory $tempRoot)

        Assert-True (Test-Path -LiteralPath $tempTarget -PathType Container) "Temp repo install target was not created: $tempTarget"
        $targetItem = Get-Item -LiteralPath $tempTarget -Force
        Assert-True (($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) "Temp repo install target is not a reparse point: $tempTarget"
        Assert-True (Test-Path -LiteralPath (Join-Path $tempTarget "SKILL.md") -PathType Leaf) "Temp repo install target SKILL.md does not resolve: $tempTarget"

        $actualTarget = Normalize-PathForCompare -Path (Get-ReparsePointTarget -Path $tempTarget)
        $expectedTarget = Normalize-PathForCompare -Path (Resolve-Path -LiteralPath (Join-Path $tempRoot "adapters\codex\powershell-command-runner")).ProviderPath
        Assert-True ($actualTarget.Equals($expectedTarget, [StringComparison]::OrdinalIgnoreCase)) "Temp repo install target mismatch. Expected=[$expectedTarget] Actual=[$actualTarget]"
    }
    finally {
        if (Test-Path -LiteralPath $tempTarget) {
            $tempTargetItem = Get-Item -LiteralPath $tempTarget -Force
            if (($tempTargetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                [IO.Directory]::Delete($tempTarget)
            }
        }
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Test-IsolatedGlobalInstall {
    $tempRepo = Join-Path ([IO.Path]::GetTempPath()) ("powershell-skills-global-repo-" + [guid]::NewGuid().ToString("N"))
    $tempCodexHome = Join-Path ([IO.Path]::GetTempPath()) ("powershell-skills-codex-home-" + [guid]::NewGuid().ToString("N"))
    $tempTarget = Join-Path $tempCodexHome "skills\powershell-command-runner"

    try {
        New-Item -ItemType Directory -Path (Join-Path $tempRepo "scripts") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRepo "adapters\codex") -Force | Out-Null

        Copy-Item -LiteralPath (Join-RepoPath "scripts\install-codex-global.ps1") -Destination (Join-Path $tempRepo "scripts\install-codex-global.ps1")
        Copy-Item -LiteralPath (Join-RepoPath "adapters\codex\powershell-command-runner") -Destination (Join-Path $tempRepo "adapters\codex\powershell-command-runner") -Recurse
        Copy-Item -LiteralPath (Join-RepoPath "core") -Destination (Join-Path $tempRepo "core") -Recurse

        $installScript = Join-Path $tempRepo "scripts\install-codex-global.ps1"
        $firstResult = Invoke-ProcessCapture -FileName "powershell.exe" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $installScript, "-CodexHome", $tempCodexHome) -WorkingDirectory $tempRepo
        if ($firstResult.ExitCode -ne 0) {
            throw "Global install script failed with exit code $($firstResult.ExitCode).`nSTDOUT:`n$($firstResult.Stdout)`nSTDERR:`n$($firstResult.Stderr)"
        }

        Assert-True (Test-Path -LiteralPath $tempTarget -PathType Container) "Global install target was not created: $tempTarget"
        Assert-True (Test-Path -LiteralPath (Join-Path $tempTarget "SKILL.md") -PathType Leaf) "Global install SKILL.md is missing"
        Assert-True (Test-Path -LiteralPath (Join-Path $tempTarget "agents\openai.yaml") -PathType Leaf) "Global install openai.yaml is missing"
        Assert-True (Test-Path -LiteralPath (Join-Path $tempTarget "core\execution-contract.md") -PathType Leaf) "Global install core contract is missing"
        Assert-True (Test-Path -LiteralPath (Join-Path $tempTarget ".powershell-skills-install.json") -PathType Leaf) "Global install marker is missing"

        $globalSkillText = Get-Content -LiteralPath (Join-Path $tempTarget "SKILL.md") -Raw
        Assert-True ($globalSkillText.Contains("core/execution-contract.md")) "Global install SKILL.md should reference bundled core"
        Assert-True (-not $globalSkillText.Contains("../../../core")) "Global install SKILL.md must not keep repo-local core references"

        $secondResult = Invoke-ProcessCapture -FileName "powershell.exe" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $installScript, "-CodexHome", $tempCodexHome) -WorkingDirectory $tempRepo
        if ($secondResult.ExitCode -ne 0) {
            throw "Global install script must be idempotent for managed targets.`nSTDOUT:`n$($secondResult.Stdout)`nSTDERR:`n$($secondResult.Stderr)"
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempCodexHome) {
            Remove-Item -LiteralPath $tempCodexHome -Recurse -Force
        }
        if (Test-Path -LiteralPath $tempRepo) {
            Remove-Item -LiteralPath $tempRepo -Recurse -Force
        }
    }
}

$requiredFiles = @(
    "README.md",
    "core\execution-contract.md",
    "core\scripts\Test-AgentCommand.ps1",
    "core\scripts\Resolve-AgentPath.ps1",
    "core\scripts\Classify-AgentFailure.ps1",
    "core\scripts\Invoke-AgentCommand.ps1",
    "core\tests\run-smoke.ps1",
    "adapters\codex\powershell-command-runner\SKILL.md",
    "adapters\codex\powershell-command-runner\agents\openai.yaml",
    "scripts\install-codex-local.ps1",
    "scripts\install-codex-global.ps1"
)

foreach ($relativePath in $requiredFiles) {
    Assert-RequiredPath -RelativePath $relativePath -PathType Leaf
}

$readmeText = Get-Content -LiteralPath (Join-RepoPath "README.md") -Raw
$requiredReadmeMarkers = @(
    "# powershell-skills",
    "## V0.1 Features",
    "## Installation",
    "## Triggering",
    "## Compatibility",
    "## Verification",
    "## Current Limits"
)

foreach ($marker in $requiredReadmeMarkers) {
    Assert-True ($readmeText.Contains($marker)) "README.md is missing required section marker: $marker"
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
$smokeResult = Invoke-ProcessCapture -FileName "powershell.exe" -Arguments @("-NoLogo", "-NonInteractive", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $smokePath) -WorkingDirectory $RepoRoot
if ($smokeResult.ExitCode -ne 0) {
    throw "Smoke tests failed with exit code $($smokeResult.ExitCode).`nSTDOUT:`n$($smokeResult.Stdout)`nSTDERR:`n$($smokeResult.Stderr)"
}
Assert-True ($smokeResult.Stdout -match "\[OK\] smoke tests passed") "Smoke tests exited 0 but did not report success. stdout=[$($smokeResult.Stdout)] stderr=[$($smokeResult.Stderr)]"

$adapterDir = Join-RepoPath "adapters\codex\powershell-command-runner"
$skillPath = Join-Path $adapterDir "SKILL.md"
$skillText = Get-Content -LiteralPath $skillPath -Raw
$frontMatterMatch = [regex]::Match($skillText, "\A---\r?\n(?<frontmatter>[\s\S]*?)\r?\n---(?:\r?\n|\z)")
Assert-True $frontMatterMatch.Success "Adapter SKILL.md must begin with front matter delimited by ---"
$frontMatter = $frontMatterMatch.Groups["frontmatter"].Value
Assert-True ($frontMatter -match "(?m)^name:\s*powershell-command-runner\s*$") "Adapter SKILL.md front matter is missing expected skill name"
Assert-True ($frontMatter -match "(?m)^description:\s*\S") "Adapter SKILL.md front matter is missing description metadata"
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

Test-IsolatedInstall
Test-IsolatedGlobalInstall

$localSkillPath = Join-RepoPath ".agents\skills\powershell-command-runner"
if (Test-Path -LiteralPath $localSkillPath) {
    $localSkillItem = Get-Item -LiteralPath $localSkillPath -Force
    Assert-True (($localSkillItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) "Repo-local install exists but is not a reparse point: $localSkillPath"
    Assert-True (Test-Path -LiteralPath (Join-Path $localSkillPath "SKILL.md") -PathType Leaf) "Repo-local install SKILL.md does not resolve: $localSkillPath"
    $localTarget = Normalize-PathForCompare -Path (Get-ReparsePointTarget -Path $localSkillPath)
    $expectedLocalTarget = Normalize-PathForCompare -Path $adapterDir
    Assert-True ($localTarget.Equals($expectedLocalTarget, [StringComparison]::OrdinalIgnoreCase)) "Repo-local install target mismatch. Expected=[$expectedLocalTarget] Actual=[$localTarget]"
}

Write-Output "[OK] V0.1 verification passed"
