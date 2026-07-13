{
  self,
  inputs,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
  hostsMeta = self.lib.hostsMeta;
  nixlabLib = self.lib.nixlabLib;
  usersMeta = self.lib.usersMeta;
  hardwareMeta = self.lib.hardwareMeta;

  allOverlays = [
    self.overlays.unstable-packages
    self.overlays.stable-packages
    self.overlays.additions
    self.overlays.modifications
  ];

  mkCommonModules = [
    inputs.sops-nix.nixosModules.sops
    self.nixosModules.hosts--core--home-manager-config
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
  ];

  mkHardwareProfile = machine: let
    meta =
      hardwareMeta.${machine}
      or (throw "mkHardwareProfile: no hardwareMeta entry for machine '${machine}'");
  in
    {
      config,
      lib,
      ...
    }:
      lib.mkMerge [
        {
          fileSystems."/home" = {
            device = "/dev/disk/by-label/home";
            fsType = "ext4";
          };
          fileSystems."/" = {
            device = "/dev/disk/by-label/root";
            fsType = "ext4";
          };
          fileSystems."/boot" = {
            device = "/dev/disk/by-label/boot";
            fsType = "vfat";
            options = ["fmask=0077" "dmask=0077"];
          };
          swapDevices = [{device = "/dev/disk/by-label/swap";}];

          boot.initrd.availableKernelModules = meta.initrdAvailableKernelModules;
          boot.initrd.kernelModules = meta.initrdKernelModules;
          boot.kernelModules = meta.kernelModules;
          boot.extraModulePackages = meta.extraModulePackages;
          networking.useDHCP = lib.mkDefault true;
        }
        (lib.mkIf (meta.cpuVendor == "intel") {
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
        (lib.mkIf (meta.cpuVendor == "amd") {
          hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
        meta.extraConfig
      ];

  mkHost = {
    name,
    modules,
  }:
    assert lib.assertMsg
    (builtins.hasAttr name hostsMeta)
    "mkHost: no hostsMeta entry found for '${name}'"; let
      meta = hostsMeta.${name};
    in
      assert lib.assertMsg
      (builtins.hasAttr meta.nixpkgsInput inputs)
      "mkHost: nixpkgsInput '${meta.nixpkgsInput}' not found in flake inputs for host '${name}'"; let
        nixpkgsSource = inputs.${meta.nixpkgsInput};
        hostLib = nixpkgsSource.lib;
        hostPkgs = import nixpkgsSource {
          inherit (meta) system;
          config = {
            allowUnfree = true;
            nvidia.acceptLicense = true;
          };
          overlays = allOverlays;
        };
      in
        hostLib.nixosSystem {
          specialArgs = {
            inherit inputs self;
            inherit nixlabLib;
            outputs = self;
            flakePath = self;
            allHosts = hostsMeta;
            hostMeta = meta;
            nixpkgsSource = nixpkgsSource;
            self' = {
              packages = self.packages.${meta.system};
              devShells = self.devShells.${meta.system};
              apps = self.apps.${meta.system} or {};
            };
          };
          modules =
            mkCommonModules
            ++ modules
            ++ [
              {networking.hostName = name;}
              (hostLib.mkIf (meta.hostId != null) {
                networking.hostId = meta.hostId;
              })
              {
                imports = ["${nixpkgsSource}/nixos/modules/misc/nixpkgs/read-only.nix"];
                nixpkgs.pkgs = hostPkgs;
              }
              {
                nix.registry.nixpkgs = hostLib.mkForce {
                  flake = nixpkgsSource;
                };
              }
            ];
        };

  # builds a single system user configuration.
  mkSystemUser = username: let
    userMeta = usersMeta.${username};
  in
    {
      isNormalUser = userMeta.isNormalUser or true;
      openssh.authorizedKeys.keys = userMeta.sshAuthorizedKeys or [];
      extraGroups = userMeta.extraGroups or [];
    }
    // lib.optionalAttrs (userMeta.initialPassword or null != null) {
      initialPassword = userMeta.initialPassword;
    };

  mkSystemUsersForHost = hostName:
    assert lib.assertMsg
    (builtins.hasAttr hostName hostsMeta)
    "mkSystemUsersForHost: no hostsMeta entry found for '${hostName}'"; let
      meta = hostsMeta.${hostName};
    in
      lib.genAttrs meta.systemUsers (username:
        assert lib.assertMsg
        (builtins.hasAttr username usersMeta)
        "mkSystemUsersForHost: no usersMeta entry found for user '${username}' (host '${hostName}')";
          mkSystemUser username);

  # builds a single home-manager user configuration.
  mkHomeUser = {
    username,
    hostName,
  }: let
    userMeta = usersMeta.${username};
    override = userMeta.hostOverrides.${hostName} or {};
    profile = override.profile or userMeta.defaultProfile;
    extraModules = override.extraModules or [];
  in {
    imports =
      [self.homeModules.home--profl--base]
      ++ lib.optional (profile == "desktop") self.homeModules.home--profl--desktop
      ++ extraModules;

    home = {
      inherit username;
      homeDirectory = "/home/${username}";
      enableNixpkgsReleaseCheck = false;
      stateVersion = "24.11";
    };
    programs.home-manager.enable = true;
    programs.git.enable = true;
    programs.git.settings.user.name = userMeta.gitName;
    programs.git.settings.user.email = userMeta.gitEmail;
  };

  # generates the full home-manager.users attrset for one host,
  # driven entirely by hostsMeta.<host>.homeUsers.
  mkHomeUsersForHost = hostName:
    assert lib.assertMsg
    (builtins.hasAttr hostName hostsMeta)
    "mkHomeUsersForHost: no hostsMeta entry found for '${hostName}'"; let
      meta = hostsMeta.${hostName};
    in
      lib.genAttrs meta.homeUsers (username:
        assert lib.assertMsg
        (builtins.hasAttr username usersMeta)
        "mkHomeUsersForHost: no usersMeta entry found for user '${username}' (host '${hostName}')";
          mkHomeUser {inherit username hostName;});
in {
  flake.lib = {inherit mkHost mkHomeUser mkHomeUsersForHost mkSystemUser mkSystemUsersForHost mkHardwareProfile;};
  # hostsMeta, nixlabLib, usersMeta no longer assigned here — they already
  # arrived via flake.lib from their own self-registering files, and
  # flake-parts merges everyone's flake.lib contributions together.
}
