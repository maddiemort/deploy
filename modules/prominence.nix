{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.prominence;
in
{
  options = {
    custom.services.prominence = {
      enable = mkEnableOption "Activate the Prominence II Minecraft server on this host";

      port = mkOption {
        description = ''
          Port to expose the Minecraft server over. This must match the value in server.properties.
        '';
        type = types.int;
        default = 25565;
        example = 25569;
      };

      rconPort = mkOption {
        description = ''
          Port to connect to RCON through. This must match the value in server.properties.
        '';
        type = types.int;
        default = 25575;
        example = 25579;
      };

      memory = mkOption {
        description = ''
          How many MB of memory to dedicate to the server.
        '';
        type = types.int;
        default = 3072;
        example = 2048;
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.minecraft = {
      createHome = true;
      description = "Prominence II Minecraft server service user";
      isSystemUser = true;
      group = "minecraft";
      home = "/srv/prominence";
    };

    users.groups.minecraft = { };

    systemd.services.prominence = {
      description = "Prominence II Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jdk}/bin/java -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M -jar fabric-server-mc.1.20.1-loader.0.14.25-launcher.0.11.2.jar nogui";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/prominence";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
