{ pkgs
, system
, mkOverlays
, ...
}:

{
  environment.systemPackages = with pkgs; [
    neovim
  ];

  nix = {
    # gc.automatic = true;

    settings = {
      extra-experimental-features = "nix-command flakes";

      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      auto-optimise-store = true;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = builtins.map builtins.readFile [
    ../keys/maddie-ditto-c.pub
    ../keys/maddie-ditto.pub
    ../keys/maddie-wtf-c.pub
    ../keys/maddie-wtf.pub
    ../keys/maddiemort-deploy.pub
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = mkOverlays system;
  };

  # Reject HTTP requests to the root. This in particular also prevents requests to domains with
  # stale DNS records that still point to a server from succeeding even if there's no active virtual
  # host for that domain.
  services.nginx = {
    enable = true;
    virtualHosts = {
      "\"\"" = {
        default = true;
        rejectSSL = true;
        locations."/" = {
          return = "418";
        };
      };
    };
  };

  services.openssh.settings.PermitRootLogin = "prohibit-password";
  security.acme.acceptTerms = true;
}
