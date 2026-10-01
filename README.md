# dotfiles

Portable user configuration for a consistent development environment across Linux, WSL, and Windows where applicable.

## Goals

- Keep user configuration version-controlled.
- Make several computers behave consistently without provisioning the operating system.
- Prefer portable, understandable defaults over large frameworks.
- Keep personal, machine-specific, and secret values outside the repository.
- Make setup convenient enough to repeat without making it opaque.

## Managed configuration

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

Or install selected packages:

```sh
./install.sh git bash readline vim
```

Stow creates symlinks in the home directory. For example:

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
- `git lg` shows a compact decorated commit graph;
- `~/.gitconfig.local` is included for identity and machine-specific settings.

Example local identity:

```ini
[user]
    name = Your Name
    email = you@example.com
```

## Bash and Readline

The Bash configuration keeps 10,000 history entries, suppresses duplicate history, appends history instead of overwriting it, and exchanges newly entered history between concurrent interactive shells.

Up and Down search backward and forward through history using the text already typed at the prompt.

When Bash completion is installed by the host system, it is loaded automatically.

The prompt remains close to the traditional `user@host path $` form while adding restrained color and the current Git branch or detached commit.

Machine-specific interactive settings can live in `~/.bashrc.local`.

## Vim

Vim is configured as a lightweight CLI editor rather than an IDE.

Defaults include:

- line numbers;
- four-space indentation as the baseline;
- filetype plugins and indentation;
- incremental, highlighted, smart-case search;
- predictable split placement;
- a small scroll margin.

Machine-specific overrides can live in `~/.vimrc.local`.

## Visual Studio Code

VS Code configuration is stored separately from Stow because the user-settings location differs by platform:

```text
vscode/
├── settings.json
├── extensions.txt
├── install-extensions.sh
└── install-extensions.ps1
```

The preferred theme is `Dark (Visual Studio - C/C++)`, supplied by Microsoft's C/C++ Themes extension. If that theme is unavailable, use the built-in `Dark+` theme until the extension is installed.

Install the tracked extensions on Linux/WSL/Git Bash:

```sh
bash vscode/install-extensions.sh
```

Install them from PowerShell on Windows:

```powershell
.\vscode\install-extensions.ps1
```

The canonical user settings are in `vscode/settings.json`. Apply or link that file to the platform's VS Code user-settings location as appropriate.

Typical locations are:

- Linux: `~/.config/Code/User/settings.json`
- Windows: `%APPDATA%\Code\User\settings.json`
- WSL: desktop user settings normally live on the Windows side; remote-specific settings are separate.

VS Code's CLI supports installing extensions by their `publisher.extension` identifiers, which is what the extension installers use.

## Installation

Prerequisites for the Stow-managed configuration:

- Git
- Bash
- GNU Stow

Clone the repository:

```sh
git clone git@github.com:joshuabisdorf/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Then install the desired packages.

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
- machine-specific shell settings in `~/.bashrc.local`.

See [`.github/SECURITY.md`](.github/SECURITY.md) for vulnerability reporting guidance.

## License

This repository is released under the [Zero-Clause BSD (0BSD) license](LICENSE).

You may use, copy, modify, and redistribute the contents for any purpose, with or without fee. Attribution is not required.
