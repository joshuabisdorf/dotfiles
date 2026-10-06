param(
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$ManagedMarker = "# Managed by joshuabisdorf/dotfiles: powershell-profile"

# Test-ManagedProfile
# Requires:
#   - $Path is a PowerShell profile path.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the first line identifies a profile shim managed by this repo.
# Inputs:
#   - Path: profile path to inspect.
# Outputs:
#   - Boolean management status.
function Test-ManagedProfile {
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
#   - profile.ps1 exists beside this script.
#   - $PROFILE.CurrentUserAllHosts identifies a writable per-user profile path when installing.
# Modifies:
#   - The Current User/All Hosts PowerShell profile unless DryRun is enabled.
# Effects:
#   - Installs a managed shim that dot-sources the repo profile, or removes that shim.
# Inputs:
#   - DryRun: report changes without writing.
#   - Uninstall: remove the managed shim.
#   - Force: replace an existing unmanaged profile when installing.
# Outputs:
#   - Status messages on standard output.
function Main {
    $sourceProfile = Join-Path $PSScriptRoot "profile.ps1"
    $targetProfile = $PROFILE.CurrentUserAllHosts

    if ($Uninstall) {
        if (-not (Test-Path -LiteralPath $targetProfile)) {
            Write-Host "PowerShell profile is not installed by this repo."
            return
        }

        if (-not (Test-ManagedProfile -Path $targetProfile)) {
            throw "Refusing to remove unmanaged PowerShell profile: $targetProfile"
        }

        if ($DryRun) {
            Write-Host "Would remove managed PowerShell profile: $targetProfile"
            return
        }

        Remove-Item -LiteralPath $targetProfile -Force
        Write-Host "Removed managed PowerShell profile: $targetProfile"
        return
    }

    if (-not (Test-Path -LiteralPath $sourceProfile -PathType Leaf)) {
        throw "PowerShell profile source not found: $sourceProfile"
    }

    if ((Test-Path -LiteralPath $targetProfile) -and
        -not (Test-ManagedProfile -Path $targetProfile) -and
        -not $Force) {
        throw "Refusing to overwrite unmanaged PowerShell profile: $targetProfile. Re-run with -Force to adopt it."
    }

    $escapedSource = $sourceProfile.Replace("'", "''")
    $shim = @(
        $ManagedMarker
        ". '$escapedSource'"
        ""
    ) -join [Environment]::NewLine

    if ($DryRun) {
        Write-Host "Would install PowerShell profile shim: $targetProfile -> $sourceProfile"
        return
    }

    $targetDirectory = Split-Path -Parent $targetProfile
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Set-Content -LiteralPath $targetProfile -Value $shim -Encoding utf8
    Write-Host "Installed PowerShell profile shim: $targetProfile"
}

Main
