{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.custom.services.arma-3-status-bot;

  inherit (lib) mkEnableOption mkIf mkOption types;
in
{
  options = {
    custom.services.arma-3-status-bot = {
      enable = mkEnableOption "Arma 3 status Discord bot";

      discordToken = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the Discord token for arma-3-status-bot, as
                declared to Age, without the .age extension.
              '';
              type = types.str;
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };

      queryAddress = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                The name of the Agenix secret that contains the query address (in the form of
                `URL:PORT` or `IP_ADDR:PORT`) to query for Arma status, without the .age extension.
              '';
              type = types.str;
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
    users.users.arma-3-status-bot = {
      createHome = true;
      description = "Arma 3 status Discord bot user";
      isSystemUser = true;
      group = "arma-3-status-bot";
      home = "/srv/arma-3-status-bot";
    };

    users.groups.arma-3-status-bot = { };

    age.secrets."${cfg.discordToken.name}" = {
      inherit (cfg.discordToken) file;
      owner = "arma-3-status-bot";
      group = "arma-3-status-bot";
    };

    age.secrets."${cfg.queryAddress.name}" = {
      inherit (cfg.queryAddress) file;
      owner = "arma-3-status-bot";
      group = "arma-3-status-bot";
    };

    systemd.services.arma-3-status-bot = {
      wantedBy = [ "multi-user.target" ];
      after = [ ];
      wants = [ ];

      serviceConfig = {
        User = "arma-3-status-bot";
        Group = "arma-3-status-bot";
        Restart = "always";
        WorkingDirectory = "/srv/arma-3-status-bot";
        RestartSec = "30s";
      };

      script = ''
        export RUST_LOG="info"
        export DISCORD_TOKEN="$(cat "${config.age.secrets."${cfg.discordToken.name}".path}")"
        export ARMA_QUERY_ADDR="$(cat "${config.age.secrets."${cfg.queryAddress.name}".path}")"
        ${pkgs.arma-3-status-bot}/bin/arma-3-status-bot -r
      '';
    };
  };
}
