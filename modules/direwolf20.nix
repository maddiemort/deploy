{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.direwolf20;
in
{
  options = {
    custom.services.direwolf20 = {
      enable = mkEnableOption "Activate the Direwolf20 1.18 Minecraft server on this host";

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
      description = "FTB Direwolf20 1.18 Minecraft server service user";
      isSystemUser = true;
      group = "minecraft";
      home = "/srv/direwolf20";
    };

    users.groups.minecraft = { };

    systemd.services.direwolf20 = {
      description = "FTB Direwolf20 1.18 Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.jdk17}/bin/java \
            -Xms${toString cfg.memory}M \
            -Xmx${toString cfg.memory}M \
            -javaagent:log4jfix/Log4jPatcher-1.0.0.jar \
            -XX:+UseG1GC \
            -XX:+UnlockExperimentalVMOptions \
            @user_jvm_args.txt \
            @libraries/net/minecraftforge/forge/1.18.2-40.2.1/unix_args.txt \
            nogui
        '';
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/direwolf20";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
