<!-- ppt-master-schema: design-spec/v1 -->
# manual-macrostudio-beta1-production - Design Spec

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | manual-macrostudio-beta1-production |
| Canvas Format | PPT 16:9 (1280×720) |
| Page Count | 34（表紙 1 / 第1部 5 / 第2部 16 / 第3部 2 / 第4部 1 / 第5部 8 / 裏表紙 1） |
| Target Audience | 本編: VBA や Office ファイルの内部構造を知らない業務担当者。マクロ付きブックを預かっているが、直せる人が身近にいない。ファイル添付ができるチャット AI（Copilot Chat など）は日常的に使える。付録: 導入可否や運用条件を判断する IT・管理担当者。 |
| Communication Intent | 手引き（teach）が主: 最初の一件（改修または相談）を一人で最後まで完了させる。並行して説明（explain）: アプリが守る範囲と保証しない範囲を実装事実で正確に理解させ、過信も過度な恐れも取り除く。付録で記録（record）: beta 1.0.0 時点の仕組み・対応範囲・未検証事項を導入判断に使える形で残す。 |
| Desired Audience Outcome | 業務担当者が、怖がらず・しかし過信もせず、一つのサンプルと同じ手順で自分のブックの最初の一件を完了し、確認すべきもの（diff・出力ファイル・Excel での動作）を自分の目で確認できる。IT 担当者が、仕組み・保証範囲・未検証事項・EDR/DLP の確認手順を読んで導入判断ができる。 |
| Core Message / Ask / Action | AIチャットが使えれば、マクロは自分で直せる。元のブックはどの操作でも変わらず、何度でもやり直せる。ただし、改修後のマクロが業務で正しく動くことの最終確認は、あなたが Excel で行う。 |
| Delivery Context | 配布して手元で読みながら操作する（reader-led）。第1部は導入紹介として投影にも使える。読者は 1 画面ずつアプリと見比べながら進む。 |
| Artifact Afterlife | 操作の参照先として繰り返し開かれる。導入判断の説明材料。beta 1.0.0 時点の画面・仕様の記録。 |
| Reading Mode | text（read-close。ページだけで完結する読み物。lock `consumption_mode: text`） |
| Content Strategy | content_divergence: 事実は sources/macrostudio-production-manual-facts.md（2026-07-30 現行実装で検証済みの事実台帳）に厳密準拠し、画面の見出し・ボタン名・案内文・ファイル名は一字一句実物を使う。構成・見せ方・言い回しは読者に合わせて自由に設計する。書かないもの: 画面を見れば分かることの説明 / 存在しない操作の否定（「黒い画面は出ません」等） / 実装経緯・開発都合 / 操作説明と製品説明の重複 / 必要以上に不安を煽る内部用語の羅列。確認できていない事項は断言せず「ベータ版の未確認事項」として扱う。 |
| Design Style | mode: instructional / visual_style: soft-rounded / 配色は製品 UI の実装トークン（assets/css/variables.css ライトテーマ）に調和させた「MacroStudio の青」 |
| Created Date | 2026-07-30 |

- **構成の設計（instructional の適用）**: 第1部で「何をする道具か・誰が何を担うか・何が守られるか」の理解を作り、第2部で一つのサンプルを最初から最終確認まで通す（1 ページ = 流れの中の 1 場面。左に実画面・右に番号付き操作の骨格を維持）。第3部で相談の道、第4部で戻り方、第5部は読者を IT 担当に切り替えた技術・運用付録。フッタの部表示で立場の切り替えを示す。
- **安全性の書き方**: 宣伝文句ではなく実装が何をしているかで書く。「絶対に安全」「必ず正しく直る」とは書かない。アプリが守る範囲（受け渡しと構造の完全性）と、人が判断する範囲（業務上の正しさ）を、同じページの中で分けて示す。

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280×720 |
| viewBox | `0 0 1280 720` |
| Margins | 上下左右 48px（安全域 1184×624） |
| Content Area | ヘッダ帯 y 44–104 / 本文域 y 128–652 / フッタ y 668–700 |

## III. Visual Theme

### Theme Style

- **Mode**: instructional — 理解を段階的に積み上げる。手順ページは「左に実画面・右に番号付き操作」を崩さず、見出しにはアプリ画面の言葉をそのまま使う。
- **Visual style**: soft-rounded — 角丸カード・控えめな段差・十分な余白。製品 UI 自体が同じ設計言語なので、スクリーンショットがページに自然に馴染む。
- **Theme**: 社内で配れる実務書。装飾は情報の理解を助けるものだけ。
- **Tone**: 落ち着いて、脅かさない。断定形で短く。丁寧語。

### Color Scheme

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | `#FFFFFF` | 全ページの地 |
| Secondary background | `#F2F6FB` | カード面・画面写真の敷き板（製品 --l-indigo-0） |
| Primary | `#24507F` | 見出し、手順番号、強い罫（製品 --l-indigo-4 系） |
| Accent | `#C05B21` | 「ここを押す」の指示、注意。1 ページ 1〜2 箇所まで |
| Secondary accent | `#2B5C96` | 矢印、補助ラベル、リンク的要素（製品 --l-indigo-3） |
| Body text | `#1F2A37` | 本文（製品 --l-gray-10） |
| Surface | `#FAFBFC` | 淡い面・コード面の地（製品 --l-gray-1） |
| Grid | `#E2E7EC` | 罫線・カード境界（製品 --l-gray-4） |
| Divider | `#CFD7DE` | セクション区切り（製品 --l-gray-5） |
| Muted text | `#5D6B7A` | 注釈・キャプション・ページ番号（製品 --l-gray-8） |
| Positive | `#3A7A47` | 「元のまま」「やり直せる」の安心コールアウト（製品 --l-green-4） |
| Diff removed | `#C25560` | 凡例「赤 = 消える行」。製品の削除色 --l-red-3 と同値 |
| Diff added | `#4C9155` | 凡例「緑 = 増える行」。製品の追加色 --l-green-3 と同値 |

- 60-30-10: `#FFFFFF`/`#F2F6FB` が地、`#24507F` が構造、`#C05B21` は 1 ページ 1〜2 箇所。1 ページの色数は 4 色まで（diff 凡例ページのみ赤緑を加えて 5）。
- 本文コントラスト: `#1F2A37`/白 ≈ 14.9:1、`#5D6B7A`/白 ≈ 5.6:1、白/`#24507F` ≈ 8.7:1、白/`#C05B21` ≈ 4.6:1。

## IV. Typography System

### Font Plan

| Role | Chinese | English | Fallback tail |
| --- | --- | --- | --- |
| Title | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Body | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Emphasis | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif`（weight 700） |
| Code | Consolas | Consolas | `Consolas,monospace` |

- 「Chinese」列はスキーマ由来の見出し。本デッキの CJK は日本語で、Windows 標準の Yu Gothic UI のみを使う（PowerPoint 実機で解決可能）。
- Title: Yu Gothic UI 700 / Body: Yu Gothic UI 400 / Emphasis: 同 700 / Code: Consolas 400。

### Font Size Hierarchy

| Purpose | Size |
| --- | --- |
| Body | 22px |
| Page title | 40px |
| Subtitle | 30px |
| Lead | 26px |
| Annotation | 18px |
| Note（付録の本文注記） | 17px |
| Caption（画面写真の説明） | 16px |
| Small（凡例内の補足） | 15px |
| Footnote / page number | 14px |
| Cover title | 64px |
| Code / file name | 18px |

- 確定値（body 22 / title 40 / subtitle 30 / lead 26 / annotation 18 / note 17 / caption 16 / small 15 / footnote 14 / cover_title 64 / code 18）は再導出しない。
- 折り返しは明示的に決め打つ。1 文字だけが次行へ落ちる折り返し、見出しの途中改行、日本語の不自然な分かち書きを作らない。手順テキストは 1 行 21 字以内。

## V. Layout Principles

### Page Structure

- **Header area**: y 44–104。左端 x=48 に部ラベルのピル（`primary` 塗り・角丸 16・白 14px・幅 132×高 30）※手順ページは「手順 n」を併記。その下 y=72 から見出し 40px を x=48 に置く。y=116 に `grid` のヘアライン。
- **Content area**: y 128–652。手順ページの骨格は「左 704×396 の画面写真（16:9 そのまま・角丸 10・`grid` 細枠・`#F2F6FB` の敷き板）＋右 432px の番号付き操作」。全幅写真ページは 1000×562 を中央置き。
- **Footer area**: y 668–700。左に部名（第1部 MacroStudioを知る / 第2部 最初の一件 / 第3部 相談する使い方 / 第4部 困ったとき / 第5部 技術・運用付録）、右にページ番号（14px, muted）。表紙・裏表紙には置かない。

