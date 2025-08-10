{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.minecraft-almost-vanilla;
in
{
  options = {
    custom.services.minecraft-almost-vanilla = {
      enable = mkEnableOption "Activate the Minecraft 1.21.8 Almost Vanilla server on this host";

      memory = mkOption {
        description = ''
          How many MB of memory to dedicate to the server.
        '';
        type = types.int;
        default = 4096;
        example = 2048;
      };
    };
  };

  config = mkIf cfg.enable {
    services.minecraft-server = {
      enable = true;
      declarative = false;
      eula = true;
      dataDir = "/srv/minecraft";
      openFirewall = true;
      # This should currently be 1.21.8
      package = pkgs.minecraftServers.vanilla-1-21;
      jvmOpts = "-Xms${toString cfg.memory}M -Xmx${toString cfg.memory}M";
    };

    # This JDK should be 21
    systemd.services.minecraft-server.serviceConfig.ExecStart = mkForce ''
      ${pkgs.jdk}/bin/java \
        ${config.services.minecraft-server.jvmOpts} \
        -jar fabric-server-mc.1.21.8-loader.0.17.2-launcher.1.1.0.jar \
        nogui
    '';
  };
}
