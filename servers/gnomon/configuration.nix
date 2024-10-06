{ lib
, ...
}:

{
  imports = [
    ./hardware.nix
    ./networking.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "gnomon";

  services.openssh.enable = true;

  time.timeZone = "Europe/London";

  system.stateVersion = "22.11";
}
