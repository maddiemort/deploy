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

      ensureDatabases = [ "vexillologist" ];
      ensureUsers = [
        {
          name = "vexillologist";
          ensureDBOwnership = true;
        }
      ];

      authentication = mkOverride 10 ''
        # TYPE    DATABASE       USER        ADDRESS    METHOD    OPTIONS
        local     sameuser       all                    peer      map=superuser_map
        local     all            postgres               peer
        local     replication    all                    peer
      '';
      identMap = ''
        # ArbitraryMapName SystemUser DBUser
        superuser_map      root       postgres
        superuser_map      postgres   postgres
        superuser_map      /^(.*)$    \1
      '';
    };
  };
}