### Spacing Specification

| Element | Current Project |
| --- | --- |
| Safe margin | 48px |
| 画面写真の版 | 敷き板 720×412（`#F2F6FB`・角丸 14）／写真 704×396（角丸 10・`grid` 1.5px 枠）。16:9 を保ち切り抜かない |
| Content block gap | 24px（カード間）／ 行間 1.55（本文） |
| Icon-text gap | 12px（アイコン 26px 角） |
| 手順番号 | 直径 30px の円（`primary` 塗り・白 700） + 18px 間隔で本文 |
| コールアウト | 角丸 12・地 `#FFFFFF`・枠 1.5px（安心=`positive` / 注意=`accent`）・左にアイコン 24px |

## VI. Icon Usage Specification

ライブラリは `tabler-filled` に統一（icons/ へ複製済み）。

| Purpose | Icon Path | Page |
| --- | --- | --- |
| マクロ入りブック・コード | `tabler-filled/file-code` | P03, P04, P08, P11 |
| チャット AI | `tabler-filled/message-chatbot` | P04, P15, P24 |
| 人（選ぶ・確認する） | `tabler-filled/user` | P04 |
| 起動・はじめる | `tabler-filled/player-play` | P09 |
| ひな形・一覧 | `tabler-filled/list-check` | P13 |
| 依頼文 | `tabler-filled/file-text` | P14, P28 |
| コピー | `tabler-filled/copy` | P15 |
| 取り込み | `tabler-filled/clipboard-check` | P16 |
| 確認する・読む | `tabler-filled/eye` | P17, P18, P22 |
| 出力フォルダ | `tabler-filled/folder-open` | P20 |
| 元のブックは無傷 | `tabler-filled/shield-check` | P02, P06, P20, P21, P25 |
| できる・完了 | `tabler-filled/circle-check` | P05, P21, P34 |
| 流れ・次へ | `tabler-filled/circle-arrow-right` | P07 |
| 相談・調べる | `tabler-filled/search` | P05, P23 |
| 注意・つまずき | `tabler-filled/alert-triangle` | P06, P16, P25, P30 |
| 困ったとき | `tabler-filled/help-circle` | P25 |
| 設定・運用 | `tabler-filled/settings` | P33 |
| 閲覧ロック | `tabler-filled/lock` | P30 |
| 暗号化 | `tabler-filled/shield-lock` | P30 |
| 署名 | `tabler-filled/key` | P30 |
| 保護の仕組み一般 | `tabler-filled/shield` | P26, P29, P32 |
| 動作要件・端末 | `tabler-filled/device-desktop` | P26 |

## VII. Visualization Reference List

| Page | Template | Path | Summary-quote | Usage |
| --- | --- | --- | --- | --- |
| P07 | process_flow | templates/charts/process_flow.svg | "Pick for 3-8 sequential steps connected by simple arrows — approval workflows, customer onboarding, request handling, lifecycle stages. Skip if cyclical (use circular_stages) or stages produce named outputs (use pipeline_with_stages)." | 4 手順（作業とブックを選ぶ→AIへ依頼する→返答を取り込む→ブックを作る）の横一列 + 各手順の中身を下段に細分。相談の分岐を下に 1 行で添える。矢印はネイティブ rightArrow プリセット |
| P29 | process_flow | templates/charts/process_flow.svg | "Pick for 3-8 sequential steps connected by simple arrows — approval workflows, customer onboarding, request handling, lifecycle stages. Skip if cyclical (use circular_stages) or stages produce named outputs (use pipeline_with_stages)." | ビルドの 5 段階（同一性確認→コピー→差し替え→再構築→再読検証）を左→右の関門付き流れで描く。失敗時「出力を残さない」の脱落線を下へ |
| P27 | no-template-match | — | — | 入れ子構造（.xlsm(ZIP) ⊃ xl/vbaProject.bin(OLE2) ⊃ dir/PROJECT/モジュールストリーム(MS-OVBA 圧縮) ⊃ VBA ソース)。数量データではなく包含関係のため、カタログの階層テンプレート（layered_architecture=水平レイヤ、pyramid_chart=序列、module_composition=並列モジュール）は当たらない。フォールバックは角丸の入れ子カードによるカスタムレイアウト |

Runners-up considered:
- pipeline_with_stages | rejected for P29: 各段が名前付き成果物を持つ形が前提だが、ビルド段階の成果物は最終の 1 つで、中間段は検査関門。skip 条項により process_flow が適合
- layered_architecture | rejected for P27: 水平レイヤ＋各レイヤ内モジュールカードの形。P27 は包含（中に入っている）関係で、層状アーキテクチャではない
- module_composition | rejected for P27: 親 1 + 子 N の並列分解の形。P27 は 4 重の直列入れ子

**Native-preset note**: P07 の手順間矢印は PowerPoint 標準の rightArrow を `preset_shape_svg.py` で生成して使う。P29 の関門は同プリセットの chevron ではなく細罫＋ラベルで描く（過剰装飾を避ける）。

## VIII. Image Resource List

素材はすべて 2026-07-30 の現行アプリ（beta 1.0.0）を実操作して撮影したスクリーンショット（sources/capture-rig で再生成可能）。原寸 2732×1536 / 比 1.78。加工・切り抜きをしない（no-crop）。全 25 枚で目視確認済み: エラー・警告・失敗・処理途中の異常表示・実在の個人名・実ユーザーパスは写っていない（ブックは架空の `C:\Tools\申請チェック\申請データ検証.xlsm`）。

