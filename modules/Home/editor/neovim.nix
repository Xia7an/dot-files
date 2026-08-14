{ lib, pkgs, ... }:

let
  # nvim-treesitter は main ブランチに移行済みで、パーサは runtimepath 全体ではなく
  # `install_dir`(既定 ~/.local/share/nvim/site) 直下の parser/ と queries/ しか
  # 見ない (lua/nvim-treesitter/config.lua の get_installed)。
  # nixpkgs の grammar derivation はちょうどこのレイアウト(parser/*.so + queries/<lang>/)
  # で出力されるので、symlinkJoin したものをそのまま install_dir として渡す。
  # これをやらないと LazyVim が「未インストール」と判定して :TSInstall を走らせ、
  # コンパイラとネットワークを要求してしまう。
  treesitterParsers = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = pkgs.unstable.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
  };

  # nvim-lint は upstream が codeberg.org に移動したが、Nix ビルダからの git
  # フェッチが Codeberg の abuse mitigation に 403 で弾かれてビルドできない
  # (ブラウザからは 200 なので Codeberg 自体が落ちているわけではない)。
  # 同じ commit が GitHub ミラーにもあるので src だけ差し替える。
  # Codeberg 側が復旧したら削除して素の vimPlugins.nvim-lint に戻せる。
  nvim-lint = pkgs.unstable.vimPlugins.nvim-lint.overrideAttrs (_: {
    src = pkgs.fetchFromGitHub {
      owner = "mfussenegger";
      repo = "nvim-lint";
      rev = "a219b2c9e5b4765e5c845aba119dad55806fcaf1";
      hash = "sha256-pABhzTRkcxAT/ELeltz47eCAKCnzdoCtc2QRu3wm0xU=";
    };
  });

  # avante.nvim は Rust 製のコアライブラリ (avante_templates など) を require するが、
  # nixpkgs は macOS 向けにこれを lua/*.dylib という名前で出力する。
  # 一方 Neovim の Lua ローダが runtimepath から探すのは lua/?.so だけなので、
  # そのままだと require に失敗し avante 側が「ビルドしていない」と判断して落ちる。
  # .so の別名を張って両方から見えるようにする。
  avante-nvim = pkgs.unstable.vimPlugins.avante-nvim.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      for dylib in $out/lua/*.dylib; do
        ln -s "$dylib" "''${dylib%.dylib}.so"
      done
    '';
  });

  # markdown-table-wrap.nvim はまだ nixpkgs に収録されていないため、upstream の
  # commit を固定して取り込む。nixpkgs に追加されたら vimPlugins のものへ置換できる。
  markdown-table-wrap-nvim = pkgs.unstable.vimUtils.buildVimPlugin {
    pname = "markdown-table-wrap.nvim";
    version = "unstable-2026-08-14";
    src = pkgs.fetchFromGitHub {
      owner = "ice345";
      repo = "markdown-table-wrap.nvim";
      rev = "f2c31f3c22f79ef4fb9d3d9f6356310c8c13fe52";
      hash = "sha256-09e5UwdldlSRv8i0LtjIbovflRaolQXiGDx+pzJVQm0=";
    };
  };
in

{
  home.packages = with pkgs; [
    ghostscript
    mermaid-cli
  ];

  programs.neovim = {
    enable = true;
    # プラグインと treesitter パーサを unstable から取るため、本体も unstable に揃える。
    # (programs.neovim.package の既定は pkgs.neovim-unwrapped = stable なので明示が必要)
    package = pkgs.unstable.neovim-unwrapped;

    # mason.nvim を無効化しているぶん、LSP/フォーマッタ/リンタは全て PATH から供給する。
    extraPackages = with pkgs.unstable; [
      # LazyVim 本体
      lua-language-server
      stylua
      shfmt
      # snacks picker / grug-far / LazyVim の git 連携
      ripgrep
      fd
      lazygit
      tree-sitter
      # extras: lang.clangd
      clang-tools
      # extras: lang.docker
      dockerfile-language-server
      docker-compose-language-service
      hadolint
      # extras: lang.nix
      nil
      nixfmt
      statix
      # extras: lang.python
      pyright
      ruff
      # extras: lang.rust
      rust-analyzer
      # extras: lang.typescript (+ biome)
      vtsls
      biome
      # 独自: plugins/avante.lua (provider = "claude-code")
      # avante が ACP で起動するアダプタ。claude 本体は PATH のものを使う
      claude-agent-acp
      # 独自: plugins/image.lua (processor = "magick_cli")
      imagemagick
      # 独自: plugins/typst.lua
      typst
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      # macOS: 独自 plugins/im-select.lua の default_command
      macism
    ];

    # lazy.nvim 本体だけ runtimepath に置き、残りは下の dev.path 経由で読ませる。
    plugins = with pkgs.unstable.vimPlugins; [
      lazy-nvim
    ];

    extraLuaConfig =
      let
        # 実機 (~/.config/nvim/lazy-lock.json) に入っているプラグインと 1:1 で対応させる。
        # lazy.nvim は spec の名前 (= lazy-lock.json のキー) で dev.path 配下を探すため、
        # linkFarm のエントリ名をその名前に揃える必要がある。
        # lib.getName が期待どおりの名前を返さないもの (catppuccin と mini.nvim 由来の
        # サブモジュール) だけ手で名前を付けている。
        plugins = with pkgs.unstable.vimPlugins; [
          LazyVim
          # `with pkgs.unstable.vimPlugins` に上書きされないよう明示的に let 側の
          # override を指す
          { name = "avante.nvim"; path = avante-nvim; }
          blink-cmp
          # extras/ai/avante.lua が blink.cmp の specs に足すので実体が要る
          blink-cmp-avante
          bufferline-nvim
          clangd_extensions-nvim
          conform-nvim
          crates-nvim
          flash-nvim
          friendly-snippets
          gitsigns-nvim
          grug-far-nvim
          im-select-nvim
          image-nvim
          img-clip-nvim
          lazydev-nvim
          lualine-nvim
          { name = "markdown-table-wrap.nvim"; path = markdown-table-wrap-nvim; }
          noice-nvim
          nui-nvim
          # `with pkgs.unstable.vimPlugins` に上書きされないよう明示的に let 側の
          # override を指す
          { name = "nvim-lint"; path = nvim-lint; }
          nvim-lspconfig
          nvim-surround
          nvim-treesitter
          nvim-treesitter-textobjects
          nvim-ts-autotag
          nvim-web-devicons
          persistence-nvim
          plenary-nvim
          render-markdown-nvim
          rustaceanvim
          snacks-nvim
          todo-comments-nvim
          tokyonight-nvim
          trouble-nvim
          ts-comments-nvim
          typst-vim
          venv-selector-nvim
          which-key-nvim
          { name = "catppuccin"; path = catppuccin-nvim; }
          { name = "mini.ai"; path = mini-nvim; }
          { name = "mini.icons"; path = mini-nvim; }
          { name = "mini.pairs"; path = mini-nvim; }
        ];
        mkEntryFromDrv = drv:
          if lib.isDerivation drv then
            { name = "${lib.getName drv}"; path = drv; }
          else
            drv;
        lazyPath = pkgs.unstable.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins);
      in
      ''
        require("lazy").setup({
          defaults = {
            -- LazyVim 側のプラグインだけ遅延し、lua/plugins/ の自作 spec は起動時に読む
            -- (LazyVim starter の既定と同じ)
            lazy = false,
          },
          dev = {
            -- pkgs.unstable.vimPlugins.* の実体を再利用する
            path = "${lazyPath}",
            patterns = { "" },
            -- dev.path に無いものだけ GitHub から取得する保険
            fallback = true,
          },
          install = {
            colorscheme = { "tokyonight", "habamax" },
          },
          checker = {
            -- プラグインは flake.lock で固定されており lazy からは更新できないため無効化
            enabled = false,
          },
          rocks = {
            -- luarocks(hererocks) の実行時インストールは再現性を壊すので使わない。
            -- image.nvim は processor = "magick_cli" 運用なので magick rock は不要。
            enabled = false,
          },
          performance = {
            rtp = {
              disabled_plugins = {
                "gzip",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
              },
            },
          },
          spec = {
            { "LazyVim/LazyVim", import = "lazyvim.plugins" },

            -- 実機の ~/.config/nvim/lazyvim.json で有効化されている extras。
            -- lazyvim.json は LazyVim が実行時に書き換えるファイルなので、
            -- nix からは spec に直接 import して宣言的に固定する。
            -- ai.avante は右サイドの AI エージェントパネル
            -- (プロバイダなどの調整は lua/plugins/avante.lua)
            { import = "lazyvim.plugins.extras.ai.avante" },
            { import = "lazyvim.plugins.extras.lang.clangd" },
            { import = "lazyvim.plugins.extras.lang.docker" },
            { import = "lazyvim.plugins.extras.lang.git" },
            { import = "lazyvim.plugins.extras.lang.nix" },
            { import = "lazyvim.plugins.extras.lang.python" },
            { import = "lazyvim.plugins.extras.lang.rust" },
            { import = "lazyvim.plugins.extras.lang.typescript" },
            { import = "lazyvim.plugins.extras.lang.typescript.biome" },

            -- 以下は LazyVim を nix 上で動かすための調整
            -- mason.nvim は使わず programs.neovim.extraPackages で供給する
            { "mason-org/mason.nvim", enabled = false },
            { "mason-org/mason-lspconfig.nvim", enabled = false },
            -- blink.cmp は nixpkgs 版に Rust 製 fuzzy ライブラリが同梱済み
            {
              "saghen/blink.cmp",
              build = false,
              opts = { fuzzy = { prebuilt_binaries = { download = false } } },
            },

            -- カーソル下の Markdown 表を、元のソースを変更せず罫線付きで表示する。
            -- 表にいる間だけ nowrap にすることで、長い表の崩れを防ぐ。
            {
              "ice345/markdown-table-wrap.nvim",
              ft = { "markdown", "quarto", "rmd" },
              opts = {
                preview_mode = "inline",
                inline_mode = "replace",
                auto_preview = true,
                render_all = false,
                clear_on_cursor_leave = true,
                clear_on_insert = true,
                clear_on_visual = true,
                inline_disable_wrap = true,
                inline_wrap_scope = "cursor",
                fit_to_window = false,
                table_border = "rounded",
                row_separator = true,
              },
            },

            -- 自作 spec (xdg.configFile."nvim/lua" 経由)
            { import = "plugins" },

            -- treesitter パーサを nix store から供給する。
            -- ensure_installed を潰す代わりに install_dir を差し替えることで、
            -- LazyVim 側の「未インストールなら :TSInstall」判定を満たす。
            -- spec の最後に置いて確実に上書きさせる。
            {
              "nvim-treesitter/nvim-treesitter",
              build = false,
              opts = { install_dir = "${treesitterParsers}" },
            },
          },
        })
      '';
  };

  # LazyVim 標準の設定置き場, see https://github.com/LazyVim/starter/tree/main/lua
  xdg.configFile."nvim/lua".source = ./lua;
  xdg.configFile."nvim/stylua.toml".source = ./stylua.toml;
}
