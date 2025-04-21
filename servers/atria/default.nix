{ config
, modules
, ...
}:

{
  imports = [
    ./configuration.nix

    modules.mailserver
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

  age.secrets."secrets/zulip-noreply-hashed-password" = {
    file = ../../secrets/zulip-noreply-hashed-password.age;
    owner = "virtualMail";
    group = "virtualMail";
  };

  age.secrets."secrets/zulip-incoming-hashed-password" = {
    file = ../../secrets/zulip-incoming-hashed-password.age;
    owner = "virtualMail";
    group = "virtualMail";
  };

  security.acme.certs."mail.chat.maddie.wtf".email = "admin@maddie.wtf";

  mailserver = {
    enable = true;
    fqdn = "mail.chat.maddie.wtf";
    domains = [ "chat.maddie.wtf" ];

    loginAccounts = {
      "noreply@chat.maddie.wtf" = {
        hashedPasswordFile = config.age.secrets."secrets/zulip-noreply-hashed-password".path;

        aliasesRegexp = [
          "/^noreply-.*@chat\\.maddie\\.wtf$/"
          "/^admin@maddie\\.wtf$/"
        ];

        sendOnly = true;
      };

      "incoming@chat.maddie.wtf" = {
        hashedPasswordFile = config.age.secrets."secrets/zulip-incoming-hashed-password".path;

        aliasesRegexp = [
          "/^incoming\\+.*@chat\\.maddie\\.wtf$/"
        ];
      };
    };

    forwards = {
      "admin@maddie.wtf" = "me@maddie.wtf";
    };

    certificateScheme = "acme-nginx";
  };
}
