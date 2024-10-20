{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.arma-3-status-bot
    modules.five-blocks-apart
    modules.prometheus
    modules.promtail
    modules.tailscale
  ];

  custom.services.five-blocks-apart = {
    enable = true;
    memory = 6144;
  };

  custom.services.prometheus.nodeExporter.enable = true;

  custom.services.promtail = {
    enable = true;
    loki.host = "koeia";
  };

  custom.services.tailscale = {
    enable = true;
    trustInterface = true;

    authKey = {
      name = "secrets/tailscale-gnomon";
      file = ../../secrets/tailscale-gnomon.age;
    };
  };

  custom.services.arma-3-status-bot = {
    enable = true;

    discordToken = {
      name = "secrets/arma-3-status-discord-token";
      file = ../../secrets/arma-3-status-discord-token.age;
    };
    queryAddress = {
      name = "secrets/arma-3-status-query-address";
      file = ../../secrets/arma-3-status-query-address.age;
    };
  };

  services.teamspeak3 = {
    enable = true;
    dataDir = "/srv/teamspeak3-server";
    openFirewall = true;
  };
}