| Filename | Dimensions | Ratio | Purpose | Type | Layout pattern | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 21-done.png | 2732x1536 | 1.78 | 表紙の主役。完了画面 = この本の約束 | Screenshot | #4 Right image bleeding off the canvas edge + #21 Rounded rectangle crop + #70 Thin colored matte frame | user | Existing | 改修済みブック作成完了。5 ファイルの一覧と出力フォルダ | none | hero_page |
| 01-mode.png | 2732x1536 | 1.78 | P05 二つの作業。2 択が並ぶ最初の画面 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 | user | Existing | AIで改修する / AIで相談する の 2 カード | none | local |
| 04-book-loaded.png | 2732x1536 | 1.78 | P09 画面の見かた（注釈付き骨格見本） | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 | user | Existing | 進捗バー・見出し・作業領域・次にすること・次へ/戻るが全部写る | none | local |
| 02-mode-selected.png | 2732x1536 | 1.78 | P10 手順1 作業を選ぶ | Screenshot | #19 + #21 | user | Existing | AIで改修するに選択チェック、次へが青 | none | local |
| 03-book-empty.png | 2732x1536 | 1.78 | P11 手順1 読み込み前（ドロップ枠） | Screenshot | #48 Side-by-side comparison + #21 | user | Existing | 点線のドロップ枠と「ファイルを選ぶ」 | none | local |
| 04-book-loaded.png（再掲） | 2732x1536 | 1.78 | P11 手順1 読み込み後 | Screenshot | #48 + #21 | user | Existing | ブック名とパスのカード、選び直す | none | local |
| 05-read.png | 2732x1536 | 1.78 | P12 手順1 読み取り結果 | Screenshot | #48 + #21 | user | Existing | 8モジュール・484行を読み込みました | none | local |
| 06-read-open.png | 2732x1536 | 1.78 | P12 手順1 読み取った内容を見る | Screenshot | #48 + #21 | user | Existing | モジュール名と行数の一覧 | none | local |
| 08-purpose-selected.png | 2732x1536 | 1.78 | P13 手順2 目的を選んだ状態 | Screenshot | #19 + #21 | user | Existing | Win32 API を使わない形へ直す に選択チェック | none | local |
| 09-request.png | 2732x1536 | 1.78 | P14 手順2 依頼文（既定の畳んだ状態） | Screenshot | #48 + #21 | user | Existing | モジュール単位出力の選択肢も写る | none | local |
| 10-request-open.png | 2732x1536 | 1.78 | P14 手順2 依頼文を確認・編集を開いた状態 | Screenshot | #48 + #21 | user | Existing | 依頼文全文の編集欄 | none | local |
| 11-handoff.png | 2732x1536 | 1.78 | P15 手順2 受け渡し（押す前） | Screenshot | #48 + #21 | user | Existing | 2 枚のカードと添付の案内 | none | local |
| 12-handoff-done.png | 2732x1536 | 1.78 | P15 手順2 受け渡し（両方済み） | Screenshot | #48 + #21 | user | Existing | コピーしました / フォルダを開きました、次へが青 | none | local |
| 13-intake.png | 2732x1536 | 1.78 | P16 手順3 取り込み前（3 ステップ案内） | Screenshot | #48 + #21 | user | Existing | クリップボードからAIの返答を取り込む | none | local |
| 14-intake-done.png | 2732x1536 | 1.78 | P16 手順3 取り込み成功 | Screenshot | #48 + #21 | user | Existing | 5個のモジュールを取り込みました。既存 4個・新規 1個 | none | local |
| 15-intake-summary.png | 2732x1536 | 1.78 | P17 AIが書いた改修内容を見る | Screenshot | #48 + #21 | user | Existing | AI の要約が日本語で読める | none | local |
| 16-review.png | 2732x1536 | 1.78 | P17 確認画面の入口 | Screenshot | #48 + #21 | user | Existing | 5個のモジュールへ変更を取り込みました | none | local |
| 17-review-diff-timerutils.png | 2732x1536 | 1.78 | P18 変更内容を見る（インライン diff） | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 | user | Existing | 左にモジュール一覧と増減、右に赤緑の diff、ツールバー | none | local |
| 19-output-name.png | 2732x1536 | 1.78 | P19 手順4 出力名の確認 | Screenshot | #48 + #21 | user | Existing | 集計カードと出力ファイル名 | none | local |
| 20-building.png | 2732x1536 | 1.78 | P19 手順4 ビルド中 | Screenshot | #48 + #21 | user | Existing | 書き戻し後にブックを読み直して検証 | none | local |
| 21-done.png（再掲） | 2732x1536 | 1.78 | P20 手順4 完了画面 | Screenshot | #19 + #21 | user | Existing | 5 ファイルの一覧と出力フォルダを開くボタン | none | local |
| 40-report-light.png | 2732x1536 | 1.78 | P22 Diff レポート（ライト） | Screenshot | #48 + #21 | user | Existing | ブラウザで開いた自己完結レポート | none | local |
| 41-report-dark.png | 2732x1536 | 1.78 | P22 Diff レポート（ダーク切替） | Screenshot | #48 + #21 | user | Existing | ダークにする で切り替えた状態 | none | local |
| 31-purpose-diagnose.png | 2732x1536 | 1.78 | P23 相談の目的選択 | Screenshot | #48 + #21 | user | Existing | AIに何を聞くか選びます。診断側 3 ひな形 | none | local |
| 32-questions.png | 2732x1536 | 1.78 | P23 質問画面 | Screenshot | #48 + #21 | user | Existing | いくつか教えてください。1/6 と選択肢ピル | none | local |
| 35-request-diagnose-open.png | 2732x1536 | 1.78 | P24 質問への回答入りの依頼文 | Screenshot | #48 + #21 | user | Existing | 【質問への回答】が折り込まれた依頼文 | none | local |
| 37-handoff-diagnose-done.png | 2732x1536 | 1.78 | P24 相談の受け渡し完了（完了ボタン） | Screenshot | #48 + #21 | user | Existing | AIチャットへ質問します。右下が完了 | none | local |

**Image-as-Canvas + Native Overlay の適用**: P09 と P18 が `#45`（番号付きホットスポット + 凡例）。画面写真の上に番号の丸を置き、説明は SVG テキストで持つ。他ページは切り抜き不可のスクリーンショットが主題そのもののため、枠付き配置（#19）と対比配置（#48）を採る。注記・番号・キャプション・矢印はすべてネイティブ SVG（text_policy: none。画像に文字を焼き込まない）。

## IX. Content Outline

構成原則: 見出しにはアプリ画面の言葉をそのまま使う。各手順ページは「この場面で何をするか」「押すもの」「次に起きること」だけを持つ。同じ説明を二度しない（製品説明は第1部、操作は第2部）。UI 文言・ファイル名は事実台帳（sources/macrostudio-production-manual-facts.md）の実物を一字一句使う。

### Part 0: 表紙

#### Slide 01 - 表紙

- **Audience move**: 「VBAが読めなくても、この本のとおりに進めれば最初の一件が終わる」という約束を受け取る。
- **Cover impact**: フックは完了画面そのもの——読者が最後に到達する画面を表紙で先に見せる（ゴールの先出し）。構成は `#4 右へ画面外にはみ出す実画面`: 左 55% にタイトルスタック、右に 21-done.png が角丸+細枠で画面外へ流れる。左下に `#F2F6FB` の広い角丸面を敷き、版表記を載せる。箇条書きは置かない。
- **Layout**: 左テキストスタック（コードは読めなくていい。/ MacroStudio 操作マニュアル / リード 2 行）+ 右ブリード写真。
- **Title**: コードは読めなくていい。
- **Core message**: AIチャットが使えれば、マクロは自分で直せる。
- **Content**: 製品名ロック「MacroStudio 操作マニュアル」。リード「ブックを読み込み、AIへ依頼し、返答を取り込む。改修済みブックは、このアプリが別ファイルとして作ります。」版表記「beta 1.0.0 対応 ／ 2026-07-30」。
- **Image**: 21-done.png

### Part 1: MacroStudioを知る（P02–P06）

#### Slide 02 - このマニュアルの読み方

- **Audience move**: 自分が読むべき場所と、この本を読み終えたときの到達点を知る。
- **Layout**: 上に 1 行の約束。下に 5 部構成の地図（横帯 5 枚: 部名 + 一言 + ページ範囲）。右端に読者ラベル（本編=業務担当者 / 付録=IT・管理担当者）。
- **Title**: このマニュアルの読み方
- **Core message**: 第2部を、アプリと見比べながら一度通せば、最初の一件が終わる。
- **Content**: 約束「この本は、初めての一件に付き添う手引きです。第2部は、一つのサンプルブックを最初から最後まで通します。」地図: 第1部 MacroStudioを知る（どんな道具か・何が守られるか）P03–06 ／ 第2部 最初の一件（読み込みから最終確認まで）P07–22 ／ 第3部 相談する使い方 P23–24 ／ 第4部 困ったとき P25 ／ 第5部 技術・運用付録（IT・管理担当者向け）P26–33。注記「付録は、仕組みを詳しく知りたくなったときに開いてください。本編を読むのに付録の知識は要りません。」
- **Icons**: shield-check

