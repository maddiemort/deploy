{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.custom.services.vexillologist;

  inherit (lib) mkEnableOption mkIf mkOverride mkOption types;
in
{
  options = {
    custom.services.vexillologist = {
      enable = mkEnableOption "Vexillologist Discord bot";

      discordToken = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the Discord token for vexillologist, as
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

      connectionString = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the database connection string for
                vexillologist, as declared to Age, without the .age extension.
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
    environment.systemPackages = [
      config.services.postgresql.package
    ];

    users.users.vexillologist = {
      description = "Vexillologist Discord bot service user";
      home = "/srv/vexillologist";
      createHome = true;
      isSystemUser = true;
      group = "vexillologist";
    };
    users.groups.vexillologist = { };

    services.postgresql = {
      inherit (cfg) enable;
      package = pkgs.postgresql_15;

      ensureDatabases = [
        "vexillologist"
        "vexillologist-dev"
      ];

      ensureUsers = [
        {
          name = "vexillologist";
          ensureDBOwnership = true;
        }
        {
          name = "vexillologist-dev";
          ensureDBOwnership = true;
        }
      ];

      enableTCPIP = true;

      authentication = mkOverride 10 ''
        # TYPE    DATABASE       USER                 ADDRESS              METHOD    OPTIONS
        local     sameuser       all                                       peer      map=superuser_map
        local     all            postgres                                  peer
        local     replication    all                                       peer
        host      sameuser       vexillologist        100.114.76.116/32    trust
        host      sameuser       vexillologist        100.85.114.74/32     trust
        host      sameuser       vexillologist-dev    100.114.76.116/32    trust
        host      sameuser       vexillologist-dev    100.85.114.74/32     trust
      '';
      identMap = ''
        # ArbitraryMapName SystemUser DBUser
        superuser_map      root       postgres
        superuser_map      postgres   postgres
        superuser_map      maddie     vexillologist
        superuser_map      maddie     vexillologist-dev
        superuser_map      /^(.*)$    \1
      '';

      initialScript = pkgs.writeText "postgres-init-script" ''
        GRANT ALL ON SCHEMA public TO vexillologist;
        GRANT ALL ON SCHEMA public TO vexillologist-dev;
      '';
    };


    age.secrets."${cfg.discordToken.name}" = {
      inherit (cfg.discordToken) file;
      owner = "vexillologist";
      group = "vexillologist";
    };

    age.secrets."${cfg.connectionString.name}" = {
      inherit (cfg.connectionString) file;
      owner = "vexillologist";
      group = "vexillologist";
    };

    systemd.services.vexillologist = {
      inherit (cfg) enable;

      description = "Vexillologist Discord bot service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Restart = "always";
        User = "vexillologist";
        WorkingDirectory = "/srv/vexillologist";
      };

      script = ''
        export RUST_LOG="info"
        export DISCORD_TOKEN='$(cat "${config.age.secrets."${cfg.discordToken.name}".path}")'
        export CONNECTION_STRING='$(cat "${config.age.secrets."${cfg.connectionString.name}".path}")'
        ${pkgs.vexillologist}/bin/vexillologist
      '';
    };
  };
}
