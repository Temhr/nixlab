# NOTE: Several packages in this shell require allowUnfree = true in nixpkgs.
# If a package fails to build, check whether it requires unfree and whether
# it is available on your current nixpkgs channel.
{...}: {
  perSystem = {pkgs, ...}: {
    devShells.security = pkgs.mkShell {
      name = "security-dev";

      buildInputs = with pkgs; [
        # Network reconnaissance
        nmap
        masscan # faster port scanner for large ranges
        netcat-gnu

        # Traffic analysis
        tcpdump
        termshark # terminal UI for tshark / wireshark captures

        # Web application testing
        nikto
        gobuster
        ffuf # fast web fuzzer, modern dirb replacement

        # Cryptography and password tools
        openssl
        hashcat
        john

        # Utilities
        sqlmap
        thc-hydra
      ];

      shellHook = ''
        echo "🔒 Security Development Environment"
        echo "⚠️  Use these tools only on systems you own or"
        echo "   have explicit written permission to test."
        echo ""
        echo "Network:   nmap  masscan  netcat  tcpdump  termshark"
        echo "Web:       nikto  gobuster  ffuf  sqlmap"
        echo "Passwords: hashcat  john  hydra"
        echo "Crypto:    openssl"
      '';
    };
  };
}
