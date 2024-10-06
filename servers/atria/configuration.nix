{ lib
, ...
}:

{
  imports = [
    ./hardware.nix
    ./networking.nix
  ];

  boot.tmp.cleanOnBoot = true;

  networking.hostName = "atria";

  services.openssh.enable = true;

  time.timeZone = "Europe/London";

  system.stateVersion = "22.11";
}
