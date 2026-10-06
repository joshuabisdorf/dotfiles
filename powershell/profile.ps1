# Portable PowerShell defaults shared across hosts.

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

    Set-PSReadLineKeyHandler -Key Tab -Function Complete
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

# Get-DotfilesGitContext
# Requires:
#   - Git on PATH to display repository context; otherwise returns an empty string.
# Modifies:
#   - Nothing.
# Effects:
#   - Inspects the current directory for a Git branch or detached HEAD.
# Inputs:
#   - The shell's current working directory.
# Outputs:
#   - " (branch)", " (@commit)", or an empty string.
function Get-DotfilesGitContext {
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
        return ""
    }

    $branch = git symbolic-ref --quiet --short HEAD 2>$null |
        Select-Object -First 1

    if ($LASTEXITCODE -eq 0 -and $branch) {
        return " ($branch)"
    }

    $commit = git rev-parse --short HEAD 2>$null |
        Select-Object -First 1

    if ($LASTEXITCODE -eq 0 -and $commit) {
        return " (@$commit)"
    }

    return ""
}

# Get-DotfilesPromptPath
# Requires:
#   - None.
# Modifies:
#   - Nothing.
# Effects:
#   - Formats the current location and shortens the user's home directory to "~".
# Inputs:
#   - The shell's current working directory and HOME.
# Outputs:
#   - The display path for the prompt.
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

# prompt
# Requires:
#   - PowerShell 7 for PSStyle colors.
# Modifies:
#   - Preserves LASTEXITCODE after Git context lookup.
# Effects:
#   - Renders a Bash-like user@host path (git-context) prompt.
# Inputs:
#   - Current user, machine name, working directory, and Git state.
# Outputs:
#   - A colored "user@host ~/path (branch) > " prompt string.
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
