# dotfiles

Personal configuration files for my development environment.

## Goals

- Keep development configuration version-controlled.
- Make setting up a new machine reproducible.
- Keep configuration organized and understandable.
- Separate portable configuration from machine-specific settings.
- Never commit credentials, private keys, tokens, or other secrets.

## Management

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) to manage symlinks.

Each top-level configuration directory is a Stow package whose contents mirror their paths relative to the home directory.

For example:

```text
dotfiles/
├── git/
│   └── .gitconfig
├── shell/
│   └── .bashrc
└── nvim/
    └── .config/
        └── nvim/
            └── init.lua
```

Stowing the `git` package creates:

```text
~/.gitconfig -> ~/dotfiles/git/.gitconfig
```

## Installation

GNU Stow must already be installed.

Clone the repository:

```sh
git clone git@github.com:joshuabisdorf/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Install one or more packages by name:

```sh
./install.sh git shell
```

The install script only operates on explicitly named packages.

## Security

This repository must not contain secrets.

Examples of files and values that should remain outside version control include:

- SSH private keys
- API keys and access tokens
- passwords and credentials
- `.env` files containing secrets
- machine-specific secrets
- authentication cookies or sessions
- private certificates

Machine-specific or sensitive configuration should be stored separately and referenced by the tracked configuration where appropriate.

## Security

Do not commit credentials, private keys, access tokens, or other secrets.

See [`.github/SECURITY.md`](.github/SECURITY.md) for vulnerability reporting guidance.

## License

This repository is released under the [Zero-Clause BSD (0BSD) license](LICENSE).

You may use, copy, modify, and redistribute the contents for any purpose, with or without fee. Attribution is not required.
