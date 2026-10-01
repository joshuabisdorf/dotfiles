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
  printf 'Usage: %s <package> [package ...]\n' "$0"
}

# main
# Requires:
#   - GNU Stow is installed and available on PATH.
#   - Each package argument names an existing top-level directory in this repo.
# Modifies:
#   - Symlinks under the current user's home directory.
# Effects:
#   - Creates or updates GNU Stow-managed symlinks for each requested package.
# Inputs:
#   - One or more package names as positional arguments.
# Outputs:
#   - Status messages on standard output.
main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 64
  fi

  if ! command -v stow >/dev/null 2>&1; then
    printf 'Error: GNU Stow is not installed or not available on PATH.\n' >&2
    exit 69
  fi

  local repo_dir
  repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  local package
  for package in "$@"; do
    if [[ "$package" == .* || "$package" == */* || ! -d "$repo_dir/$package" ]]; then
      printf 'Error: invalid package: %s\n' "$package" >&2
      exit 66
    fi

    printf 'Stowing %s...\n' "$package"
    stow --dir="$repo_dir" --target="$HOME" --restow "$package"
  done
}

main "$@"
