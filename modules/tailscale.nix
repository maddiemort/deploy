{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.custom.services.tailscale;
in
{
  options = {
    custom.services.tailscale = {
      enable = mkEnableOption "Activate Tailscale on this host";
      trustInterface = mkEnableOption "Add tailscale0 to the firewall's trusted interfaces";

      authKey = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Name of the secret as declared to Age, without the .age extension";
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

  config = mkIf cfg.enable {
    services.tailscale.enable = true;

    age.secrets."${cfg.authKey.name}" = {
      inherit (cfg.authKey) file;
      owner = "root";
      group = "root";
    };

    # Allow the Tailscale UDP port through the firewall
    networking.firewall = {
      trustedInterfaces = optional cfg.trustInterface "tailscale0";
      allowedUDPPorts = [
        config.services.tailscale.port
      ];
    };

    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to tailscale";

      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";

      script = ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
          echo "already authenticated, doing nothing"
          exit 0
        fi

        # otherwise authenticate with tailscale
        echo "authenticating..."
        ${pkgs.tailscale}/bin/tailscale up -authkey file:${config.age.secrets."${cfg.authKey.name}".path}
      '';
    };
  };
}
