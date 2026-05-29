# .bash_profile — runs once at login
# Hands off to .bashrc for all interactive config

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Login-only: start ssh-agent once per session if not already running
if [ -z "$SSH_AGENT_PID" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi
