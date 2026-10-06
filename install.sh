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
  printf 'Usage: %s [--dry-run] [--uninstall] (--all | <package> [package ...])\n' "$0"
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
#   - Symlinks beneath the target home directory unless dry-run is enabled.
# Effects:
#   - Restows or removes one package, optionally simulating the operation.
# Inputs:
#   - $1: repository directory.
#   - $2: target home directory.
#   - $3: package name.
#   - $4: action: restow or delete.
#   - $5: dry-run flag: true or false.
# Outputs:
#   - A status message on standard output and GNU Stow simulation output when applicable.
stow_package() {
  local repo_dir="$1"
  local target_home="$2"
  local package="$3"
  local action="$4"
  local dry_run="$5"
  local suffix=''

  if [[ "$dry_run" == "true" ]]; then
    suffix=' (dry run)'
  fi

  local -a args=(
    "--dir=$repo_dir"
    "--target=$target_home"
  )

  if [[ "$action" == "delete" ]]; then
    printf 'Unstowing %s%s...\n' "$package" "$suffix"
    args+=(--delete)
  else
    printf 'Stowing %s%s...\n' "$package" "$suffix"
    args+=(--restow)
  fi

  if [[ "$dry_run" == "true" ]]; then
    args+=(--simulate)
  fi

  stow "${args[@]}" "$package"
}

# main
# Requires:
#   - GNU Stow is installed and available on PATH.
#   - stow-packages.txt exists beside this script.
# Modifies:
#   - Symlinks beneath the current user's home directory unless dry-run is enabled.
# Effects:
#   - Restows or removes all managed packages or explicitly requested packages.
# Inputs:
#   - Optional --dry-run.
#   - Optional --uninstall or --delete.
#   - --all, or one or more managed package names.
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

  local dry_run=false
  local action=restow
  local install_all=false
  local -a requested_packages=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      --uninstall|--delete)
        action=delete
        ;;
      --all)
        install_all=true
        ;;
      --)
        shift
        requested_packages+=("$@")
        break
        ;;
      -*)
        printf 'Error: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 64
        ;;
      *)
        requested_packages+=("$1")
        ;;
    esac
    shift
  done

  if [[ "$install_all" == "true" && ${#requested_packages[@]} -gt 0 ]]; then
    printf 'Error: --all cannot be combined with package names.\n' >&2
    exit 64
  fi

  if [[ "$install_all" == "false" && ${#requested_packages[@]} -eq 0 ]]; then
    printf 'Error: choose --all or at least one package.\n' >&2
    usage >&2
    exit 64
  fi

  local -a managed_packages
  mapfile -t managed_packages < <(grep -Ev '^[[:space:]]*(#|$)' "$manifest")

  local -a selected_packages
  if [[ "$install_all" == "true" ]]; then
    selected_packages=("${managed_packages[@]}")
  else
    selected_packages=("${requested_packages[@]}")
  fi

  local package
  for package in "${selected_packages[@]}"; do
    if [[ "$package" == .* || "$package" == */* ]] ||
       ! package_is_managed "$package" "${managed_packages[@]}" ||
       [[ ! -d "$repo_dir/$package" ]]; then
      printf 'Error: unmanaged or invalid package: %s\n' "$package" >&2
      exit 66
    fi

    stow_package "$repo_dir" "$HOME" "$package" "$action" "$dry_run"
  done
}

main "$@"
