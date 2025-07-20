{
  description = "Unified deployment configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils/main";

    deploy-rs.url = "github:serokell/deploy-rs/master";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";

    # Secrets management that avoids putting unencrypted secrets in the Nix store.
    agenix.url = "github:ryantm/agenix/main";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # Site for deployment to maddie.wtf.
    maddie-wtf.url = "github:maddiemort/maddie-wtf/main";
    maddie-wtf.inputs.flake-utils.follows = "flake-utils";

    maddie-wtf-content.url = "git+ssh://git@github.com/maddiemort/maddie-wtf-content.git";
    maddie-wtf-content.flake = false;

    onehalf.follows = "maddie-wtf/onehalf";

    wirebrush.url = "github:gememma/wirebrush/main";
    wirebrush.inputs.nixpkgs.follows = "nixpkgs";
    wirebrush.inputs.flake-utils.follows = "flake-utils";

    vexillologist.url = "github:maddiemort/vexillologist/v1.5.0";
    vexillologist.inputs.nixpkgs.follows = "nixpkgs-unstable";
    vexillologist.inputs.flake-utils.follows = "flake-utils";

    arma-3-status-bot.url = "github:maddiemort/arma-3-status-bot/main";
    arma-3-status-bot.inputs.nixpkgs.follows = "nixpkgs-unstable";
    arma-3-status-bot.inputs.flake-utils.follows = "flake-utils";

    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-24.05";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nixos-mailserver.inputs.nixpkgs-24_05.follows = "nixpkgs";
    nixos-mailserver.inputs.utils.follows = "flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , flake-utils
    , ...
    } @ inputs:
    let
      inherit (nixpkgs.lib) nixosSystem;
      inherit (flake-utils.lib) eachDefaultSystem;

      mkOverlays = system: [
        inputs.agenix.overlays.default

        (final: prev:
          let
            unstable = import nixpkgs-unstable {
              inherit system;
            };
          in
          {
            inherit (unstable)
              anubis
              grafana
              loki
              prometheus
              prometheus-node-exporter
              tempo
              ;

            tailscale = unstable.tailscale.overrideAttrs (old: {
              subPackages = old.subPackages ++ [
                "cmd/proxy-to-grafana"
              ];
            });
          })

        (final: prev: {
          deploy-rs = inputs.deploy-rs.packages.${system}.deploy-rs;

          maddie-wtf = inputs.maddie-wtf.packages.${system}.maddie-wtf;
          maddie-wtf-static = inputs.maddie-wtf.packages.${system}.maddie-wtf-static;
          onehalf = inputs.onehalf;

          maddie-wtf-content = inputs.maddie-wtf-content;

          wirebrush = inputs.wirebrush.packages.${system}.wirebrush;
          wirebrush-content = inputs.wirebrush.packages.${system}.content;
          wirebrush-static = inputs.wirebrush.packages.${system}.static;

          vexillologist = inputs.vexillologist.packages.${system}.default;

          arma-3-status-bot = inputs.arma-3-status-bot.packages.${system}.default;
        })
      ];

      mkSystem = system: config: nixosSystem {
        inherit system;
        modules = [
          inputs.agenix.nixosModules.age
          config
          ./servers/common.nix
        ];
        specialArgs = {
          inherit inputs mkOverlays system;
          modules = self.nixosModules // {
            mailserver = inputs.nixos-mailserver.nixosModules.mailserver;
          };
        };
      };

      mkNode = system: nixosConfig: {
        hostname = nixosConfig.config.networking.hostName;
        profiles.system.user = "root";
        profiles.system.path = inputs.deploy-rs.lib.${system}.activate.nixos nixosConfig;
      };
    in
    {
      nixosConfigurations = {
        atria = mkSystem "x86_64-linux" (import ./servers/atria);
        gnomon = mkSystem "x86_64-linux" (import ./servers/gnomon);
        koeia = mkSystem "aarch64-linux" (import ./servers/koeia);
        stribor = mkSystem "x86_64-linux" (import ./servers/stribor);
      };

      nixosModules = import ./modules;

      deploy = {
        magicRollback = true;
        autoRollback = true;
        remoteBuild = true;
        sshUser = "root";
        sshOpts = [ "-F" "/dev/null" ];

        nodes = {
          atria = mkNode "x86_64-linux" self.nixosConfigurations.atria;
          gnomon = mkNode "x86_64-linux" self.nixosConfigurations.gnomon;
          koeia = mkNode "aarch64-linux" self.nixosConfigurations.koeia;
          stribor = mkNode "x86_64-linux" self.nixosConfigurations.stribor;
        };
      };
    } // eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = mkOverlays system;
      };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          age-plugin-yubikey
          agenix
          deploy-rs
        ];
      };

      formatter = pkgs.nixpkgs-fmt;
    });
}
