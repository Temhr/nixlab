# aliases/files.sh — file management, listing, and viewing

# Safer file operations (prompt before overwrite/delete)
alias cp='cp -iv'
alias mv='mv -iv'
alias ln='ln -i'
alias mkdir='mkdir -pv'
alias rm='rm -I --preserve-root'      # prompt if deleting 3+ files; never touch /
alias rmd='rm -r -i'                  # recursive delete with per-file confirmation

# Protect against accidental permission changes on /
alias chgrp='chgrp --preserve-root'
alias chmod='chmod -c --preserve-root'
alias chown='chown --preserve-root'

# Listing variants
alias l='ls -lah --color=auto'
alias l.='ls -lhFa --time-style=long-iso --color=auto'
alias la='ls -A --color=auto'
alias ll='ls -lhF --color=auto'
alias lS='ls -lSh --color=auto'       # sort by size
alias ls='ls -la --color=auto'
alias lt='ls -lt --color=auto'        # sort by time
alias ltr='ls -ltr --color=auto'      # sort by time, oldest first
alias tree='tree -C'                  # colourised tree view

# Archive helpers (extract() function is in bash_functions)
alias targz='tar -czvf'
alias untar='tar -xvf'
alias untargz='tar -xzvf'
alias zipf='zip -r'
alias unzipf='unzip'
alias lz='ls *.tar.gz *.zip *.rar *.xz 2>/dev/null'  # list archives in cwd

# Viewing
alias cat='bat --paging=never'        # requires: bat
alias diff='colordiff'
alias grep='grep --color=auto'
alias egrep='egrep --colour=auto'
alias fgrep='fgrep --color=auto'
alias ff='find . -type f -name'       # quick filename search
alias finds='find . -type f -iname'   # case-insensitive filename search
alias head='head -n 20'
alias tail='tail -n 20'
alias tlf='tail -f'
alias less='less -R'                  # pass colour codes through
