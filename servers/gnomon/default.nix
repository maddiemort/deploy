{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.arma-3-status-bot
    modules.direwolf20-s14
    modules.prometheus
    modules.promtail
    modules.tailscale
  ];

  custom.services.direwolf20-s14 = {
    enable = true;
    memory = 12288;
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
