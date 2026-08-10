{ pkgs, ... }: {
  # fish シェルを有効化
  # NixOS 側で users.users.<name>.shell = pkgs.fish として設定済み
  programs.fish = {
    enable = true;
    shellAliases = {
      grep = "rg";
      l = "ls -la";
      zj = "zellij";
    };
    shellInit = ''
      # PATH additions
      fish_add_path /Users/inoyu/.local/bin
      fish_add_path /Users/inoyu/.lmstudio/bin
      fish_add_path /Users/inoyu/.antigravity/antigravity/bin

      # 予測候補の色を薄くして実際の入力と区別しやすくする
      # Ghostty + Dracula テーマだと濃すぎるので明るめのグレーに
      set fish_color_autosuggestion 6b6b80

      # Tab補完の選択中候補を白地に黒でハイライト
      set fish_pager_color_selected_background white
      set fish_pager_color_selected_completion black
    '';
    shellAbbrs = {
      cduniv = "cd ~/Documents/大学/授業/3年前期/";
      ls = "eza --icons always --classify always";
      la = "eza --icons always --classify always --all";
      ll = "eza --icons always --long --all --git";
    };
    functions = {
      ya = {
        body = ''
          set tmp (mktemp -t "yazi-cwd.XXXXXX")
          yazi $argv --cwd-file="$tmp"
          if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
          end
          rm -f -- "$tmp"
        '';
      };
    };
  };
  home.sessionVariables = {
    UNIV = "$HOME/Documents/大学/授業/3年前期/";
  };
}
