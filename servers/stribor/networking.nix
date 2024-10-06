{ lib
, ...
}:

{
  networking = {
    firewall = {
      enable = true;

      checkReversePath = "loose";

      # Expose the SSH port to the public internet
      allowedTCPPorts = [ 22 ];
    };
  };
}
