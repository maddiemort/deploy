let
  inherit (builtins) mapAttrs readFile;

  # Public keys of specific machines.
  atria = readFile ./keys/atria.pub;
  gnomon = readFile ./keys/gnomon.pub;
  koeia = readFile ./keys/koeia.pub;
  stribor = readFile ./keys/stribor.pub;

  secrets = {
    "secrets/grafana-admin-password.age".publicKeys = [ koeia ];
    "secrets/tailscale-atria.age".publicKeys = [ atria ];
    "secrets/tailscale-gnomon.age".publicKeys = [ gnomon ];
    "secrets/tailscale-grafana.age".publicKeys = [ koeia ];
    "secrets/tailscale-koeia.age".publicKeys = [ koeia ];
    "secrets/tailscale-stribor.age".publicKeys = [ stribor ];
  };

  # Public keys of age-plugin-yubikey keys, the counterparts to the keygrips in
  # `./identities/*.txt`.
  #
  # These are not SSH keys, because those can't be used with agenix at the moment.
  maddie-ditto = "age1yubikey1qgeyg6v9kch8g0tu05ms05z40lv250eguy0ujep7em4l2hqvrd3uwtjm47u";
  maddie-ditto-c = "age1yubikey1q29q3ykjxvwxv6dmtldkxjuc2c0227x5lsknpvmxxk64nhggxc7dqzpnp0l";
  maddie-wtf = "age1yubikey1qdtdsjttgdcsfvu0g5n3vsf50e35ntcgjkjpd4d7hgzez8gk55rguc6tte7";
  maddie-wtf-c = "age1yubikey1q0cqe58rgzxjaky7nj3gzs6a9eujsu35lkchl9njlep80atwd6w4v3nu7pz";

  # Keys that should always be able to access every secret, so they can be used to access and
  # re-encrypt secrets.
  general = [
    maddie-ditto
    maddie-ditto-c
    maddie-wtf
    maddie-wtf-c
  ];
in
# Map each secret's `publicKeys` list to a new one that also includes `general`.
mapAttrs
  (_: secret: { publicKeys = secret.publicKeys ++ general; })
  secrets
