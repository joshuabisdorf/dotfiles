# dotfiles

Portable user configuration for a consistent development environment across Linux, WSL, and Windows where applicable.

## Goals

- Keep user configuration version-controlled.
- Make several computers behave consistently without provisioning the operating system.
- Prefer portable, understandable defaults over large frameworks.
- Keep personal, machine-specific, and secret values outside the repository.
- Make installation, dry runs, updates, and removal explicit and reversible.

## Top-level setup

The repository has two top-level entry points.

Linux:

```sh
./setup.sh
```

Windows PowerShell:

```powershell
.\setup.ps1
```

Both support a dry run and uninstall:

```sh
./setup.sh --dry-run
./setup.sh --uninstall
```

```powershell
.\setup.ps1 -DryRun
.\setup.ps1 -Uninstall
```

When an existing VS Code settings file, Windows Terminal settings file, or PowerShell profile is not already managed by this repository, setup refuses to overwrite it. Use `--force` or `-Force` to explicitly adopt that file.

The setup commands configure applications that are already installed. They do not install Git, Bash, GNU Stow, Vim, PowerShell, VS Code, Windows Terminal, or operating-system packages.

### WSL

Run `./setup.sh` inside WSL for the Unix environment. VS Code desktop settings are intentionally skipped there because normal VS Code user settings live on the Windows side. Run `.\setup.ps1` from Windows to configure Windows-side VS Code, PowerShell, and Windows Terminal.

## GNU Stow packages

GNU Stow manages Unix-style dotfiles:

```text
dotfiles/
├── git/
│   └── .gitconfig
├── bash/
│   └── .bashrc
├── readline/
│   └── .inputrc
└── vim/
    └── .vimrc
```

The managed package list lives in `stow-packages.txt`.

Install every Stow package:

```sh
./install.sh --all
```

Install selected packages:

```sh
./install.sh git bash readline vim
```

Preview an operation without changing the home directory:

```sh
./install.sh --dry-run --all
```

Remove managed links:

```sh
./install.sh --uninstall --all
./install.sh --uninstall git bash
```

Stow creates symlinks in the home directory, for example:

```text
~/.gitconfig -> ~/dotfiles/git/.gitconfig
~/.bashrc    -> ~/dotfiles/bash/.bashrc
~/.inputrc   -> ~/dotfiles/readline/.inputrc
~/.vimrc     -> ~/dotfiles/vim/.vimrc
```

## Git

Portable Git defaults include:

- new repositories use `main`;
- `git pull` rebases rather than creating a merge commit;
- fetches prune stale remote-tracking references;
- the first push of a new branch automatically sets its upstream;
- `git lg` shows a compact decorated commit graph;
- `~/.gitconfig.local` is included for identity and machine-specific settings.

Example local identity:

```ini
[user]
    name = Your Name
    email = you@example.com
```

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
├── extensions.txt
├── install-settings.sh
├── install-settings.ps1
├── install-extensions.sh
└── install-extensions.ps1
```

The C/C++ Themes extension labels the selected theme in the GUI as `Dark (Visual Studio - C/C++)`. VS Code stores that selection in `settings.json` as:

```json
"workbench.colorTheme": "Visual Studio Dark - C++"
```

The settings installer uses the normal user-settings locations:

- Linux: `~/.config/Code/User/settings.json` unless `XDG_CONFIG_HOME` overrides it;
- Windows: `%APPDATA%\Code\User\settings.json`.

Settings are copied from the repository and accompanied by a small ownership marker. Subsequent setup runs may update managed settings. An unmanaged existing settings file is not overwritten unless force is explicitly requested.

Extensions are installed from `extensions.txt` through the `code` CLI and can also be removed by the uninstall operation.

## PowerShell

Portable PowerShell configuration lives in:

```text
powershell/
├── profile.ps1
└── install.ps1
```

The installer manages the Current User/All Hosts PowerShell profile. The installed profile is a small shim that dot-sources the repository's `powershell/profile.ps1`, so changes in the repository take effect without copying the profile again.

The profile configures PSReadLine with:

- 10,000 history entries;
- duplicate suppression during recall;
- Up/Down prefix history search.

Machine-specific PowerShell configuration can live in `profile.local.ps1` beside the user's Current User/All Hosts profile.

## Windows Terminal

Windows Terminal configuration lives in:

```text
windows-terminal/
├── settings.json
└── install.ps1
```

The baseline keeps Windows Terminal close to a conventional Unix terminal while remaining native to Windows:

- PowerShell 7's `PowerShell` profile is the default profile;
- Cascadia Mono at 12 points with normal weight;
- the built-in Campbell dark color scheme;
- a filled block cursor;
- 8-pixel terminal padding;
- a fully opaque background with acrylic disabled;
- plain-text clipboard copying;
- 10,000 lines of scrollback history for every profile.

No global `startingDirectory` is set. PowerShell therefore keeps its normal Windows user-home start location, while WSL and other shells remain free to use their own native home-directory behavior.

The installer supports the stable packaged Windows Terminal settings location and the normal unpackaged location. It uses the same ownership-marker model as the VS Code settings installer and refuses to overwrite unmanaged settings without `-Force`.

## Installation

Prerequisites for the Stow-managed Unix configuration:

- Git
- Bash
- GNU Stow

Clone the repository:

```sh
git clone git@github.com:joshuabisdorf/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Then run the appropriate top-level setup command.

## CI

CI validates the repository on both Linux and Windows.

Linux validation covers Bash syntax, ShellCheck, Git and Vim configuration, strict JSON settings, Stow dry-run behavior, install/uninstall round trips, and the top-level setup dry run.

Windows validation parses every PowerShell script, validates JSON settings, and runs the Windows top-level setup in dry-run mode.

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
