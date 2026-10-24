# Portable PowerShell defaults shared across hosts.

<#
.SYNOPSIS
    Compute case-sensitive directory completion for cd and Set-Location.
.DESCRIPTION
    Handles unquoted directory names at the end of a filesystem command; other inputs are left to default PowerShell completion.
.PARAMETER Line
    Command line entered at the prompt.
.PARAMETER Cursor
    Zero-based cursor position.
.OUTPUTS
    PSCustomObject - Handled, Start, Length, and replacement Text.
#>
function Get-DotfilesDirectoryCompletion {
    param(
        [Parameter(Mandatory)]
        [string]$Line,

        [Parameter(Mandatory)]
        [int]$Cursor
    )

    $notHandled = [pscustomobject]@{
        Handled = $false
        Start = 0
        Length = 0
        Text = $null
    }

    if ($Cursor -ne $Line.Length) {
        return $notHandled
    }

    $match = [regex]::Match(
        $Line,
        '^\s*(?:cd|Set-Location|sl)\s+(?<path>[^\s"'';|&]+)$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if (-not $match.Success) {
        return $notHandled
    }

    $typedPath = $match.Groups["path"].Value
    if (
        [string]::IsNullOrEmpty($typedPath) -or
        $typedPath.Contains("\") -or
        $typedPath.Contains("/") -or
        $typedPath.Contains(":")
    ) {
        return $notHandled
    }

    $location = Get-Location
    if ($location.Provider.Name -ne "FileSystem") {
        return $notHandled
    }

    $matches = @(
        Get-ChildItem -LiteralPath $location.Path -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name.StartsWith(
                    $typedPath,
                    [System.StringComparison]::Ordinal
                )
            } |
            Sort-Object Name
    )

    if ($matches.Count -eq 0) {
        return [pscustomobject]@{
            Handled = $true
            Start = $match.Groups["path"].Index
            Length = $typedPath.Length
            Text = $null
        }
    }

    if ($matches.Count -eq 1) {
        $replacement = $matches[0].Name +
            [System.IO.Path]::DirectorySeparatorChar

        return [pscustomobject]@{
            Handled = $true
            Start = $match.Groups["path"].Index
            Length = $typedPath.Length
            Text = $replacement
        }
    }

    $commonPrefix = $matches[0].Name
    foreach ($item in $matches | Select-Object -Skip 1) {
        $maxLength = [Math]::Min($commonPrefix.Length, $item.Name.Length)
        $prefixLength = 0

        while (
            $prefixLength -lt $maxLength -and
            $commonPrefix[$prefixLength] -ceq $item.Name[$prefixLength]
        ) {
            $prefixLength++
        }

        $commonPrefix = $commonPrefix.Substring(0, $prefixLength)
    }

    $replacement = $null
    if ($commonPrefix.Length -gt $typedPath.Length) {
        $replacement = $commonPrefix
    }

    return [pscustomobject]@{
        Handled = $true
        Start = $match.Groups["path"].Index
        Length = $typedPath.Length
        Text = $replacement
    }
}

