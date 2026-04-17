{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.custom.services.terraria;

  dataDir = "/srv/terraria";
  worldDir = "${dataDir}/worlds";

  # Simple config file serializer. Not very robust.
  mkConfig = options:
    builtins.toFile
    "terraria.cfg"
    (lib.concatStrings
      (lib.mapAttrsToList
        (name: value: "${name}=${toString value}\n")
        options));

  # Config Generator
  mkWorld = name: {
    seed ? "maddiemort-deploy-${name}",
    worldSize ? "large",
    extraOptions ? {},
  }: {
    config = mkConfig (extraOptions
      // {
        world = "${worldDir}/${name}.wld";
        inherit seed;
        autocreate =
          {
            small = 1;
            medium = 2;
            large = 3;
          }.${
            worldSize
          };
        upnp = 0;
      });
  };

  # High-level Config
  worlds = lib.mapAttrs mkWorld {
    world-alpha = {};
    wet-soggy-leaf = {
      seed = "wet-soggy-leaf";
    };
  };

  world = worlds.wet-soggy-leaf;
in {
  options = {
    custom.services.terraria = {
      enable = mkEnableOption "Activate the Terraria server on this host";

      password = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Name of the secret as declared to Age, without the .age extension";
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.terraria = {
      group = "terraria";
      home = dataDir;
      uid = config.ids.uids.terraria;
    };

    users.groups.terraria = {
      gid = config.ids.gids.terraria;
    };

    systemd.sockets.terraria = {
      socketConfig = {
        ListenFIFO = ["/run/terraria.sock"];
        SocketUser = "terraria";
        SocketMode = "0660";
        RemoveOnStop = true;
      };
    };

    age.secrets."${cfg.password.name}" = {
      inherit (cfg.password) file;
      owner = "terraria";
      group = "terraria";
    };

    systemd.services.terraria = {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      bindsTo = ["terraria.socket"];

      preStop = ''
        printf '\nexit\n' >/run/terraria.sock
      '';

      script = ''
        TERRARIA_PASSWORD="$(cat ${config.age.secrets."${cfg.password.name}".path})"
        ${pkgs.terraria-server}/bin/TerrariaServer \
          -config ${world.config} \
          -password "$TERRARIA_PASSWORD"
      '';

      serviceConfig = {
        User = "terraria";

        StateDirectory = "terraria";
        StateDirectoryMode = "0750";

        StandardInput = "socket";
        StandardOutput = "journal";
        StandardError = "journal";

        # Wait for exit after `ExecStop` (https://github.com/systemd/systemd/issues/13284)
        KillSignal = "SIGCONT";
        TimeoutStopSec = "1h";
      };
    };

    networking.firewall.allowedTCPPorts = [7777];
  };
}
