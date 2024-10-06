{ config
, lib
, ...
}:

let
  cfg = config.custom.services.promtail;

  inherit (lib) mkIf;
in
{
  options = with lib; {
    custom.services.promtail = {
      enable = mkEnableOption "Promtail";

      port = mkOption rec {
        description = ''
          Port for Promtail to listen over.
        '';
        type = types.int;
        default = 9004;
        example = default;
      };

      loki = {
        host = mkOption {
          description = ''
            Host that Loki runs on to push data to.
          '';
          type = types.str;
          example = "loki";
        };

        port = mkOption rec {
          description = ''
            Port that Loki listens on to push data to.
          '';
          type = types.int;
          default = 9003;
          example = default;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.port;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [{
          url = "http://${cfg.loki.host}:${toString cfg.loki.port}/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
    };
  };
}