#### Slide 03 - どんな場面で使う道具か

- **Audience move**: 「自分の部門のあのマクロのことだ」と当事者になる。
- **Layout**: 上にリード 1 行。中央に困りごとカード 3 枚（アイコン + 見出し + 2 行）。下に一言定義の帯。
- **Title**: どんな場面で使う道具か
- **Core message**: マクロを直したいのに、VBA に詳しい人が身近にいない。そのための道具。
- **Content**: カード①「新しい端末で動かない」— パソコンの入れ替えで、今まで動いていたマクロが止まった。②「作った人がもういない」— 中身が分からないまま、部門のマクロを預かっている。③「直せる人が近くにいない」— 詳しい人に頼めず、そのままになっている。定義帯「MacroStudio は、Excel のマクロ（VBA）を、開発画面（VBE）を一度も開かずに見て・調べて・直すための道具です。」
- **Icons**: file-code

#### Slide 04 - だれが何を担うのか

- **Audience move**: 「判断は AI、選択と確認は自分、運搬と検証はアプリ」という分担を掴み、「自分にコードの判断は求められない」と安心する。
- **Layout**: 三者の横並びカード（チャットAI / あなた / MacroStudio）。各カードにアイコン + 担当 3 行。カード間を双方向矢印でつなぐ。下に 1 行の要点。
- **Title**: だれが何を担うのか
- **Core message**: このアプリは判断をしない。判断は AI、選ぶのはあなた、運んで検証するのがアプリ。
- **Content**: チャットAI「どこを直すか・どう直すかを判断する／コードを書く／改修内容を説明する」。あなた「作業と目的を選ぶ／依頼文とファイルを渡す／返答を取り込み、変更を確認する／最後に Excel で動作を確認する」。MacroStudio「コードを取り出して運ぶ／返答を機械的に検証する／別ファイルへ書き戻し、再読して確認する」。要点「コードの中身を判断する場面は、あなたには回ってきません。あなたが見るのは『何が変わるか』と『業務でいつもどおり動くか』です。」
- **Icons**: message-chatbot, user, file-code

#### Slide 05 - 「AIで改修する」と「AIで相談する」

- **Audience move**: 最初の画面の 2 択の違い（どこまで進むか・何ができるか）を理解し、自分の一件がどちらかを決められる。
- **Layout**: 左に 01-mode.png（#19）。右に 2 択の対比表（選ぶもの／すること／できあがるもの／終わりかた）。
- **Title**: 「AIで改修する」と「AIで相談する」
- **Core message**: ブックを作り替えるのは「AIで改修する」だけ。「AIで相談する」は AI へ渡すファイルを作って終わる。
- **Content**: AIで改修する — AI の返答を取り込んで、改修済みブックをこのアプリで作る。できあがるもの: 改修済みブック・変更内容の確認レポート・改修の概要メモ。手順 4 まで通る。／ AIで相談する — 診断や質問のための依頼文とコード全文を作って AI へ渡す。できあがるもの: request.md と source-code.md。手順 2 で完了（返答はチャットで読む）。共通の注記「どちらを選んでも、元のブックは変更されません。」
- **Image**: 01-mode.png
- **Icons**: circle-check, search

#### Slide 06 - 守られていること・あなたが確かめること

- **Audience move**: アプリが守る範囲を実装事実として知り、過度な恐れを手放す。同時に「業務で正しく動くかの確認は自分の仕事」と引き受ける。
- **Layout**: 左右 2 枚の大カード。左「アプリが守っていること」5 行（shield 系アイコン + 短文）。右「アプリが保証しないこと」2 行 + 「だからあなたが確かめること」1 行。下に positive の安心帯。
- **Title**: 守られていること・あなたが確かめること
- **Core message**: 受け渡しと書き戻しの正確さはアプリが守る。改修後のマクロが業務で正しく動くかは、あなたが確かめる。
- **Content**: 守っていること ①元のブックは上書きしない（結果は必ず別ファイル）②コードを AI へ自動送信しない（渡すのはあなた）③返答は依頼番号や区切りを機械的に確認してから取り込む（合わなければ何も取り込まない）④ビルド前に、元のブックが途中で変わっていないかを確認する ⑤書き戻したブックを読み直し、意図したコードが入ったこと・それ以外を変えていないことを検証する（失敗したら出力を残さない）。保証しないこと「AI の返答の中身が業務として正しいかは、アプリには分かりません。」「だから、変更内容の確認と、Excel での最後の動作確認は、あなたの目で行います（→P18・P21）。」安心帯「途中でやめても、失敗しても、元のブックは変わっていません。何度でもやり直せます。」
- **Icons**: shield-check, alert-triangle

### Part 2: 最初の一件（P07–P22）

#### Slide 07 - 全体の流れ

- **Audience move**: 4 手順の並びと画面の対応を掴み、いまどこにいるかを常に言えるようになる。
- **Layout**: 上段に process_flow: 4 手順の横一列（番号ピル + 手順名 + rightArrow×3）。各手順の下に含まれる画面を小さく列挙。下段に相談の分岐 1 行。
- **Title**: 全体の流れ
- **Core message**: 手順は 4 つ。画面は 1 つずつ進み、右下の［次へ］が青くなったらその画面は終わり。
- **Content**: 1 作業とブックを選ぶ（作業を選ぶ→ブックを読み込む→読み取りを確かめる）／2 AIへ依頼する（目的を選ぶ→依頼文を確かめる→AIチャットへ渡す）／3 返答を取り込む（取り込む→変更を確かめる）／4 ブックを作る（名前を確かめる→ビルド→できあがり）。分岐「『AIで相談する』を選んだときは、手順 2 で完了になります（→P23）。」
- **Icons**: circle-arrow-right

#### Slide 08 - この本で使うサンプル

- **Audience move**: これから通す一件の事例（ブックと困りごと）を把握し、以後のすべての画面写真を自分の文脈に重ねられる。
- **Layout**: 左にブックのプロフィールカード（ファイル名・中身・行数・モジュール構成表）。右に「困りごと」と「今回やること」。
- **Title**: この本で使うサンプル
- **Core message**: 申請データのチェックに使っているマクロを、新しい端末でも動く形に直す。
- **Content**: プロフィール: 申請データ検証.xlsm — 申請一覧シートの内容を検証し、結果とログを書き込む部門マクロ。8 モジュール・484 行（AppController 103 行／SystemInfo 157 行／TimerUtils 14 行／WindowUtils 210 行、ほかはシート側で 0 行）。困りごと「新しい業務端末では Win32 API という古い仕組みが使えない。このマクロは待ち時間を作るために 19 か所でそれ（Sleep）を使っている。」今回やること「目的『Win32 API を使わない形へ直す』で AI に依頼し、改修済みブックを作って、Excel で動作を確かめるところまで。」注記「画面写真の内容はすべてこのサンプルの実操作です。」
- **Icons**: file-code

#### Slide 09 - 起動と画面の見かた

