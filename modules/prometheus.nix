{ config
, lib
, ...
}:

let
  cfg = config.custom.services.prometheus;

  inherit (lib) optionals;
in
{
  options = with lib; {
    custom.services.prometheus = {
      enable = mkEnableOption "Prometheus";

      nodes = mkOption {
        description = "List of hostnames of servers running node-exporter to scrape from";
        type = types.listOf types.str;
        default = [ ];
      };

      port = mkOption rec {
        description = ''
          Port to serve Prometheus over.
        '';
        type = types.int;
        default = 9001;
        example = default;
      };

      nodeExporter = {
        enable = mkEnableOption "Prometheus node exporter";

        port = mkOption rec {
          description = ''
            Port to serve the Prometheus node exporter over.
          '';
          type = types.int;
          default = 9002;
          example = default;
        };
      };
    };
  };

  config = {
    services.prometheus = {
      inherit (cfg) enable port;

      exporters = {
        node = {
          inherit (cfg.nodeExporter) enable port;
          enabledCollectors = [ "systemd" ];
        };
        nginx = {
          inherit (cfg) enable;
        };
      };

      globalConfig = {
        scrape_interval = "5s";
      };

      scrapeConfigs = [
        {
          job_name = "vexillologist";
          static_configs = [
            {
              targets = [
                "localhost:9010"
              ];
              labels.host = "koeia";
            }
          ];
        }
        {
          job_name = "maddie-wtf";
          static_configs = [
            {
              targets = [
                "localhost:9069"
              ];
              labels.host = "koeia";
            }
          ];
        }
        {
          job_name = "anubis";
          static_configs = [
            {
              targets = [
                "localhost:9401"
              ];
              labels.target = "maddie-wtf";
            }
            {
              targets = [
                "localhost:9402"
              ];
              labels.target = "wirebrush";
            }
          ];
        }
        {
          job_name = "minecraft";
          static_configs = [
            {
              targets = [
                "gnomon:19565"
              ];
              labels.host = "gnomon";
              labels.application = "direwolf20-s14";
            }
          ];
        }
        {
          job_name = "nginx";
          static_configs = [
            {
              targets = [
                "localhost:${toString config.services.prometheus.exporters.nginx.port}"
              ];
              labels.host = "koeia";
            }
          ];
        }
        {
          job_name = "node";
          static_configs = map
            (hostname: {
              targets = [ "${hostname}:${toString cfg.nodeExporter.port}" ];
              labels.host = hostname;
            })
            cfg.nodes;
        }
      ];
    };
  };
}
