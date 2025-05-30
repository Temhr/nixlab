{ pkgs, ... }: {

  default = import ./default-shell.nix { inherit pkgs; };
  rust = import ./rust.nix { inherit pkgs; };
  python = import ./python.nix { inherit pkgs; };
  web = import ./web.nix { inherit pkgs; };
  security = import ./security.nix { inherit pkgs; };
  minimal = import ./minimal.nix { inherit pkgs; };
}
