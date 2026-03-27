{...}: {
  perSystem = {pkgs, ...}: {
    devShells.security = pkgs.mkShell {
      name = "security-dev";

      buildInputs = with pkgs; [
        # Network tools
        nmap
        netcat
        wireshark
        tcpdump

        # Web security
        burpsuite
        nikto
        dirb
        gobuster

        # Cryptography
        hashcat
        john
        openssl

        # General security
        metasploit
        sqlmap
        hydra
      ];

      shellHook = ''
        echo "🔒 Security Development Environment"
        echo "⚠️  Use these tools responsibly and ethically!"
        echo ""
        echo "Available tools:"
        echo "  - nmap: Network scanner"
        echo "  - burpsuite: Web application security"
        echo "  - hashcat/john: Password cracking"
        echo "  - metasploit: Penetration testing framework"
        echo ""
        echo "Remember: Only test on systems you own or have permission to test!"
      '';
    };
  };
}
