#!/usr/bin/env bash
set -euo pipefail

# usage
# Requires:
#   - None.
# Modifies:
#   - Standard output.
# Effects:
#   - Prints command usage.
# Inputs:
#   - None.
# Outputs:
#   - Usage text on standard output.
usage() {
  printf 'Usage: %s [--dry-run] [--uninstall] [--force]\n' "$0"
}

# is_wsl
# Requires:
#   - /proc/sys/kernel/osrelease when available.
# Modifies:
#   - Nothing.
# Effects:
#   - Detects whether the current Linux environment is WSL.
# Inputs:
#   - Kernel release metadata.
# Outputs:
#   - Exit status 0 under WSL; 1 otherwise.
is_wsl() {
  [[ -r /proc/sys/kernel/osrelease ]] &&
    grep -qi 'microsoft' /proc/sys/kernel/osrelease
}

# main
# Requires:
#   - install.sh and component installers exist in this repository.
#   - GNU Stow is installed for Unix dotfile management.
# Modifies:
#   - Managed user configuration unless dry-run is enabled.
# Effects:
#   - Coordinates Stow, VS Code, and PowerShell user configuration on Linux/WSL.
# Inputs:
#   - Optional --dry-run, --uninstall, and --force flags.
# Outputs:
#   - Component status and skip messages on standard output.
main() {
  local dry_run=false
  local uninstall=false
  local force=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      --uninstall)
        uninstall=true
        ;;
      --force)
        force=true
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        printf 'Error: unknown option: %s\n' "$1" >&2
        usage >&2
        return 64
        ;;
    esac
    shift
  done

  local repo_dir
  repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  local -a stow_args=(--all)
  if [[ "$dry_run" == "true" ]]; then
    stow_args=(--dry-run "${stow_args[@]}")
  fi
  if [[ "$uninstall" == "true" ]]; then
    stow_args=(--uninstall "${stow_args[@]}")
  fi

  "$repo_dir/install.sh" "${stow_args[@]}"

  if is_wsl; then
    printf 'Skipping VS Code desktop settings under WSL; run setup.ps1 on the Windows host.\n'
  else
    local -a settings_args=()
    local -a extension_args=()

    if [[ "$dry_run" == "true" ]]; then
      settings_args+=(--dry-run)
      extension_args+=(--dry-run)
    fi
    if [[ "$uninstall" == "true" ]]; then
      settings_args+=(--uninstall)
      extension_args+=(--uninstall)
    fi
    if [[ "$force" == "true" ]]; then
      settings_args+=(--force)
    fi

    if command -v code >/dev/null 2>&1 || [[ "$dry_run" == "true" || "$uninstall" == "true" ]]; then
      "$repo_dir/vscode/install-settings.sh" "${settings_args[@]}"

      if command -v code >/dev/null 2>&1 || [[ "$dry_run" == "true" ]]; then
        "$repo_dir/vscode/install-extensions.sh" "${extension_args[@]}"
      else
        printf 'VS Code CLI "code" is unavailable; skipping extension removal.\n'
      fi
    else
      printf 'VS Code CLI "code" is unavailable; skipping VS Code configuration.\n'
    fi
  fi

  if command -v pwsh >/dev/null 2>&1; then
    local -a pwsh_args=(-NoProfile -File "$repo_dir/powershell/install.ps1")
    if [[ "$dry_run" == "true" ]]; then
      pwsh_args+=(-DryRun)
    fi
    if [[ "$uninstall" == "true" ]]; then
      pwsh_args+=(-Uninstall)
    fi
    if [[ "$force" == "true" ]]; then
      pwsh_args+=(-Force)
    fi
    pwsh "${pwsh_args[@]}"
  else
    printf 'PowerShell is unavailable; skipping PowerShell profile configuration.\n'
  fi
}

main "$@"
