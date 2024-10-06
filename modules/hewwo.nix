{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.hewwo;
in
{
  options = {
    custom.services.hewwo = {
      enable = mkEnableOption ''Activate the ferris "hewwo?" zone Minecraft server on this host'';

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
      description = "Hewwo Minecraft server service user";
      isSystemUser = true;
      group = "minecraft";
      home = "/srv/hewwo";
    };

    users.groups.minecraft = { };

    systemd.services.hewwo = {
      inherit (cfg) enable;

      description = "Hewwo Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jdk17}/bin/java -Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M -jar fabric-server-mc.1.19.2-loader.0.14.22-launcher.0.11.2.jar nogui";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/hewwo";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
