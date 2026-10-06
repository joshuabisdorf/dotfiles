#!/usr/bin/env bash
set -euo pipefail

readonly MANAGED_MARKER='joshuabisdorf/dotfiles:vscode-settings'

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

# target_is_managed
# Requires:
#   - $1 names a marker file path.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether a marker file identifies a VS Code settings file managed by this repo.
# Inputs:
#   - $1: marker file path.
# Outputs:
#   - Exit status 0 when managed; 1 otherwise.
target_is_managed() {
  local marker="$1"
  [[ -r "$marker" ]] || return 1

  local marker_id
  IFS= read -r marker_id < "$marker"
  [[ "$marker_id" == "$MANAGED_MARKER" ]]
}

# main
# Requires:
#   - settings.json exists beside this script.
#   - HOME is set.
# Modifies:
#   - VS Code user settings and an adjacent ownership marker unless dry-run is enabled.
# Effects:
#   - Installs or removes the repo's canonical VS Code user settings.
# Inputs:
#   - Optional --dry-run, --uninstall, and --force flags.
# Outputs:
#   - Status or error messages on standard output/standard error.
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

  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  local source_file="$script_dir/settings.json"
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local target_file="$config_home/Code/User/settings.json"
  local marker_file="${target_file}.dotfiles-managed"

  if [[ "$uninstall" == "true" ]]; then
    if [[ ! -e "$target_file" && ! -e "$marker_file" ]]; then
      printf 'VS Code settings are not installed by this repo.\n'
      return 0
    fi

    if ! target_is_managed "$marker_file"; then
      printf 'Error: refusing to remove unmanaged VS Code settings: %s\n' "$target_file" >&2
      return 73
    fi

    if [[ "$dry_run" == "true" ]]; then
      printf 'Would remove managed VS Code settings: %s\n' "$target_file"
      return 0
    fi

    rm -f -- "$target_file" "$marker_file"
    printf 'Removed managed VS Code settings: %s\n' "$target_file"
    return 0
  fi

  if [[ ! -r "$source_file" ]]; then
    printf 'Error: VS Code settings source not found: %s\n' "$source_file" >&2
    return 66
  fi

  if [[ -e "$target_file" ]] && ! target_is_managed "$marker_file" && [[ "$force" != "true" ]]; then
    printf 'Error: refusing to overwrite unmanaged VS Code settings: %s\n' "$target_file" >&2
    printf 'Re-run with --force to adopt this settings file.\n' >&2
    return 73
  fi

  if [[ "$dry_run" == "true" ]]; then
    printf 'Would install VS Code settings: %s -> %s\n' "$source_file" "$target_file"
    return 0
  fi

  mkdir -p -- "$(dirname -- "$target_file")"
  cp -- "$source_file" "$target_file"
  {
    printf '%s\n' "$MANAGED_MARKER"
    printf '%s\n' "$source_file"
  } > "$marker_file"

  printf 'Installed VS Code settings: %s\n' "$target_file"
}

main "$@"
