{self, ...}: {
  flake.homeModules.common-optional--config-virt-manager = {...}: {
    ## Removes initial virt-manager warning
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };
}
