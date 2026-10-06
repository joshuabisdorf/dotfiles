param(
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Invoke-DotfilesInstaller
# Requires:
#   - ScriptPath names an existing PowerShell installer.
# Modifies:
#   - Whatever user configuration the child installer manages unless DryRun is enabled.
# Effects:
#   - Invokes one component installer with the top-level operation flags.
# Inputs:
#   - ScriptPath: child installer path.
#   - IncludeForce: pass -Force when requested.
# Outputs:
#   - Child installer status on standard output.
function Invoke-DotfilesInstaller {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [switch]$IncludeForce
    )

    $parameters = @{}

    if ($DryRun) {
        $parameters["DryRun"] = $true
    }

    if ($Uninstall) {
        $parameters["Uninstall"] = $true
    }

    if ($Force -and $IncludeForce) {
        $parameters["Force"] = $true
    }

    & $ScriptPath @parameters
}

# Main
# Requires:
#   - Component installers exist beneath this repository.
# Modifies:
#   - PowerShell, VS Code, and Windows Terminal user configuration unless DryRun is enabled.
# Effects:
#   - Coordinates native Windows user configuration without installing applications.
# Inputs:
#   - DryRun: report changes without writing.
#   - Uninstall: remove managed configuration.
#   - Force: adopt existing VS Code/Terminal settings or PowerShell profile.
# Outputs:
#   - Component status and skip messages on standard output.
function Main {
    $repoDir = $PSScriptRoot

    Invoke-DotfilesInstaller `
        -ScriptPath (Join-Path $repoDir "powershell\install.ps1") `
        -IncludeForce

    $codeAvailable = [bool](Get-Command code -ErrorAction SilentlyContinue)

    if ($codeAvailable -or $DryRun -or $Uninstall) {
        Invoke-DotfilesInstaller `
            -ScriptPath (Join-Path $repoDir "vscode\install-settings.ps1") `
            -IncludeForce

        if ($codeAvailable -or $DryRun) {
            Invoke-DotfilesInstaller `
                -ScriptPath (Join-Path $repoDir "vscode\install-extensions.ps1")
        }
        else {
            Write-Host 'VS Code CLI "code" is unavailable; skipping extension removal.'
        }
    }
    else {
        Write-Host 'VS Code CLI "code" is unavailable; skipping VS Code configuration.'
    }

    $terminalAvailable = [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)
    if ($terminalAvailable -or $DryRun -or $Uninstall) {
        Invoke-DotfilesInstaller `
            -ScriptPath (Join-Path $repoDir "windows-terminal\install.ps1") `
            -IncludeForce
    }
    else {
        Write-Host "Windows Terminal is unavailable; skipping Windows Terminal configuration."
    }
}

Main
