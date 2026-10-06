#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly VSCODE_MARKER='joshuabisdorf/dotfiles:vscode-settings'
readonly -a STOW_COMPONENTS=(git bash readline vim)
readonly -a COMPONENTS=(git bash readline vim vscode)

# usage
# Requires:
#   - None.
# Modifies:
#   - Standard output.
# Effects:
#   - Prints the public Linux/WSL setup interface.
# Inputs:
#   - None.
# Outputs:
#   - Usage text on standard output.
usage() {
  cat <<'EOF'
Usage:
  ./setup-linux.sh list
  ./setup-linux.sh install --all [--dry-run] [--force]
  ./setup-linux.sh install <component...> [--dry-run] [--force]
  ./setup-linux.sh reinstall --all [--dry-run] [--force]
  ./setup-linux.sh reinstall <component...> [--dry-run] [--force]
  ./setup-linux.sh uninstall --all [--dry-run]
  ./setup-linux.sh uninstall <component...> [--dry-run]

Commands:
  list       Show available setup components.
  install    Install missing configuration.
  reinstall  Reapply configuration from the repository.
  uninstall  Remove configuration managed by this repository.

Flags:
  --dry-run  Show what would change without changing anything.
  --force    Adopt an existing unmanaged copied/profile configuration.

Run "./setup-linux.sh list" to see components.
EOF
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

# list_components
# Requires:
#   - None.
# Modifies:
#   - Standard output.
# Effects:
#   - Describes every Linux/WSL component exposed by setup.sh.
# Inputs:
#   - Current platform and available commands for availability notes.
# Outputs:
#   - Component names, descriptions, and availability notes.
list_components() {
  printf '%-12s %s\n' 'COMPONENT' 'DESCRIPTION'
  printf '%-12s %s\n' 'git' 'Git user configuration (~/.gitconfig via GNU Stow)'
  printf '%-12s %s\n' 'bash' 'Interactive Bash configuration (~/.bashrc via GNU Stow)'
  printf '%-12s %s\n' 'readline' 'Readline key bindings (~/.inputrc via GNU Stow)'
  printf '%-12s %s\n' 'vim' 'Vim configuration (~/.vimrc via GNU Stow)'

  if is_wsl; then
    printf '%-12s %s\n' 'vscode' 'VS Code desktop settings + extensions (Windows host only under WSL)'
  elif command -v code >/dev/null 2>&1; then
    printf '%-12s %s\n' 'vscode' 'VS Code user settings + extensions'
  else
    printf '%-12s %s\n' 'vscode' 'VS Code user settings + extensions (code CLI not currently available)'
  fi

}

# component_is_known
# Requires:
#   - $1 is a requested component name.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the requested component is part of the public interface.
# Inputs:
#   - $1: component name.
# Outputs:
#   - Exit status 0 when known; 1 otherwise.
component_is_known() {
  local requested="$1"
  local component

  for component in "${COMPONENTS[@]}"; do
    if [[ "$component" == "$requested" ]]; then
      return 0
    fi
  done

  return 1
}

# component_uses_stow
# Requires:
#   - $1 is a component name.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the component is managed through GNU Stow.
# Inputs:
#   - $1: component name.
# Outputs:
#   - Exit status 0 for a Stow component; 1 otherwise.
component_uses_stow() {
  local requested="$1"
  local component

  for component in "${STOW_COMPONENTS[@]}"; do
    if [[ "$component" == "$requested" ]]; then
      return 0
    fi
  done

  return 1
}

# marker_is_managed
# Requires:
#   - $1 is a marker file path.
#   - $2 is the marker identifier expected on the first line.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether a sidecar marker identifies a managed copied file.
# Inputs:
#   - $1: marker file path.
#   - $2: marker identifier.
# Outputs:
#   - Exit status 0 when managed; 1 otherwise.
marker_is_managed() {
  local marker_file="$1"
  local marker_id="$2"

  [[ -r "$marker_file" ]] || return 1

  local first_line
  IFS= read -r first_line < "$marker_file"
  [[ "$first_line" == "$marker_id" ]]
}

# configure_stow_component
# Requires:
#   - GNU Stow is installed and available on PATH.
#   - $2 names a Stow package directory in the repository.
# Modifies:
#   - Symlinks beneath HOME unless dry-run is enabled.
# Effects:
#   - Installs, restows, or deletes one Stow package.
# Inputs:
#   - $1: action: install, reinstall, or uninstall.
#   - $2: package/component name.
#   - $3: dry-run flag: true or false.
# Outputs:
#   - Status and GNU Stow output.
configure_stow_component() {
  local action="$1"
  local component="$2"
  local dry_run="$3"

  if ! command -v stow >/dev/null 2>&1; then
    printf 'Error: GNU Stow is required for component "%s".\n' "$component" >&2
    return 69
  fi

  if [[ ! -d "$REPO_DIR/$component" ]]; then
    printf 'Error: Stow package directory is missing: %s\n' "$REPO_DIR/$component" >&2
    return 66
  fi

  local -a args=(
    "--dir=$REPO_DIR"
    "--target=$HOME"
  )

  case "$action" in
    install)
      args+=(--stow)
      ;;
    reinstall)
      args+=(--restow)
      ;;
    uninstall)
      args+=(--delete)
      ;;
  esac

  if [[ "$dry_run" == "true" ]]; then
    args+=(--simulate)
  fi

  printf '%s %s%s...\n'     "${action^}"     "$component"     "$([[ "$dry_run" == "true" ]] && printf ' (dry run)')"

  stow "${args[@]}" "$component"
}

