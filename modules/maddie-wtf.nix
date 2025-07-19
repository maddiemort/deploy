{ config
, inputs
, lib
, pkgs
, ...
}:

let
  cfg = config.custom.services.maddie-wtf;

  inherit (lib) mkIf;
in
{
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/anubis.nix"
  ];

  options = with lib; {
    custom.services.maddie-wtf = {
      enable = mkEnableOption "maddie.wtf website service";

      acme = mkOption {
        type = types.submodule {
          options = {
            email = mkOption {
              type = types.str;
              description = "Email for registration with the CA";
            };
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Expose the HTTP and HTTPS ports to the public internet
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    security.acme.certs."maddie.wtf".email = cfg.acme.email;

    services.anubis.instances.maddie-wtf = {
      settings = {
        COOKIE_DOMAIN = "maddie.wtf";
        METRICS_BIND = "127.0.0.1:9401";
        METRICS_BIND_NETWORK = "tcp";
        SERVE_ROBOTS_TXT = true;
        TARGET = "http://127.0.0.1:6942";
        WEBMASTER_EMAIL = "admin@maddie.wtf";
      };
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "anubis";
        static_configs = [
          {
            targets = [
              "localhost:9401"
            ];
            labels.target = "maddie-wtf";
          }
        ];
      }
    ];

    services.nginx = {
      enable = true;

      virtualHosts."maddie.wtf" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://unix:${config.services.anubis.instances.maddie-wtf.settings.BIND}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };

    users.users.nginx.extraGroups = [ config.users.groups.anubis.name ];

    users.users.maddie-wtf = {
      createHome = true;
      description = "github.com/maddiemort/maddie-wtf";
      isSystemUser = true;
      group = "maddie-wtf";
      home = "/srv/maddie-wtf";
    };

    users.groups.maddie-wtf = { };

    systemd.services.maddie-wtf = {
      wantedBy = [ "multi-user.target" ];
      after = [ ];
      wants = [ ];

      serviceConfig = {
        User = "maddie-wtf";
        Group = "maddie-wtf";
        Restart = "on-failure";
        WorkingDirectory = "/srv/maddie-wtf";
        RestartSec = "30s";
      };

      script = ''
        export RUST_LOG="maddie_wtf=debug,info"
        export CONTENT_PATH="${pkgs.maddie-wtf-content}"
        export STATIC_PATH="${pkgs.maddie-wtf-static}"
        export THEMES_PATH="${pkgs.onehalf}/sublimetext"
        ${pkgs.maddie-wtf}/bin/maddie-wtf
      '';
    };
  };
}
