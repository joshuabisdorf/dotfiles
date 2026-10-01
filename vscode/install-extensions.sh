#!/usr/bin/env bash
set -euo pipefail

# main
# Requires:
#   - Visual Studio Code's "code" CLI is installed and available on PATH.
#   - extensions.txt exists beside this script.
# Modifies:
#   - The current VS Code installation's extension set.
# Effects:
#   - Installs or updates each extension listed in extensions.txt.
# Inputs:
#   - None.
# Outputs:
#   - VS Code extension installation status on standard output.
main() {
  if ! command -v code >/dev/null 2>&1; then
    printf 'Error: VS Code CLI "code" is not available on PATH.\n' >&2
    exit 69
  fi

  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  local extension
  while IFS= read -r extension || [[ -n "$extension" ]]; do
    if [[ -z "$extension" || "$extension" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    printf 'Installing VS Code extension %s...\n' "$extension"
    code --install-extension "$extension"
  done < "$script_dir/extensions.txt"
}

main "$@"
