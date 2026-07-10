# .bashrc — sourced for every interactive shell

# Load all modules in order: env first so vars are available to everything else
for _file in ~/.bash/{environment_variables,ghostty_theme_randomizer,bash_prompt,bash_functions}; do
    [ -r "$_file" ] && source "$_file"
done
unset _file

# Load all alias domain files
for _file in ~/.bash/aliases/*.sh; do
    [ -r "$_file" ] && source "$_file"
done
unset _file

# Show system info on login (interactive terminal only)
if [ -t 0 ]; then
    if type -p "fastfetch" > /dev/null; then
        fastfetch
    else
        echo "Warning: fastfetch not installed."
    fi
fi

# History: no duplicates, no lines starting with a space
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%Y-%m-%d %T "

# Fix minor cd typos automatically
shopt -s cdspell

# Add ~/bin and ~/.local/bin to PATH if not already present
case :$PATH: in
    *:/home/$USER/bin:*)       ;;
    *) PATH=/home/$USER/bin:$PATH ;;
esac
case :$PATH: in
    *:/home/$USER/.local/bin:*) ;;
    *) PATH=/home/$USER/.local/bin:$PATH ;;
esac

# Zoxide (smart cd) and fzf (fuzzy finder) init
eval "$(zoxide init bash)"
eval "$(fzf --bash)"
