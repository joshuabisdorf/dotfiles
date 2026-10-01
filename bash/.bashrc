# shellcheck shell=bash
# shellcheck disable=SC1091
# ~/.bashrc: portable interactive Bash configuration.

# Stop here for non-interactive shells.
case $- in
  *i*) ;;
  *) return ;;
esac

# Keep useful history without suppressing commands that begin with a space.
HISTCONTROL=ignoredups:erasedups
HISTSIZE=10000
HISTFILESIZE=10000
shopt -s histappend
shopt -s checkwinsize

# Share newly entered history between concurrently running interactive shells.
if [[ "${PROMPT_COMMAND:-}" != *"history -a; history -n"* ]]; then
  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"
  else
    PROMPT_COMMAND="history -a; history -n"
  fi
fi

# Load programmable completion when the host provides it.
if ! shopt -oq posix; then
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck source=/usr/share/bash-completion/bash_completion
    . /usr/share/bash-completion/bash_completion
  elif [[ -r /etc/bash_completion ]]; then
    # shellcheck source=/etc/bash_completion
    . /etc/bash_completion
  fi
fi

# __dotfiles_git_context
# Requires:
#   - An interactive Bash shell.
#   - Git on PATH to display repository context; otherwise it returns silently.
# Modifies:
#   - Nothing.
# Effects:
#   - Inspects the current directory for a Git branch or detached HEAD.
# Inputs:
#   - The shell's current working directory.
# Outputs:
#   - " (branch)" or " (@commit)" on standard output when inside a Git repository.
__dotfiles_git_context() {
  command -v git >/dev/null 2>&1 || return 0

  local ref
  if ref="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    printf ' (%s)' "$ref"
    return 0
  fi

  if ref="$(git rev-parse --short HEAD 2>/dev/null)"; then
    printf ' (@%s)' "$ref"
  fi
}

# Keep the prompt familiar while adding restrained color and Git context.
# shellcheck disable=SC2016
if [[ -t 1 ]]; then
  PS1='\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w\[\033[01;35m\]$(__dotfiles_git_context)\[\033[00m\] \$ '
else
  PS1='\u@\h \w$(__dotfiles_git_context) \$ '
fi

# Machine-specific interactive shell settings can live outside this repository.
if [[ -r "$HOME/.bashrc.local" ]]; then
  # shellcheck source=/dev/null
  . "$HOME/.bashrc.local"
fi
