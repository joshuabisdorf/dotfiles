# dotfiles

Portable user configuration for a consistent development environment across Linux, WSL, and Windows where applicable.

## Goals

- Keep user configuration version-controlled.
- Make several computers behave consistently without provisioning the operating system.
- Prefer portable, understandable defaults over large frameworks.
- Keep personal, machine-specific, and secret values outside the repository.
- Keep the setup interface small: one entry point for Linux/WSL and one for Windows.
- Make installation, reinstallation, dry runs, and removal explicit and reversible.

## Setup interface

There are exactly two setup entry points:

- Linux / WSL: `./setup-linux.sh`
- Windows: `.\setup-windows.ps1`

All component-specific setup logic lives inside those two scripts. Configuration directories contain configuration, not separate installer commands.

### Linux / WSL

List available components:

```sh
./setup-linux.sh list
```

Install everything applicable:

```sh
./setup-linux.sh install --all
```

Install selected components:

```sh
./setup-linux.sh install git bash readline vim
```

Reapply repository configuration after changes:

```sh
./setup-linux.sh reinstall --all
```

Preview without changing anything:

```sh
./setup-linux.sh reinstall --all --dry-run
```

Remove selected managed configuration:

```sh
./setup-linux.sh uninstall git bash
```

Available Linux components are:

- `git`: Git user configuration through GNU Stow;
- `bash`: interactive Bash configuration through GNU Stow;
- `readline`: Readline key bindings through GNU Stow;
- `vim`: Vim configuration through GNU Stow;
- `vscode`: VS Code settings and extensions on desktop Linux.

Use `--all` to select every Linux component. It is a selector flag, not a component name.

Under WSL, Windows-side VS Code configuration is intentionally left to the Windows setup entry point.

### Windows

Run setup from PowerShell 7.

List available components:

```powershell
.\setup-windows.ps1 list
```

Install everything:

```powershell
.\setup-windows.ps1 install -All
```

Install selected components:

```powershell
.\setup-windows.ps1 install git powershell
```

Reapply repository configuration after changes:

```powershell
.\setup-windows.ps1 reinstall -All
```

Preview without changing anything:

```powershell
.\setup-windows.ps1 reinstall -All -DryRun
```

Remove selected managed configuration:

```powershell
.\setup-windows.ps1 uninstall vscode terminal
```

Available Windows components are:

- `git`: shared Git user configuration;
- `powershell`: PowerShell 7 Current User/All Hosts profile;
- `vscode`: VS Code settings and extensions;
- `terminal`: Windows Terminal settings.

Use `-All` to select every Windows component. `--all` is also accepted for symmetry with Linux. The selector is not a component name.

Use `-Force` on Windows or `--force` on Linux when explicitly adopting an existing unmanaged copied/profile configuration. Setup otherwise refuses to overwrite unrelated user files.

## Install vs. reinstall

`install` is for initial setup. Managed copied/profile files that are already installed are left alone. Use `--all` on Linux or `-All` on Windows to select every component.

`reinstall` reapplies the repository's current configuration. This is the normal command after changing a copied configuration or pulling such changes from Git.

On Linux, GNU Stow components use `--stow` for install and `--restow` for reinstall. Because Stow creates symlinks, edits to existing linked configuration files are already visible immediately.

On Windows, Git, VS Code, and Windows Terminal configuration is copied into the applications' normal user locations and tracked with small sidecar ownership markers, so `reinstall` refreshes those copies. The PowerShell profile itself is a small managed shim that dot-sources the repository profile directly.

## Git

Portable Git defaults include:

- new repositories use `main`;
- `git pull` rebases rather than creating a merge commit;
- fetches prune stale remote-tracking references;
- the first push of a new branch automatically sets its upstream;
- `git lg` shows a compact decorated commit graph;
- `~/.gitconfig.local` is included for identity and machine-specific settings.

On Linux/WSL, `git/.gitconfig` is linked to `~/.gitconfig` with GNU Stow. On Windows, `setup-windows.ps1` copies the same file to `~/.gitconfig` and tracks ownership with `~/.gitconfig.dotfiles-managed`.

Keep personal identity outside the repository:

```ini
[user]
    name = Your Name
    email = you@example.com
```

Save that as `~/.gitconfig.local`.

If Windows already has an unmanaged `~/.gitconfig`, review it before using `-Force`; move personal settings you want to retain into `~/.gitconfig.local`.

## Bash and Readline

Bash keeps 10,000 history entries, suppresses duplicate history during recall, appends history instead of overwriting it, and exchanges newly entered history between concurrent interactive shells.

Up and Down search backward and forward through history using the text already typed at the prompt.

When Bash completion is installed by the host system, it is loaded automatically.

The prompt remains close to the traditional `user@host path $` form while adding restrained color and the current Git branch or detached commit.

Machine-specific interactive settings can live in `~/.bashrc.local`.

## Vim

