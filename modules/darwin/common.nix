{ inputs, pkgs, ... }:
{
  time.timeZone = "Asia/Tokyo";

  programs.zsh.enable = true;
  programs.fish.enable = true;

  # ログインシェルに指定できるよう /etc/shells に登録する。
  # 実際の切り替えは `chsh -s /run/current-system/sw/bin/fish` で行う
  # (macOS の既存ユーザーは nix-darwin の users.users.<name>.shell の対象外)。
  environment.shells = [ pkgs.fish ];

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    optimise.automatic = true;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # llm-agents.nix (AI エージェント一式) のビルド済みバイナリ
      substituters = [
        "https://cache.nixos.org/"
        "https://cache.numtide.com"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
  };

  system.stateVersion = 6;
}
