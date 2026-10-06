$ErrorActionPreference = "Stop"
$script:RawArguments = @($args)

$script:RepoDir = $PSScriptRoot
$script:DryRun = $false
$script:Force = $false
$script:GitMarker = "joshuabisdorf/dotfiles:git-config"
$script:VSCodeMarker = "joshuabisdorf/dotfiles:vscode-settings"
$script:TerminalMarker = "joshuabisdorf/dotfiles:windows-terminal-settings"
$script:PowerShellMarker = "# Managed by joshuabisdorf/dotfiles: powershell-profile"
$script:Components = @("git", "powershell", "vscode", "terminal")

# Show-Usage
# Requires:
#   - None.
# Modifies:
#   - Standard output.
# Effects:
#   - Prints the public Windows setup interface.
# Inputs:
#   - None.
# Outputs:
#   - Usage text on standard output.
function Show-Usage {
    @"
Usage:
  .\setup.ps1 list
  .\setup.ps1 install <all|component...> [-DryRun] [-Force]
  .\setup.ps1 reinstall <all|component...> [-DryRun] [-Force]
  .\setup.ps1 uninstall <all|component...> [-DryRun]

Commands:
  list       Show available setup components.
  install    Install missing configuration.
  reinstall  Reapply configuration from the repository.
  uninstall  Remove configuration managed by this repository.

Flags:
  -DryRun    Show what would change without changing anything.
  -Force     Adopt an existing unmanaged copied/profile configuration.

Run ".\setup.ps1 list" to see components.
"@ | Write-Host
}

# Show-Components
# Requires:
#   - None.
# Modifies:
#   - Standard output.
# Effects:
#   - Describes every Windows component exposed by setup.ps1.
# Inputs:
#   - Available applications for availability notes.
# Outputs:
#   - Component names, descriptions, and availability notes.
function Show-Components {
    $gitAvailability = if (Get-Command git -ErrorAction SilentlyContinue) { "" } else { " (git is not currently available)" }
    $vscodeAvailability = if (Get-Command code -ErrorAction SilentlyContinue) { "" } else { " (code CLI not currently available)" }
    $terminalAvailability = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "" } else { " (Windows Terminal not currently available)" }

    "{0,-12} {1}" -f "COMPONENT", "DESCRIPTION" | Write-Host
    "{0,-12} {1}" -f "git", "Git user configuration (~/.gitconfig)$gitAvailability" | Write-Host
    "{0,-12} {1}" -f "powershell", "PowerShell 7 Current User/All Hosts profile" | Write-Host
    "{0,-12} {1}" -f "vscode", "VS Code user settings + extensions$vscodeAvailability" | Write-Host
    "{0,-12} {1}" -f "terminal", "Windows Terminal settings$terminalAvailability" | Write-Host
    "{0,-12} {1}" -f "all", "All components above" | Write-Host
}

# Test-ManagedMarker
# Requires:
#   - Path is a marker file path.
#   - MarkerId is the expected first-line marker.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether a sidecar marker identifies a managed copied file.
# Inputs:
#   - Path: marker file path.
#   - MarkerId: expected marker identifier.
# Outputs:
#   - Boolean management status.
function Test-ManagedMarker {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$MarkerId
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1
    return $firstLine -eq $MarkerId
}

# Test-ManagedPowerShellProfile
# Requires:
#   - Path is a PowerShell profile path.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the first line identifies a profile shim managed by this repository.
# Inputs:
#   - Path: PowerShell profile path.
# Outputs:
#   - Boolean management status.
function Test-ManagedPowerShellProfile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1
    return $firstLine -eq $script:PowerShellMarker
}

