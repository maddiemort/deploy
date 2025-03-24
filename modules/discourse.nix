{ config
, lib
, modules
, ...
}:

let
  cfg = config.custom.services.discourse;

  inherit (lib) mkEnableOption mkIf mkOption types;
in
{
  imports = [
    modules.mailserver
  ];

  options = {
    custom.services.discourse = {
      enable = mkEnableOption "Discourse forum";

      hostname = mkOption {
        description = "The hostname for the forum";
        type = types.str;
      };

      title = mkOption {
        description = "The title of the forum";
        type = types.str;
      };

      acmeEmail = mkOption {
        description = "Email address for ACME certificate generation";
        type = types.str;
      };

      adminEmail = mkOption {
        description = "Email address for the admin account";
        type = types.str;
      };

      adminPassword = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the admin password for Discourse, as
                declared to Age, without the .age extension.
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

      secretKeyBase = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the secret key base for Discourse, as
                declared to Age, without the .age extension.
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

      noreplyPassword = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the password for the noreply email account,
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

      noreplyHashedPassword = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              description = ''
                Name of the agenix secret that contains the hashed password for the noreply email
                account, as declared to Age, without the .age extension.
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
    };
  };

  config = mkIf cfg.enable {
    age.secrets."${cfg.adminPassword.name}" = {
      inherit (cfg.adminPassword) file;
      owner = "discourse";
      group = "discourse";
    };

    age.secrets."${cfg.secretKeyBase.name}" = {
      inherit (cfg.secretKeyBase) file;
      owner = "discourse";
      group = "discourse";
    };

    age.secrets."${cfg.noreplyPassword.name}" = {
      inherit (cfg.noreplyPassword) file;
      owner = "discourse";
      group = "discourse";
    };

    security.acme.certs."${cfg.hostname}".email = cfg.acmeEmail;

    services.discourse = {
      inherit (cfg) enable hostname;

      admin = {
        email = cfg.adminEmail;
        username = "admin";
        fullName = "Administrator";
        passwordFile = config.age.secrets."${cfg.adminPassword.name}".path;
      };

      mail.outgoing = {
        serverAddress = "mail.${cfg.hostname}";
        port = 587;
        username = "noreply@${cfg.hostname}";
        passwordFile = config.age.secrets."${cfg.noreplyPassword.name}".path;
      };

      mail.incoming.enable = true;

      database = {
        ignorePostgresqlVersion = true;
      };

      secretKeyBaseFile = config.age.secrets."${cfg.secretKeyBase.name}".path;

      siteSettings = {
        required = {
          inherit (cfg) title;
          exclude_rel_nofollow_domains = "${cfg.hostname}";
        };
        basic_setup = {
          display_local_time_in_user_card = true;
          allow_user_locale = true;
          set_locale_from_accept_language_header = true;
        };
        login = {
          # invite_only = true;
          login_required = true;
          must_approve_users = true;
          enable_local_logins_via_email = true;
          # allow_new_registrations = false;
          enable_signup_cta = false;
          hide_email_address_taken = true;
        };
        users = {
          enable_user_directory = false;
          hide_user_profiles_from_public = true;
        };
      };
      backendSettings = { };
    };
  };
}
