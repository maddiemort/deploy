{...}: {
  imports = [
    ./hardware.nix
    ./networking.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = false;

  networking.hostName = "koeia";

  services.openssh.enable = true;

  system.stateVersion = "24.05";
}
