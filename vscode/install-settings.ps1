param(
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$ManagedMarker = "joshuabisdorf/dotfiles:vscode-settings"

# Test-ManagedMarker
# Requires:
#   - $Path is a marker file path.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the marker identifies VS Code settings managed by this repo.
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

# Main
# Requires:
#   - settings.json exists beside this script.
#   - APPDATA is set.
# Modifies:
#   - VS Code user settings and an adjacent ownership marker unless DryRun is enabled.
# Effects:
#   - Installs or removes the repo's canonical VS Code user settings.
# Inputs:
#   - DryRun: report changes without writing.
#   - Uninstall: remove managed settings.
#   - Force: replace existing unmanaged settings when installing.
# Outputs:
#   - Status messages on standard output.
function Main {
    if (-not $env:APPDATA) {
        throw "APPDATA is not set."
    }

    $sourceFile = Join-Path $PSScriptRoot "settings.json"
    $targetFile = Join-Path $env:APPDATA "Code\User\settings.json"
    $markerFile = "$targetFile.dotfiles-managed"

    if ($Uninstall) {
        if (-not (Test-Path -LiteralPath $targetFile) -and
            -not (Test-Path -LiteralPath $markerFile)) {
            Write-Host "VS Code settings are not installed by this repo."
            return
        }

        if (-not (Test-ManagedMarker -Path $markerFile)) {
            throw "Refusing to remove unmanaged VS Code settings: $targetFile"
        }

        if ($DryRun) {
            Write-Host "Would remove managed VS Code settings: $targetFile"
            return
        }

        Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $markerFile -Force -ErrorAction SilentlyContinue
        Write-Host "Removed managed VS Code settings: $targetFile"
        return
    }

    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        throw "VS Code settings source not found: $sourceFile"
    }

    if ((Test-Path -LiteralPath $targetFile) -and
        -not (Test-ManagedMarker -Path $markerFile) -and
        -not $Force) {
        throw "Refusing to overwrite unmanaged VS Code settings: $targetFile. Re-run with -Force to adopt it."
    }

    if ($DryRun) {
        Write-Host "Would install VS Code settings: $sourceFile -> $targetFile"
        return
    }

    $targetDirectory = Split-Path -Parent $targetFile
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    Set-Content -LiteralPath $markerFile -Value @($ManagedMarker, $sourceFile) -Encoding utf8
    Write-Host "Installed VS Code settings: $targetFile"
}

Main
