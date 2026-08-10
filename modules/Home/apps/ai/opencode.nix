{ lib, pkgs, ... }:

let
  openUltraCode = pkgs.fetchzip {
    url = "https://github.com/norandom/OpenUltraCode/releases/download/v0.1.3/open-ultracode-release.tar.gz";
    hash = "sha256-NrwSSFhQuzgy6TzEVusUOGJp5WjYPpfEH+/VIWjlwoU=";
    stripRoot = false;
  };
in

{
  programs.opencode = {
    enable = true;
    package = pkgs.unstable.opencode;

    settings = {
      plugin = [ "${openUltraCode}/.opencode/plugins/open-ultracode.ts" ];
      skills.paths = [ "${openUltraCode}/.opencode/skills" ];
    };
  };

  home.file = {
    ".config/opencode/commands" = {
      source = "${openUltraCode}/.opencode/commands";
      recursive = true;
    };
    ".config/opencode/agents" = {
      source = "${openUltraCode}/.opencode/agents";
      recursive = true;
    };
  };

  # 旧shellモジュールが生成した通常ファイルは、モジュールを差し替えても
  # Home Managerが自動削除しないため、OpenCodeが旧設定を優先しないように除去する。
  home.activation.removeLegacyOpenCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.config/opencode/opencode.json"
    for legacy in "$HOME/.config/opencode"/oh-my-*.json*; do
      if [ -e "$legacy" ]; then
        rm -f "$legacy"
      fi
    done
  '';
}
