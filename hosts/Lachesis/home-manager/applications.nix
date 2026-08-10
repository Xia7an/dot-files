# Lachesis 用アプリケーション設定
# nixpkgs で導入できない(または cask 版が実質標準の) GUI アプリだけ
# nix-darwin の Homebrew cask に残し、それ以外は Home Manager へ委譲する。
{
  imports = [
    # ─── macOS 自動化 / ウィンドウ管理 ───
    ../../../modules/Home/darwin/aquaskk.nix
    ../../../modules/Home/darwin/ice.nix

    # ─── AI ───
    # codex は CLI 単体で使う。
    # claude は native installer 版 (~/.local/bin/claude) をそのまま使う
    # (nvim の avante.nvim もこれを ACP 経由で叩く)。
    ../../../modules/Home/apps/ai/codex.nix
    ../../../modules/Home/apps/ai/opencode.nix

    # ─── マルチメディア / PDF ───
    ../../../modules/Home/apps/media/multimedia.nix
    ../../../modules/Home/apps/document/pdf.nix

    # ─── Nixpkgs で管理する GUI アプリ ───
    ../../../modules/Home/apps/vdesktop/immersed.nix
    ../../../modules/Home/apps/creative/blender.nix
    ../../../modules/Home/apps/creative/musescore.nix
    # discord / slack は Homebrew cask で管理する (modules/darwin/homebrew/applications.nix)
    ../../../modules/Home/apps/browser/chrome.nix
    ../../../modules/Home/apps/document/obsidian.nix
  ];
}
