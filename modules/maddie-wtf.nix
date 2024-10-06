{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.custom.services.maddie-wtf;

  inherit (lib) mkIf;
in
{
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

    services.nginx = {
      enable = true;

      virtualHosts."maddie.wtf" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:6942";
          proxyWebsockets = true;
        };
      };
    };

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
