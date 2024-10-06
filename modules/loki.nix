{ config
, lib
, ...
}:

let
  cfg = config.custom.services.loki;
  home = "/srv/loki";

  inherit (lib) mkIf;
in
{
  options = with lib; {
    custom.services.loki = {
      enable = mkEnableOption "Loki";

      port = mkOption rec {
        description = ''
          Port for Loki to listen over
        '';
        type = types.int;
        default = 9003;
        example = default;
      };
    };
  };

  config = mkIf cfg.enable {
    services.loki = {
      enable = true;
      dataDir = home;

      configuration = {
        server.http_listen_port = cfg.port;
        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 999999;
          chunk_retain_period = "30s";
        };

        schema_config = {
          configs = [{
            from = "2024-08-11";
            object_store = "filesystem";
            store = "tsdb";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];
        };

        storage_config = {
          tsdb_shipper = {
            active_index_directory = "${home}/tsdb-shipper-active";
            cache_location = "${home}/tsdb-shipper-cache";
            cache_ttl = "24h";
          };

          filesystem = {
            directory = "${home}/chunks";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };

        compactor = {
          working_directory = home;
          compactor_ring = {
            kvstore = {
              store = "inmemory";
            };
          };
        };
      };
    };
  };
}
