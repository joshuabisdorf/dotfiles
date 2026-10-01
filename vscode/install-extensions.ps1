$ErrorActionPreference = "Stop"

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    throw 'VS Code CLI "code" is not available on PATH.'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$extensionsFile = Join-Path $scriptDir "extensions.txt"

Get-Content $extensionsFile | ForEach-Object {
    $extension = ($_ -split '#', 2)[0].Trim()

    if ($extension) {
        Write-Host "Installing VS Code extension $extension..."
        code --install-extension $extension

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install VS Code extension: $extension"
        }
    }
}
