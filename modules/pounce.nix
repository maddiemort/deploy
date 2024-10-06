{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.pounce;

  server = types.submodule {
    options = {
      local-host = mkOption {
        type = types.str;
        description = "Host that this bouncer is hosted on";
      };
      remote-host = mkOption {
        type = types.str;
        description = "Host that this bouncer connects to";
      };
      acme-host = mkOption {
        type = types.str;
        description = "ACME host to use";
      };
      client-cert = mkOption {
        type = types.path;
        description = "Path to the client certificate used to connect to the remote host";
      };
      nick = mkOption {
        type = types.str;
        description = "IRC nickname";
      };
      real = mkOption {
        type = types.str;
        description = "IRC realname";
      };
    };
  };
in
{
  options = {
    custom.services.pounce = {
      enable = mkEnableOption "pounce IRC bouncer";

      external-port = mkOption {
        description = "Externally open port that clients should connect to";
        type = types.port;
        default = 6697;
      };

      calico-port = mkOption {
        description = "Internal Calico port";
        type = types.port;
        default = 6969;
      };

      local-ca = mkOption {
        type = types.path;
        description = "Path to the client certificate file that clients must authenticate against";
      };

      instances = mkOption {
        type = types.attrsOf server;
        description = "Servers to set up bouncers for";
        default = { };
      };
    };
  };

  config =
    let
      inherit (lib.attrsets) mapAttrs' mapAttrsToList;
      inherit (lib.modules) mkMerge;
    in
    mkIf cfg.enable {
      environment.etc = (mapAttrs'
        (name: instance: {
          name = "xdg/pounce/${name}";
          value = {
            text = ''
              local-cert = /var/lib/acme/${instance.local-host}/fullchain.pem
              local-priv = /var/lib/acme/${instance.local-host}/key.pem

              local-host = ${instance.local-host}
              host = ${instance.remote-host}

              client-cert = ${instance.client-cert}
              client-priv = ${instance.client-cert}
              sasl-external

              nick = ${instance.nick}
              real = ${instance.real}
            '';
          };
        })
        cfg.instances
      ) // {
        "xdg/pounce/defaults".text = ''
          local-ca = ${cfg.local-ca}
          local-path = /srv/pounce
        '';
      };

      users.groups.pounce = { };
      users.users.pounce = {
        description = "Pounce IRC bouncer user";
        home = "/srv/pounce";
        createHome = true;
        isSystemUser = true;
        group = "pounce";
        extraGroups = [ "keys" "nginx" ];
      };

      systemd.services = (mapAttrs'
        (name: instance: {
          name = "pounce-${name}";
          value = {
            description = "Pounce IRC Bouncer Service (${name})";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network.target"
              "acme-${instance.acme-host}.service"
            ];

            serviceConfig = {
              ExecStart = "${pkgs.pounce}/bin/pounce defaults ${name}";
              Restart = "always";
              User = "pounce";
              WorkingDirectory = "/srv/pounce";
            };
          };
        })
        cfg.instances
      ) // {
        calico = {
          description = "Calico IRC Dispatcher";
          wantedBy = [ "multi-user.target" ];
          after = mapAttrsToList
            (name: _: "pounce-${name}.service")
            cfg.instances;

          serviceConfig = {
            ExecStart = ''
              ${pkgs.pounce}/bin/calico \
                -P ${toString cfg.calico-port} \
                /srv/pounce
            '';
            Restart = "always";
            User = "pounce";
            WorkingDirectory = "/srv/pounce";
          };
        };
      };

      networking.firewall.allowedTCPPorts = [ 80 443 cfg.external-port ];

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;

        virtualHosts = (mapAttrs'
          (_: instance: {
            name = instance.local-host;
            value = {
              forceSSL = true;
              useACMEHost = instance.acme-host;
            };
          })
          cfg.instances
        ) // (mapAttrs'
          (_: instance: {
            name = instance.acme-host;
            value = {
              enableACME = true;
              forceSSL = true;
            };
          })
          cfg.instances);

        streamConfig = ''
          upstream calico {
            server 127.0.0.1:${toString cfg.calico-port};
          }

          server {
            listen ${toString cfg.external-port};
            listen [::0]:${toString cfg.external-port};

            proxy_pass calico;
          }
        '';
      };

      security.acme.certs = mkMerge (mapAttrsToList
        (_: instance: {
          "${instance.acme-host}" = {
            extraDomainNames = [ instance.local-host ];
          };
        })
        cfg.instances);
    };
}
