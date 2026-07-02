$ErrorActionPreference = "Stop"
$ErrorText = $null
$ExitCode = 1

function Set-AgentUtf8Output {
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [Console]::OutputEncoding = $utf8NoBom
        $script:OutputEncoding = $utf8NoBom
    }
    catch {}
}

Set-AgentUtf8Output

function Test-KnownParameterName {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return $false }
    return ($Value -eq "-ErrorText" -or $Value -eq "-ExitCode")
}

for ($i = 0; $i -lt $args.Count; $i++) {
    $token = [string]$args[$i]
    if ($token -eq "-ErrorText") {
        if ($i + 1 -lt $args.Count -and -not (Test-KnownParameterName -Value ([string]$args[$i + 1]))) {
            $i++
            $ErrorText = [string]$args[$i]
        }
        else {
            $ErrorText = ""
        }
    }
    elseif ($token -eq "-ExitCode") {
        if ($i + 1 -lt $args.Count -and -not (Test-KnownParameterName -Value ([string]$args[$i + 1]))) {
            $i++
            $parsedExitCode = 1
            if ([int]::TryParse(([string]$args[$i]), [ref]$parsedExitCode)) {
                $ExitCode = $parsedExitCode
            }
        }
    }
    elseif ($null -eq $ErrorText) {
        $ErrorText = $token
    }
}

function Get-Classification {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { $Text = "" }
    if ($Text -match 'not a valid statement separator|\&\&') { return "shell-selection" }
    if ($Text -match 'missing the terminator|unterminated string|quote terminator|quotation mark is missing') { return "quoting" }
    if ($Text -match 'An empty pipe element is not allowed|Unexpected token|positional parameter') { return "powershell-parser" }
    if ($Text -match 'Cannot find path|does not exist|Could not find a part of the path') { return "path-handling" }
    if ($Text -match 'not recognized as (the name of )?(a cmdlet|an internal or external command)|is not recognized') { return "tool-discovery" }
    if ($Text -match 'UnicodeEncodeError|UnicodeDecodeError|encoding|codec') { return "encoding" }
    if ($Text -match 'Access is denied|UnauthorizedAccess|permission') { return "permission" }
    if ($Text -match 'TIMEOUT|timed out|timeout') { return "timeout-and-process" }
    if ($Text -match 'Remove-Item|recursive delete|destructive') { return "destructive-op-risk" }
    return "unknown"
}

function Get-Excerpt {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { return "" }
    if ($Text.Length -le 1000) { return $Text }
    return $Text.Substring(0, 1000)
}

$classification = Get-Classification -Text $ErrorText
@{
    status = "success"
    exit_code = $ExitCode
    classification = $classification
    error_excerpt = Get-Excerpt -Text $ErrorText
} | ConvertTo-Json -Depth 8 -Compress
exit 0
