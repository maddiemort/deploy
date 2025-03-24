{ config
, lib
, ...
}:

with lib;
let
  cfg = config.custom.services.zulip;
in
{
  options = {
    custom.services.zulip = {
      enable = mkEnableOption "Zulip server";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;

      virtualHosts."chat.maddie.wtf" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "https://127.0.0.1:36443";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header  X-Forwarded-For ''$proxy_add_x_forwarded_for;
            proxy_set_header  X-Forwarded-Proto ''$scheme;
            proxy_set_header  Host ''$host;
          '';
        };
      };
    };

    security.acme.acceptTerms = true;
    security.acme.certs."chat.maddie.wtf".email = "admin@maddie.wtf";

    age.secrets."secrets/zulip-database-env" = {
      file = ../secrets/zulip-database-env.age;
      owner = "root";
      group = "root";
    };

    age.secrets."secrets/zulip-memcached-env" = {
      file = ../secrets/zulip-memcached-env.age;
      owner = "root";
      group = "root";
    };

    age.secrets."secrets/zulip-rabbitmq-env" = {
      file = ../secrets/zulip-rabbitmq-env.age;
      owner = "root";
      group = "root";
    };

    age.secrets."secrets/zulip-redis-env" = {
      file = ../secrets/zulip-redis-env.age;
      owner = "root";
      group = "root";
    };

    age.secrets."secrets/zulip-zulip-env" = {
      file = ../secrets/zulip-zulip-env.age;
      owner = "root";
      group = "root";
    };

    virtualisation.podman.defaultNetwork.settings = {
      # This is necessary so that the containers are able to talk to each other via hostname.
      dns_enabled = true;
    };

    virtualisation.oci-containers.containers = {
      database = {
        image = "zulip/zulip-postgresql:14";
        hostname = "database";

        environment = {
          POSTGRES_DB = "zulip";
          POSTGRES_USER = "zulip";
        };

        environmentFiles = [
          # Note that you need to do a manual `ALTER ROLE` query if you change this on a system
          # after booting the postgres container the first time on a host. Instructions are
          # available in README.md.
          config.age.secrets."secrets/zulip-database-env".path
        ];

        volumes = [
          "zulip-postgresql-14:/var/lib/postgresql/data:rw"
        ];
      };

      memcached = {
        image = "memcached:alpine";
        hostname = "memcached";

        cmd = [
          "sh"
          "-euc"
          ''
            echo 'mech_list: plain' > "''$SASL_CONF_PATH"
            echo "zulip@''$HOSTNAME:''$MEMCACHED_PASSWORD" > "''$MEMCACHED_SASL_PWDB"
            echo "zulip@localhost:''$MEMCACHED_PASSWORD" >> "''$MEMCACHED_SASL_PWDB"
            exec memcached -S
          ''
        ];

        environment = {
          SASL_CONF_PATH = "/home/memcache/memcached.conf";
          MEMCACHED_SASL_PWDB = "/home/memcache/memcached-sasl-db";
        };

        environmentFiles = [
          config.age.secrets."secrets/zulip-memcached-env".path
        ];
      };

      rabbitmq = {
        image = "rabbitmq:4.0.7";
        hostname = "rabbitmq";

        environment = {
          RABBITMQ_DEFAULT_USER = "zulip";
        };

        environmentFiles = [
          config.age.secrets."secrets/zulip-rabbitmq-env".path
        ];

        volumes = [
          "rabbitmq:/var/lib/rabbitmq:rw"
        ];
      };

      redis = {
        image = "redis:alpine";
        hostname = "redis";

        cmd = [
          "sh"
          "-euc"
          ''
            echo "requirepass ''$REDIS_PASSWORD" > /etc/redis.conf
            exec redis-server /etc/redis.conf
          ''
        ];

        environmentFiles = [
          config.age.secrets."secrets/zulip-redis-env".path
        ];

        volumes = [
          "redis:/data:rw"
        ];
      };

      zulip = {
        dependsOn = [
          "database"
          "memcached"
          "rabbitmq"
          "redis"
        ];

        image = "immortalvision/zulip-arm:10.1-0";

        ports = [
          "3680:80"
          "36443:443"
        ];

        environment = {
          DB_HOST = "database";
          DB_HOST_PORT = "5432";
          DB_USER = "zulip";
          SSL_CERTIFICATE_GENERATION = "self-signed";
          SETTING_MEMCACHED_LOCATION = "memcached:11211";
          SETTING_RABBITMQ_HOST = "rabbitmq";
          SETTING_REDIS_HOST = "redis";

          SETTING_EXTERNAL_HOST = "chat.maddie.wtf";
          SETTING_ZULIP_ADMINISTRATOR = "admin@maddie.wtf";
          SETTING_EMAIL_HOST = "mail.chat.maddie.wtf";
          SETTING_EMAIL_HOST_USER = "noreply@chat.maddie.wtf";
          SETTING_EMAIL_PORT = "587";
          SETTING_EMAIL_USE_SSL = "False";
          SETTING_EMAIL_USE_TLS = "True";
          SETTING_ADD_TOKENS_TO_NOREPLY_ADDRESS = "True";
          SETTING_ZULIP_SERVICE_PUSH_NOTIFICATIONS = "False";
          SETTING_PASSWORD_MIN_LENGTH = "20";
          SETTING_PASSWORD_MAX_LENGTH = "128";
          ZULIP_AUTH_BACKENDS = "EmailAuthBackend";

          LOADBALANCER_IPS = "157.90.147.15";
        };

        environmentFiles = [
          config.age.secrets."secrets/zulip-zulip-env".path
        ];

        volumes = [
          "zulip:/data:rw"
        ];
      };
    };
  };
}