# Set-ManagedCopy
# Requires:
#   - Source exists for install/reinstall operations.
# Modifies:
#   - Target and its sidecar ownership marker unless DryRun is enabled.
# Effects:
#   - Installs, reinstalls, or removes a copied configuration safely.
# Inputs:
#   - Action: install, reinstall, or uninstall.
#   - Source: repository source file.
#   - Target: user configuration target.
#   - MarkerId: ownership marker identifier.
#   - Label: human-readable component label.
# Outputs:
#   - Status or safety errors.
function Set-ManagedCopy {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$MarkerId,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $markerFile = "$Target.dotfiles-managed"

    if ($Action -eq "uninstall") {
        if (-not (Test-Path -LiteralPath $Target) -and -not (Test-Path -LiteralPath $markerFile)) {
            Write-Host "$Label is not installed by this repository."
            return
        }

        if (-not (Test-ManagedMarker -Path $markerFile -MarkerId $MarkerId)) {
            throw "Refusing to remove unmanaged ${Label}: $Target"
        }

        if ($script:DryRun) {
            Write-Host "Would remove managed ${Label}: $Target"
            return
        }

        Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $markerFile -Force -ErrorAction SilentlyContinue
        Write-Host "Removed managed ${Label}: $Target"
        return
    }

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Source file not found for ${Label}: $Source"
    }

    $managed = Test-ManagedMarker -Path $markerFile -MarkerId $MarkerId

    if ($Action -eq "install" -and (Test-Path -LiteralPath $Target -PathType Leaf) -and $managed) {
        Write-Host "$Label is already installed; use reinstall to reapply it."
        return
    }

    if ((Test-Path -LiteralPath $Target) -and -not $managed -and -not $script:Force) {
        throw "Refusing to overwrite unmanaged ${Label}: $Target. Re-run with -Force to adopt it."
    }

    if ($script:DryRun) {
        Write-Host "Would $Action ${Label}: $Source -> $Target"
        return
    }

    $targetDirectory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Target -Force
    Set-Content -LiteralPath $markerFile -Value @($MarkerId, $Source) -Encoding utf8
    Write-Host "$($Action.Substring(0,1).ToUpper() + $Action.Substring(1))ed ${Label}: $Target"
}

# Invoke-GitSetup
# Requires:
#   - git/.gitconfig exists in the repository.
# Modifies:
#   - ~/.gitconfig and its ownership marker unless DryRun is enabled.
# Effects:
#   - Manages the shared Git configuration on native Windows.
# Inputs:
#   - Action: install, reinstall, or uninstall.
# Outputs:
#   - Git configuration status.
function Invoke-GitSetup {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action
    )

    $source = Join-Path $script:RepoDir "git\.gitconfig"
    $target = Join-Path $HOME ".gitconfig"
    Set-ManagedCopy -Action $Action -Source $source -Target $target -MarkerId $script:GitMarker -Label "Git configuration"
}

