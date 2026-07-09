{...}: {
  flake.homeModules.home--apps--virtualization = {...}: {
    ## Removes initial virt-manager warning
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };
}
