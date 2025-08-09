{ modules
, pkgs
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

  services.minecraft-server = {
    enable = true;
    declarative = false;
    eula = true;
    dataDir = "/srv/minecraft";
    openFirewall = true;
    # This should currently be 1.21.8
    package = pkgs.minecraftServers.vanilla-1-21;
    jvmOpts = ''
      -Xms6144M -Xmx6144M
    '';
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
