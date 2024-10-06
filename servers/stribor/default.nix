{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.direwolf20
    modules.prometheus
    modules.promtail
    modules.tailscale
  ];

  custom.services.direwolf20 = {
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
      name = "secrets/tailscale-stribor";
      file = ../../secrets/tailscale-stribor.age;
    };
  };
}
