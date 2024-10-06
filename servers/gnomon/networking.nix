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
          { address = "142.132.232.247"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "2a01:4f8:c010:8519::1"; prefixLength = 64; }
          { address = "fe80::9400:2ff:fe72:a4d7"; prefixLength = 64; }
        ];
        ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
        ipv6.routes = [{ address = "fe80::1"; prefixLength = 128; }];
      };
    };

    firewall = {
      enable = true;

      checkReversePath = "loose";

      # Expose the SSH port to the public internet
      allowedTCPPorts = [ 22 ];
    };
  };

  services.udev.extraRules = ''
    ATTR{address}=="96:00:02:72:a4:d7", NAME="eth0"
  '';
}