# configure_managed_copy
# Requires:
#   - $2 exists when installing or reinstalling.
# Modifies:
#   - $3 and its sidecar marker unless dry-run is enabled.
# Effects:
#   - Installs, reinstalls, or removes a copied configuration with ownership tracking.
# Inputs:
#   - $1: action.
#   - $2: source file.
#   - $3: target file.
#   - $4: marker identifier.
#   - $5: human-readable label.
#   - $6: dry-run flag.
#   - $7: force flag.
# Outputs:
#   - Status or safety errors.
configure_managed_copy() {
  local action="$1"
  local source_file="$2"
  local target_file="$3"
  local marker_id="$4"
  local label="$5"
  local dry_run="$6"
  local force="$7"
  local marker_file="${target_file}.dotfiles-managed"

  if [[ "$action" == "uninstall" ]]; then
    if [[ ! -e "$target_file" && ! -e "$marker_file" ]]; then
      printf '%s is not installed by this repository.\n' "$label"
      return 0
    fi

    if ! marker_is_managed "$marker_file" "$marker_id"; then
      printf 'Error: refusing to remove unmanaged %s: %s\n' "$label" "$target_file" >&2
      return 73
    fi

    if [[ "$dry_run" == "true" ]]; then
      printf 'Would remove managed %s: %s\n' "$label" "$target_file"
      return 0
    fi

    rm -f -- "$target_file" "$marker_file"
    printf 'Removed managed %s: %s\n' "$label" "$target_file"
    return 0
  fi

  if [[ ! -r "$source_file" ]]; then
    printf 'Error: source file not found for %s: %s\n' "$label" "$source_file" >&2
    return 66
  fi

  if [[ "$action" == "install" ]] &&
     [[ -e "$target_file" ]] &&
     marker_is_managed "$marker_file" "$marker_id"; then
    printf '%s is already installed; use reinstall to reapply it.\n' "$label"
    return 0
  fi

  if [[ -e "$target_file" ]] &&
     ! marker_is_managed "$marker_file" "$marker_id" &&
     [[ "$force" != "true" ]]; then
    printf 'Error: refusing to overwrite unmanaged %s: %s\n' "$label" "$target_file" >&2
    printf 'Re-run with --force to adopt it.\n' >&2
    return 73
  fi

  if [[ "$dry_run" == "true" ]]; then
    printf 'Would %s %s: %s -> %s\n' "$action" "$label" "$source_file" "$target_file"
    return 0
  fi

  mkdir -p -- "$(dirname -- "$target_file")"
  cp -- "$source_file" "$target_file"
  {
    printf '%s\n' "$marker_id"
    printf '%s\n' "$source_file"
  } > "$marker_file"

  printf '%s %s: %s\n' "${action^}ed" "$label" "$target_file"
}

