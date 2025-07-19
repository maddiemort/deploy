{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.custom.services.wirebrush;

  inherit (lib) mkIf;
in
{
  options = with lib; {
    custom.services.wirebrush = {
      enable = mkEnableOption "wirebrush website service";

      domain = mkOption {
        type = types.str;
        description = "Domain to host the website on";
      };

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

    security.acme.certs."${cfg.domain}".email = cfg.acme.email;

    services.anubis.instances.wirebrush = {
      settings = {
        COOKIE_DOMAIN = cfg.domain;
        METRICS_BIND = "127.0.0.1:9402";
        METRICS_BIND_NETWORK = "tcp";
        SERVE_ROBOTS_TXT = true;
        TARGET = "http://127.0.0.1:8000";
      };
    };

    services.nginx = {
      enable = true;

      virtualHosts."${cfg.domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://unix:${config.services.anubis.instances.wirebrush.settings.BIND}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };

    users.users.nginx.extraGroups = [ config.users.groups.anubis.name ];

    users.users.wirebrush = {
      createHome = true;
      description = "github.com/gememma/wirebrush";
      isSystemUser = true;
      group = "wirebrush";
      home = "/srv/wirebrush";
    };

    users.groups.wirebrush = { };

    systemd.services.wirebrush = {
      wantedBy = [ "multi-user.target" ];
      after = [ ];
      wants = [ ];

      serviceConfig = {
        User = "wirebrush";
        Group = "wirebrush";
        Restart = "on-failure";
        WorkingDirectory = "/srv/wirebrush";
        RestartSec = "30s";
      };

      script = ''
        export RUST_LOG="wirebrush=debug,info"
        export WIREBRUSH_CONTENT="${pkgs.wirebrush-content}"
        export WIREBRUSH_STATIC="${pkgs.wirebrush-static}"
        ${pkgs.wirebrush}/bin/wirebrush
      '';
    };
  };
}
