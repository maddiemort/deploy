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
    modules.zulip
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
      "atria"
      "gnomon"
      "koeia"
      "stribor"
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
    connectionString = {
      name = "secrets/vexillologist-connection-string";
      file = ../../secrets/vexillologist-connection-string.age;
    };
    discordToken = {
      name = "secrets/vexillologist-discord-token";
      file = ../../secrets/vexillologist-discord-token.age;
    };
  };

  custom.services.wirebrush = {
    enable = true;
    domain = "gemmat.dev";
    acme.email = "gemtipper@gmail.com";
  };

  custom.services.zulip = {
    enable = true;
    hostname = "chat.maddie.wtf";
    adminEmail = "admin@chat.maddie.wtf";

    databaseEnv = {
      name = "secrets/zulip-database-env";
      file = ../../secrets/zulip-database-env.age;
    };

    memcachedEnv = {
      name = "secrets/zulip-memcached-env";
      file = ../../secrets/zulip-memcached-env.age;
    };

    rabbitmqEnv = {
      name = "secrets/zulip-rabbitmq-env";
      file = ../../secrets/zulip-rabbitmq-env.age;
    };

    redisEnv = {
      name = "secrets/zulip-redis-env";
      file = ../../secrets/zulip-redis-env.age;
    };

    zulipEnv = {
      name = "secrets/zulip-zulip-env";
      file = ../../secrets/zulip-zulip-env.age;
    };

    jitsi = {
      enable = false;
      hostname = "meet.maddie.wtf";
    };
  };
}
