# source Ghostty Theme Randomizer
source ~/.bash/ghostty_theme_randomizer

# source bash prompt
source ~/.bash/bash_prompt

# Source bash aliases
source ~/.bash/bash_aliases

# Source bash functions
source ~/.bash/bash_functions

# Source bash Environment Variables
source ~/.bash/environment_variables

# Show system information at login
if [ -t 0 ]; then
    if type -p "fastfetch" > /dev/null; then
        fastfetch
    else
        echo "Warning: fastfetch was called, but it's not installed."
    fi
fi

# Don't add duplicate lines or lines beginning with a space to the history
HISTCONTROL=ignoreboth

# Set history format to include timestamps
HISTTIMEFORMAT="%Y-%m-%d %T "

# Correct simple errors while using cd
shopt -s cdspell

# Add /home/$USER/bin to $PATH
case :$PATH: in
	*:/home/$USER/bin:*) ;;
	*) PATH=/home/$USER/bin:$PATH ;;
esac

# Add /home/$USER/.local/bin to $PATH
case :$PATH: in
	*:/home/$USER/.local/bin:*) ;;
	*) PATH=/home/$USER/.local/bin:$PATH ;;
esac

# Add zoxide to Bash
eval "$(zoxide init bash)"

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"
