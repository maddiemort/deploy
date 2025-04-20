{ ...
}:

{
  imports = [
    ./hardware.nix
    ./networking.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "koeia";

  services.openssh.enable = true;

  system.stateVersion = "24.05";
}
