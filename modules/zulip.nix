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

      hostname = mkOption {
        description = "The root hostname Zulip will be hosted on";
        type = types.str;
      };

      adminEmail = mkOption {
        description = "Email address for the administrator";
        type = types.str;
      };

      databaseEnv = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the env file for the Zulip database
                container, as declared to Age, without the .age extension.
              '';
              type = types.str;
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };

      memcachedEnv = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the env file for the Zulip memcached
                container, as declared to Age, without the .age extension.
              '';
              type = types.str;
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };

      rabbitmqEnv = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the env file for the Zulip rabbitmq
                container, as declared to Age, without the .age extension.
              '';
              type = types.str;
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };

      redisEnv = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the env file for the Zulip redis container,
                as declared to Age, without the .age extension.
              '';
              type = types.str;
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };

      zulipEnv = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the env file for the Zulip zulip container,
                as declared to Age, without the .age extension.
              '';
              type = types.str;
            };

            file = mkOption {
              type = types.path;
              description = "Path to the encrypted Age secret";
            };
          };
        };
      };

      jitsi = mkOption {
        type = types.submodule {
          options = {
            enable = mkEnableOption "Jitsi Meet service for use with Zulip";

            hostname = mkOption {
              description = "The root hostname Jitsi Meet will be hosted on";
              type = types.str;
            };
          };
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.nginx = {
        enable = true;

        virtualHosts."${cfg.hostname}" = {
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

      services.cron = {
        enable = true;
        systemCronJobs = [
          "* * * * *   root podman exec -u zulip zulip /home/zulip/deployments/current/manage.py email_mirror"
        ];
      };

      security.acme.acceptTerms = true;
      security.acme.certs."${cfg.hostname}".email = cfg.adminEmail;

      age.secrets."${cfg.databaseEnv.name}" = {
        inherit (cfg.databaseEnv) file;
        owner = "root";
        group = "root";
      };

      age.secrets."${cfg.memcachedEnv.name}" = {
        inherit (cfg.memcachedEnv) file;
        owner = "root";
        group = "root";
      };

      age.secrets."${cfg.rabbitmqEnv.name}" = {
        inherit (cfg.rabbitmqEnv) file;
        owner = "root";
        group = "root";
      };

      age.secrets."${cfg.redisEnv.name}" = {
        inherit (cfg.redisEnv) file;
        owner = "root";
        group = "root";
      };

      age.secrets."${cfg.zulipEnv.name}" = {
        inherit (cfg.zulipEnv) file;
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
            config.age.secrets."${cfg.databaseEnv.name}".path
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
            config.age.secrets."${cfg.memcachedEnv.name}".path
          ];
        };

        rabbitmq = {
          image = "rabbitmq:4.0.7";
          hostname = "rabbitmq";

          environment = {
            RABBITMQ_DEFAULT_USER = "zulip";
          };

          environmentFiles = [
            config.age.secrets."${cfg.rabbitmqEnv.name}".path
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
            config.age.secrets."${cfg.redisEnv.name}".path
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

          environment = mkMerge [
            {
              DB_HOST = "database";
              DB_HOST_PORT = "5432";
              DB_USER = "zulip";
              LOADBALANCER_IPS = "157.90.147.15";
              SSL_CERTIFICATE_GENERATION = "self-signed";
              ZULIP_AUTH_BACKENDS = "EmailAuthBackend";

              SETTING_ADD_TOKENS_TO_NOREPLY_ADDRESS = "True";
              SETTING_EMAIL_GATEWAY_IMAP_FOLDER = "INBOX";
              SETTING_EMAIL_GATEWAY_IMAP_PORT = "993";
              SETTING_EMAIL_GATEWAY_IMAP_SERVER = "mail.${cfg.hostname}";
              SETTING_EMAIL_GATEWAY_LOGIN = "incoming@${cfg.hostname}";
              SETTING_EMAIL_GATEWAY_PATTERN = "incoming+%s@${cfg.hostname}";
              SETTING_EMAIL_HOST = "mail.${cfg.hostname}";
              SETTING_EMAIL_HOST_USER = "noreply@${cfg.hostname}";
              SETTING_EMAIL_PORT = "587";
              SETTING_EMAIL_USE_SSL = "False";
              SETTING_EMAIL_USE_TLS = "True";
              SETTING_EXTERNAL_HOST = cfg.hostname;
              SETTING_MEMCACHED_LOCATION = "memcached:11211";
              SETTING_NOREPLY_EMAIL_ADDRESS = "noreply@${cfg.hostname}";
              SETTING_PASSWORD_MAX_LENGTH = "128";
              SETTING_PASSWORD_MIN_LENGTH = "20";
              SETTING_RABBITMQ_HOST = "rabbitmq";
              SETTING_REDIS_HOST = "redis";
              SETTING_ZULIP_ADMINISTRATOR = cfg.adminEmail;
              SETTING_ZULIP_SERVICE_PUSH_NOTIFICATIONS = "False";
            }

            (mkIf cfg.jitsi.enable {
              SETTING_JITSI_SERVER_URL = "https://${cfg.jitsi.hostname}";
            })
          ];

          environmentFiles = [
            config.age.secrets."${cfg.zulipEnv.name}".path
          ];

          volumes = [
            "zulip:/data:rw"
          ];
        };
      };
    })

    (mkIf (cfg.enable && cfg.jitsi.enable) {
      services.jitsi-meet = {
        enable = true;
        nginx.enable = true;

        hostName = cfg.jitsi.hostname;
      };

      # There is a security warning about this package due to a potential issue in an upstream
      # cryptography library. This is not a concern for this service, so we're permitting the
      # insecure package to be built.
      #
      # Flake input updates will likely require the version number here to be updated.
      nixpkgs.config.permittedInsecurePackages = [
        "jitsi-meet-1.0.7952"
      ];

      security.acme.certs."${cfg.jitsi.hostname}".email = cfg.adminEmail;
    })
  ];
}
