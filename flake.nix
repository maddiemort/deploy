{
  description = "Unified deployment configuration flake";

  nixConfig.extra-deprecated-features = "url-literals";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils/main";

    nixpkgs-graalvm-oracle-23.url = "github:nixos/nixpkgs/3f078e4";

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

    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-24.11";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nixos-mailserver.inputs.nixpkgs-24_11.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-graalvm-oracle-23,
    flake-utils,
    ...
  } @ inputs: let
    inherit (nixpkgs.lib) nixosSystem;
    inherit (flake-utils.lib) eachDefaultSystem;

    config = {
      allowUnfree = true;

      # There is a security warning about this package (used by Jitsi Meet, which is set up in
      # combination with Zulip) due to a potential issue in an upstream cryptography library. This
      # is not a concern for this service, so we're permitting the insecure package to be built.
      #
      # Flake input updates will likely require the version number here to be updated.
      permittedInsecurePackages = [
        "jitsi-meet-1.0.8792"
      ];
    };

    mkOverlays = system: [
      inputs.agenix.overlays.default

      (final: prev: let
        unstable = import nixpkgs-unstable {
          inherit config system;
        };
        graalvm-oracle-23 = import nixpkgs-graalvm-oracle-23 {
          inherit config system;
        };
      in {
        inherit
          (unstable)
          alejandra
          anubis
          grafana
          jitsi-excalidraw
          jitsi-meet
          jitsi-meet-prosody
          jre21_minimal
          loki
          minecraftServers
          # nix
          prometheus
          prometheus-node-exporter
          # prosody
          tempo
          terraria-server
          ;

        graalvm-oracle_23 = graalvm-oracle-23.graalvmPackages.graalvm-oracle_23;

        tailscale = unstable.tailscale.overrideAttrs (old: {
          subPackages =
            old.subPackages
            ++ [
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

    mkPkgs = system:
      import nixpkgs {
        inherit config system;
        overlays = mkOverlays system;
      };

    mkSystem = system: module:
      nixosSystem {
        inherit system;
        pkgs = mkPkgs system;
        modules = [
          inputs.agenix.nixosModules.age
          module
          ./servers/common.nix
        ];
        specialArgs = {
          inherit inputs;
          modules =
            self.nixosModules
            // {
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
        sshOpts = ["-F" "/dev/null"];

        nodes = {
          atria = mkNode "x86_64-linux" self.nixosConfigurations.atria;
          gnomon = mkNode "x86_64-linux" self.nixosConfigurations.gnomon;
          koeia = mkNode "aarch64-linux" self.nixosConfigurations.koeia;
          stribor = mkNode "x86_64-linux" self.nixosConfigurations.stribor;
        };
      };
    }
    // eachDefaultSystem (system: let
      pkgs = mkPkgs system;
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          age-plugin-yubikey
          agenix
          deploy-rs
        ];
      };

      formatter = pkgs.alejandra;
    });
}