- **Audience move**: 起動方法と画面の 5 つの部品を覚え、迷ったら左下を読めばよいと知る。
- **Layout**: `#45`: 04-book-loaded.png を大きく（1000×562 中央）置き、番号ホットスポット 5 つ + 右側に凡例。上に起動の 1 行。
- **Title**: 起動と画面の見かた
- **Core message**: 起動は launch.vbs をダブルクリック。画面は 1 つずつ進み、迷ったら左下の一行を読む。
- **Content**: 起動「フォルダの中の launch.vbs をダブルクリックします。」凡例 ①進捗バー — いま 4 手順のどこにいるか ②画面の見出し — この画面ですること ③作業領域 — 選ぶ・入れるのはここだけ ④次にすること — 迷ったらここを読む ⑤［戻る］［次へ］ — 進む道はこの 2 つだけ（必要なものが揃うと［次へ］が青くなる）。注記「右上の月・太陽ボタンで画面の明暗を切り替えられます。［最初から］を押すと、いつでも最初の画面に戻れます。」
- **Image**: 04-book-loaded.png
- **Icons**: player-play

#### Slide 10 - 手順1 作業を選んでください

- **Audience move**: 最初の決定（今回は「AIで改修する」）をして進む。
- **Layout**: 左に 02-mode-selected.png（#19 + 手順ページ骨格）。右に操作 2 件 + 補足 1 行。
- **Title**: 作業を選んでください
- **Core message**: 今回は「AIで改修する」。選ぶと［次へ］が青くなる。
- **Content**: ①［AIで改修する］を押します。カードにチェックが付きます。②右下の［次へ］を押します。補足「聞きたいだけのときは［AIで相談する］を選びます（→P23）。あとでブックを替えても、ここで選んだ作業は残ります。」
- **Image**: 02-mode-selected.png

#### Slide 11 - 手順1 Excelブックを読み込みます

- **Audience move**: 対象ブックを読み込ませる。ドラッグでもクリックでもよいと知る。
- **Layout**: `#48`: 左 03-book-empty.png（読み込み前）/ 右 04-book-loaded.png（読み込み後）。下に操作 3 件。
- **Title**: Excelブックを読み込みます
- **Core message**: 枠へドラッグするか、クリックして選ぶ。名前が出たら［次へ］。
- **Content**: ①改修したいブックを点線の枠へドラッグします（クリックしてファイルを選んでもかまいません）。②ファイル名とパスのカードが出たら読み込み完了です。［選び直す］でいつでも替えられます。③［次へ］を押します。注記「対応形式は .xlsm / .xlam / .xlsb / .xls。Excel で開いたままのブックも読み込めます（元のブックは変更されません）。」
- **Image**: 03-book-empty.png, 04-book-loaded.png
- **Icons**: file-code

#### Slide 12 - 手順1 読み込んだマクロを確認します

- **Audience move**: モジュール数と行数を見て、読み取りの案内が出たときの 2 通りの意味を区別できるようになる。
- **Layout**: `#48`: 左 05-read.png / 右 06-read-open.png。下に 2 通りの案内の対比（お知らせ／注意）。
- **Title**: 読み込んだマクロを確認します
- **Core message**: 件数を確かめて［次へ］。案内が出ても、意味は 2 通りしかない。
- **Content**: ①「8モジュール・484行を読み込みました」のように件数が出ます。「読み取った内容を見る」を開くと、モジュール名と行数を確かめられます。②そのまま［次へ］で進みます。案内の対比: 「マクロのコードは全モジュール読み取れています。」= ブック内部の管理情報が標準と違っていただけ。コードは全部読めているので、何もしなくて大丈夫です。／「一部をバイナリレベルで読み取れませんでした。」= 挙げられたモジュールのコードが途中までの可能性。改修前後のコードを見比べてください。どちらの場合も読み込みは成功で、先へ進めます。
- **Image**: 05-read.png, 06-read-open.png

#### Slide 13 - 手順2 目的を選んでください

- **Audience move**: 6 つのひな形から自分の一件に近いものを選べる。迷ったときの選び方も知る。
- **Layout**: 左に 08-purpose-selected.png（#19）。右に改修側 3 ひな形の一覧（名前 + 1 行説明）+ 選び方 2 行。
- **Title**: 目的を選んでください
- **Core message**: 近い目的をひとつ選ぶ。迷ったら「自分で改修内容を書く」。
- **Content**: 一覧（画面に出る名前と説明そのまま）: VBAリファクター（動きを変えずに整理・改善する）— 今の動きを変えないまま、コードを読みやすく直してもらいます。／Win32 API を使わない形へ直す — Win32 API を使っている箇所を、新しい端末でも動く書き方へ置き換えてもらいます。／自分で改修内容を書く — どう直してほしいかを、この後の画面で自分の言葉で書きます。操作: ①今回は「Win32 API を使わない形へ直す」を押します。②［次へ］を押します。補足「ひな形によっては、先にいくつか質問が出ます（相談の例→P23）。答えた内容は依頼文に折り込まれます。」
- **Image**: 08-purpose-selected.png
- **Icons**: list-check

#### Slide 14 - 手順2 AIへ送る依頼文を用意しました

- **Audience move**: 依頼文はそのままでよいと分かる。直したいときと、コードが長いときの対処も知る。
- **Layout**: `#48`: 左 09-request.png（既定の畳んだ状態）/ 右 10-request-open.png（開いた状態）。下に操作 3 件。
- **Title**: AIへ送る依頼文を用意しました
- **Core message**: 直すところがなければ、そのまま［次へ］。
- **Content**: ①そのままでよければ［次へ］を押します。②書き足したいときは「依頼文を確認・編集」を開きます（この文章と、返答のしかたの指示、コード全文ファイルが AI へ渡ります）。③コードがとても長く、AI の返答が途中で切れてしまうときだけ、［モジュール単位出力（コードが長い時用）］に印を付けます（→P33 運用のヒント）。ふだんは付けません。
- **Image**: 09-request.png, 10-request-open.png
- **Icons**: file-text

#### Slide 15 - 手順2 AIチャットへ改修を依頼します

- **Audience move**: 依頼文とファイルの 2 つを AI チャットへ渡し、送信できる。
- **Layout**: `#48`: 左 11-handoff.png（押す前）/ 右 12-handoff-done.png（両方済み）。下に操作 4 件 + 注記。
- **Title**: AIチャットへ改修を依頼します
- **Core message**: 依頼文を貼り、source-code.md を添付して送る。
- **Content**: ①［依頼文をコピー］を押し、チャットの入力欄に貼り付けます（Ctrl+V）。②［ファイルの場所を開く］を押すと、今回の改修専用フォルダが開きます。③その中の source-code.md（マクロのコード全文）をチャットに添付します。④送信して、返答を待ちます。注記（画面の文言）「マクロが読み書きするExcelシートやファイルがあれば、それも一緒にAIチャットへ添付すると、より正確な回答が得られます。」
- **Image**: 11-handoff.png, 12-handoff-done.png
- **Icons**: copy, message-chatbot

#### Slide 16 - 手順3 AIの返答をまとめて取り込みます

- **Audience move**: コードブロック全文のコピーと 1 ボタンの取り込みを実行できる。失敗しても何も壊れないと知る。
- **Layout**: `#48`: 左 13-intake.png（取り込み前・3 ステップ案内）/ 右 14-intake-done.png（成功）。下に操作 3 件 + 注意コールアウト。
- **Title**: AIの返答をまとめて取り込みます
- **Core message**: AI の返答のコードブロックを先頭から末尾までコピーして、ボタンを 1 回押す。
- **Content**: ①AI の返答にあるコードブロックを、先頭から末尾まで全文コピーします。②［クリップボードからAIの返答を取り込む］を押します（Ctrl+V でも同じです）。③「5個のモジュールを取り込みました」のように件数が出たら成功です。［次へ］で確認へ進みます。注意「取り込めないときは、画面に次にすることが 1 文で出ます。多いのはコピー範囲の不足です。コードブロック全体をもう一度コピーして押し直してください。何も取り込まれていないので、状態は壊れていません。」
- **Image**: 13-intake.png, 14-intake-done.png
- **Icons**: clipboard-check, alert-triangle