# configure_vscode_extensions
# Requires:
#   - vscode/extensions.txt exists.
#   - VS Code's code CLI is available unless dry-run is enabled.
# Modifies:
#   - Installed VS Code extensions unless dry-run is enabled.
# Effects:
#   - Installs, force-reinstalls, or removes extensions in the repository manifest.
# Inputs:
#   - $1: action.
#   - $2: dry-run flag.
# Outputs:
#   - Extension status.
configure_vscode_extensions() {
  local action="$1"
  local dry_run="$2"
  local extensions_file="$REPO_DIR/vscode/extensions.txt"

  if [[ ! -r "$extensions_file" ]]; then
    printf 'Error: VS Code extension manifest not found: %s\n' "$extensions_file" >&2
    return 66
  fi

  if [[ "$dry_run" != "true" ]] && ! command -v code >/dev/null 2>&1; then
    printf 'Error: VS Code CLI "code" is not available on PATH.\n' >&2
    return 69
  fi

  local installed_extensions=''
  if [[ "$dry_run" != "true" && "$action" == "uninstall" ]]; then
    installed_extensions="$(code --list-extensions)"
  fi

  local extension
  while IFS= read -r extension || [[ -n "$extension" ]]; do
    extension="${extension%%#*}"
    extension="${extension#"${extension%%[![:space:]]*}"}"
    extension="${extension%"${extension##*[![:space:]]}"}"

    if [[ -z "$extension" ]]; then
      continue
    fi

    if [[ "$dry_run" == "true" ]]; then
      printf 'Would %s VS Code extension %s.\n' "$action" "$extension"
      continue
    fi

    case "$action" in
      install)
        printf 'Installing VS Code extension %s...\n' "$extension"
        code --install-extension "$extension"
        ;;
      reinstall)
        printf 'Reinstalling VS Code extension %s...\n' "$extension"
        code --install-extension "$extension" --force
        ;;
      uninstall)
        if grep -Fxiq -- "$extension" <<< "$installed_extensions"; then
          printf 'Uninstalling VS Code extension %s...\n' "$extension"
          code --uninstall-extension "$extension"
        else
          printf 'VS Code extension %s is not installed; skipping.\n' "$extension"
        fi
        ;;
    esac
  done < "$extensions_file"
}

# configure_vscode
# Requires:
#   - VS Code desktop use is not delegated to the Windows host.
# Modifies:
#   - VS Code user settings and extensions unless dry-run is enabled.
# Effects:
#   - Manages VS Code as one public setup component.
# Inputs:
#   - $1: action.
#   - $2: dry-run flag.
#   - $3: force flag.
# Outputs:
#   - Settings and extension status.
configure_vscode() {
  local action="$1"
  local dry_run="$2"
  local force="$3"
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local target_file="$config_home/Code/User/settings.json"

  configure_managed_copy     "$action"     "$REPO_DIR/vscode/settings.json"     "$target_file"     "$VSCODE_MARKER"     'VS Code settings'     "$dry_run"     "$force"

  configure_vscode_extensions "$action" "$dry_run"
}

