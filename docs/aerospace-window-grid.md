# AeroSpace workspace window grid

Option + Tab で、現在の AeroSpace ワークスペース内のウィンドウをグリッド表示する。
Tab は離してよく、Option を押している間は一覧を表示し続ける。

| 操作 | 動作 |
| --- | --- |
| Option + Tab | 一覧を開く。初期選択は現在のウィンドウ |
| h / j / k / l、矢印キー | 左 / 下 / 上 / 右へ選択を移動 |
| Tab を離す | 一覧を維持し、引き続き選択できる |
| Option を離す | 選択したウィンドウにフォーカスして閉じる |
| Esc | フォーカスを変えずにキャンセル |

Tab の自動リピートでは選択を変えない。左右は前後の項目、上下は列数分の移動で、
端では止まる。最大 4 列 × 3 行、画面サイズに応じて縮小し、項目が多ければ選択に
追従してページを切り替える。表示順は window ID 順で、選択中はウィンドウを動かさない。
一覧取得より早く Option を離した場合は、後からフォーカスを変更せずキャンセルする。

## 構成

- `config/hammerspoon/aerospace-window-grid.lua`: キー処理、非同期 CLI、canvas 描画。
- `modules/Home/darwin/hammerspoon.nix`: Lua の配置とログイン起動。
- `config/aerospace/aerospace.toml`: Lachesis の既存設定を移管。競合する `alt-tab` のみ解除。
- `modules/Home/darwin/aerospace.nix`: AeroSpace 設定の配置。
- `modules/darwin/homebrew/applications.nix`: Hammerspoon cask。

AeroSpace の `list-windows --workspace focused --json` でメンバーを取得し、
確定時だけ `focus --window-id` を実行する。macOS Spaces と AeroSpace の
ワークスペースは別物なので、macOS の可視ウィンドウだけで絞り込まない。
Hammerspoon の event tap が Option+Tab と表示中のキーを消費する。
通常時の AeroSpace の Option+hjkl はそのまま使える。

CLI はシェルを介さず `hs.task` で起動し、3 秒でタイムアウトする。
終了済みセッションのコールバックは無視する。プレビューは表示中のカードを
順に取得し、その呼び出し中だけメモリに保持する。画像をディスクには保存しない。

## 適用と権限

```sh
sudo darwin-rebuild switch --flake .#Lachesis
home-manager switch -b before-window-grid --flake .#LachesisHome
aerospace reload-config --no-gui
open -a Hammerspoon
```

既存の `~/.hammerspoon/init.lua` や AeroSpace 設定が通常ファイルの場合、
Home Manager の `-b` はそれを退避する。同名バックアップが存在する場合は
別の接尾辞を使う。Hammerspoon が既に動いていればメニューから Reload Config。
従来の PaperWM 設定は、この機能の init.lua に置き換わる。

システム設定 → プライバシーとセキュリティ:

- アクセシビリティ: Hammerspoon を許可。キーの監視・抑止に必要。
- 画面収録: プレビューが必要な場合に Hammerspoon を許可し、再起動する。
  許可しなくてもアプリ名・タイトルのカードで選択できる。

パスワード入力などで Secure Input が有効な間は OS がキー監視を制限する。
表示中にこれを検出するとキャンセルする。イベント監視が停止した場合も
キャンセルして再開し、次回の操作に備える。

## 検証

```sh
lua tests/aerospace-window-grid-test.lua
aerospace reload-config --no-gui --dry-run
```

Lua 5.4 のテストは Hammerspoon API を模擬し、Option 解放での確定、Tab 解放後の選択継続、リピート、
非同期結果の競合、キャンセル、ページ境界、空一覧、失敗、タイムアウト、
プレビュー取得不可、Secure Input、イベント監視復旧を確認する。
実機では複数ウィンドウのワークスペースで Option+Tab を押し、Tab を離しても
hjklで枠だけが動くこと、Option を離すと選択したウィンドウに移れることを確認する。

## 参考

- [AeroSpace commands](https://nikitabobko.github.io/AeroSpace/commands#list-windows)
- [Hammerspoon eventtap](https://www.hammerspoon.org/docs/hs.eventtap.html)
- [Hammerspoon canvas](https://www.hammerspoon.org/docs/hs.canvas.html)
- [Hammerspoon window snapshots](https://www.hammerspoon.org/docs/hs.window.html#snapshotForID)