#### Slide 17 - 手順3 AIの説明を読んでから確認へ

- **Audience move**: AI 自身の説明（何をどう直したか）を日本語で読み、確認画面の入口に立つ。
- **Layout**: `#48`: 左 15-intake-summary.png（AIが書いた改修内容）/ 右 16-review.png（確認画面の要約）。下に操作 2 件。
- **Title**: AIの説明を読んでから確認へ
- **Core message**: まず AI の説明で「何をしたつもりか」を読み、次の画面で「実際に何が変わるか」を見る。
- **Content**: ①「AIが書いた改修内容を見る」を開くと、AI の説明が日本語で読めます。今回の例では「Sleep の呼び出し（計 19 箇所）を WaitMilliseconds へ置き換えました」など。②［次へ］で確認画面へ。「5個のモジュールへ変更を取り込みました」の要約が出ます。中身を見るときは「変更内容を見る」を開きます。
- **Image**: 15-intake-summary.png, 16-review.png
- **Icons**: eye

#### Slide 18 - 手順3 取り込んだ変更を確認します

- **Audience move**: diff（変更一覧）の読み方を覚え、赤と緑を自分の目で確かめてから進めるようになる。
- **Layout**: `#45`: 17-review-diff-timerutils.png を大きく（1000×562 中央）+ 番号ホットスポット 4 つ + 右凡例。下に diff の色の凡例帯（赤=消える行 / 緑=増える行）。
- **Title**: 取り込んだ変更を確認します
- **Core message**: 赤が消える行、緑が増える行。納得できなければ［戻る］でやり直せる。
- **Content**: 凡例 ①モジュール一覧 — 変更のあったモジュールと増減行数（+1 −9 など）②赤い行 — 消える行（今回は Sleep の宣言と呼び出し）③緑の行 — 増える行（置き換え後のコード）④ツールバー — ［変更箇所のみ］で変更部分だけに絞る、［↑前の変更］［↓次の変更］で順に見る、間違い書き写しは［手動修正］で直せる。下帯「見て納得したら［次へ］。『これは違う』と思ったら［戻る］で取り込みへ戻り、AI に言い直して新しい返答を取り込み直します。元のブックはまだ何も変わっていません。」
- **Image**: 17-review-diff-timerutils.png
- **Icons**: eye

#### Slide 19 - 手順4 作成する改修済みブックを確認します

- **Audience move**: 出力ファイル名を確かめてビルドを開始し、待っている間に何が行われているかを知る。
- **Layout**: `#48`: 左 19-output-name.png（名前の確認）/ 右 20-building.png（ビルド中）。下に操作 3 件。
- **Title**: 作成する改修済みブックを確認します
- **Core message**: 名前を確かめて［次へ］。ビルド後の検証まで自動で進む。
- **Content**: ①出力ファイル名を確かめます。最初から「申請データ検証-Modified-20260730.xlsm」のように「元の名前-Modified-日付」が入っています。変えるときもファイル名だけ・拡張子はそのままにします。②［次へ］でビルドが始まります。書き戻したブックを読み直して検証するところまで自動で行われます（ふつうは数秒です）。③「時間がかかっています」と出ても処理は続いています。終わるまで待ちます。
- **Image**: 19-output-name.png, 20-building.png

#### Slide 20 - 手順4 改修済みブックを作成しました

- **Audience move**: できあがった 5 つのファイルの場所と役割を知る。
- **Layout**: 左に 21-done.png（#19）。右にフォルダツリー図（実行フォルダ + 5 ファイル + 一言ずつ）。下に安心コールアウト。
- **Title**: 改修済みブックを作成しました
- **Core message**: 元のブックの隣の MacroStudio フォルダに、今回の一件がまるごと残る。
- **Content**: ①［出力フォルダをエクスプローラーで開く］で場所を開きます。フォルダは「元のブックのフォルダ\MacroStudio\申請データ検証_日付_時刻」。②中身: request.md — AIへ渡した依頼文 ／ source-code.md — 元マクロのコード全文 ／ 申請データ検証-Modified-20260730.xlsm — 改修済みブック ／ 申請データ検証-Diff-Report-20260730.html — 変更内容の確認レポート（→P22）／ result.md — 改修の概要メモ。③［完了］で最初の画面に戻ります。安心「元のブックは元の場所にそのまま残っています。」
- **Image**: 21-done.png
- **Icons**: folder-open, shield-check

#### Slide 21 - 最後の確認は、あなたの目で

- **Audience move**: アプリの検証がどこまでで、自分が何を確かめるのかを引き受け、4 つの最小チェックを実行できる。
- **Layout**: 上に境界の 1 行（アプリが確かめたこと / ここから先）。中央に番号付きチェックリスト 4 件の大カード。下に「問題があったら」の 1 行。
- **Title**: 最後の確認は、あなたの目で
- **Core message**: アプリが確かめたのは「コードが正しく入ったこと」まで。業務でいつもどおり動くかは、あなたが確かめる。
- **Content**: 境界「ビルドの検証で確かめたのは、取り込んだコードがそのまま入り、それ以外を変えていないことです。マクロの中身が業務として正しいかは、ここから先の確認で分かります。」チェック ①改修済みブック（-Modified- の付いた方）を Excel で開く ②いつも使うマクロを、いつもの手順で 1 回実行する ③結果（出力・集計・保存されるもの）がいつもどおりかを確かめる ④しばらくは元のブックも残しておく。問題があったら「元のブックで業務を続けながら、P25 の戻り先からやり直してください。」
- **Icons**: circle-check, shield-check

#### Slide 22 - 変更内容は、あとからでも読める

- **Audience move**: Diff レポートをブラウザで開き、アプリなしで確認・共有できると知る。
- **Layout**: `#48`: 左 40-report-light.png / 右 41-report-dark.png。下に説明 3 行。
- **Title**: 変更内容は、あとからでも読める
- **Core message**: 出力フォルダの Diff-Report をダブルクリックすると、確認画面と同じ差分がブラウザで開く。
- **Content**: ①申請データ検証-Diff-Report-20260730.html をダブルクリックすると、ブラウザで開きます。アプリの「変更内容を見る」とほぼ同じ画面の、読むだけの版です。②左の一覧には変更しなかったモジュールも含めて全部並びます。［前の変更］［次の変更］［変更箇所のみ］［折り返し］、右上の［ダークにする］が使えます。③この 1 ファイルで完結していて、どこにも通信しません。詳しい人に確認を頼むときは、このファイルを渡せば同じものが見られます。
- **Image**: 40-report-light.png, 41-report-dark.png
- **Icons**: eye

### Part 3: 相談する使い方（P23–P24）

#### Slide 23 - 聞くだけの道 — AIで相談する

- **Audience move**: 直す前に相談したいとき・診断だけしたいときの流れ（2 手順で完了）を掴む。
- **Layout**: `#48`: 左 31-purpose-diagnose.png / 右 32-questions.png。下に相談側 3 ひな形の一覧 + 質問画面の説明。
- **Title**: 聞くだけの道 — AIで相談する
- **Core message**: 最初の画面で「AIで相談する」を選ぶと、依頼文とコードを作って渡すところまでで完了する。
- **Content**: 一覧（画面の名前と説明そのまま）: 新しい端末で動くかを調べてもらう — コードは直さず、新しい端末で困りそうな箇所を洗い出してもらいます。／相談用の依頼文を作る（進め方を決めたいとき）— いくつかの質問に答えると、進め方を相談する依頼文ができます。／聞きたいことを自分で書く — マクロについて聞きたいことを、この後の画面で自分の言葉で書きます。質問画面「『相談用の依頼文を作る』では、困りごとや使い方を 6 問たずねられます。分かるところだけ答えれば進めます。答えは依頼文に折り込まれます。」
- **Image**: 31-purpose-diagnose.png, 32-questions.png
- **Icons**: search

