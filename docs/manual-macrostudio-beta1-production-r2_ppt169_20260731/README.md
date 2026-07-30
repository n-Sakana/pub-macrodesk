# manual-macrostudio-beta1-production-r2

MacroStudio ベータ版(beta 1.0.0)操作マニュアルの改訂版(r2)。先生の初回レビュー
(2026-07-31)を全項目反映し、旧 34 ページ版を 22 ページに再構成したものです。
旧版プロジェクト `docs/manual-macrostudio-beta1-production_ppt169_20260730/` は
比較用にそのまま残しています(本改訂では一切変更していません)。

- Canvas format: ppt169(1280×720)
- Created: 20260731
- 成果物: `exports/manual-macrostudio-beta1-production-r2_20260731_043120.pptx`(22 枚)
- 編集元: `svg_output/`(1 ページ = 1 SVG。ここを直して下記手順で再生成)

## 改訂の要点(レビュー対応)

- ページ数: 34 → 22(統合はページ削除ではなく内容の集約。対応表は `design_spec.md`
  各ページ末尾の「(旧: Pxx)」が正本)
- 読者への語りかけ・コピー調(「あなた」「〜の道」「コードは、読めなくていい。」等)を
  全ページから排除し、事実・操作・判断可能な条件のみを平明・中立・具体で記述
- 旧 P05 の見かけ上の矛盾を解消: 新 P04 で作業別の成果物を列挙し、共通事実
  「元のブックのファイルには、どちらの作業でも書き込まない」を明示
- 旧 P18「納得できなければ」→ 新 P15 で判断条件(差分に想定外の変更や不足がある場合)
  と戻り先・全置換の事実に置換
- 旧 P21 → 新 P18: Excel での動作確認を 4 手順の平文にし、ビルド検証の範囲と
  利用者の確認範囲の境界を冒頭 2 行で明示
- 旧 P23「聞くだけの道」→ 新 P20「AIで相談する」(事実記述)
- 「完全ローカル」表現は MacroStudio 自体の処理に限定(新 P05・P13・P22)。
  チャット AI は利用者の操作で受け渡す外部サービスであることを明記
- 技術・運用付録(旧 P26–33)と裏表紙(旧 P34)を削除し、動作要件・ローカル処理・
  仕組みの要点のみ新 P22 の 1 枚に圧縮。連絡先情報は記載しない

## 画面写真

`images/` の 20 枚はすべて 2026-07-31 に現行実装(リポジトリの dirty worktree 含む)から
撮影。撮影リグ(`sources/shoot.py`・`mock.js`・`fixtures_build.py`・`fixture.json`)は
WebView2 ホストだけをモックし、実 UI を実フローで操作して到達した通常状態のみを撮影
しています。

ウォークスルーの対象は製品同梱のサンプルブック `sample-book\sample_win32_sleep.xlsm`
(= `testdata/input_win32_sleep.xlsm` と md5 一致の同一ファイル、Win32 Sleep 19 か所)。
画面に写るフォルダ `C:\Tools\MacroStudio\sample-book` は展開先の例です。シートの中身は
業務マクロを模した架空データで、実在の業務データは含みません。

注(2026-07-31 のレビュー2で修正): 撮影リグの `RUN_STAMP` と実行フォルダ名が r1 当時の
値のままで、完了画面の表示とファイル名の日付・ブック名が食い違っていました。リグを
実サンプル名に切り替えたうえで全シーンを再撮影しています。

## 再生成手順

ppt-master スキルのスクリプトを使用(リポジトリルートで実行):

```
python <ppt-master>/scripts/finalize_svg.py docs/manual-macrostudio-beta1-production-r2_ppt169_20260731
python <ppt-master>/scripts/svg_quality_checker.py docs/manual-macrostudio-beta1-production-r2_ppt169_20260731 --stage final --json
python <ppt-master>/scripts/svg_to_pptx.py docs/manual-macrostudio-beta1-production-r2_ppt169_20260731 --no-merge
```

**`--no-merge` は必須**(この日本語デッキでは)。既定の段落マージでは、dy で改行した
各行が空白でつながれて 1 段落になり、テキストボックス幅が推定値(和文の平均字幅)で
決まります。漢字の多い行は実測幅がその推定を超えるため、PowerPoint が独自に再折り返し
して行が増え、カードや表と重なります。`--no-merge` は 1 行 = 1 テキストフレームで
書き出すため、SVG の行組みがそのまま再現されます。ブラウザ表示や品質ゲートでは
この差は出ません(PowerPoint で開いて初めて分かります)。

