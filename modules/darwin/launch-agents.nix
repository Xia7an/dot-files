{ ... }:
{
  # Raycast の「Launch at login」は SMAppService (Background Task Management)
  # 経由で登録されるため defaults では宣言できない。
  # ログイン時の起動を launchd で管理する。
  #
  # Raycast 本体は Homebrew cask (modules/darwin/homebrew/system.nix) で
  # /Applications に入る。
  launchd.user.agents.raycast = {
    serviceConfig = {
      # Launch Services 経由で起動し、既存インスタンスを再利用する。
      ProgramArguments = [ "/usr/bin/open" "-g" "/Applications/Raycast.app" ];
      LimitLoadToSessionType = [ "Aqua" ];
      RunAtLoad = true;
      # 手動で終了したら起動し直さない (常駐を強制しない)。
      KeepAlive = false;
      ProcessType = "Interactive";
    };
  };
}
