{ modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.grafana
    modules.promtail
    modules.maddie-wtf
    modules.tailscale
    modules.vexillologist
    modules.wirebrush
  ];

  custom.services.grafana = {
    enable = true;

    # bootstrap = true;
    # bootstrapDomain = "grafana.maddie.wtf";
    # bootstrapAcmeEmail = "me@maddie.wtf";

    tailscaleDomain = "penguin-bramble.ts.net";

    secrets = {
      adminPassword = {
        name = "secrets/grafana-admin-password";
        file = ../../secrets/grafana-admin-password.age;
      };

      tailscaleAuthkey = {
        name = "secrets/tailscale-grafana";
        file = ../../secrets/tailscale-grafana.age;
      };
    };
  };

  custom.services.prometheus = {
    nodes = [
      "gnomon"
      "koeia"
    ];

    nodeExporter.enable = true;
  };

  custom.services.promtail = {
    enable = true;
    loki.host = "127.0.0.1";
  };

  custom.services.maddie-wtf = {
    enable = true;
    acme.email = "me@maddie.wtf";
  };

  custom.services.tailscale = {
    enable = true;
    trustInterface = true;

    authKey = {
      name = "secrets/tailscale-koeia";
      file = ../../secrets/tailscale-koeia.age;
    };
  };

  custom.services.vexillologist = {
    enable = true;
  };

  custom.services.wirebrush = {
    enable = true;
    domain = "gemmat.dev";
    acme.email = "gemtipper@gmail.com";
  };
}