# Invoke-PowerShellSetup
# Requires:
#   - PowerShell 7 is running.
#   - powershell/profile.ps1 exists in the repository.
# Modifies:
#   - Current User/All Hosts PowerShell profile unless DryRun is enabled.
# Effects:
#   - Installs a managed shim, reinstalls it, or removes it.
# Inputs:
#   - Action: install, reinstall, or uninstall.
# Outputs:
#   - PowerShell profile status.
function Invoke-PowerShellSetup {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action
    )

    $sourceProfile = Join-Path $script:RepoDir "powershell\profile.ps1"
    $targetProfile = $PROFILE.CurrentUserAllHosts

    if ($Action -eq "uninstall") {
        if (-not (Test-Path -LiteralPath $targetProfile)) {
            Write-Host "PowerShell profile is not installed by this repository."
            return
        }

        if (-not (Test-ManagedPowerShellProfile -Path $targetProfile)) {
            throw "Refusing to remove unmanaged PowerShell profile: $targetProfile"
        }

        if ($script:DryRun) {
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

    $managed = Test-ManagedPowerShellProfile -Path $targetProfile

    if ($Action -eq "install" -and (Test-Path -LiteralPath $targetProfile -PathType Leaf) -and $managed) {
        Write-Host "PowerShell profile is already installed; use reinstall to reapply it."
        return
    }

    if ((Test-Path -LiteralPath $targetProfile) -and -not $managed -and -not $script:Force) {
        throw "Refusing to overwrite unmanaged PowerShell profile: $targetProfile. Re-run with -Force to adopt it."
    }

    $escapedSource = $sourceProfile.Replace("'", "''")
    $shim = @(
        $script:PowerShellMarker
        ". '$escapedSource'"
        ""
    ) -join [Environment]::NewLine

    if ($script:DryRun) {
        Write-Host "Would $Action PowerShell profile shim: $targetProfile -> $sourceProfile"
        return
    }

    $targetDirectory = Split-Path -Parent $targetProfile
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Set-Content -LiteralPath $targetProfile -Value $shim -Encoding utf8
    Write-Host "$($Action.Substring(0,1).ToUpper() + $Action.Substring(1))ed PowerShell profile shim: $targetProfile"
}

# Invoke-VSCodeExtensions
# Requires:
#   - vscode/extensions.txt exists.
#   - VS Code's code CLI is available unless DryRun is enabled.
# Modifies:
#   - Installed VS Code extensions unless DryRun is enabled.
# Effects:
#   - Installs, force-reinstalls, or removes extensions in the repository manifest.
# Inputs:
#   - Action: install, reinstall, or uninstall.
# Outputs:
#   - Extension status.
function Invoke-VSCodeExtensions {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action
    )

    $extensionsFile = Join-Path $script:RepoDir "vscode\extensions.txt"

    if (-not (Test-Path -LiteralPath $extensionsFile -PathType Leaf)) {
        throw "VS Code extension manifest not found: $extensionsFile"
    }

    if (-not $script:DryRun -and -not (Get-Command code -ErrorAction SilentlyContinue)) {
        if ($Action -eq "uninstall") {
            Write-Host 'VS Code CLI "code" is unavailable; skipping extension removal.'
            return
        }

        throw 'VS Code CLI "code" is not available on PATH.'
    }

    $installedExtensions = @()
    if (-not $script:DryRun -and $Action -eq "uninstall") {
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

        if ($script:DryRun) {
            Write-Host "Would $Action VS Code extension $extension."
            return
        }

        switch ($Action) {
            "install" {
                Write-Host "Installing VS Code extension $extension..."
                code --install-extension $extension
            }
            "reinstall" {
                Write-Host "Reinstalling VS Code extension $extension..."
                code --install-extension $extension --force
            }
            "uninstall" {
                if ($installedExtensions -contains $extension) {
                    Write-Host "Uninstalling VS Code extension $extension..."
                    code --uninstall-extension $extension
                }
                else {
                    Write-Host "VS Code extension $extension is not installed; skipping."
                    return
                }
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "VS Code extension operation failed: $extension"
        }
    }
}

# Invoke-VSCodeSetup
# Requires:
#   - vscode/settings.json and vscode/extensions.txt exist.
# Modifies:
#   - VS Code user settings and extensions unless DryRun is enabled.
# Effects:
#   - Manages VS Code as one public setup component.
# Inputs:
#   - Action: install, reinstall, or uninstall.
# Outputs:
#   - VS Code settings and extension status.
function Invoke-VSCodeSetup {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action
    )

    $source = Join-Path $script:RepoDir "vscode\settings.json"
    $target = Join-Path $env:APPDATA "Code\User\settings.json"
    Set-ManagedCopy -Action $Action -Source $source -Target $target -MarkerId $script:VSCodeMarker -Label "VS Code settings"
    Invoke-VSCodeExtensions -Action $Action
}

# Get-WindowsTerminalSettingsPath
# Requires:
#   - LOCALAPPDATA is set.
# Modifies:
#   - Nothing.
# Effects:
#   - Selects the stable packaged or unpackaged Windows Terminal settings path.
# Inputs:
#   - Current user's LOCALAPPDATA.
# Outputs:
#   - Windows Terminal settings.json path.
function Get-WindowsTerminalSettingsPath {
    if (-not $env:LOCALAPPDATA) {
        throw "LOCALAPPDATA is not set."
    }

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

# Invoke-TerminalSetup
# Requires:
#   - windows-terminal/settings.json exists.
# Modifies:
#   - Windows Terminal settings and ownership marker unless DryRun is enabled.
# Effects:
#   - Installs, reinstalls, or removes the repository's Terminal configuration.
# Inputs:
#   - Action: install, reinstall, or uninstall.
# Outputs:
#   - Windows Terminal settings status.
function Invoke-TerminalSetup {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action
    )

    $source = Join-Path $script:RepoDir "windows-terminal\settings.json"
    $target = Get-WindowsTerminalSettingsPath
    Set-ManagedCopy -Action $Action -Source $source -Target $target -MarkerId $script:TerminalMarker -Label "Windows Terminal settings"
}