#### Slide 24 - 渡したら、続きはチャットで

- **Audience move**: 相談の受け渡しと、その後の進め方（チャットで往復→方針が決まったら改修へ）を知る。
- **Layout**: `#48`: 左 35-request-diagnose-open.png（質問への回答が折り込まれた依頼文）/ 右 37-handoff-diagnose-done.png（完了）。下に操作 2 件 + 続きの 1 行。
- **Title**: 渡したら、続きはチャットで
- **Core message**: 相談はここで完了。返答はチャットで読み、方針が決まったら「AIで改修する」でやり直す。
- **Content**: ①依頼文には、答えた内容が【質問への回答】として入っています。コピーして貼り、source-code.md を添付して送ります。②両方済むと右下が［完了］になります。押すと最初の画面へ戻ります。続き「AI は質問しながら進め方を一緒に絞り、最後に改修方針をまとめてくれます。その方針は、『AIで改修する』の『自分で改修内容を書く』にそのまま使えます。」
- **Image**: 35-request-diagnose-open.png, 37-handoff-diagnose-done.png
- **Icons**: message-chatbot

### Part 4: 困ったとき（P25）

#### Slide 25 - つまずいたら、ここへ戻る

- **Audience move**: 起きたことから戻り先を引けるようになり、「どこで止まっても元のブックは無事」を確信する。
- **Layout**: 上に安心の 1 行。中央に戻り先の表（起きたこと / すること）7 行。下に［最初から］とログの 1 行。
- **Title**: つまずいたら、ここへ戻る
- **Core message**: どこで止まっても、元のブックは無事。起きたことに合った場所へ戻ればやり直せる。
- **Content**: 表: 返答を取り込めない → コードブロック全体をコピーし直して、もう一度取り込む（→P16）／取り込んだ内容が意図と違う → ［戻る］で取り込みへ戻り、AI に言い直して取り込み直す（前の取り込みは全部置き換わります）／余計な記号など軽い写し間違い → 確認画面の［手動修正］で直して［修正を反映］（→P18）／「元のブックのマクロが、読み込んだときから変わっています」→ 読み込んだ後に誰かがマクロを保存し直した合図。ブックを読み込み直して、依頼から作り直す（出力は作られていません）／ビルドできませんでした → ［もう一度ビルドする］。再発するならログを添えて配布元へ／「時間がかかっています」→ 処理は続いています。終わるまで待つ／依頼をやり直したい → 目的を選び直すと依頼番号が新しくなるので、AI へ送り直してから返答を取り込む。下段「全部やり直すときは右上の［最初から］。動作の記録は %LOCALAPPDATA%\MacroStudio\logs にあり、問い合わせ時に添えられます（コードの中身は記録されません）。」
- **Icons**: help-circle, shield-check, alert-triangle

### Part 5: 技術・運用付録（P26–P33）

#### Slide 26 - 付録 — IT・管理担当の方へ

- **Audience move**: 付録の範囲（仕組み・境界・導入判断材料）と動作要件を掴む。
- **Layout**: 左に付録の目次カード（P27–33 の 7 行）。右に動作要件の表 + 構成の 3 行。
- **Title**: 付録 — IT・管理担当の方へ
- **Core message**: ここからは仕組みと境界の話。導入判断と環境検証に使う。
- **Content**: 目次: 仕組み（P27）／受け渡しの照合（P28）／書き戻しと検証（P29）／ロック・暗号化・署名（P30）／対応形式と検証状態（P31）／EDR・DLP 環境（P32）／運用のヒント（P33）。動作要件: Windows 10・11 ／ Windows PowerShell 5.1（OS 標準）／ WebView2 ランタイム（Windows 11 は標準搭載）／ .NET Framework 4.7.2 以降（OS 標準）／ Excel はツール自体には不要（最終確認時に使用）。構成「PowerShell + WebView2 のローカルアプリ。インストール不要でフォルダコピーのみ。ツール自体は一切通信しません（AI との通信は使用者のチャット AI 側）。」
- **Icons**: device-desktop, shield

#### Slide 27 - Excelを開かずにVBAを読む仕組み

- **Audience move**: xlsm の中の入れ子構造を図で理解し、「ファイルから直接読んでいる」ことに納得する。
- **Layout**: カスタム入れ子図（左→右に 4 層の角丸カード: 申請データ検証.xlsm(ZIP) ⊃ xl/vbaProject.bin ⊃ OLE2（dir・PROJECT・モジュールの区画）⊃ 圧縮された VBA ソース）。右に読み方 3 行。
- **Title**: Excelを開かずにVBAを読む仕組み
- **Core message**: マクロはブックの中の 1 ファイルに規格どおり収まっている。MacroStudio はそれを直接読む。
- **Content**: 図の各層: .xlsm は ZIP 形式の入れ物 ／ その中の xl/vbaProject.bin にマクロ全体が入る ／ 中身は OLE2（複合ドキュメント）という区画構造（Microsoft の公開仕様 MS-CFB）／ 各モジュールのコードは MS-OVBA という公開仕様の圧縮で収まっている。説明 ①MacroStudio はこの経路を自前の実装でたどり、Excel を起動せずにコードを取り出します ②書き戻しも同じ経路の逆向きで、vbaProject.bin だけを組み直します ③シートの値・書式・数式には触れません。注記「壊れかけたブックでも、複数の経路で読み直して、読めたモジュールは必ず保持します（読み取り結果の案内 → P12）。」
- **Icons**: file-code

#### Slide 28 - 受け渡しの照合 — 依頼番号と区切り行

- **Audience move**: 取り込みが「なんとなく」ではなく機械的な照合で守られていることを理解する。
- **Layout**: 上に流れ 1 行（依頼文に番号を埋める→返答が写す→取り込みで照合）。中央左に返答パッケージの形（コード風の枠: SUMMARY/BEGIN/END/COMPLETE 行）。右に検査の一覧 6 行。
- **Title**: 受け渡しの照合 — 依頼番号と区切り行
- **Core message**: 依頼ごとに発行される番号が区切り行に入り、合わない返答は 1 行も取り込まれない。
- **Content**: 形（実物の形式）: '@MACROSTUDIO 依頼番号 SUMMARY BEGIN（改修内容の要約）… BEGIN standard WaitUtils（モジュール全文）… COMPLETE 5。検査: 依頼番号が今回のものか／区切りの対応と終端があるか（途中で切れていないか）／件数が名乗りと一致するか／同じモジュールの重複がないか／種類と名前が正しいか／どれか 1 つでも通らなければ、何も取り込まない。注記「区切り行は ' で始まる VBA のコメントなので、コードとしても無害です。新しく増やせるのは標準モジュールだけで、既存モジュールの種類はブック側が正本です。」
- **Icons**: file-text

#### Slide 29 - 書き戻しと検証 — all-or-nothing

