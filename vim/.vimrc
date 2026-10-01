" Portable Vim defaults for quick CLI editing.

set nocompatible

filetype plugin indent on
syntax enable

set number
set showcmd
set wildmenu
set backspace=indent,eol,start

" Four spaces are the baseline; filetype indentation may override specifics.
set autoindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" Friendly incremental search.
set ignorecase
set smartcase
set incsearch
set hlsearch

" Predictable window behavior.
set splitbelow
set splitright
set scrolloff=3

" Allow machine-specific overrides without tracking them.
if filereadable(expand('~/.vimrc.local'))
  execute 'source' fnameescape(expand('~/.vimrc.local'))
endif
