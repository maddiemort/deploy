{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.direwolf20-s14;
in
{
  options = {
    custom.services.direwolf20-s14 = {
      enable = mkEnableOption "Activate the FTB Direwolf20 Season 14 Minecraft 1.21 server on this host";

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

  config =
    let
      stopScript = pkgs.writeShellScript "minecraft-server-stop" ''
        echo stop > ${config.systemd.sockets.direwolf20-s14.socketConfig.ListenFIFO}

        # Wait for the PID of the minecraft server to disappear before returning, so systemd doesn't
        # attempt to SIGKILL it.
        while kill -0 "$1" 2> /dev/null; do
          sleep 1s
        done
      '';
    in
    mkIf cfg.enable {
      users.users.minecraft = {
        createHome = true;
        description = "FTB Direwolf20 Season 14 Minecraft 1.21 Minecraft server service user";
        isSystemUser = true;
        group = "minecraft";
        home = "/srv/direwolf20-s14";
      };

      users.groups.minecraft = { };

      systemd.sockets.direwolf20-s14 = {
        bindsTo = [ "direwolf20-s14.service" ];
        socketConfig = {
          ListenFIFO = "/run/direwolf20-s14.stdin";
          SocketMode = "0660";
          SocketUser = "minecraft";
          SocketGroup = "minecraft";
          RemoveOnStop = true;
          FlushPending = true;
        };
      };

      systemd.services.direwolf20-s14 = {
        description = "FTB Direwolf20 Season 14 Minecraft 1.21 Minecraft server service";
        wantedBy = [ "multi-user.target" ];
        requires = [ "direwolf20-s14.socket" ];
        after = [
          "network.target"
          "direwolf20-s14.socket"
        ];

        serviceConfig = {
          # This JDK should be 21
          ExecStart = ''
            ${pkgs.jdk}/bin/java \
              -Xms${toString cfg.memory}M \
              -Xmx${toString cfg.memory}M \
              -XX:+UseG1GC \
              -XX:+UnlockExperimentalVMOptions \
              @libraries/net/neoforged/neoforge/21.1.172/unix_args.txt \
              nogui
          '';
          ExecStop = "${stopScript} $MAINPID";
          Restart = "always";
          User = "minecraft";
          WorkingDirectory = "/srv/direwolf20-s14";

          StandardInput = "socket";
          StandardOutput = "journal";
          StandardError = "journal";

          # Hardening
          CapabilityBoundingSet = [ "" ];
          DeviceAllow = [ "" ];
          LockPersonality = true;
          PrivateDevices = true;
          PrivateTmp = true;
          PrivateUsers = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ cfg.port ];
        allowedUDPPorts = [ cfg.port ];
      };
    };
}