$psReadLine = Get-Module -Name PSReadLine -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($psReadLine) {
    Import-Module PSReadLine -MinimumVersion $psReadLine.Version

    Set-PSReadLineOption `
        -MaximumHistoryCount 10000 `
        -HistoryNoDuplicates `
        -HistorySearchCursorMovesToEnd

    Set-PSReadLineOption -Colors @{
        Command          = "White"
        Parameter        = "DarkGray"
        String           = "Yellow"
        Variable         = "Cyan"
        Number           = "DarkCyan"
        Keyword          = "Cyan"
        Operator         = "DarkGray"
        Type             = "Cyan"
        Member           = "Gray"
        Comment          = "DarkGreen"
        Error            = "Red"
        InlinePrediction = "DarkGray"
    }

    Set-PSReadLineKeyHandler -Key Tab -BriefDescription "AcceptSuggestionOrComplete" -Description "Accept inline prediction first, then use Bash-like directory or normal PowerShell completion." -ScriptBlock {
        param($key, $arg)

        $line = $null
        [int]$cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
            [ref]$line,
            [ref]$cursor
        )

        $beforeSuggestionLine = $line
        $beforeSuggestionCursor = $cursor

        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion($key, $arg)

        $line = $null
        [int]$cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
            [ref]$line,
            [ref]$cursor
        )

        if (
            $line -ne $beforeSuggestionLine -or
            $cursor -ne $beforeSuggestionCursor
        ) {
            return
        }

        $completion = Get-DotfilesDirectoryCompletion -Line $line -Cursor $cursor

        if ($completion.Handled) {
            if ($null -ne $completion.Text) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                    $completion.Start,
                    $completion.Length,
                    $completion.Text
                )
            }

            return
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Complete($key, $arg)
    }

    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# Keep file listings close to conventional Unix shell colors while leaving
# ordinary files at the terminal's default foreground color.
$PSStyle.FileInfo.Directory = $PSStyle.Foreground.BrightBlue
$PSStyle.FileInfo.SymbolicLink = $PSStyle.Foreground.Cyan
$PSStyle.FileInfo.Executable = $PSStyle.Foreground.BrightGreen

foreach ($extension in @(".ps1", ".psm1", ".psd1", ".ps1xml")) {
    $PSStyle.FileInfo.Extension[$extension] = $PSStyle.Foreground.Cyan
}

foreach ($extension in @(".json", ".yaml", ".yml", ".toml", ".ini")) {
    $PSStyle.FileInfo.Extension[$extension] = $PSStyle.Foreground.Yellow
}

$PSStyle.FileInfo.Extension[".md"] = $PSStyle.Foreground.Green

foreach ($extension in @(".zip", ".7z", ".tar", ".gz", ".tgz", ".bz2", ".xz")) {
    $PSStyle.FileInfo.Extension[$extension] = $PSStyle.Foreground.Red
}

<#
.SYNOPSIS
    Render Git branch or detached-HEAD context for the prompt.
.DESCRIPTION
    Returns no context if Git is unavailable or the location is not a repository.
.OUTPUTS
    System.String - Context or an empty string.
#>
function Get-DotfilesGitContext {
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
        return ""
    }

    $location = Get-Location
    if ($location.Provider.Name -ne "FileSystem") {
        return ""
    }

    $branch = git -C $location.Path symbolic-ref --quiet --short HEAD 2>$null |
        Select-Object -First 1

    if ($branch) {
        return " ($branch)"
    }

    $commit = git -C $location.Path rev-parse --short HEAD 2>$null |
        Select-Object -First 1

    if ($commit) {
        return " (@$commit)"
    }

    return ""
}

<#
.SYNOPSIS
    Shorten the user's home prefix in the prompt path.
.OUTPUTS
    System.String - Display path.
#>
function Get-DotfilesPromptPath {
    $path = (Get-Location).Path

    if ($path -eq $HOME) {
        return "~"
    }

    $homePrefix = "$HOME$([System.IO.Path]::DirectorySeparatorChar)"
    if ($path.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "~$($path.Substring($HOME.Length))"
    }

    return $path
}

<#
.SYNOPSIS
    Render the Git-aware user@host PowerShell prompt.
.DESCRIPTION
    Restores global LASTEXITCODE after inspecting Git state.
.OUTPUTS
    System.String - Colorized prompt.
#>
function prompt {
    $previousExitCode = $global:LASTEXITCODE

    $userName = [Environment]::UserName
    $hostName = [Environment]::MachineName
    $path = Get-DotfilesPromptPath
    $gitContext = Get-DotfilesGitContext

    $global:LASTEXITCODE = $previousExitCode

    return (
        "$($PSStyle.Foreground.BrightGreen)$userName@$hostName$($PSStyle.Reset) " +
        "$($PSStyle.Foreground.BrightBlue)$path" +
        "$($PSStyle.Foreground.BrightMagenta)$gitContext$($PSStyle.Reset) > "
    )
}

$localProfileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
$localProfile = Join-Path $localProfileDirectory "profile.local.ps1"

if (Test-Path -LiteralPath $localProfile) {
    . $localProfile
}
