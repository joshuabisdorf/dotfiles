$ErrorActionPreference = "Stop"
$script:RawArguments = @($args)

$script:RepoDir = $PSScriptRoot
$script:DryRun = $false
$script:Force = $false
$script:All = $false
$script:GitMarker = "joshuabisdorf/dotfiles:git-config"
$script:VSCodeMarker = "joshuabisdorf/dotfiles:vscode-settings"
$script:TerminalMarker = "joshuabisdorf/dotfiles:windows-terminal-settings"
$script:PowerShellMarker = "# Managed by joshuabisdorf/dotfiles: powershell-profile"
$script:Components = @("git", "powershell", "vscode", "terminal")

<#
.SYNOPSIS
    Display the supported Windows setup commands.
.OUTPUTS
    System.String - Help text.
#>
function Show-Usage {
    @"
Usage:
  .\setup-windows.ps1 list
  .\setup-windows.ps1 install -All [-DryRun] [-Force]
  .\setup-windows.ps1 install <component...> [-DryRun] [-Force]
  .\setup-windows.ps1 reinstall -All [-DryRun] [-Force]
  .\setup-windows.ps1 reinstall <component...> [-DryRun] [-Force]
  .\setup-windows.ps1 uninstall -All [-DryRun]
  .\setup-windows.ps1 uninstall <component...> [-DryRun]

Commands:
  list       Show available setup components.
  install    Install missing configuration.
  reinstall  Reapply configuration from the repository.
  uninstall  Remove configuration managed by this repository.

Flags:
  -All       Select every setup component.
  -DryRun    Show what would change without changing anything.
  -Force     Adopt an existing unmanaged copied/profile configuration.

Run ".\setup-windows.ps1 list" to see components.
"@
}

<#
.SYNOPSIS
    List supported Windows components and availability.
.OUTPUTS
    System.String - Component descriptions.
#>
function Show-Components {
    $gitAvailability = if (Get-Command git -ErrorAction SilentlyContinue) { "" } else { " (git is not currently available)" }
    $vscodeAvailability = if (Get-Command code -ErrorAction SilentlyContinue) { "" } else { " (code CLI not currently available)" }
    $terminalAvailability = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "" } else { " (Windows Terminal not currently available)" }

    "{0,-12} {1}" -f "COMPONENT", "DESCRIPTION"
    "{0,-12} {1}" -f "git", "Git user configuration (~/.gitconfig)$gitAvailability"
    "{0,-12} {1}" -f "powershell", "PowerShell 7 Current User/All Hosts profile"
    "{0,-12} {1}" -f "vscode", "VS Code user settings + extensions$vscodeAvailability"
    "{0,-12} {1}" -f "terminal", "Windows Terminal settings$terminalAvailability"
}

<#
.SYNOPSIS
    Test a sidecar file against this repository's ownership marker.
.PARAMETER Path
    Path to the sidecar marker.
.PARAMETER MarkerId
    Expected marker identifier.
.OUTPUTS
    System.Boolean - Whether the marker matches.
#>
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

<#
.SYNOPSIS
    Test whether the profile is a repository-managed shim.
.PARAMETER Path
    PowerShell Current User/All Hosts profile path.
.OUTPUTS
    System.Boolean - Whether the file has the managed shim marker.
#>
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

<#
.SYNOPSIS
    Manage a copied settings file and sidecar ownership marker.
.DESCRIPTION
    Refuses to overwrite or delete an unmanaged target. Force allows adopting a target on install/reinstall without backing it up. Dry runs do not modify files.
.PARAMETER Action
    Install, reinstall, or uninstall.
.PARAMETER Source
    Repository source path.
.PARAMETER Target
    User destination path.
.PARAMETER MarkerId
    Expected marker identifier.
.PARAMETER Label
    Display label for messages.
#>
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

<#
.SYNOPSIS
    Manage the shared Git user configuration.
.DESCRIPTION
    Uses a managed copy of git/.gitconfig at the user's ~/.gitconfig.
.PARAMETER Action
    Install, reinstall, or uninstall Git settings.
#>
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

<#
.SYNOPSIS
    Manage the PowerShell Current User/All Hosts profile shim.
.DESCRIPTION
    The marked shim dot-sources the repository profile. Uninstall deletes only the marked shim; Force adoption overwrites without a backup.
.PARAMETER Action
    Install, reinstall, or uninstall the shim.
#>
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

<#
.SYNOPSIS
    Apply VS Code extension actions from the manifest.
.DESCRIPTION
    Uninstall removes listed extensions even if they were previously installed outside dotfiles.
.PARAMETER Action
    Install, reinstall, or uninstall listed extensions.
#>
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

<#
.SYNOPSIS
    Manage Windows VS Code user settings and extensions.
.DESCRIPTION
    Settings are copied and tracked with a marker; extensions are managed using the code CLI.
.PARAMETER Action
    Install, reinstall, or uninstall VS Code configuration.
#>
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

<#
.SYNOPSIS
    Find the packaged or unpackaged Windows Terminal settings path.
.DESCRIPTION
    Uses an existing packaged directory first, then an unpackaged directory; otherwise defaults to the packaged path.
.OUTPUTS
    System.String - User settings.json path.
#>
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

<#
.SYNOPSIS
    Manage Windows Terminal settings and their ownership marker.
.PARAMETER Action
    Install, reinstall, or uninstall Terminal settings.
#>
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

<#
.SYNOPSIS
    Dispatch a selected Windows setup component.
.DESCRIPTION
    When -All is used, unavailable optional applications may be skipped; explicitly requested unavailable applications cause errors.
.PARAMETER Action
    Install, reinstall, or uninstall.
.PARAMETER Component
    Recognized component name.
.PARAMETER SelectedAll
    Whether -All was selected.
#>
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

<#
.SYNOPSIS
    Parse Windows setup commands, components, and flags.
.DESCRIPTION
    Sets script-scoped DryRun, Force, and All flags; command-line flags may appear in any position.
.OUTPUTS
    PSCustomObject - Command and Requested component array.
#>
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
            "-all" {
                $script:All = $true
                continue
            }
            "--all" {
                $script:All = $true
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

<#
.SYNOPSIS
    Validate the Windows setup CLI and run selected components.
.DESCRIPTION
    Requires PowerShell 7 for mutating operations. Rejects invalid selectors, -Force with uninstall, and unmanaged targets without explicit adoption.
#>
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
            if ($requested.Count -ne 0 -or $script:All -or $script:DryRun -or $script:Force) {
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
        throw "PowerShell 7 is required. Run: pwsh -File .\setup-windows.ps1 $command ..."
    }

    if ($command -eq "uninstall" -and $script:Force) {
        throw "-Force is not valid with uninstall."
    }

    if ($script:All -and $requested.Count -gt 0) {
        throw "-All cannot be combined with individual components."
    }

    if (-not $script:All -and $requested.Count -eq 0) {
        Show-Usage
        throw "Choose -All or at least one component."
    }

    $selectedAll = $script:All

    $selected = if ($selectedAll) {
        @($script:Components)
    }
    else {
        foreach ($component in $requested) {
            if ($script:Components -notcontains $component) {
                throw "Unknown component: $component. Run '.\setup-windows.ps1 list' to see available components."
            }

            $component
        }
    }

    foreach ($component in $selected) {
        Invoke-Component -Action $command -Component $component -SelectedAll $selectedAll
    }
}

Main