- **Audience move**: ビルドの 5 段階と「失敗したら出力を残さない」原則を理解し、生成物の信頼性を判断できる。
- **Layout**: process_flow: 5 段の横流れ（①添付時点との同一性確認 ②元ブックを別名コピー ③vbaProject.bin のソース部だけ差し替え ④OLE2 を全面再構築 ⑤出力を読み直して検証）。下に検証 3 点と all-or-nothing の帯。
- **Title**: 書き戻しと検証 — all-or-nothing
- **Core message**: 書き戻しは元に触れず、検証を通らない出力は残さない。
- **Content**: 各段の一言: ①読み込んだ時点とビルド直前の VBA が完全一致しなければ中止（AI へ渡した後の手直しを黙って失わないため）②元ファイルには一切書き込まない ③変更モジュールのソースと新規標準モジュールだけを差し替え・追加 ④コンテナは毎回まるごと組み直す ⑤読み直して 3 点を検証 — 書き戻した全モジュールのコード一致／それ以外の全区画のバイト単位一致／構造・名前・種別の維持。帯「1 つでも失敗したら出力ファイルを削除します。中途半端に直ったブックは残しません。だから、できあがったブックが在ること自体が検証合格の証です（業務上の正しさは別。→P21）。」
- **Icons**: shield

#### Slide 30 - 閲覧ロック・暗号化・署名

- **Audience move**: 紛らわしい 3 つの保護の違いと、それぞれの扱い（実測済み/見込み/未検証）を区別できる。
- **Layout**: 3 枚の縦カード（アイコン + 名前 + それは何か + MacroStudio での扱い）。下に注記 1 行。
- **Title**: 閲覧ロック・暗号化・署名
- **Core message**: 読めるのは「開けるブック」だけ。ロックは維持され、署名は改修で無効になる。
- **Content**: カード① lock VBAプロジェクトの閲覧ロック — VBE でコードを見るときにパスワードを求める保護。コード自体は暗号化されない仕様のため、読み取り・書き戻しの影響はない見込みで、ロックの記録はそのまま維持され、従来のパスワードで解除できる見込み（実ファイルでの確認は未実施 = ベータ版の未確認事項。ロックを外す機能はありません）。② shield-lock ファイル全体の暗号化 — 開くときにパスワードを求めるブック。中身全体が暗号化されるため読み取れません（実測: モジュール 0 件になり先へ進めません）。パスワードを外した複製で作業してください。③ key VBA 署名 — マクロの発行元を示す署名。コードを書き換えた時点で（どんな道具で直しても）無効になります。MacroStudio は署名部分には触れません。再署名は組織の手順で行ってください。
- **Icons**: lock, shield-lock, key, alert-triangle

#### Slide 31 - 対応形式と検証状態

- **Audience move**: 自分の環境のファイルが「実機確認済み」「条件付き」「未検証」のどこかを判断できる。
- **Layout**: 上に形式の表（形式/読み取り/書き戻し/検証状態）5 行。下に「ベータ版の未確認事項」カード。
- **Title**: 対応形式と検証状態
- **Core message**: .xlsm は実機確認済み。それ以外は読めるが、実ファイルでの確認が済んでいないものがある。
- **Content**: 表: .xlsm 対応/対応/実機確認済み（抽出・書き戻し・Excel での再オープンとマクロ実行）／.xlam 対応/対応/合成データでの試験のみ／.xlsb 対応/対応/実ファイル未検証（解析できない場合は明示エラー）／.xls 読み取り対応/検証合格時のみ/限定対応／拡張子が違うファイル: 中身で判定して読む。未確認事項（主なもの）: 閲覧ロック付きプロジェクトの実ファイル／120 秒を超える大型ブックのビルド実測／モジュール単位出力を実際のチャット AI がどこまで守るか／Diff レポートの他ブラウザ表示。注記「判定は拡張子ではなく中身です。未検証のものが読めた場合も、P21 の最終確認は必ず行ってください。」
- **Icons**: file-code

#### Slide 32 - EDR / DLP 環境での導入

- **Audience move**: 検知製品のある環境では事前検証が必要なこと、同梱サンプルで何がどこまで分かるかを知る。
- **Layout**: 左に「確認済みのこと」カード（1 環境の結果要約 + ローカル全通過）。右に「環境ごとに試すこと」カード（サンプルの使い方 3 行）。下に境界の 1 行。
- **Title**: EDR / DLP 環境での導入
- **Core message**: 検知・遮断は環境ごとに違う。同梱の検証サンプルを対象環境で実行してから展開する。
- **Content**: 確認済み「samples\edr-dlp-validation（検証サンプル一式）を同梱しています。実在の 1 業務環境では、通常マクロの読み取りやクリップボード操作は通り、Win32 API 宣言を含むファイルの読取・複製・書き込みと、貼り付け内容の新規ブック保存が遮断されました。制約のない開発機では全 35 診断が通過しています。」試すこと ①対象環境で FIRST-OPEN のランナーだけを開き、診断を一件ずつ実行 ②外部ログ（output/diagnostic-progress.tsv）の停止地点と、管理コンソールの検知イベントを突き合わせる ③遮断される操作があれば、除外設定や運用の回避策を検討してから展開する。境界「ローカルで通ったことは、本番の EDR/DLP を通ることを意味しません。検知回避を目的とした道具ではありません。」
- **Icons**: shield

#### Slide 33 - 運用のヒント

- **Audience move**: 配布・ひな形の追加・枠の変更・ログの場所という運用の 4 点を押さえる。
- **Layout**: 2×2 の角丸カード。
- **Title**: 運用のヒント
- **Core message**: 配布はフォルダコピー。ひな形は Markdown を置くだけで増える。
- **Content**: ①配布 — フォルダ一式をコピーし「launch.vbs をダブルクリック」とだけ案内。ZIP 配布は展開前にプロパティで［許可する］（Mark of the Web の解除）が必要なことがあります。②ひな形の追加・差し替え — presets フォルダに Markdown を置くだけ。1 ファイルが 1 つの目的になり、再起動は不要。書式が足りないファイルは「読み込めないひな形」として理由付きで表示されます。③依頼文の枠 — templates\request-template.txt（UTF-8）で組み立て枠を変更可能。長いコードで返答が切れる場合の［モジュール単位出力］は、ひな形が対応節を持つときだけ現れます。④ログ — %LOCALAPPDATA%\MacroStudio\logs に動作記録（コード本文は記録しません）。問い合わせ時に添付を依頼してください。
- **Icons**: settings

### Part 6: 裏表紙

#### Slide 34 - 裏表紙

- **Audience move**: 核メッセージを 3 行で持ち帰り、必要なときにこの本へ戻ってくる。
- **Closing impact**: 持ち帰りは「元のブックは変わらない。やり直せる。最後の確認はあなたの目で。」の 3 行。構成はタイポグラフィック・クローズ: 白地中央に 3 行を大きく置き、下に細罫 + 製品名と版表記だけ。連絡先だけの締めや「ありがとうございました」にはしない。
- **Layout**: 中央寄せテキストスタック + 下部に細罫と版表記。
- **Title**: （表示タイトルなし。3 行のメッセージが主役）
- **Core message**: 元のブックは変わらない。やり直せる。最後の確認はあなたの目で。
- **Content**: 3 行「元のブックは、変わらない。／何度でも、やり直せる。／最後の確認は、あなたの目で。」下部「MacroStudio 操作マニュアル ／ beta 1.0.0 対応 ／ 2026-07-30 版」。
- **Icons**: circle-check

## X. Speaker Notes Requirements

- **Filename**: match each SVG filename under `notes/`
- **Content**: この資料は読み物（reader-led）のため、ノートは「配布時の補足」と「維持管理者向けのメモ」を持つ。各ページのノートは、ページ本文に書かなかった背景（出典となる実装事実・検証日・関連ページ）とページ間のつなぎだけを書き、本文の読み上げ直しはしない。画面写真のブック名・パスが架空のサンプルである旨は P08 のノートで一度だけ述べる。文体は です・ます。1 ページ 3〜6 行。
