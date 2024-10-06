{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.prometheus
    modules.promtail
    modules.tailscale
  ];

  custom.services.prometheus.nodeExporter.enable = true;

  custom.services.promtail = {
    enable = true;
    loki.host = "koeia";
  };

  custom.services.tailscale = {
    enable = true;
    trustInterface = true;

    authKey = {
      name = "secrets/tailscale-atria";
      file = ../../secrets/tailscale-atria.age;
    };
  };
}