Vim is configured as a lightweight CLI editor rather than an IDE.

Defaults include:

- line numbers;
- spaces instead of tabs;
- two-space indentation as the baseline;
- filetype plugins and indentation;
- incremental, highlighted, smart-case search;
- predictable split placement;
- a small scroll margin.

Machine-specific overrides can live in `~/.vimrc.local`.

## Visual Studio Code

VS Code configuration lives in:

```text
vscode/
├── settings.json
└── extensions.txt
```

The C/C++ Themes extension labels the selected theme in the GUI as `Dark (Visual Studio - C/C++)`. VS Code stores that selection in `settings.json` as:

```json
"workbench.colorTheme": "Visual Studio Dark - C++"
```

The setup entry points treat VS Code as one component: user settings plus extensions.

Settings use the normal user locations:

- Linux: `~/.config/Code/User/settings.json` unless `XDG_CONFIG_HOME` overrides it;
- Windows: `%APPDATA%\Code\User\settings.json`.

Copied settings are accompanied by a small ownership marker. Unmanaged existing settings are not overwritten unless force is explicitly requested.

## PowerShell

Portable PowerShell configuration lives in:

```text
powershell/
└── profile.ps1
```

The Windows setup entry point manages the Current User/All Hosts PowerShell profile as a small shim that dot-sources the repository's `powershell/profile.ps1`.

The profile configures PSReadLine with:

- 10,000 history entries;
- duplicate suppression during recall;
- Up/Down prefix history search;
- Bash-like Tab completion for `cd`/`Set-Location`: directory matching is case-sensitive, avoids an unnecessary `.\\` prefix, and expands the longest unambiguous match;
- normal PowerShell completion remains available for commands, parameters, and other non-directory cases;
- restrained syntax colors for commands, parameters, strings, variables, numbers, comments, and related tokens.

PowerShell file listings use conventional terminal distinctions:

- directories are bright blue;
- executables are bright green;
- symbolic links are cyan;
- PowerShell files are cyan;
- JSON/YAML/TOML/INI files are yellow;
- Markdown files are green;
- common archive formats are red;
- ordinary files keep the terminal's default foreground color.

The PowerShell prompt mirrors the Bash prompt style:

```text
user@host ~/path (branch) >
```

The user/host portion is bright green, the path is bright blue, Git context is bright magenta, home is shortened to `~`, and detached HEADs display as `(@commit)`.

Machine-specific PowerShell configuration can live in `profile.local.ps1` beside the Current User/All Hosts profile.

Native Windows setup requires PowerShell 7 rather than Windows PowerShell 5.1.

## Windows Terminal

Windows Terminal configuration lives in:

```text
windows-terminal/
└── settings.json
```

The baseline keeps Windows Terminal close to a conventional Unix terminal while remaining native to Windows:

- PowerShell 7's generated `PowerShell` profile is explicitly kept visible and set as the default profile;
- Cascadia Mono at 12 points with normal weight;
- the built-in Campbell dark color scheme;
- a filled block cursor;
- 8-pixel terminal padding;
- a fully opaque background with acrylic disabled;
- plain-text clipboard copying;
- 10,000 lines of scrollback history for every profile.

No global `startingDirectory` is set, so each shell keeps its own normal home-directory behavior.

## Installation

The setup scripts configure applications that are already installed; they do not provision the operating system or install applications.

Linux/WSL prerequisites for the core Stow-managed configuration:

- Git
- Bash
- GNU Stow
- Vim, if using the `vim` component

The optional Linux `vscode` component requires VS Code and its `code` CLI.

Windows setup requires PowerShell 7. Git, VS Code, and Windows Terminal should be installed for their respective components.

Clone the repository and inspect available components:

```sh
git clone git@github.com:joshuabisdorf/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup-linux.sh list
```

On Windows:

```powershell
git clone https://github.com/joshuabisdorf/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
.\setup-windows.ps1 list
```

## CI

CI validates both public setup entry points.

Linux validation covers Bash syntax, ShellCheck, Git and Vim configuration, strict JSON settings, component listing, dry runs, Stow install/reinstall/uninstall behavior, and Bash defaults.

Windows validation parses PowerShell, validates JSON settings, checks the component interface, exercises the Windows all-components dry run, and verifies that obsolete component installer scripts are absent.

## Security

Do not commit credentials, private keys, access tokens, or other secrets.

Examples of values that should remain outside version control include:

- SSH private keys;
- API keys and access tokens;
- passwords and credentials;
- secret `.env` files;
- authentication cookies or sessions;
- private certificates;
- personal Git identity in `~/.gitconfig.local`;
- machine-specific shell settings.

See [`.github/SECURITY.md`](.github/SECURITY.md) for vulnerability reporting guidance.

## License

This repository is released under the [Zero-Clause BSD (0BSD) license](LICENSE).

You may use, copy, modify, and redistribute the contents for any purpose, with or without fee. Attribution is not required.
