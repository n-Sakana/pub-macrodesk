# capture-rig — 撮影・検証の再生成キット

本番マニュアルのスクリーンショットと実機検証を再現するためのスクリプト一式。
リポジトリ位置 `C:\repos\pub\macrostudio` を前提にする（変更時は各スクリプト内の
`REPO` / `$repo` を修正）。

## スクリーンショット再生成（現行UIから撮り直し）

1. `powershell -NoProfile -ExecutionPolicy Bypass -File extract-modules.ps1 -OutPath win32sleep-modules.json`
   — MacroStudio エンジンで `testdata/input_win32_sleep.xlsm` の全モジュールを抽出する。
2. `python fixtures_build.py`
   — `fixture.json`（撮影用データと正解パッケージ）を生成する。
   モジュール種別ラベルは製品の `assets/messages/module-type-*.txt` から読む。
3. `python shoot.py out`
   — 実 UI をホストモック（`mock.js`）注入で駆動し、改修フロー 22 場面 +
   相談フロー 8 場面 + Diff レポート明暗 2 場面を 1366x768@2x で撮影する。
   アプリ自身が生成した request.md / source-code.md / Diff レポート HTML /
   result.md も `out/` に保存される。要 Python + Playwright(Chromium)。

撮影ハーネスは製品コードを一切変更しない（`assets/` を読み取り専用で配信し、
WebView2 ホストの IPC だけをモックする。画面遷移はすべて実コントロールのクリック）。

## 実機検証の再現

- `real-build.ps1` — 撮影と同一のパッケージを実エンジンでビルドし、出力ブックを
  再読して全モジュールを比較する（スクリプト先頭の `$scratch` パスを配置に合わせる）。
- `encrypted-test.ps1` — ファイル全体を暗号化したブックの読込挙動の観測（要 Excel）。

## 注意

- `.ps1` は Windows PowerShell 5.1 で実行する。**日本語リテラルを含む .ps1 は
  UTF-8 BOM が無いと CP932 解釈で文字化けする**。本キットの .ps1 は ASCII 主体とし、
  日本語データは JSON / 製品メッセージファイル経由で受け渡している。
