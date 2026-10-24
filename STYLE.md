# Documentation and code style

This repository uses the documentation conventions native to its scripting
languages rather than the former custom Requires/Modifies/Effects/Inputs/Outputs
(RMEIO) blocks. Keep documentation close to the function or configuration it
explains; do not add redundant comments to obvious settings.

## PowerShell: comment-based help

Use PowerShell's built-in **comment-based help** for functions in
`setup-windows.ps1` and `powershell/profile.ps1`. Keep a concise
`.SYNOPSIS` and add only applicable sections:

- `.DESCRIPTION` for state changes, invariants, or error handling.
- `.PARAMETER Name` for meaningful user-facing or helper arguments.
- `.OUTPUTS` where the function returns a value rather than only writing status.
- `.EXAMPLE` for non-obvious public usage, when applicable.

```powershell
<#
.SYNOPSIS
    Check whether a sidecar file belongs to this repository.
.PARAMETER Path
    Path to the marker file.
.PARAMETER MarkerId
    Expected first-line ownership identifier.
.OUTPUTS
    System.Boolean - Whether the marker matches.
#>
function Test-ManagedMarker {
    param(
        [string]$Path,
        [string]$MarkerId
    )
    # ...
}
```

PowerShell's built-in help can be inspected with `Get-Help
Test-ManagedMarker -Full` after loading the function in a suitable context.
Document side effects and requirements in `.DESCRIPTION`, not separate
project-specific contract headings. The example above illustrates the format;
the actual function declaration includes mandatory parameter attributes.

## Bash: ShellCheck-friendly function comments

Use short comments immediately above non-obvious functions in `setup-linux.sh`
and `bash/.bashrc`. Explain positional arguments (`$1`, `$2`, etc.),
significant exit statuses, and safety-critical side effects where applicable.

```bash
# Check whether a component uses GNU Stow.
# Arg: $1 - Component name.
# Behavior: Returns 0 for Stow-managed components; 1 otherwise.
component_uses_stow() {
  # ...
}
```

Preserve the ShellCheck directives already present in the scripts. Avoid
RMEIO labels and needless boilerplate such as 'Modifies: Nothing' or 'Inputs:
None'. Do not add nonportable syntax to make comments look uniform.

## Configuration formats

- **Git INI, Readline, Vim:** explain policy choices or machine-local override
  entry points with the format's native comment syntax.
- **JSON:** keep application settings strict JSON; document them in the README
  rather than introducing unsupported comments.
- **Extension manifests:** keep one extension ID per line, with explanatory
  comment lines beginning with `#`.
- **GitHub Actions:** retain explicit permissions, minimal privileges, and
  pinned third-party action commit SHAs.

## Verification

Run the relevant existing checks before requesting review:

```sh
bash -n setup-linux.sh bash/.bashrc
shellcheck setup-linux.sh bash/.bashrc
./setup-linux.sh list
./setup-linux.sh install --all --dry-run
```

On Windows, validate PowerShell parsing and run the documented all-components
dry run. The GitHub Actions workflow is the authority for cross-platform
checks; it performs additional Git, Vim, JSON, PowerShell, and setup lifecycle
tests. Documentation changes should not alter executable behavior.
