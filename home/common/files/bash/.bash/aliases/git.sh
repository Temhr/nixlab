# aliases/git.sh — Git and development helpers

# Common Git operations
alias ga='git add .'
alias gc='git commit -m'
alias gd='git diff'
alias gl='git pull'
alias gp='git push'
alias gr='git remote -v'
alias gs='git status'
alias gslog='git log --oneline --graph --decorate'

# Nixlab-specific Git shortcuts
alias gpull="cd $NIXLAB && git pull"
alias greset="cd $NIXLAB && git reset --hard origin/main && git pull --rebase"

# Dev environment helpers
alias pyvenv='python3 -m venv .venv && source .venv/bin/activate'
alias runpy='python3 -u'       # unbuffered Python output
alias s='code .'               # open VS Code in cwd
alias svim='sudo vim'
alias v='nvim'
