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

  age.secrets."secrets/discourse-noreply-hashed-password" = {
    file = ../../secrets/discourse-noreply-hashed-password.age;
    owner = "virtualMail";
    group = "virtualMail";
  };

  security.acme.certs."mail.forum.maddie.wtf".email = "admin@maddie.wtf";

  mailserver = {
    enable = true;
    fqdn = "mail.forum.maddie.wtf";
    domains = [ "forum.maddie.wtf" ];

    loginAccounts = {
      "noreply@forum.maddie.wtf" = {
        hashedPasswordFile = config.age.secrets."secrets/discourse-noreply-hashed-password".path;

        aliases = [
          "@forum.maddie.wtf"
        ];
      };
    };

    certificateScheme = "acme-nginx";
  };
}
