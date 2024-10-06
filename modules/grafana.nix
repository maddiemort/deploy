{ config
, lib
, pkgs
, modules
, ...
}:

let
  cfg = config.custom.services.grafana;
  lokicfg = config.custom.services.loki;
  promcfg = config.custom.services.prometheus;
  tempocfg = config.custom.services.tempo;

  inherit (lib) mkIf mkMerge;
in
{
  imports = [
    modules.loki
    modules.prometheus
    modules.tempo
  ];

  options = with lib; {
    custom.services.grafana = {
      enable = mkEnableOption "Grafana";

      bootstrap = mkEnableOption "temporary bootstrap access before setting up Tailscale proxy";
      bootstrapDomain = mkOption {
        description = "Domain to access Grafana over when bootstrapping";
        type = types.str;
      };
      bootstrapAcmeEmail = mkOption {
        description = "Email for registration with the CA for the bootstrap domain";
        type = types.str;
      };

      port = mkOption rec {
        description = ''
          Port to serve Grafana interface over.
        '';
        type = types.int;
        default = 2342;
        example = default;
      };

      hostname = mkOption {
        description = ''
          Hostname to use for the grafana service within your tailnet
        '';
        type = types.str;
        default = "grafana";
        example = "dashboards";
      };

      tailscaleDomain = mkOption {
        description = ''
          Tailscale domain for your tailnet
        '';
        type = types.str;
        example = "your-tailscale-https-domain.ts.net";
      };

      secrets = mkOption {
        description = "Secrets for use in this module";

        type = types.submodule {
          options = {
            adminPassword = mkOption {
              type = types.submodule {
                options = {
                  name = mkOption {
                    description = ''
                      Name of the agenix secret that contains the Grafana admin password, as
                      declared to Age, without the .age extension.
                    '';
                    type = types.str;
                    example = "grafana-admin-password";
                  };

                  file = mkOption {
                    type = types.path;
                    description = "Path to the encrypted Age secret";
                  };
                };
              };
            };

            tailscaleAuthkey = mkOption {
              type = types.submodule {
                options = {
                  name = mkOption {
                    description = ''
                      Name of the agenix secret that contains the Tailscale authkey for
                      proxy-to-grafana, as declared to Age, without the .age extension.
                    '';
                    type = types.str;
                    example = "proxy-to-grafana-hostname";
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
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      custom.services.loki.enable = cfg.enable;
      custom.services.prometheus.enable = cfg.enable;
      custom.services.tempo.enable = cfg.enable;

      age.secrets."${cfg.secrets.adminPassword.name}" = {
        inherit (cfg.secrets.adminPassword) file;
        owner = "grafana";
        group = "grafana";
      };

      age.secrets."${cfg.secrets.tailscaleAuthkey.name}" = {
        inherit (cfg.secrets.tailscaleAuthkey) file;
        owner = "proxy-to-grafana";
        group = "proxy-to-grafana";
      };

      services.grafana = {
        inherit (cfg) enable;

        dataDir = "/srv/grafana";

        settings = {
          server = {
            domain =
              if cfg.bootstrap
              then cfg.bootstrapDomain
              else "${cfg.hostname}.${cfg.tailscaleDomain}";
            root_url =
              if cfg.bootstrap
              then "https://${cfg.bootstrapDomain}"
              else "https://${cfg.hostname}.${cfg.tailscaleDomain}";
            http_addr =
              if cfg.bootstrap
              then "0.0.0.0"
              else "127.0.0.1";
            http_port = cfg.port;
          };

          security = {
            admin_password = "$__file{${config.age.secrets."${cfg.secrets.adminPassword.name}".path}}";
          };

          "auth.proxy" = {
            enabled = true;
            header_name = "X-WebAuth-User";
            header_property = "username";
            auto_sign_up = true;
            sync_ttl = 60;
            whitelist = "127.0.0.1";
            headers = "Name:X-WebAuth-Name";
            enable_login_token = true;
          };
        };

        provision = {
          enable = true;

          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://localhost:${toString promcfg.port}";
              jsonData = {
                scrape_interval = "15s";
              };
            }
            {
              name = "Loki";
              type = "loki";
              url = "http://localhost:${toString lokicfg.port}";
              jsonData = {
                derivedFields = [
                  {
                    datasourceUid = "Tempo";
                    matcherRegex = "trace_id=(\\w+)";
                    name = "Trace ID";
                    url = "$${__value.raw}";
                  }
                ];
              };
            }
            {
              name = "Tempo";
              type = "tempo";
              url = "http://localhost:${toString tempocfg.port}";
              jsonData = {
                tracesToLogs = {
                  datasourceUid = "Loki";
                  mappedTags = [
                    {
                      key = "service.name";
                      value = "service";
                    }
                  ];
                  mapTagNamesEnabled = true;
                  filterByTraceID = true;
                };
              };
            }
          ];
        };
      };

      users.users.proxy-to-grafana = {
        createHome = true;
        description = "proxy-to-grafana";
        isSystemUser = true;
        group = "proxy-to-grafana";
        home = "/srv/proxy-to-grafana";
      };

      users.groups.proxy-to-grafana = { };

      systemd.services.proxy-to-grafana = {
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          User = "proxy-to-grafana";
          Group = "proxy-to-grafana";
          Restart = "on-failure";
          WorkingDirectory = "/srv/proxy-to-grafana";
        };

        script = ''
          export TS_HOSTNAME="${cfg.hostname}"
          export GRAFANA_ADDR="127.0.0.1:${builtins.toString cfg.port}"
          export TS_AUTHKEY="$(cat ${config.age.secrets."${cfg.secrets.tailscaleAuthkey.name}".path})"
          ${pkgs.tailscale}/bin/proxy-to-grafana --use-https=true --hostname=$TS_HOSTNAME --backend-addr=$GRAFANA_ADDR
        '';
      };
    })

    (mkIf (cfg.enable && cfg.bootstrap) {
      security.acme.certs."${cfg.bootstrapDomain}".email = cfg.bootstrapAcmeEmail;
      services.nginx = {
        enable = true;

        virtualHosts."${cfg.bootstrapDomain}" = {
          enableACME = true;
          forceSSL = true;

          locations."/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host ${cfg.bootstrapDomain};
              proxy_set_header Origin https://${cfg.bootstrapDomain};
            '';
          };
        };
      };
    })
  ];
}
