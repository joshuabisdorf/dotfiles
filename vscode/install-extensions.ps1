param(
    [switch]$DryRun,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Main
# Requires:
#   - extensions.txt exists beside this script.
#   - VS Code's "code" CLI is available unless DryRun is enabled.
# Modifies:
#   - The current VS Code installation's extension set unless DryRun is enabled.
# Effects:
#   - Installs/updates or removes each extension listed in extensions.txt.
# Inputs:
#   - DryRun: report changes without invoking VS Code.
#   - Uninstall: remove listed extensions instead of installing them.
# Outputs:
#   - VS Code extension status on standard output.
function Main {
    if (-not $DryRun -and -not (Get-Command code -ErrorAction SilentlyContinue)) {
        throw 'VS Code CLI "code" is not available on PATH.'
    }

    $extensionsFile = Join-Path $PSScriptRoot "extensions.txt"
    if (-not (Test-Path -LiteralPath $extensionsFile -PathType Leaf)) {
        throw "Extension manifest not found: $extensionsFile"
    }

    $installedExtensions = @()
    if (-not $DryRun -and $Uninstall) {
        $installedExtensions = @(code --list-extensions)
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list installed VS Code extensions."
        }
    }

    Get-Content -LiteralPath $extensionsFile | ForEach-Object {
        $extension = ($_ -split '#', 2)[0].Trim()

        if (-not $extension) {
            return
        }

        if ($DryRun) {
            if ($Uninstall) {
                Write-Host "Would uninstall VS Code extension $extension."
            }
            else {
                Write-Host "Would install VS Code extension $extension."
            }
            return
        }

        if ($Uninstall) {
            if ($installedExtensions -contains $extension) {
                Write-Host "Uninstalling VS Code extension $extension..."
                code --uninstall-extension $extension
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to uninstall VS Code extension: $extension"
                }
            }
            else {
                Write-Host "VS Code extension $extension is not installed; skipping."
            }
        }
        else {
            Write-Host "Installing VS Code extension $extension..."
            code --install-extension $extension
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install VS Code extension: $extension"
            }
        }
    }
}

Main
