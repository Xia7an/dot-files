{ pkgs, ... }:

{
  home.packages = [ pkgs.unstable.claude-code ];

  # Claude Code の環境変数設定
  # DISABLE_AUTOUPDATER: Nix が更新を管理するため無効化（自動アップデートを抑制）
  # DISABLE_INSTALLATION_CHECKS: nix 経由のインストールであるため警告を抑制
  home.sessionVariables = {
    DISABLE_AUTOUPDATER = "1";
    DISABLE_INSTALLATION_CHECKS = "1";
  };

  # ~/.claude 設定ディレクトリ
  # 参考: https://docs.anthropic.com/en/docs/claude-code/overview
  # home.file.".claude/settings.json".text = builtins.toJSON {
  # 必要に応じて設定を追加
  # 例: API キーは環境変数 ANTHROPIC_API_KEY で設定推奨
  # };
}