# run_component
# Requires:
#   - $2 is a known component.
# Modifies:
#   - The selected user configuration unless dry-run is enabled.
# Effects:
#   - Dispatches one public component to its internal setup implementation.
# Inputs:
#   - $1: action.
#   - $2: component.
#   - $3: dry-run flag.
#   - $4: force flag.
#   - $5: whether the request used "all".
# Outputs:
#   - Component status or availability messages.
run_component() {
  local action="$1"
  local component="$2"
  local dry_run="$3"
  local force="$4"
  local selected_all="$5"

  if component_uses_stow "$component"; then
    configure_stow_component "$action" "$component" "$dry_run"
    return
  fi

  case "$component" in
    vscode)
      if is_wsl; then
        if [[ "$selected_all" == "true" ]]; then
          printf 'Skipping vscode under WSL; configure Windows-side VS Code with setup-windows.ps1.\n'
          return 0
        fi

        printf 'Error: vscode desktop configuration is managed from Windows when running under WSL.\n' >&2
        return 69
      fi

      if [[ "$dry_run" != "true" && "$action" != "uninstall" ]] &&
         ! command -v code >/dev/null 2>&1; then
        if [[ "$selected_all" == "true" ]]; then
          printf 'Skipping vscode because the code CLI is unavailable.\n'
          return 0
        fi

        printf 'Error: VS Code CLI "code" is not available on PATH.\n' >&2
        return 69
      fi

      configure_vscode "$action" "$dry_run" "$force"
      ;;
  esac
}

# main
# Requires:
#   - Repository configuration files exist for selected components.
#   - Required host applications are installed for non-dry-run component operations.
# Modifies:
#   - User configuration selected by the command unless dry-run is enabled.
# Effects:
#   - Provides the only Linux/WSL setup entry point for listing and managing dotfiles.
# Inputs:
#   - list, install, reinstall, or uninstall command.
#   - --all or one or more component names for mutating commands.
#   - Optional --dry-run and --force flags.
# Outputs:
#   - Setup status and safety errors.
main() {
  if [[ $# -eq 0 ]]; then
    usage
    return 64
  fi

  local command="$1"
  shift

  case "$command" in
    -h|--help|help)
      usage
      return 0
      ;;
    list)
      if [[ $# -ne 0 ]]; then
        printf 'Error: list does not accept components or flags.\n' >&2
        return 64
      fi
      list_components
      return 0
      ;;
    install|reinstall|uninstall)
      ;;
    *)
      printf 'Error: unknown command: %s\n' "$command" >&2
      usage >&2
      return 64
      ;;
  esac

  local dry_run=false
  local force=false
  local selected_all=false
  local -a requested=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        selected_all=true
        ;;
      --dry-run)
        dry_run=true
        ;;
      --force)
        force=true
        ;;
      -*)
        printf 'Error: unknown option: %s\n' "$1" >&2
        return 64
        ;;
      *)
        requested+=("$1")
        ;;
    esac
    shift
  done

  if [[ "$command" == "uninstall" && "$force" == "true" ]]; then
    printf 'Error: --force is not valid with uninstall.\n' >&2
    return 64
  fi

  if [[ "$selected_all" == "true" && ${#requested[@]} -gt 0 ]]; then
    printf 'Error: --all cannot be combined with individual components.\n' >&2
    return 64
  fi

  if [[ "$selected_all" == "false" && ${#requested[@]} -eq 0 ]]; then
    printf 'Error: choose --all or at least one component.\n' >&2
    usage >&2
    return 64
  fi

  local -a selected=()
  if [[ "$selected_all" == "true" ]]; then
    selected=("${COMPONENTS[@]}")
  else
    local component
    for component in "${requested[@]}"; do
      if ! component_is_known "$component"; then
        printf 'Error: unknown component: %s\n' "$component" >&2
        printf 'Run "./setup-linux.sh list" to see available components.\n' >&2
        return 66
      fi
      selected+=("$component")
    done
  fi

  local component
  for component in "${selected[@]}"; do
    run_component "$command" "$component" "$dry_run" "$force" "$selected_all"
  done
}

main "$@"
