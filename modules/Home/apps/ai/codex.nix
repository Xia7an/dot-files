{
  inputs,
  pkgs,
  ...
}:

let
  codexPackage = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # codex-cli-nix の native 版は最終的に `codex-raw` として実行される。
  # Herdr はプロセス名だけではこれを Codex と判定できないため、Herdr が
  # macOS/Linux のプロセス環境から読む公式の foreground-process hint を渡す。
  codexWithHerdrHint = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      export HERDR_AGENT=codex
      exec "${codexPackage}/bin/codex" "$@"
    '';
  };
in
{
  home.packages = [
    codexWithHerdrHint
  ];
}
