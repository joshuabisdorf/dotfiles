param(
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$ManagedMarker = "joshuabisdorf/dotfiles:windows-terminal-settings"

# Test-ManagedMarker
# Requires:
#   - $Path is a marker file path.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the marker identifies Windows Terminal settings managed by this repo.
# Inputs:
#   - Path: marker file path to inspect.
# Outputs:
#   - Boolean management status.
function Test-ManagedMarker {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1
    return $firstLine -eq $ManagedMarker
}

# Get-WindowsTerminalSettingsPath
# Requires:
#   - LOCALAPPDATA is set.
# Modifies:
#   - Nothing.
# Effects:
#   - Chooses the stable packaged or unpackaged Windows Terminal settings path.
# Inputs:
#   - The current user's LOCALAPPDATA directory.
# Outputs:
#   - The selected settings.json path.
function Get-WindowsTerminalSettingsPath {
    $packaged = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $unpackaged = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"

    if (Test-Path -LiteralPath (Split-Path -Parent $packaged)) {
        return $packaged
    }

    if (Test-Path -LiteralPath (Split-Path -Parent $unpackaged)) {
        return $unpackaged
    }

    return $packaged
}

# Main
# Requires:
#   - settings.json exists beside this script.
#   - LOCALAPPDATA is set.
# Modifies:
#   - Windows Terminal user settings and an adjacent ownership marker unless DryRun is enabled.
# Effects:
#   - Installs or removes the repo's canonical Windows Terminal settings.
# Inputs:
#   - DryRun: report changes without writing.
#   - Uninstall: remove managed settings.
#   - Force: replace existing unmanaged settings when installing.
# Outputs:
#   - Status messages on standard output.
function Main {
    if (-not $env:LOCALAPPDATA) {
        throw "LOCALAPPDATA is not set."
    }

    $sourceFile = Join-Path $PSScriptRoot "settings.json"
    $targetFile = Get-WindowsTerminalSettingsPath
    $markerFile = "$targetFile.dotfiles-managed"

    if ($Uninstall) {
        if (-not (Test-Path -LiteralPath $targetFile) -and
            -not (Test-Path -LiteralPath $markerFile)) {
            Write-Host "Windows Terminal settings are not installed by this repo."
            return
        }

        if (-not (Test-ManagedMarker -Path $markerFile)) {
            throw "Refusing to remove unmanaged Windows Terminal settings: $targetFile"
        }

        if ($DryRun) {
            Write-Host "Would remove managed Windows Terminal settings: $targetFile"
            return
        }

        Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $markerFile -Force -ErrorAction SilentlyContinue
        Write-Host "Removed managed Windows Terminal settings: $targetFile"
        return
    }

    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        throw "Windows Terminal settings source not found: $sourceFile"
    }

    if ((Test-Path -LiteralPath $targetFile) -and
        -not (Test-ManagedMarker -Path $markerFile) -and
        -not $Force) {
        throw "Refusing to overwrite unmanaged Windows Terminal settings: $targetFile. Re-run with -Force to adopt it."
    }

    if (-not $DryRun -and
        -not (Get-Command wt.exe -ErrorAction SilentlyContinue) -and
        -not (Test-Path -LiteralPath (Split-Path -Parent $targetFile))) {
        throw "Windows Terminal does not appear to be installed."
    }

    if ($DryRun) {
        Write-Host "Would install Windows Terminal settings: $sourceFile -> $targetFile"
        return
    }

    $targetDirectory = Split-Path -Parent $targetFile
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    Set-Content -LiteralPath $markerFile -Value @($ManagedMarker, $sourceFile) -Encoding utf8
    Write-Host "Installed Windows Terminal settings: $targetFile"
}

Main
