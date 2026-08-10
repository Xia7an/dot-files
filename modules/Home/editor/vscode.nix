{
  pkgs,
  lib,
  config,
  ...
}:
let
  # VSCode のユーザーデータディレクトリ。darwin だけ ~/.config ではない。
  vscodeUserDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Code/User"
    else
      "${config.xdg.configHome}/Code/User";

  # modules/Home/development/tex.nix と同じ派生物 (nix store 上は同一実体)。
  texliveFull = pkgs.texlive.combined.scheme-full;

  userSettings = {
    "locale" = "ja";
    "editor.fontFamily" = "'HackGen Console NF'";
    "editor.fontSize" = 13;
    "editor.acceptSuggestionOnCommitCharacter" = false;
    "editor.inlineSuggest.enabled" = false;
    "keyboard.dispatch" = "keyCode";
    "chat.tools.global.autoApprove" = true;

    # 今後勝手に書き換わらないようにするための追加設定
    "extensions.autoCheckUpdates" = false;
    "extensions.autoUpdate" = false;
    "update.mode" = "none";

    # latex-workshop: VSCode.app を Dock/Spotlight から GUI 起動すると
    # fish の home.sessionPath を継承せず PATH に nix store が乗らないため、
    # latexmk はコマンド名ではなく nix store の絶対パスで直接指定する。
    "latex-workshop.latex.tools" = [
      {
        "name" = "latexmk";
        "command" = "${texliveFull}/bin/latexmk";
        "args" = [
          "-pdf"
          "-interaction=nonstopmode"
          "-synctex=1"
          "-outdir=%OUTDIR%"
          "%DOC%"
        ];
      }
    ];
    "latex-workshop.latex.recipes" = [
      {
        "name" = "latexmk";
        "tools" = [ "latexmk" ];
      }
    ];
    "latex-workshop.view.pdf.viewer" = "tab";
  };

  settingsJson = (pkgs.formats.json { }).generate "vscode-user-settings.json" userSettings;

  marketplaceExtensions = pkgs.unstable.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "vscode-sqlite";
      publisher = "alexcvzz";
      version = "0.14.1";
      sha256 = "1iaklnhw74iwyjw74prnrx34ba25ra7ld71zlip04lv401329r4c";
    }
    {
      name = "html-preview-vscode";
      publisher = "george-alisson";
      version = "0.2.5";
      sha256 = "1n41xb22cqpn0058qksyx1xp00zjx5gf8a497lhsnlain4sf2j6n";
    }
    # 日本語校正(textlint 内蔵、設定不要)
    {
      name = "japanese-proofreading";
      publisher = "ics";
      version = "1.3.0";
      sha256 = "1xwsr4c73xkr0rl8y73q3j2jdzyd9g1yzqa2z88a3afvwcmiwhah";
    }
    {
      name = "markdown-alert";
      publisher = "kejun";
      version = "0.0.4";
      sha256 = "1jfydk7fsfm760lfgs6igv2xfy62gna49pjq95dmx3cwvabyc8wd";
    }
    {
      name = "language-matlab";
      publisher = "mathworks";
      version = "1.3.10";
      sha256 = "1xn3zg65pwbm7iablxbwx3vpngipkqm7bjap2bvb9wpgbwksb002";
    }
    {
      name = "cpp-devtools";
      publisher = "ms-vscode";
      version = "0.5.13";
      sha256 = "0g2nmpvhfx2yrsb9k1qfrc66hghv1iabqms54hjal1qa91s5gil3";
    }
    {
      name = "cpptools-themes";
      publisher = "ms-vscode";
      version = "2.0.0";
      sha256 = "05r7hfphhlns2i7zdplzrad2224vdkgzb0dbxg40nwiyq193jq31";
    }
    {
      name = "vscode-websearchforcopilot";
      publisher = "ms-vscode";
      version = "0.1.4";
      sha256 = "1m791c502mnzgnz85ipc6v9wd1ay7c3hzdwgahzk2i6adz6inih3";
    }
    {
      name = "sqltools";
      publisher = "mtxr";
      version = "0.28.5";
      sha256 = "13za2a9s1jrl26rakfww4hf3pkvkvkkkqx76kji7flwdqr20366q";
    }
    {
      name = "sqltools-driver-mysql";
      publisher = "mtxr";
      version = "0.6.6";
      sha256 = "1ykkppirpq1rh2ac2j3zscgdz2fbs3add9ri1qp7pfcpi4r9lw9f";
    }
    {
      name = "vscode-paste-image";
      publisher = "mushan";
      version = "1.0.4";
      sha256 = "1wkplvrn31vly5gw35hlgpjpxgq3dzb16hz64xcf77bwcqfnpakb";
    }
    {
      name = "background";
      publisher = "shalldie";
      version = "2.0.10";
      sha256 = "15p3rqsvraiaq3x5xls565l9ysmiahqh9zf9y6cgzj5brl99qhys";
    }
    {
      name = "open-in-browser";
      publisher = "techer";
      version = "2.0.0";
      sha256 = "1s5mgw0jaasis0ish3da3dl7vqsgkx9cgrp1mmpgh9c4wlr12xnx";
    }
  ];

  # PlatformIO IDE は nixpkgs の vscode-extensions に無いので marketplace から取る。
  # VSIX がターゲットごとに分かれている (universal 版が存在しない) ため、
  # 本リポジトリで使う system ごとに arch と sha256 を持つ。
  # 未対応の system では eval が落ちるので、ホストを増やしたらここに追記すること。
  platformioTarget =
    {
      "aarch64-darwin" = {
        arch = "darwin-arm64";
        sha256 = "0avw9arqmfxcmvzmg8q9g6y24dy5p7kr7igimf3pnaqis8ky90lm";
      };
      "x86_64-linux" = {
        arch = "linux-x64";
        sha256 = "0saqkiaa5f8cnwlr5q51nnzmihx1w268wh7nrfqahh2bmrm85vhw";
      };
    }
    .${pkgs.stdenv.hostPlatform.system};

  platformioExtensions = pkgs.unstable.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "platformio-ide";
      publisher = "platformio";
      version = "3.3.4";
      inherit (platformioTarget) arch sha256;
    }
  ];

  darwinMarketplaceExtensions = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
    pkgs.unstable.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "vscode-python-envs";
        publisher = "ms-python";
        version = "1.30.0";
        sha256 = "1rh7pfc4v4rbqi115zszrx35dcm4vl4prhy9h0vb090yrxzh73rm";
        arch = "darwin-arm64";
      }
      # Typst は myriad-dreamin.tinymist に一本化。
      # nvarner.typst-lsp はアーカイブ済みで tinymist と診断が二重化するため入れない。
      # NOTE: 26.506.21252 に同梱の codex バイナリは OpenAI の Developer ID 証明書が
      # 失効しており (codesign --check-revocation → CSSMERR_TP_CERT_REVOKED)、
      # macOS が「マルウェア」ダイアログを出して起動を止める。
      # 26.5721.30844 は署名・notarization ともに有効なので、これより下げないこと。
      {
        name = "chatgpt";
        publisher = "openai";
        version = "26.5721.30844";
        sha256 = "1jl8h73h7z3a219d05ird2x4vhxvrfhmrbkbyq7aapqw0a80g0jl";
        arch = "darwin-arm64";
      }
    ]
  );

  vscodeWrapped = pkgs.unstable.vscode.overrideAttrs (old: {
    # ./bin/code を置き換える
    postFixup = ''
      wrapProgram $out/bin/code \
        # --add-flags "--ozone-platform=x11"
    '';
  });
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;

    # true (既定) だと HM は拡張機能を1個ずつ ~/.vscode/extensions に symlink し、
    # マニフェスト (extensions.json) の再生成を VSCode 任せにする。
    # この再生成は VSCode 側の .obsolete と競合して壊れやすく、実際に
    # extensions.json が1エントリまで削られて拡張機能が一切ロードされなくなった。
    # false にすると extensions.json 込みの buildEnv をディレクトリごと symlink するため、
    # VSCode に再生成させる必要がなくなる。代償として GUI からの拡張機能追加は不可
    # (このリポジトリでは全拡張を宣言的に管理しているので問題ない)。
    mutableExtensionsDir = false;

    profiles.default = {
      extensions =
        (with pkgs.unstable.vscode-extensions; [
          # General
          vscodevim.vim
          ms-ceintl.vscode-language-pack-ja
          usernamehw.errorlens
          ms-vscode.hexeditor
          wakatime.vscode-wakatime
          anthropic.claude-code

          # Nix / Web / Markdown
          bbenoist.nix
          biomejs.biome
          ecmel.vscode-html-css
          bierner.markdown-preview-github-styles
          shd101wyy.markdown-preview-enhanced

          # Python / Notebook
          ms-python.debugpy
          ms-python.python
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
          ms-toolsai.vscode-jupyter-cell-tags
          ms-toolsai.vscode-jupyter-slideshow

          # Native / Containers / Remote
          ms-azuretools.vscode-containers
          ms-vscode-remote.remote-containers
          ms-vscode-remote.remote-ssh
          ms-vscode-remote.remote-ssh-edit
          ms-vscode.remote-explorer
          ms-vscode.cmake-tools
          ms-vscode.cpptools
          ms-vscode.cpptools-extension-pack
          vadimcn.vscode-lldb
          twxs.cmake

          # Languages
          dart-code.dart-code
          dart-code.flutter
          github.vscode-github-actions
          hediet.vscode-drawio
          james-yu.latex-workshop
          mechatroner.rainbow-csv
          mhutchie.git-graph
          myriad-dreamin.tinymist
          redhat.java
          rust-lang.rust-analyzer
          tomoki1207.pdf
          vscjava.vscode-gradle
          vscjava.vscode-java-debug
          vscjava.vscode-java-dependency
          vscjava.vscode-java-pack
          vscjava.vscode-java-test
          vscjava.vscode-maven
        ])
        ++ marketplaceExtensions
        ++ platformioExtensions
        ++ darwinMarketplaceExtensions;

      # settings.json は home.file (= store への読み取り専用 symlink) にすると
      # VSCode が書き込めずエラーになるため、ここでは設定せず
      # home.activation.vscodeUserSettings で実ファイルとして配置する。

      keybindings = [
        # エディター(Vimノーマルモード)からエクスプローラーへ
        {
          key = "ctrl+shift+h";
          command = "workbench.view.explorer";
          when = "editorFocus && vim.mode == 'Normal'";
        }
        # ターミナルからエクスプローラーへ
        {
          key = "ctrl+shift+h";
          command = "workbench.view.explorer";
          when = "terminalFocus";
        }
        # エクスプローラーからエディターへ
        {
          key = "ctrl+shift+l";
          command = "workbench.action.focusActiveEditorGroup";
          when = "explorerViewletFocus && explorerViewletVisible && !inputFocus";
        }
        # エクスプローラーからターミナルへ
        {
          key = "ctrl+shift+j";
          command = "workbench.action.terminal.focus";
          when = "explorerViewletFocus && explorerViewletVisible && !inputFocus";
        }
        # エディター(Vimノーマルモード)からターミナルへ
        {
          key = "ctrl+shift+j";
          command = "workbench.action.terminal.focus";
          when = "editorFocus && explorerViewletVisible && vim.mode == 'Normal'";
        }
        # ターミナルからエディターへ
        {
          key = "ctrl+shift+k";
          command = "workbench.action.focusActiveEditorGroup";
          when = "terminalFocus";
        }
        # デフォルトキーバインドの無効化
        {
          key = "ctrl+shift+k";
          command = "-editor.action.deleteLines";
          when = "textInputFocus && !editorReadonly";
        }
        {
          key = "ctrl+shift+h";
          command = "-workbench.action.replaceInFiles";
        }
        {
          key = "ctrl+w";
          command = "-extension.vim_ctrl+w";
          when = "editorTextFocus && vim.active && vim.use<C-w> && !inDebugRepl";
        }
      ];
    };
  };
  # VSCode は通常操作の中で settings.json を書き換える (言語パックの再起動プロンプト、
  # 「今後表示しない」トグル、拡張機能の初回セットアップなど)。
  # home.file 経由だと settings.json が nix store への symlink = 読み取り専用になり、
  # 「ユーザー設定を書き込めません」と出たうえ差分の保存も失敗する。
  # そこで実ファイルとして配置し、切り替えのたびに宣言的な値だけを上書きマージする。
  # ここに書いていないキー (VSCode が勝手に足した値) はそのまま残る。
  home.activation.vscodeUserSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }''${PATH:+:}$PATH
    target="${vscodeUserDir}/settings.json"

    if [[ -v DRY_RUN ]]; then
      verboseEcho "Would merge VSCode user settings into $target"
    else
      mkdir -p "$(dirname "$target")"

      # 旧世代が残した store への symlink は実ファイルに置き換える
      if [ -L "$target" ]; then
        rm -f "$target"
      fi

      if [ -f "$target" ] && jq -e . "$target" > /dev/null 2>&1; then
        # 既存の値をベースに、宣言的な値で上書きする (宣言側が勝つ)
        jq -s '.[0] * .[1]' "$target" ${settingsJson} > "$target.hm-new"
      else
        # JSON として壊れている / コメント付きなどマージ不能な場合は退避して作り直す
        if [ -e "$target" ]; then
          mv "$target" "$target.hm-bak"
          verboseEcho "Could not parse $target as JSON, backed up to $target.hm-bak"
        fi
        cp ${settingsJson} "$target.hm-new"
      fi

      mv "$target.hm-new" "$target"
      chmod u+w "$target"
    fi
  '';

  xdg.configFile."code-flags.conf" = {
    text = ''
      --enable-wayland-ime
      --enable-features=UseOzonePlatform,WaylandWindowDecorations
      --ozone-platform=wayland
      --gtk-version=4
      --disable-features=WaylandTextInputV3
      --ime-mode=async
    '';
  };

  # NOTE: darwin では VSCode が読むのは ~/Library/Application Support/Code/User なので、
  # この xdg.configFile 版 (~/.config/Code/User) は mac 上では効いていない。
  # programs.vscode.profiles.default.userMcp に移すと両プラットフォームで正しい場所に置けるが、
  # 現行 mac の実ファイルには serena / brave-search / websearcher が手動で入っており、
  # 移行するとそれらが消えるため一旦保留。
  xdg.configFile."Code/User/mcp.json".text = builtins.toJSON {
    servers = {
      notionMCP = {
        command = "npx";
        args = [
          "-y"
          "mcp-remote"
          "https://mcp.notion.com/sse"
        ];
        type = "stdio";
      };
    };
    inputs = [ ];
  };

  # VSCode argv.json でIME設定を追加
  # home.file.".vscode/argv.json".text = builtins.toJSON {
  #   enable-crash-reporter = true;
  #   crash-reporter-id = "1a93b80d-ce8f-4f89-ab61-829c60f7e187";
  #   password-store = "basic";
  #   locale = "ja";
  #   disable-hardware-acceleration = false;
  #   enable-wayland-ime = true;
  # };
}
