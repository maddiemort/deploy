{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.mince-pie-raft;

  eulaFile = builtins.toFile "eula.txt" ''
    # eula.txt managed by NixOS Configuration
    eula=true
  '';

  stopScript = pkgs.writeShellScript "mince-pie-raft-stop" ''
    echo stop > ${config.systemd.sockets.mince-pie-raft.socketConfig.ListenFIFO}

    # Wait for the PID of the minecraft server to disappear before returning, so systemd doesn't
    # attempt to SIGKILL it.
    while kill -0 "$1" 2> /dev/null; do
      sleep 1s
    done
  '';
in
{
  options = {
    custom.services.mince-pie-raft = {
      enable = mkEnableOption "FTB Evolution server";

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
      description = "FTB Evolution Minecraft server service user";
      home = "/srv/mince-pie-raft";
      createHome = true;
      isSystemUser = true;
      group = "minecraft";
    };
    users.groups.minecraft = { };

    systemd.sockets.mince-pie-raft = {
      bindsTo = [ "mince-pie-raft.service" ];
      socketConfig = {
        ListenFIFO = "/run/mince-pie-raft.stdin";
        SocketMode = "0660";
        SocketUser = "minecraft";
        SocketGroup = "minecraft";
        RemoveOnStop = true;
        FlushPending = true;
      };
    };

    systemd.services.mince-pie-raft = {
      inherit (cfg) enable;

      description = "FTB Evolution Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      requires = [ "mince-pie-raft.socket" ];
      after = [ "network.target" "mince-pie-raft.socket" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.jdk21}/bin/java \
            -Xms${toString cfg.memory}M \
            -Xmx${toString cfg.memory}M \
            @libraries/net/neoforged/neoforge/21.1.74/unix_args.txt \
            nogui
        '';
        ExecStop = "${stopScript} $MAINPID";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = "/srv/mince-pie-raft";

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
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };

      preStart = ''
        ln -sf ${eulaFile} eula.txt
      '';
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
  };
}
