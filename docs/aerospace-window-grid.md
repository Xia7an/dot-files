# AeroSpace workspace window grid

Option + Tab で、全 AeroSpace ワークスペースのウィンドウをワークスペースごとの行にまとめて表示する。
Tab は離してよく、Option を押している間は一覧を表示し続ける。

| 操作 | 動作 |
| --- | --- |
| Option + Tab | 一覧を開く。初期選択は現在のウィンドウ |
| h / l、左右キー | 同じワークスペース内の前後のウィンドウへ移動 |
| j / k、上下キー | 下 / 上のワークスペースへ移動 |
| Tab を離す | 一覧を維持し、引き続き選択できる |
| Option を離す | 選択先のワークスペースへ切り替え、そのウィンドウにフォーカスして閉じる |
| Esc | フォーカスを変えずにキャンセル |

最大 4 列 × 6 行を表示し、画面サイズに応じてカードを縮小する。
各ワークスペースは必ず1行で、5枚目以降を選択するとその行だけ横スクロールする。
7行目以降へ移動すると一覧が縦スクロールする。スクロールは選択を見える範囲へ
1項目ずつ追従させる方式で、ページ単位の切り替えや端での折り返しは行わない。
空のワークスペースは表示しない。行の左に名前と表示範囲、右下に行の表示範囲を示す。

各行は選択位置と横スクロール位置を独立して保持する。上下に移動して戻ると、
その行で最後に選んだウィンドウに戻る。初めて入る行は先頭のウィンドウを選択する。
数字だけのワークスペース名は数値順（1、2、10）、その後に名前順で並ぶ。
各行のウィンドウは window ID 順で並び、起動時は現在フォーカス中のウィンドウが
表示範囲に入るようにスクロールする。Tab の自動リピートや押し直しでは選択を変えない。
選択中は実際のワークスペースやフォーカスを変えず、ウィンドウの所属も変更しない。
一覧取得より早く Option を離した場合は、後からフォーカスを変更せずキャンセルする。

## 構成

- `config/hammerspoon/aerospace-window-grid.lua`: キー処理、非同期 CLI、canvas 描画。
- `modules/Home/darwin/hammerspoon.nix`: Lua の配置とログイン起動。
- `config/aerospace/aerospace.toml`: Lachesis の既存設定を移管。競合する `alt-tab` のみ解除。
- `modules/Home/darwin/aerospace.nix`: AeroSpace 設定の配置。
- `modules/darwin/homebrew/applications.nix`: Hammerspoon cask。

AeroSpace の `list-windows --all --json` で全ウィンドウと所属ワークスペースを取得し、
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
非同期結果の競合、キャンセル、行ごとに独立した横スクロール、6行を超える縦スクロール、
非表示行へ戻ったときの位置復元、行の長さの違い、ワークスペース間の確定、空一覧、失敗、タイムアウト、
プレビュー取得不可、Secure Input、イベント監視復旧を確認する。
実機では複数ウィンドウのワークスペースで Option+Tab を押し、Tab を離しても
hjklで枠だけが動くこと、Option を離すと別ワークスペースのウィンドウにも移れることを確認する。

## 参考

- [AeroSpace commands](https://nikitabobko.github.io/AeroSpace/commands#list-windows)
- [Hammerspoon eventtap](https://www.hammerspoon.org/docs/hs.eventtap.html)
- [Hammerspoon canvas](https://www.hammerspoon.org/docs/hs.canvas.html)
- [Hammerspoon window snapshots](https://www.hammerspoon.org/docs/hs.window.html#snapshotForID)
