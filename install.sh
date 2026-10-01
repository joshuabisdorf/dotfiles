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
  printf 'Usage: %s --all | <package> [package ...]\n' "$0"
}

# package_is_managed
# Requires:
#   - A package name followed by zero or more managed package names.
# Modifies:
#   - Nothing.
# Effects:
#   - Tests whether the requested package is present in the managed package list.
# Inputs:
#   - $1: requested package name.
#   - Remaining arguments: managed package names.
# Outputs:
#   - Exit status 0 when managed; 1 otherwise.
package_is_managed() {
  local requested="$1"
  shift

  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$requested" ]]; then
      return 0
    fi
  done

  return 1
}

# stow_package
# Requires:
#   - GNU Stow is installed and available on PATH.
#   - The requested package is an existing managed Stow package.
# Modifies:
#   - Symlinks beneath the target home directory.
# Effects:
#   - Restows one package into the target home directory.
# Inputs:
#   - $1: repository directory.
#   - $2: target home directory.
#   - $3: package name.
# Outputs:
#   - A status message on standard output.
stow_package() {
  local repo_dir="$1"
  local target_home="$2"
  local package="$3"

  printf 'Stowing %s...\n' "$package"
  stow --dir="$repo_dir" --target="$target_home" --restow "$package"
}

# main
# Requires:
#   - GNU Stow is installed and available on PATH.
#   - stow-packages.txt exists beside this script.
# Modifies:
#   - Symlinks beneath the current user's home directory.
# Effects:
#   - Restows either all managed packages or explicitly requested packages.
# Inputs:
#   - --all, or one or more managed package names as positional arguments.
# Outputs:
#   - Status or error messages on standard output/standard error.
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

  local manifest="$repo_dir/stow-packages.txt"
  if [[ ! -r "$manifest" ]]; then
    printf 'Error: package manifest not found: %s\n' "$manifest" >&2
    exit 66
  fi

  local -a managed_packages
  mapfile -t managed_packages < <(grep -Ev '^[[:space:]]*(#|$)' "$manifest")

  local -a selected_packages
  if [[ "$1" == "--all" ]]; then
    if [[ $# -ne 1 ]]; then
      printf 'Error: --all cannot be combined with package names.\n' >&2
      exit 64
    fi
    selected_packages=("${managed_packages[@]}")
  else
    selected_packages=("$@")
  fi

  local package
  for package in "${selected_packages[@]}"; do
    if [[ "$package" == .* || "$package" == */* ]] ||
       ! package_is_managed "$package" "${managed_packages[@]}" ||
       [[ ! -d "$repo_dir/$package" ]]; then
      printf 'Error: unmanaged or invalid package: %s\n' "$package" >&2
      exit 66
    fi

    stow_package "$repo_dir" "$HOME" "$package"
  done
}

main "$@"
