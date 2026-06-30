param()

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$ScriptsRoot = Join-Path $RepoRoot "core\scripts"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-ScriptJson {
    param(
        [string]$ScriptName,
        [string[]]$Arguments = @()
    )
    $scriptPath = Join-Path $ScriptsRoot $ScriptName
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) "Missing script: $scriptPath"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    $exit = $LASTEXITCODE
    $json = ($output | Out-String).Trim()
    if (-not $json) { throw "No JSON output from $ScriptName" }
    $data = $json | ConvertFrom-Json
    [pscustomobject]@{ ExitCode = $exit; Data = $data; Raw = $json }
}

function New-TestWorkspace {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("powershell-skills-smoke-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

$workspace = New-TestWorkspace
try {
    $spacePath = Join-Path $workspace "space path"
    $unicodeName = "unicode-" + [char]0x4E2D + [char]0x6587
    $unicodePath = Join-Path $workspace $unicodeName
    New-Item -ItemType Directory -Path $spacePath -Force | Out-Null
    New-Item -ItemType Directory -Path $unicodePath -Force | Out-Null

    $commandResult = Invoke-ScriptJson "Test-AgentCommand.ps1" @("-Command", "powershell.exe")
    Assert-True ($commandResult.ExitCode -eq 0) "powershell.exe should be found"
    Assert-True ($commandResult.Data.found -eq $true) "Expected found=true for powershell.exe"

    $missingResult = Invoke-ScriptJson "Test-AgentCommand.ps1" @("-Command", "definitely-missing-powershell-skills-tool")
    Assert-True ($missingResult.ExitCode -eq 1) "missing command should exit 1"
    Assert-True ($missingResult.Data.classification -eq "tool-discovery") "Expected tool-discovery classification"

    $pathResult = Invoke-ScriptJson "Resolve-AgentPath.ps1" @("-Path", $spacePath, "-MustExist")
    Assert-True ($pathResult.ExitCode -eq 0) "space path should resolve"
    Assert-True ($pathResult.Data.exists -eq $true) "Expected exists=true for space path"
    Assert-True ($pathResult.Data.use_literal_path -eq $true) "Expected literal path recommendation"

    $unicodeResult = Invoke-ScriptJson "Resolve-AgentPath.ps1" @("-Path", $unicodePath, "-MustExist")
    Assert-True ($unicodeResult.ExitCode -eq 0) "unicode path should resolve"
    Assert-True ($unicodeResult.Data.exists -eq $true) "Expected exists=true for unicode path"

    $classifyResult = Invoke-ScriptJson "Classify-AgentFailure.ps1" @("-ErrorText", "An empty pipe element is not allowed.")
    Assert-True ($classifyResult.ExitCode -eq 0) "classifier should exit 0"
    Assert-True ($classifyResult.Data.classification -eq "powershell-parser") "Expected powershell-parser classification"

    $specPath = Join-Path $workspace "invoke-spec.json"
    @{
        command = "powershell.exe"
        args = @("-NoProfile", "-Command", "Write-Output ok")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "normal"
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $specPath -Encoding UTF8
    $invokeResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $specPath)
    Assert-True ($invokeResult.ExitCode -eq 0) "invoke command should exit 0"
    Assert-True ($invokeResult.Data.stdout -match "ok") "Expected stdout to contain ok"

    $destructiveSpecPath = Join-Path $workspace "destructive-spec.json"
    @{
        command = "powershell.exe"
        args = @("-NoProfile", "-Command", "Write-Output should-not-run")
        cwd = $workspace
        timeout_seconds = 15
        env = @{}
        risk = "destructive"
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destructiveSpecPath -Encoding UTF8
    $destructiveResult = Invoke-ScriptJson "Invoke-AgentCommand.ps1" @("-SpecPath", $destructiveSpecPath)
    Assert-True ($destructiveResult.ExitCode -eq 1) "destructive spec should be blocked"
    Assert-True ($destructiveResult.Data.classification -eq "destructive-op-risk") "Expected destructive-op-risk classification"

    Write-Output "[OK] smoke tests passed"
}
finally {
    if (Test-Path -LiteralPath $workspace) {
        Remove-Item -LiteralPath $workspace -Recurse -Force
    }
}
