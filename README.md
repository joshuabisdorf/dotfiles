# dotfiles

Personal configuration files for my development environment.

## Goals

- Keep development configuration version-controlled.
- Make setting up a new machine reproducible.
- Keep configuration organized and understandable.
- Separate portable configuration from machine-specific settings.
- Never commit credentials, private keys, tokens, or other secrets.

## Structure

The repository structure will evolve as configurations are added.

Planned areas include:

```text
dotfiles/
├── git/
├── shell/
├── ssh/
├── tmux/
├── vim/
├── nvim/
├── scripts/
└── install.sh
```

## Installation

Installation and bootstrap instructions will be added once the configuration-management approach is finalized.

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