# Invoke-Component
# Requires:
#   - Component is a known public component.
# Modifies:
#   - Selected user configuration unless DryRun is enabled.
# Effects:
#   - Dispatches one public component and handles optional application availability for "all".
# Inputs:
#   - Action: install, reinstall, or uninstall.
#   - Component: component name.
#   - SelectedAll: whether the request used all.
# Outputs:
#   - Component status or availability messages.
function Invoke-Component {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("install", "reinstall", "uninstall")]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [bool]$SelectedAll
    )

    switch ($Component) {
        "git" {
            Invoke-GitSetup -Action $Action
        }
        "powershell" {
            Invoke-PowerShellSetup -Action $Action
        }
        "vscode" {
            if (-not $script:DryRun -and $Action -ne "uninstall" -and -not (Get-Command code -ErrorAction SilentlyContinue)) {
                if ($SelectedAll) {
                    Write-Host 'Skipping vscode because the code CLI is unavailable.'
                    return
                }

                throw 'VS Code CLI "code" is not available on PATH.'
            }

            Invoke-VSCodeSetup -Action $Action
        }
        "terminal" {
            if (-not $script:DryRun -and $Action -ne "uninstall" -and -not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
                if ($SelectedAll) {
                    Write-Host "Skipping terminal because Windows Terminal is unavailable."
                    return
                }

                throw "Windows Terminal is not available."
            }

            Invoke-TerminalSetup -Action $Action
        }
    }
}

# Parse-Arguments
# Requires:
#   - Script arguments are available through $args.
# Modifies:
#   - Script-scoped DryRun and Force flags.
# Effects:
#   - Parses the command, components, and flags with flags allowed in any position.
# Inputs:
#   - Raw script arguments.
# Outputs:
#   - PSCustomObject with Command and Requested component array.
function Parse-Arguments {
    $command = $null
    $requested = @()

    foreach ($argument in $script:RawArguments) {
        switch ($argument.ToLowerInvariant()) {
            "-dryrun" {
                $script:DryRun = $true
                continue
            }
            "--dry-run" {
                $script:DryRun = $true
                continue
            }
            "-force" {
                $script:Force = $true
                continue
            }
            "--force" {
                $script:Force = $true
                continue
            }
            "-h" {
                if (-not $command) {
                    $command = "help"
                }
                continue
            }
            "-help" {
                if (-not $command) {
                    $command = "help"
                }
                continue
            }
            "--help" {
                if (-not $command) {
                    $command = "help"
                }
                continue
            }
            default {
                if (-not $command) {
                    $command = $argument.ToLowerInvariant()
                }
                else {
                    $requested += $argument.ToLowerInvariant()
                }
            }
        }
    }

    if (-not $command) {
        $command = "help"
    }

    [PSCustomObject]@{
        Command = $command
        Requested = $requested
    }
}

# Main
# Requires:
#   - PowerShell 7 for mutating operations.
#   - Repository configuration files exist for selected components.
# Modifies:
#   - User configuration selected by the command unless DryRun is enabled.
# Effects:
#   - Provides the only native Windows setup entry point for listing and managing dotfiles.
# Inputs:
#   - list, install, reinstall, or uninstall command.
#   - all or one or more component names for mutating commands.
#   - Optional -DryRun and -Force flags.
# Outputs:
#   - Setup status and safety errors.
function Main {
    $parsed = Parse-Arguments
    $command = $parsed.Command
    $requested = @($parsed.Requested)

    switch ($command) {
        "help" {
            Show-Usage
            return
        }
        "list" {
            if ($requested.Count -ne 0 -or $script:DryRun -or $script:Force) {
                throw "list does not accept components or flags."
            }

            Show-Components
            return
        }
        "install" {}
        "reinstall" {}
        "uninstall" {}
        default {
            Show-Usage
            throw "Unknown command: $command"
        }
    }

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7 is required. Run: pwsh -File .\setup.ps1 $command ..."
    }

    if ($command -eq "uninstall" -and $script:Force) {
        throw "-Force is not valid with uninstall."
    }

    if ($requested.Count -eq 0) {
        Show-Usage
        throw 'Choose "all" or at least one component.'
    }

    $selectedAll = $requested -contains "all"
    if ($selectedAll -and $requested.Count -ne 1) {
        throw '"all" cannot be combined with individual components.'
    }

    $selected = if ($selectedAll) {
        @($script:Components)
    }
    else {
        foreach ($component in $requested) {
            if ($script:Components -notcontains $component) {
                throw "Unknown component: $component. Run '.\setup.ps1 list' to see available components."
            }

            $component
        }
    }

    foreach ($component in $selected) {
        Invoke-Component -Action $command -Component $component -SelectedAll $selectedAll
    }
}

Main
