# aliases/navigation.sh — directory movement and shell usability

# Quick directory traversal
alias ..='cd ..'
alias ...='cd ../../..'
alias ....='cd ../../../..'
alias back='cd $OLDPWD'
alias ~='cd ~'

# Typo guard for cd
alias cd..='cd ..'

# Common project dirs
alias cdg='cd ~/Git'
alias cdd='cd ~/Documents'
alias cdl='cd ~/Downloads'
alias cds='cd ~/Scripts'
alias cdp='cd ~/Projects'
alias cdtmp='cd /tmp'
alias cdw='cd /var/www'

# Shell control
alias c='clear'
alias clr='clear && printf "\e[3J"'   # also clears scrollback buffer
alias e='exit'
alias q='exit'
alias h='history'
alias j='jobs -l'
alias reload='source ~/.bashrc'
alias paths='echo -e ${PATH//:/\\n}'  # print PATH one entry per line
alias watch='watch -d'                # highlight diffs between watch updates
alias which='type -a'                 # show all matches, not just first
