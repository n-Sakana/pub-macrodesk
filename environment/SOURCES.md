# 想定動作環境の出典と改訂

`target-environment.json` は、MacroStudio が診断依頼へ渡す想定動作環境の正本です。
製品コードやひな形へ同じ制約を転記せず、このファイルだけを改訂します。

## 出典

| sourceId | 出典 | 抽出した内容 |
|---|---|---|
| `ms-preset-04` | MacroStudio β1.10 commit `f9edca70034f4bb6192b90c71a38d3a43647e4d8` の `presets/04_新しい端末で動くかを調べてもらう.md` | Win32 API、外部プロセス、URL化するブックパス、端末依存値、古い部品という5つの前提 |
| `devkit-analyze-edr` | `pub/vba-devkit/config/analyze.json#edr` | EDRで止まりうる実行経路 |
| `devkit-analyze-compat` | `pub/vba-devkit/config/analyze.json#compat` | 互換性と古い部品の候補 |
| `devkit-analyze-path` | `pub/vba-devkit/config/analyze.json#path` | パス・接続先・端末依存値の候補 |
| `devkit-analyze-basis` | `pub/vba-devkit/lib/Analyze.ps1` | 検出根拠の区別。対象端末での実測とはみなさない |
| `datadesk-envtest` | `pub/datadesk/envtest/modules` | runtime / office / webview / security / network / exe / communication の観測軸と、`ok` / `missing` / `error` の記録規律 |

`pub/vba-devkit` と `pub/datadesk` はこのリポジトリの外にある参照元です。MacroStudio
からは読み取り専用とし、内容を改訂しません。

## 軸

- `execution`: API、外部プロセス、スクリプトホストなどの実行可否
- `storage`: ブック・フォルダ・URL・固定パスの違い
- `host`: プリンタ、IP、ホスト名、接続文字列など接続先の違い
- `components`: DAO、DDE、IE、旧式UI操作、32/64ビット互換性
- `office`: Office COMの実測結果を将来置く軸
- `platform`: OS、PowerShell、.NET Frameworkの実測結果を将来置く軸

初期データでは `office` と `platform` は0件です。測定器が存在することと、対象端末で
結果を測定済みであることを混同しないためです。

## basis

- `observed`: 対象端末で実際に測り、結果を保存して確認した事実
- `declared`: 移行先の前提として明示された事実
- `inferred`: コードや設計から、そうなると推定した事項

初期24件はすべて `declared` または `inferred` です。vba-devkitで検出規則が実際に
発火したという意味の `observed` は、対象端末で制約を実測した証拠ではないため
`inferred` として扱います。

## 改訂手順

1. 対象端末で得た観測結果と日時を保存し、追跡できる出典を `sources[]` へ追加する。
2. 制約の `key` は既存参照を壊さないよう維持する。新規keyは命名規則と一意性を確認する。
3. `title` / `detail` は観測事実と推定を混ぜず、`basis` と `sourceIds` を同期する。
4. `revision` を更新し、`tests/test-target-environment.js` と
   `tests/test-environment-not-embedded.js` を実行する。
5. 下の履歴へ、変更理由・出典・観測の有無を追記する。

## 改訂履歴

| revision | 内容 |
|---|---|
| 2026-08-01 | β1.10、vba-devkit、datadeskの実物から初期24件を抽出。対象端末での実測結果は0件 |
