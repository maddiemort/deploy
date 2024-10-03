{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.custom.services.vexillologist;

  inherit (lib) mkEnableOption mkIf mkOverride;
in
{
  options = {
    custom.services.vexillologist = {
      enable = mkEnableOption "Vexillologist Discord bot";
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
  };
}
