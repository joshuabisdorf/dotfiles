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

Current package layout:

```text
dotfiles/
└── git/
    └── .gitconfig
```

Stowing the `git` package creates:

```text
~/.gitconfig -> ~/dotfiles/git/.gitconfig
```

## Git Configuration

The tracked Git configuration contains portable settings only.

Machine-specific or personal Git settings belong in:

```text
~/.gitconfig.local
```

The tracked `~/.gitconfig` includes that file when present.

For example:

```ini
[user]
    name = Your Name
    email = you@example.com
```

The current tracked Git configuration:

- sets the default initial branch name to `main`;
- includes `~/.gitconfig.local` for identity and machine-specific settings.

## Installation

GNU Stow and Git must already be installed.

Clone the repository:

```sh
git clone git@github.com:joshuabisdorf/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Install the Git package:

```sh
./install.sh git
```

The install script only operates on explicitly named packages.

## Security

Do not commit credentials, private keys, access tokens, or other secrets.

Examples of files and values that should remain outside version control include:

- SSH private keys
- API keys and access tokens
- passwords and credentials
- `.env` files containing secrets
- machine-specific secrets
- authentication cookies or sessions
- private certificates
- personal Git identity stored in `~/.gitconfig.local`

Machine-specific or sensitive configuration should be stored separately and referenced by tracked configuration where appropriate.

See [`.github/SECURITY.md`](.github/SECURITY.md) for vulnerability reporting guidance.

## License

This repository is released under the [Zero-Clause BSD (0BSD) license](LICENSE).

You may use, copy, modify, and redistribute the contents for any purpose, with or without fee. Attribution is not required.
