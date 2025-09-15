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

  security.sudo.extraRules = [
    {
      users = [ "josephcryer" ];
      commands = [
        { command = "/run/current-system/sw/bin/systemctl restart direwolf20-s14.service"; options = [ "SETENV" "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl start direwolf20-s14.service"; options = [ "SETENV" "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl stop direwolf20-s14.service"; options = [ "SETENV" "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl kill --signal 9 direwolf20-s14.service"; options = [ "SETENV" "NOPASSWD" ]; }
      ];
    }
  ];

  time.timeZone = "Europe/London";

  system.stateVersion = "22.11";
}
