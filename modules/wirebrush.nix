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

    services.nginx = {
      enable = true;

      virtualHosts."${cfg.domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8000";
          proxyWebsockets = true;
        };
      };
    };

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
