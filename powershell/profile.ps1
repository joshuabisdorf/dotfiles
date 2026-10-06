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

$localProfileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
$localProfile = Join-Path $localProfileDirectory "profile.local.ps1"

if (Test-Path -LiteralPath $localProfile) {
    . $localProfile
}
