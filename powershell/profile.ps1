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

    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

$localProfileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
$localProfile = Join-Path $localProfileDirectory "profile.local.ps1"

if (Test-Path -LiteralPath $localProfile) {
    . $localProfile
}
