{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

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

  services.teamspeak3 = {
    enable = true;
    dataDir = "/srv/teamspeak3-server";
    openFirewall = true;
  };
}
