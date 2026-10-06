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
  printf 'Usage: %s [--dry-run] [--uninstall]\n' "$0"
}

# main
# Requires:
#   - extensions.txt exists beside this script.
#   - VS Code's "code" CLI is available unless dry-run is enabled.
# Modifies:
#   - The current VS Code installation's extension set unless dry-run is enabled.
# Effects:
#   - Installs/updates or removes each extension listed in extensions.txt.
# Inputs:
#   - Optional --dry-run and --uninstall flags.
# Outputs:
#   - VS Code extension status on standard output.
main() {
  local dry_run=false
  local uninstall=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      --uninstall)
        uninstall=true
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

  if [[ "$dry_run" != "true" ]] && ! command -v code >/dev/null 2>&1; then
    printf 'Error: VS Code CLI "code" is not available on PATH.\n' >&2
    return 69
  fi

  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  local extensions_file="$script_dir/extensions.txt"
  if [[ ! -r "$extensions_file" ]]; then
    printf 'Error: extension manifest not found: %s\n' "$extensions_file" >&2
    return 66
  fi

  local installed_extensions=''
  if [[ "$dry_run" != "true" && "$uninstall" == "true" ]]; then
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
      if [[ "$uninstall" == "true" ]]; then
        printf 'Would uninstall VS Code extension %s.\n' "$extension"
      else
        printf 'Would install VS Code extension %s.\n' "$extension"
      fi
      continue
    fi

    if [[ "$uninstall" == "true" ]]; then
      if grep -Fxiq -- "$extension" <<< "$installed_extensions"; then
        printf 'Uninstalling VS Code extension %s...\n' "$extension"
        code --uninstall-extension "$extension"
      else
        printf 'VS Code extension %s is not installed; skipping.\n' "$extension"
      fi
    else
      printf 'Installing VS Code extension %s...\n' "$extension"
      code --install-extension "$extension"
    fi
  done < "$extensions_file"
}

main "$@"
