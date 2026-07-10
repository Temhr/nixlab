# aliases/nix.sh — Nix and NixOS shortcuts
# Requires $NIXLAB to be set in environment_variables (default: $HOME/nixlab)

# --- General Nix commands ---
alias nixb='nix build'
alias nixc='nix-collect-garbage -d'      # collect garbage (old generations)
alias nixd='nix develop'
alias nixgc='nix store gc'               # store-level GC
alias nixrepl='nix repl'
alias nixs='nix search'
alias nixsh='nix shell'
alias nscowsay='nix shell nixpkgs#cowsay'

# --- NixOS rebuild — local flake ($NIXLAB) ---
alias lswitch="sudo nixos-rebuild switch --flake $NIXLAB"
alias ltest="sudo nixos-rebuild test   --flake $NIXLAB"
alias lboot="sudo nixos-rebuild boot   --flake $NIXLAB && sudo reboot"
alias lfup="nix flake update           --flake $NIXLAB"

# --- NixOS rebuild — remote flake (github:temhr/nixlab) ---
alias rswitch='sudo nixos-rebuild switch --flake github:temhr/nixlab'
alias rtest='sudo nixos-rebuild test     --flake github:temhr/nixlab'
alias rboot='sudo nixos-rebuild boot     --flake github:temhr/nixlab && sudo reboot'
alias rfup='sudo systemctl start flake-update.service'

# --- Generation management ---
alias nlist='nixos-rebuild list-generations'
alias ndel='nix-collect-garbage -d'

# --- Dev shells (defined in local flake) ---
alias mesa="nix develop $NIXLAB#mesa"
alias mesa-cpu="nix develop $NIXLAB#mesa-cpu"
alias mesa-gpu="nix develop $NIXLAB#mesa-gpu"
alias repast="nix develop $NIXLAB#repast"
alias repast-cpu="nix develop $NIXLAB#repast-cpu"
alias repast-gpu="nix develop $NIXLAB#repast-gpu"

# --- Quick reference for NixOS aliases ---
alias nixhelp='echo "LOCAL: lswitch ltest lboot lfup | REMOTE: rswitch rtest rboot rfup | GC: ndel nixgc"'
