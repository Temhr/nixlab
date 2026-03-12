{
  /*
    A flake is a self-contained Nix project.

    It has:
    - inputs: where dependencies come from
    - outputs: what this flake produces (packages, dev shells, apps, etc.)
  */

  description = "Minimal example flake with extensive comments for beginners";

  /*
    ─────────────────────────────────────────────────────────────────────────────
    INPUTS
    Inputs are other flakes this flake depends on.
    Each input is pinned and locked in flake.lock for reproducibility.
    ─────────────────────────────────────────────────────────────────────────────
  */
  inputs = {
    /*
      nixpkgs is the main package repository.
      We are pulling it from GitHub and pinning it via flake.lock.
    */
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  /*
    ─────────────────────────────────────────────────────────────────────────────
    OUTPUTS
    outputs is a function.

    The arguments are the resolved inputs.
    "self" refers to this flake itself.
    ─────────────────────────────────────────────────────────────────────────────
  */
  outputs = { self, nixpkgs }:

    /*
      We define the system (platform) this flake targets.
      Common values:
        - "x86_64-linux"
        - "aarch64-linux"
        - "x86_64-darwin"
    */
    let
      system = "x86_64-linux";

      /*
        Import nixpkgs for this specific system.
        This gives us access to pkgs like pkgs.git, pkgs.hello, etc.
      */
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    {
      /*
        ─────────────────────────────────────────────────────────────────────────
        PACKAGES
        Packages are buildable outputs.

        You can build this with:
          nix build .#hello
        ─────────────────────────────────────────────────────────────────────────
      */
      packages.${system}.hello =
        /*
          pkgs.hello is a simple example package from nixpkgs.
          We expose it as an output of our flake.
        */
        pkgs.hello;

      /*
        Setting a default package allows:
          nix build
        without specifying a name.
      */
      packages.${system}.default =
        self.packages.${system}.hello;

      /*
        ─────────────────────────────────────────────────────────────────────────
        DEV SHELLS
        Development shells provide reproducible environments.

        You can enter this shell with:
          nix develop
        ─────────────────────────────────────────────────────────────────────────
      */
      devShells.${system}.default =
        pkgs.mkShell {
          /*
            Packages listed here will be available in your shell.
          */
          packages = [
            pkgs.git
            pkgs.curl
          ];

          /*
            This runs when you enter the shell.
            Useful for messages or environment setup.
          */
          shellHook = ''
            echo "Welcome to the Nix development shell!"
          '';
        };
    };
}
