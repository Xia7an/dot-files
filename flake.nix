{
  description = "Reproducible NixOS, nix-darwin, and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap-flake.url = "github:xremap/nix-flake";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux-nix = {
      url = "github:momeemt/tmux-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.noctalia-qs.follows = "noctalia-qs";
    };
    noctalia-qs = {
      url = "github:noctalia-dev/noctalia-qs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      hosts = import ./hosts { inherit inputs; };
      configurations = import ./lib/mk-configurations.nix { inherit inputs hosts; };

      inherit (configurations)
        darwinConfigurations
        homeConfigurations
        nixosConfigurations
        pkgsFor
        supportedSystems
        ;

      hostsFor = system: lib.filterAttrs (_: host: host.system == system) hosts;
    in
    {
      inherit darwinConfigurations homeConfigurations nixosConfigurations;

      # 外部に公開するのは自作パッケージの overlay のみ。
      # unstable の取り込みは本リポジトリ内部の都合なので公開しない。
      overlays.default = import ./modules/overlays/local-packages.nix;

      packages = lib.genAttrs supportedSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          inherit (pkgs) niri-taskbar;
          default = pkgs.niri-taskbar;
        }
      );

      formatter = lib.genAttrs supportedSystems (system: (pkgsFor system).nixfmt-rfc-style);

      checks = lib.genAttrs supportedSystems (
        system:
        let
          systemChecks = lib.mapAttrs' (
            name: host:
            lib.nameValuePair "${name}-system" (
              if host.kind == "darwin" then
                darwinConfigurations.${name}.system
              else
                nixosConfigurations.${name}.config.system.build.toplevel
            )
          ) (hostsFor system);

          homeChecks = lib.mapAttrs' (
            name: _: lib.nameValuePair "${name}-home" homeConfigurations."${name}Home".activationPackage
          ) (hostsFor system);
        in
        systemChecks // homeChecks
      );
    };
}
