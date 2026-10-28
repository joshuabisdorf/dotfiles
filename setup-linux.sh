#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly VSCODE_MARKER='joshuabisdorf/dotfiles:vscode-settings'
readonly CLANG_FORMAT_MARKER='joshuabisdorf/dotfiles:clang-format'
readonly -a STOW_COMPONENTS=(git bash readline vim)
readonly -a COMPONENTS=(git bash readline vim vscode)

# Print the setup commands and options.
# Behavior: Prints usage text to stdout.
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

# Detect WSL from /proc/sys/kernel/osrelease.
# Behavior: Returns 0 on WSL and 1 otherwise.
is_wsl() {
  [[ -r /proc/sys/kernel/osrelease ]] &&
    grep -qi 'microsoft' /proc/sys/kernel/osrelease
}

# List available Linux/WSL setup components.
# Behavior: Prints availability notes for VS Code.
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

# Check whether a component name belongs to the public setup interface.
# Arg: $1 - Requested component.
# Behavior: Returns 0 for recognized components and 1 otherwise.
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

# Check whether a component is managed using GNU Stow.
# Arg: $1 - Requested component.
# Behavior: Returns 0 for a Stow-managed component and 1 otherwise.
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

# Check a sidecar file for the expected repository ownership marker.
# Arg: $1 - Path of marker file.
# Arg: $2 - Expected first-line identifier.
# Behavior: Returns 0 for matching marker and 1 otherwise.
marker_is_managed() {
  local marker_file="$1"
  local marker_id="$2"

  [[ -r "$marker_file" ]] || return 1

  local first_line
  IFS= read -r first_line < "$marker_file"
  [[ "$first_line" == "$marker_id" ]]
}

# Install, restow, or remove a GNU Stow component.
# Arg: $1 - Action (install/reinstall/uninstall).
# Arg: $2 - Stow package name.
# Arg: $3 - Dry-run flag (true/false).
# Behavior: Returns Stow's status, 66 if package missing, or 69 if Stow unavailable. Force does not override Stow conflict checks.
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

# Manage a copied settings file with a sidecar ownership marker.
# Arg: $1 - Action.
# Arg: $2 - Source path.
# Arg: $3 - Destination path.
# Arg: $4 - Ownership marker identifier.
# Arg: $5 - Display label.
# Arg: $6 - Dry-run flag.
# Arg: $7 - Force flag.
# Behavior: Refuses unmanaged destinations (73) unless forced on install/reinstall. Does not back up adopted files. Missing source returns 66.
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

# Install, force-reinstall, or remove listed VS Code extensions.
# Arg: $1 - Action.
# Arg: $2 - Dry-run flag.
# Behavior: Reads vscode/extensions.txt. Uninstall removes listed extensions even when they existed before dotfiles. Returns 66 if the manifest is absent or 69 if the code CLI is required but missing.
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

# Manage native Linux VS Code settings and manifest extensions.
# Arg: $1 - Action.
# Arg: $2 - Dry-run flag.
# Arg: $3 - Force flag.
# Behavior: Uses XDG_CONFIG_HOME for settings and installs .clang-format in HOME.
configure_vscode() {
  local action="$1"
  local dry_run="$2"
  local force="$3"
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local target_file="$config_home/Code/User/settings.json"

  configure_managed_copy \
    "$action" "$REPO_DIR/vscode/settings.json" "$target_file" \
    "$VSCODE_MARKER" 'VS Code settings' "$dry_run" "$force"

  configure_managed_copy \
    "$action" "$REPO_DIR/vscode/.clang-format" "$HOME/.clang-format" \
    "$CLANG_FORMAT_MARKER" 'clang-format configuration' "$dry_run" "$force"

  configure_vscode_extensions "$action" "$dry_run"
}

# Dispatch a Linux setup component with platform availability rules.
# Arg: $1 - Action.
# Arg: $2 - Component.
# Arg: $3 - Dry-run flag.
# Arg: $4 - Force flag.
# Arg: $5 - True if the selection was --all.
# Behavior: Under WSL, --all skips Windows-side VS Code; an explicit vscode request fails.
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

# Validate the Linux CLI and apply the requested components.
# Arg: $@ - Command, selected components, and optional flags.
# Behavior: Returns 64 for invalid usage, 66 for unknown components, or the component failure status. Requires a component or --all for mutations.
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
