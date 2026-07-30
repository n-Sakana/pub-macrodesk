# MacroStudio ベータ版 本番マニュアル（beta 1.0.0 対応 / 2026-07-30 版）

ppt-master 形式のプロジェクト（canvas: ppt169）。2026-07-30 時点の現行実装・
実画面を正本として白紙から制作した本番マニュアル（全 34 ページ）。

## 成果物

- `exports/manual-macrostudio-beta1-production_20260730_225315.pptx` — 配布・編集用（34 スライド。PowerPoint 実機で開けることを確認済み）
- `svg_final/` — 1 ページ 1 ファイルの自己完結 SVG（ブラウザでそのまま閲覧可）
- `svg_output/` — 編集ソース（再書き出しの正本）
- `design_spec.md` / `spec_lock.md` — 設計正本と実行ロック
- `notes/` — ページごとの補足ノート

## 事実の出典

- `sources/macrostudio-production-manual-facts.md` — 2026-07-30 の現行実装で検証した事実台帳（画面文言・命名規則・検証手順・EDR/DLP 結果・未確認事項）
- `sources/request.md` / `source-code.md` / `result.md` / `申請データ検証-diff-report.html` — アプリ自身が生成した実成果物（ウォークスルー事例）

## スクリーンショットの再生成

`sources/` の capture-rig 一式（`sources/README.md` 参照）で、実 UI をホスト
モック注入で駆動して撮り直す。製品コードには一切触れない。

## 再書き出し

```
python <ppt-master>/scripts/svg_quality_checker.py <このフォルダ> --stage final
python <ppt-master>/scripts/finalize_svg.py <このフォルダ>
python <ppt-master>/scripts/svg_to_pptx.py <このフォルダ>
```

## ウォークスルー事例

標本はリポジトリ指定の入力サンプル `testdata/input_win32_sleep.xlsm` の複製
（読者向けに「申請データ検証.xlsm」へ改名。内容は同一）。目的
「Win32 API を使わない形へ直す」で AI 返答パッケージ（Sleep 19 箇所置換 +
新規 WaitUtils）を作成し、実エンジンでビルド → 再読比較 0 不一致 →
実 Excel でマクロ実行 PASS まで確認済み。

## ディレクトリ（scaffold 既定）

- `images/`: 撮影済みスクリーンショット（2732×1536。エラー・失敗画面なし）
- `icons/`: tabler-filled から複製したアイコン
- `analysis/`: image_analysis.csv 等の機械抽出ファクト
- `validation/`: SVG 品質レポートと PPTX postflight 監査
- `live_preview/`: ブラウザプレビューの実行時ファイル
- `backup/<timestamp>/`: svg_output のアーカイブ（古いものは削除可）