チェッカーは `--json` を付けたときだけ `validation/svg_quality_report.json` を更新
します。これを省くとエクスポート時の postflight が `quality_gate=stale` になります。
finalize は画像を差し替えた場合に svg_output へ整列情報を書き戻すため、上記の
「finalize → checker --json → svg_to_pptx」の順で実行します。

## レビュー2(2026-07-31)の反映

- P01: 「対象: VBA の知識がない業務担当者」を削除
- P05: 返答パッケージの機械的検査(内部仕様)の項目を削除して 4 項目に整理。読み直し
  照合の項目を「取り込んだコードがそのとおり書き込まれ、それ以外が変更されていない
  ことを照合。照合するのは書き込みの正確さでマクロの動作は確認しない」に精密化
  (SPEC 9.1-6 の (a)(b)(c) に対応。右カード「検証しない範囲」との衝突を解消)
- P07 ほか全ページ: 架空名 `申請データ検証.xlsm` を実在の同梱サンプル
  `sample_win32_sleep.xlsm` に変更し、全シーンを再撮影
- P10: 「一部をバイナリレベルで読み取れませんでした。」の説明を、断定を避けた表現へ
  (内訳が得られない場合にも表示される実装に合わせた)
- P11 / P20: ひな形の数に依存する「3 種類」の表記を削除
- P12: タイトルを現在形「AIへ送る依頼文を用意します」に変更
- P17: タイトルを「出力されたフォルダを確認します」に変更
- P19: レポートの明暗切替がツールバー右端のアイコンボタンへ移動したため、記述を修正し
  ライト/ダーク両方の画面を撮り直し
- P02: ページ見出しが画面見出しと一致しなくなったため、前提文を「本書で引用する画面の
  見出し・ボタン名・案内文は、実際の表示と同一です」に調整

## 検証状態(2026-07-31 時点)

- SVG 品質ゲート(final): 22 ページ全て 0 エラー(警告は Yu Gothic UI 助言等の既知のみ)
- PPTX postflight: passed-with-warnings / quality_gate=passed / 22 slides
- PowerPoint COM 実機オープン: PASS(22 枚)
- 全 22 ページを PNG 再レンダリングして目視検査(改行・文字切れ・重なり・スクショの
  サイズ)。検出した 4 件のレイアウト欠陥(P12/P13/P14/P16)と上記の日付不整合を修正済み
- **PowerPoint 実描画の確認(2026-07-31 追加)**: PowerPoint COM で全 22 スライドを
  PNG 書き出しして目視。既定エクスポートでは P05/P07/P14/P22 ほかで文章が再折り返し
  され、表・カードとの重なりが発生していた。`--no-merge` で再書き出しし、全 22 枚が
  SVG どおりに描画されることを確認。P14 の注意カードのみ高さを 116→132 に調整
  (最終行が枠線に接していたため)。
  確認手順: `scratchpad/export-slides.ps1 -Path <pptx> -OutDir <dir>`(PowerPoint COM
  の `Slide.Export`)。ファイルが開けることの確認(`open-pptx-check.ps1`)だけでは
  描画崩れは検出できない。
- 記載文言は製品の `assets/messages/`・`assets/js/screens.js`・実画面・生成実ファイル
  (request.md / source-code.md / result.md / Diff レポート)と照合。詳細は
  `sources/macrostudio-production-manual-facts.md`

## Directories

- `svg_output/`: raw SVG output
- `svg_final/`: self-contained SVG visual preview; may be inserted manually as an SVG image, but PowerPoint Convert to Shape is unsupported
- `images/`: runtime image pool; converter assets keep their original short filenames when possible
- `icons/`: project icon set — selected library icons copied in (via icon_sync.py) plus any custom icons you add; embedded from here at export
- `notes/`: speaker notes
- `templates/`: project templates
- `live_preview/`: browser preview runtime files and history (lock.json, server.log, edits.jsonl, annotations.jsonl)
- `sources/`: source materials and normalized markdown
- `analysis/`: machine-extracted intermediate analysis (PPTX intake, image_analysis.csv) — the pipeline's canonical must-read source/asset facts
- `validation/`: SVG quality reports and PPTX postflight audit reports
- `exports/`: final native DrawingML pptx deliverables only (timestamped); `_native_charts_tables.pptx` name with `--native-charts-and-tables`, `_narrated.pptx` name when narration audio is embedded
- `backup/<timestamp>/`: svg_output/ archive (always written in default-flow mode; safe to delete old timestamps)
