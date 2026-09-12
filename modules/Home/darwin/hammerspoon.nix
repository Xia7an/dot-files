# Hammerspoon 本体は nix-darwin の Homebrew cask で管理する。
{
  home.file.".hammerspoon/init.lua".text = ''
    -- Hammerspoon 設定
    hs.autoLaunch(true)
    hs.automaticallyCheckForUpdates(true)

    aerospaceWindowGrid = require("aerospace-window-grid").start()
  '';

  home.file.".hammerspoon/aerospace-window-grid.lua".source =
    ../../../config/hammerspoon/aerospace-window-grid.lua;
}
