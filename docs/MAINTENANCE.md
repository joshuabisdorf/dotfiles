# Maintenance and recovery

This guide describes the setup interface, target paths, ownership model, and
recovery procedures. For installation examples and application configuration
defaults, see the [README](../README.md).

## Component ownership model

| Platform | Component | Destination | Management |
| --- | --- | --- | --- |
| Linux / WSL | `git` | `~/.gitconfig` | GNU Stow symlink |
| Linux / WSL | `bash` | `~/.bashrc` | GNU Stow symlink |
| Linux / WSL | `readline` | `~/.inputrc` | GNU Stow symlink |
| Linux / WSL | `vim` | `~/.vimrc` | GNU Stow symlink |
| Native Linux | `vscode` settings | `${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json` | Managed copy and sidecar |
| Native Linux | `vscode` clang-format | `~/.clang-format` | Managed copy and sidecar |
| Windows | `git` | `$HOME/.gitconfig` | Managed copy and sidecar |
| Windows | `powershell` | `$PROFILE.CurrentUserAllHosts` | Managed dot-sourcing shim |
| Windows | `vscode` settings | `$env:APPDATA\Code\User\settings.json` | Managed copy and sidecar |
| Windows | `vscode` clang-format | `$HOME\.clang-format` | Managed copy and sidecar |
| Windows | `terminal` | Windows Terminal user `settings.json` | Managed copy and sidecar |

The Windows Terminal settings path is selected from the existing packaged or
unpackaged user-data directory, preferring the packaged directory. The setup
script uses a packaged path by default if neither exists.

The managed `.clang-format` uses the home directory as its installation
location. It applies to source files in projects beneath that directory
unless a closer project `.clang-format` overrides it. Files outside the
home directory require a local configuration file or an explicit path.

VS Code extension IDs come from `vscode/extensions.txt` on both supported
desktop platforms. They are installed or removed using the `code` CLI, **not**
tracked using sidecars.

Under WSL, the Linux entry point manages the Unix-side Git, Bash, Readline, and
Vim files; it does not manage Windows-side VS Code. Use the native Windows
script to manage Windows VS Code and Windows Terminal.

## Installation and reapplication

Both setup scripts expose `list`, `install`, `reinstall`, and `uninstall`.
Mutating operations require explicit components or the all-components selector.

```sh
./setup-linux.sh list
./setup-linux.sh install git bash readline vim --dry-run
./setup-linux.sh install git bash readline vim
./setup-linux.sh reinstall git bash
./setup-linux.sh uninstall readline --dry-run
```

```powershell
.\setup-windows.ps1 list
.\setup-windows.ps1 install git powershell -DryRun
.\setup-windows.ps1 install git powershell
.\setup-windows.ps1 reinstall vscode terminal
.\setup-windows.ps1 uninstall terminal -DryRun
```

On Linux, Stow links files directly into the home directory. Editing the
version-controlled source updates linked configuration immediately. `reinstall`
uses Stow's `--restow` action; it is generally needed when links themselves
change or need to be recreated. Stow detects link conflicts and does not
automatically overwrite unrelated existing files.

Copied settings require `reinstall` after editing repository source files.
The Windows PowerShell shim instead dot-sources `powershell/profile.ps1`;
changes take effect the next time that profile is loaded. Use
`profile.local.ps1` beside the Current User/All Hosts profile for private
local overrides.

## Safety and backup policy

1. **Preview changes first.** `--dry-run` (Linux) and `-DryRun` (Windows)
   report intended setup actions without writing managed files.
2. **Preserve existing configuration.** Before adoption, copy existing
   settings to a private backup outside the repository. The scripts do not
   back up files for you.
3. **Use force selectively.** `--force` / `-Force` applies to adopting
   unmanaged copied settings and the PowerShell profile shim. It does not
   suppress GNU Stow's link-conflict checks.
4. **Do not manually forge or remove ownership markers.** Copied targets have
   a `.dotfiles-managed` sidecar containing the repository identifier and
   source path. An uninstall verifies that marker before deleting a target.
   A marked file is treated as managed even if you subsequently edited it.
5. **Review extension removal.** Uninstalling the `vscode` component
   processes every extension ID in the manifest, including IDs installed
   independently before running these scripts. Extension installation is not
   ownership-tracked.
6. **Avoid storing secrets here.** Place user identity in
   `~/.gitconfig.local`, Bash machine-specific settings in
   `~/.bashrc.local`, Vim overrides in `~/.vimrc.local`, and PowerShell
   overrides in `profile.local.ps1`. See the
   [security policy](../.github/SECURITY.md).

`uninstall` refuses to remove unmanaged copied files or profile shims and
does not accept the force flag. It removes Stow-managed links, not unrelated
files at the same path. Operations are per component; if a later component
fails, earlier operations may already have completed.

## Troubleshooting

### GNU Stow reports a conflict

A target such as `~/.bashrc` is already present and is not a managed Stow
symlink. Back it up or move it, verify its content, and retry the component.
Do not expect the Linux force flag to override this safety check.

### A copied settings file is rejected as unmanaged

The target exists without the correct ownership marker. Inspect and save it
before explicitly re-running the desired install/reinstall with force.
Do **not** use force when you want to keep the unmanaged settings unchanged.

### VS Code cannot be configured

Desktop VS Code requires the `code` CLI on `PATH` for extension installation.
Use the Windows entry point under WSL, or omit `vscode` if the application
is not installed. Linux and Windows may handle an unavailable `code` CLI
differently during removal; use a dry run and the platform's CLI status.

### PowerShell profile changes do not appear

Verify you are using PowerShell 7 and that the Current User/All Hosts profile
is the marked shim pointing to this repository. The shim must be reloaded
(or a new terminal started) for edited source settings to take effect. If you
relocate the repository, reinstall the managed shim to update its source path.

### Git identity is missing

Provide your private `user.name` and `user.email` in
`~/.gitconfig.local`. The version-controlled Git defaults include that
file but deliberately do not store a personal identity.

## Verification and change review

The GitHub Actions workflow validates Bash syntax and ShellCheck, Git and Vim
configuration, JSON settings, Stow install/reinstall/uninstall, CLI selectors,
PowerShell parser correctness, PSReadLine and prompt defaults, terminal
configuration, and Windows dry-run behavior.

For a documentation-only change, review the diff and confirm there are no
changes to executable statements or user settings. For a behavioral change,
also test the relevant component's install/reinstall/uninstall path on the
target operating system with a disposable home/configuration directory.

See [STYLE.md](../STYLE.md) for PowerShell comment-based help and Bash
comment conventions.
