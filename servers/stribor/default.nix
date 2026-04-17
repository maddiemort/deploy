{modules, ...}: {
  imports = [
    ./configuration.nix

    modules.direwolf20
    modules.minecraft-almost-vanilla
    modules.prometheus
    modules.promtail
    modules.tailscale
    modules.terraria
  ];

  custom.services.minecraft-almost-vanilla = {
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
      name = "secrets/tailscale-stribor";
      file = ../../secrets/tailscale-stribor.age;
    };
  };

  custom.services.terraria = {
    enable = true;

    password = {
      name = "secrets/terraria-password";
      file = ../../secrets/terraria-password.age;
    };
  };
}
