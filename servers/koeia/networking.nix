{ lib
, ...
}:

{
  networking = {
    nameservers = [
      "8.8.8.8"
    ];
    defaultGateway = "172.31.1.1";
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce false;
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          { address = "157.90.147.15"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "2a01:4f8:1c17:53dd::1"; prefixLength = 64; }
          { address = "fe80::9400:3ff:fe9d:c0ce"; prefixLength = 64; }
        ];
        ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
        ipv6.routes = [{ address = "fe80::1"; prefixLength = 128; }];
      };
    };
  };

  services.udev.extraRules = ''
    ATTR{address}=="96:00:03:9d:c0:ce", NAME="eth0"
  '';
}
