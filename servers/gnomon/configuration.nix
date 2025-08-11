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

  users.users.josephcryer = {
    createHome = true;
    description = "Joseph Cryer";
    isNormalUser = true;
    home = "/home/josephcryer";
    group = "josephcryer";
    extraGroups = [
      "minecraft"
    ];

    openssh.authorizedKeys.keys = builtins.map builtins.readFile [
      ../../keys/joe.pub
    ];
  };

  users.groups.josephcryer = { };

  time.timeZone = "Europe/London";

  system.stateVersion = "22.11";
}
