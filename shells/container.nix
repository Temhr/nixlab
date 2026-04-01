# Tools for working with containers and virtual machines.
# Useful on hosts that run Podman, Incus, or Quickemu.
{...}: {
  perSystem = {pkgs, ...}: {
    devShells.container = pkgs.mkShell {
      name = "container-dev";

      buildInputs = with pkgs; [
        podman
        podman-compose
        skopeo # inspect and copy container images without a daemon
        dive # explore container image layers
        ctop # top-like interface for container metrics
        kubectl # if you ever point at a k8s cluster
        k9s # terminal UI for Kubernetes
        helm # Kubernetes package manager
      ];

      shellHook = ''
        echo "📦 Container Development Environment"
        echo ""
        echo "Containers:  podman  podman-compose  skopeo  dive  ctop"
        echo "Kubernetes:  kubectl  k9s  helm"
        echo ""
        echo "Tip: Podman rootless mode is enabled by default on NixOS."
        echo "     Use 'podman info' to verify your setup."
      '';
    };
  };
}
