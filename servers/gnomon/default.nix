{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.hewwo
    modules.prometheus
    modules.promtail
    modules.tailscale
  ];

  custom.services.hewwo = {
    enable = false;
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
}
