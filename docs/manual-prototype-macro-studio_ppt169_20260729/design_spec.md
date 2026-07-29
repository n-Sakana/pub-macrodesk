<!-- ppt-master-schema: design-spec/v1 -->
# manual-prototype-macro-studio - Design Spec

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | manual-prototype-macro-studio |
| Canvas Format | PPT 16:9 (1280×720) |
| Page Count | 21 |
| Target Audience | VBA・開発の知識を持たない業務担当者。Excel のマクロを直したいが VBE を開いたことがない。加えて、本試作の品質を確認するレビュー担当者。 |
| Communication Intent | 初めて触る人が 1 周を自力で完走できるように手順を教える（teach）ことを最優先に、同時に「これは試作であり、どこが未確定か」を隠さず記録して引き継ぐ（record and hand off）。優先順位は「教える」が先、「未確定の記録」は最終部で果たす。 |
| Desired Audience Outcome | 画面を見ながら、ブックの取り込み → AI への改修依頼 → 返答の取り込みと差分確認 → 改修済みブックのビルドまでを、途中で人に聞かずに完走できる。あわせて、名称・画面素材のどこが仮置きかを判別できる。 |
| Core Message / Ask / Action | 「どこをどう直すかを決めるのは AI。Macro Studio は判断材料を運び、結果を安全に書き戻す道具にすぎない。だから元のブックは最初から最後まで一切変わらない。」 |
| Delivery Context | 読者主導。実際にアプリを起動し、手元の画面と見比べながら 1 ページずつ読む。会議で投影する用途ではない。 |
| Artifact Afterlife | 試作レビューの対象物。確定後は配布用マニュアルおよび社内展開資料の下敷きとして再利用する。 |
| Reading Mode | balanced（compatibility key: delivery_purpose）。画面写真が主役だが、操作手順は本文で完結させる必要があるため、ページ＋読者の分担。 |
| Content Strategy | content_divergence: 出典（`pub-macrodesk` の実装コードと実画面）に忠実。実装から確認できない挙動は書かない。構成・言い回しは読者が追える順に組み替えてよいが、事実の追加はしない。 |
| Design Style | soft-rounded。角丸カード・穏やかな段差・十分な文字サイズ。装飾より可読性を優先し、余白偏重の「スタイリッシュ」な見え方は避ける。 |
| Created Date | 2026-07-29 |

**製品名の扱い（前提）**: 本書上の製品名は「Macro Studio（仮称）」。アプリ実装・リポジトリ・ログ保存先は現時点で `MacroDesk` のままであり、掲載する画面写真にも `MacroDesk` が写る。この不一致は隠さずページ内に明示する。

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280×720 |
| viewBox | `0 0 1280 720` |
| Margins | 上下左右 40px（安全域 1200×640） |
| Content Area | ヘッダ帯 y=40..104 / 本文域 y=120..648 / フッタ帯 y=664..696 |

## III. Visual Theme

### Theme Style

- **Mode**: instructional
- **Visual style**: soft-rounded
- **Theme**: 業務ツールの実操作マニュアル。1 ページ = 1 画面 = 1 判断。実画面を大きく置き、番号付きの吹き出しで「どこを見て、何を押すか」を指す。
- **Tone**: 落ち着いて親切。専門語を出したらその場で言い換える。脅かさない。「元のブックは変わらない」という安心を繰り返し置く。

### Color Scheme

アプリ実装（`assets/css/variables.css`）のライトテーマ・トークンをそのまま継承する。資料と製品の色が一致することで、読者は資料上の色と画面上の色を対応付けられる。

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | `#FFFFFF` | ページ地。カードを浮かせる白 |
| Secondary bg | `#F2F6FB` | 手順カード・補足帯の淡いインディゴ面（アプリの `--l-indigo-0`） |
| Primary | `#2B5C96` | 見出し・手順番号・強調（アプリの `--l-indigo-3`） |
| Accent | `#4C9155` | 完了・採用・追加行（アプリの「採用済み」緑 `--l-green-3`） |
| Secondary accent | `#C25560` | 削除行・注意（アプリの削除赤 `--l-red-3`） |
| Body text | `#1F2A37` | 本文（アプリの `--l-gray-10`） |

追加ニュートラル（soft-rounded がカードと罫を持つため先に確定させる）:

| Role | HEX | Purpose |
| --- | --- | --- |
| surface | `#FFFFFF` | カード面 |
| field | `#F4F6F8` | 画面写真の下敷き・コードブロック地 |
| grid | `#E2E7EC` | カード枠・区切り罫（本文より必ず淡い） |
| muted_text | `#5D6B7A` | 注釈・キャプション（白地でコントラスト 4.9:1） |
| caution | `#A2701C` | 「仮置き」「開発中」の印（アプリの `--l-amber-4`） |

コントラスト: `#1F2A37`/白 = 15.2:1、`#2B5C96`/白 = 7.1:1、`#5D6B7A`/白 = 4.9:1、`#4C9155`/白 = 3.9:1（面積の大きい本文には使わず、アイコン・帯・太字ラベルに限定）。1 ページの有彩色は 3 色まで。

## IV. Typography System

### Font Plan

| Role | Chinese | English | Fallback tail |
| --- | --- | --- | --- |
| Title | Yu Gothic UI | Segoe UI | sans-serif |
| Body | Meiryo | Segoe UI | sans-serif |
| Emphasis | Yu Gothic UI | Segoe UI | sans-serif |
| Code | Consolas | Consolas | monospace |

- Title: `"Yu Gothic UI","Segoe UI",sans-serif` — 見出しは字面が締まる Yu Gothic UI。
- Body: `"Meiryo","Segoe UI",sans-serif` — 本文は x ハイトが大きく可読性に振った Meiryo。長い操作文でも読み負けしない。
- Emphasis: Title と同じ（`"Yu Gothic UI","Segoe UI",sans-serif`）。
- Code: `Consolas,monospace` — ファイル名・パス・VBA 断片。
- 「Chinese」列はスキーマ由来の見出し。本デッキの CJK は日本語であり、日本語 Windows の PowerPoint に標準搭載される Meiryo / Yu Gothic UI のみを使う。

### Font Size Hierarchy

px のみで指定する（PowerPoint 上の pt は `px × 0.75` の書き出し結果であって入力値ではない）。

| Purpose | Size |
| --- | --- |
| Body | 24 |
| Page title | 42 |
| Subtitle | 32 |
| Annotation | 18 |
| Footnote | 16 |

追加の恒常ロール:

| Purpose | Size |
| --- | --- |
| Cover title | 72 |
| Lead | 30 |

読みやすさ優先の依頼に従い、本文は balanced の基準値 24px を下回らせない。注釈 18px・脚注 16px も、これ以上小さくしない下限として扱う。

## V. Layout Principles

### Page Structure

- **Header area**: y=40..104。左に手順ラベル（例「手順 3 · 2/3」、primary 色の角丸ピル）、その右にページタイトル 42px。右端に通しページ番号。
- **Content area**: y=120..648。画面写真ページは「左 = 実画面（角丸クリップ + 細枠 + 番号付きホットスポット）／右 = 番号対応の手順カード」を基本とする。
- **Footer area**: y=664..696。左に「Macro Studio（仮称）操作マニュアル 試作版」、右にページ番号。全ページ共通。

### Spacing Specification

| Element | Current Project |
| --- | --- |
| Safe margin | 40px |
| Content block gap | 24px（カード間）／16px（カード内の行間ブロック） |
| Icon-text gap | 12px |

カードは `rx=16`、画面写真は `rx=10`。影は使わず、`grid` の 1px 罫と `field` の面で段差を作る（PowerPoint 書き出しで影が崩れないため）。

## VI. Icon Usage Specification

ライブラリは `tabler-filled` に統一（角丸・曲線基調で soft-rounded と一致）。全 18 点を `icon_sync.py` で検証済み・`icons/` へ複製済み。

| Purpose | Icon Path | Page |
| --- | --- | --- |
| ブックを読み込む | tabler-filled/file-upload | P04, P06 |
| AI チャットへ渡す | tabler-filled/message-chatbot | P04, P11, P12 |
| コード全文ファイル | tabler-filled/file-code | P11, P19 |
| 採用・完了 | tabler-filled/circle-check | P04, P15, P17, P19 |
| 出力フォルダ | tabler-filled/folder-open | P18, P19 |
| 注意・仮置き | tabler-filled/alert-triangle | P02, P21 |
| ヒント | tabler-filled/bulb | P05, P13, P16 |
| コピー | tabler-filled/copy | P11, P13 |
| 困ったとき | tabler-filled/help-circle | P20 |
| 手動修正・編集 | tabler-filled/edit | P10, P16 |
| 見比べる | tabler-filled/eye | P04, P14 |
| ひな形一覧 | tabler-filled/clipboard-list | P09 |
| 補足・前提 | tabler-filled/info-circle | P02, P03, P12 |
| 生成ファイル | tabler-filled/file-text | P19 |
| 手順 1 | tabler-filled/circle-number-1 | P03, P04 |
| 手順 2 | tabler-filled/circle-number-2 | P03, P04 |
| 手順 3 | tabler-filled/circle-number-3 | P03, P04 |
| 手順 4 | tabler-filled/circle-number-4 | P03, P04 |

## VII. Visualization Reference List

| Page | Template | Path | Summary-quote | Usage |
| --- | --- | --- | --- | --- |

データ可視化ページなし。本デッキの図解は工程図・役割分担図・対応表であり、いずれも数量データを持たない構造情報のため、カタログ照会（`chart_recall.py`）の対象外。P03 の役割分担図と P04 の 4 工程図はネイティブ SVG のカスタムレイアウトで描く（`no-template-match` に相当する構造コンテンツのため）。

## VIII. Image Resource List

全 14 点は現行アプリ（`assets/index.html?demo=1`）を実際にブラウザで描画して撮影した現行 UI の実画面。2732×1536（1366×768 @2x）。スクリーンショットのため全行 `no-crop`。

| Filename | Dimensions | Ratio | Purpose | Type | Layout pattern | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| s01-book-drop.png | 2732x1536 | 1.78 | 表紙の主役／手順1-1の実画面 | Screenshot | #4 Right image bleeding off the canvas edge + #21 Rounded rectangle crop + #70 Image with thin colored matte frame | user | Existing | ブックをドロップする最初の画面。製品の入口を象徴する | none | hero_page |
| s02-book-loaded.png | 2732x1536 | 1.78 | 読み込み結果の確認 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | モジュール数・合計行数・読み取り警告の 3 指標 | none | local |
| s03-method.png | 2732x1536 | 1.78 | 依頼の作り方の二択 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | ひな形か自分で書くかの選択カード | none | local |
| s04-preset-list.png | 2732x1536 | 1.78 | ひな形の一覧 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 同梱ひな形 1 件が選択された状態 | none | local |
| s05-request-editor.png | 2732x1536 | 1.78 | 依頼文の確認と編集 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 依頼文の入力欄と、折りたたまれた出力指示 | none | local |
| s06-handoff.png | 2732x1536 | 1.78 | AI への受け渡し 2 ステップ | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | コピー済み・フォルダ開済みの完了状態と出力フォルダ | none | local |
| s07-intake.png | 2732x1536 | 1.78 | 取り込み前（比較の左） | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | モジュール選択直後、まだ貼っていない状態 | none | local |
| s08-intake-done.png | 2732x1536 | 1.78 | 取り込み後（比較の右） | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 貼り付け完了し次へ進める状態 | none | local |
| s09-diff.png | 2732x1536 | 1.78 | インライン差分の読み方 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 赤=削除・緑=追加、行番号 2 列、ツールバー | none | local |
| s10-diff-accepted.png | 2732x1536 | 1.78 | 採用を押した後の状態 | Screenshot | #46 Background image + bordered "lens" rectangle highlighting a sub-region + #21 Rounded rectangle crop | user | Existing | 左一覧が緑の「採用済み」に変わる差分 | none | local |
| s11-accepted-summary.png | 2732x1536 | 1.78 | 採用結果の集計 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 書き戻し・変更なし・未処理・追加削除行の 4 指標 | none | local |
| s12-output-name.png | 2732x1536 | 1.78 | 出力名の確認 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 出力ファイル名の入力欄と出力フォルダの中身 | none | local |
| s13-building.png | 2732x1536 | 1.78 | ビルド中 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 進行表示。通常 1〜2 秒 | none | local |
| s14-done.png | 2732x1536 | 1.78 | 完成と 4 ファイル | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 出力フォルダのパスと生成 4 ファイルの一覧 | none | local |

**Image-as-Canvas + Native Overlay の採用**: 画像を持つページが 4 枚を超えるため、`#45`（画面写真の上に番号付きホットスポット + 対応する手順カード）をマニュアル本体の主構造として採用した。操作マニュアルでは「画面のどこを見るか」と「何をするか」が対で必要であり、隣接矩形に画像と文章を並べるだけでは対応が取れない。編集が必要な文言・番号・手順はすべて SVG レイヤに置き、画像は画面の事実だけを担う。

**画面写真を用意していないページ（捏造しない代替表現）**: P12（AI チャット側の画面）、P16（手動修正・新規モジュール取り込みの部分状態）は、正確な素材を用意できないためスクリーンショットを載せない。ネイティブ SVG の模式図に `caution` 色の「画面写真なし（試作）」ラベルを添えて代替する。実在しない完成画面を描き起こすことはしない。

## IX. Content Outline

### Part 1: 導入 — 何をする道具か

#### Slide 01 - 表紙

- **Audience move**: 「VBE を開かずにマクロを直す」という約束を 1 行で受け取り、これが実画面のある実務マニュアルだと理解する。
- **Cover impact**: フックは中核主張そのもの——「VBE を開かずに、マクロを直す。」。構成は `#4 Right image bleeding off the canvas edge`：左 2/3 に 72px の主題、右からアプリ実画面（s01）が角丸 + 細枠で画面外へはみ出して立ち上がる。目次的カードも箇条書きも置かない。
- **Layout**: 左テキストスタック（タイトル 72 / リード 30 / 試作バッジ）＋右に s01 が右端をはみ出す。背景は白、左下に `#F2F6FB` の広い角丸面を敷いて画像を受ける。
- **Title**: VBEを開かずに、マクロを直す。
- **Core message**: Macro Studio（仮称）は、マクロ改修の判断を AI に任せ、その結果を安全にブックへ書き戻すための道具である。
- **Content**: サブタイトル「Macro Studio（仮称）操作マニュアル ／ 試作版」。リード「ブックの取り込みから、AIへの改修依頼、返答の取り込みと差分確認、改修済みブックの出力まで。」右下に版表記「2026-07-29 初回試作 ／ 画面表示は開発中のため MacroDesk」。
- **Image**: s01-book-drop.png
- **Data class**: scenario（画面内のブック名・行数はアプリ同梱のデモ用データ）

#### Slide 02 - このマニュアルについて

- **Audience move**: 読み始める前に「これは試作で、どこが未確定か」を把握し、画面写真の見え方の差を誤解しない。
- **Layout**: 3 枚の角丸カードを横並び（対象読者 / 読み方 / 試作としての断り）。3 枚目だけ `caution` 色の左罫と alert-triangle アイコンを持たせる。
- **Title**: このマニュアルについて
- **Core message**: 本書は初回試作であり、名称と画面素材に未確定の部分が残っている。
- **Content**: ① 対象読者「VBA や開発に詳しくない方。VBE を開いたことがなくてかまいません。」／② 読み方「アプリを起動し、手元の画面と見比べながら 1 ページずつ進めてください。1 ページが 1 画面に対応します。」／③ 試作としての断り「製品名は Macro Studio（仮称）です。アプリ画面・ロゴ・ログの保存先は開発中のため MacroDesk のままで、画面写真にもそのまま写ります。」「画面写真はアプリ同梱のデモ用データを描画したものです。ブック名・行数・日時は実在の業務データではありません。」
- **Icons**: tabler-filled/info-circle, tabler-filled/alert-triangle

#### Slide 03 - 判断するのはAI、運ぶのがこの道具

- **Audience move**: 「ツールが勝手に直すのではない」という役割分担を理解し、AI へ渡す作業が必要な理由を受け入れる。
- **Layout**: 中央に横長の 3 枠フロー（あなた → Macro Studio ⇄ AI チャット）。下に「変わらないもの」の帯を 1 本。
- **Title**: 判断するのはAI。この道具は運ぶだけ。
- **Core message**: どこをどう直すかの判断はすべてチャット AI が行い、Macro Studio は判断材料を運び、結果を安全に書き戻す配管に徹する。
- **Content**: 左「あなた」＝どのブックを直すか決める／何を直したいかを言葉にする／AI の変更を採用するか決める。中央「Macro Studio（仮称）」＝マクロのコードを取り出す／依頼文とコードを渡せる形にする／採用した変更だけを書き戻す。右「AI チャット」＝どこを直すか判断する／直したコードを返す。下帯「ツールは完全ローカル動作。AI との通信はブラウザのチャット側で行います。」「元のブックは、最初から最後まで一切変更されません。」
- **Icons**: tabler-filled/info-circle, tabler-filled/message-chatbot, tabler-filled/eye

#### Slide 04 - 全体の流れ

- **Audience move**: これから通る 4 つの手順と全 12 画面の見取り図を持ち、いま自分がどこにいるか常に照合できるようになる。
- **Layout**: 4 列のステップカード（番号アイコン + 見出し + 画面数 + ここで決めること）。カード間に細い矢印。下に「進み方の約束」帯。
- **Title**: 全体の流れ — 4つの手順・12画面
- **Core message**: 1 画面につき決めることは 1 つ。右下の［次へ］が押せるようになったら、その画面は終わっている。
- **Content**: ①ブックを読み込む（2 画面）＝どのブックを改修するか／②AIへ依頼する（4 画面）＝AI に何を依頼するか／③返答を取り込む（3 画面）＝AI の変更を採用するか／④ブックを作る（3 画面）＝出力名を確認してビルド。帯「画面の上に、いまどの手順かが常に出ています。」「右下の［次へ］は、その画面ですべきことが終わるまで押せません。押せるようになったことが合図です。」
- **Icons**: tabler-filled/circle-number-1..4, tabler-filled/file-upload, tabler-filled/message-chatbot, tabler-filled/eye, tabler-filled/circle-check

#### Slide 05 - はじめる前に

- **Audience move**: 手元に必要なものを揃え、起動方法とテーマ切り替えを知った状態で手順 1 に入る。
- **Layout**: 左に「用意するもの」カード 2 枚（縦積み）、右に「動作要件」表 + 「起動」カード。
- **Title**: はじめる前に
- **Core message**: インストールは不要。フォルダをコピーして `launch.vbs` をダブルクリックするだけで始められる。
- **Content**: 用意するもの ①改修したい Excel ブック（`.xlsm` / `.xlam` / `.xlsb` / `.xls`。判定は拡張子ではなくファイルの中身で行うため、拡張子が違っても中に VBA があれば読み込めます）②チャット AI が使えるブラウザ（ファイル添付ができるもの）。動作要件表＝OS: Windows 10 / 11 ／インストール: 不要（フォルダをコピーするだけ）／Excel: ツール自体には不要（改修後の動作確認時のみ）／ネットワーク: 完全ローカル動作。起動カード「`launch.vbs` をダブルクリック。黒い画面は出ません。」ヒント「画面右上の月／太陽ボタンで、明るい配色と暗い配色を切り替えられます。選んだ配色は次回起動時も残ります。」
- **Icons**: tabler-filled/bulb

### Part 2: 手順1 — ブックを読み込む

#### Slide 06 - 手順1-1 ブックを読み込む

- **Audience move**: 実画面のどこへブックを落とせばよいかを特定し、実際に読み込ませる。
- **Layout**: `#45` 左に s01（角丸 + 細枠 + 番号ホットスポット 1〜3）、右に番号対応の手順カード。
- **Title**: 改修するExcelブックを読み込みます
- **Core message**: 点線の枠へブックを落とすか、枠をクリックして選ぶ。それだけ。
- **Content**: ①「Excelブックをここにドロップ」の点線枠へ、改修したいブックをドラッグ＆ドロップします。／②枠をクリックすると、ファイル選択のダイアログからも選べます。／③読み込めると、枠がファイル名とパスの表示に変わり、［選び直す］が出ます。右下の［次へ］が押せるようになります。補足「Excel で開いたままのブックも、そのまま添付できます。」「画面にも出ているとおり、元のブックには書き込みません。読み取るのはマクロのコードだけです。」
- **Image**: s01-book-drop.png
- **Icons**: tabler-filled/file-upload

#### Slide 07 - 手順1-2 読み込んだ内容を確認する

- **Audience move**: 4 つの指標を読み、意図したブックが正しく読めたことを自分で判断する。
- **Layout**: `#45` 左に s02（番号ホットスポット 1〜4）、右に手順カード + 指標の読み方。
- **Title**: 読み込んだマクロを確認します
- **Core message**: ブック名・モジュール数・合計行数・読み取り警告の 4 つが合っていれば、そのまま進んでよい。
- **Content**: ①ファイル名とパス — 意図したブックか確認します。／②モジュール — 読み込んだモジュールの数です。／③合計行数 — 全モジュールの合計行数です。／④読み取り警告 — 「あり」のときは一部に不整合がありますが、読み取れる範囲で処理は続きます。補足「下に並ぶのがモジュール名です。マウスを乗せると行数が出ます。」「違うブックだったら［別のブックを選ぶ］でやり直せます。」
- **Image**: s02-book-loaded.png
- **Data class**: scenario（受注管理.xlsm / 6 モジュール / 306 行はデモ用の値）

### Part 3: 手順2 — AIへ依頼する

#### Slide 08 - 手順2-1 依頼の作り方を選ぶ

- **Audience move**: 2 つの作り方の違いを理解し、自分の状況に合う方を選ぶ。
- **Layout**: `#45` 左に s03（番号ホットスポット 1〜2）、右に手順カード + 「迷ったら」の一言。
- **Title**: 依頼の作り方を選びます
- **Core message**: 目的に近いひな形を選ぶか、最初から自分で書くか。どちらでも進める。
- **Content**: ①用意された改修依頼を選ぶ — 目的に近いひな形を選び、必要な部分だけ直します。返答のしかたを AI に伝える「出力指示」も自動で付きます。／②改修してほしい内容を自分で書く — 何をどう直すか、最初から入力します。出力指示は付きません。ヒント「迷ったら①。ひな形の文章は次の画面で自由に書き換えられます。」注記「②を選ぶと、次のひな形選択の画面は飛ばして依頼文の画面へ進みます。」
- **Image**: s03-method.png

#### Slide 09 - 手順2-2 ひな形を選ぶ

- **Audience move**: ひな形一覧から 1 つ選び、選べないファイルが出たときの意味も理解する。
- **Layout**: `#45` 左に s04（番号ホットスポット 1〜2）、右に手順カード + 「ボタンが出ないとき」の注意カード。
- **Title**: 目的に近い改修依頼を選びます
- **Core message**: ひな形は 1 ファイル 1 依頼。選んでも、内容は次の画面で直せる。
- **Content**: ①一覧からひとつ選びます。各項目には、ひな形の名前と改修指示の 1 行目が要約として出ます。／②選ぶと右端にチェックが付き、［次へ］が押せます。注意カード「ボタンが出ないひな形があるときは、画面の下に『読み込めないひな形』としてファイル名と理由が出ます。直せばそのまま使えます。」補足「ひな形は `presets\` フォルダの Markdown から自動で作られます。ボタン名はファイル名ではなく、ファイル内の見出しです。追加・削除・名前の変更は、この画面を開き直せば反映されます。」「現在同梱されているのは『新端末移行（Win32 API 依存の解消）』の 1 件だけです。」
- **Image**: s04-preset-list.png
- **Icons**: tabler-filled/clipboard-list

#### Slide 10 - 手順2-3 依頼文を確認して直す

- **Audience move**: 依頼文が編集できることを理解し、必要なら自分の言葉を足す。出力指示の役割も知る。
- **Layout**: `#45` 左に s05（番号ホットスポット 1〜3）、右に手順カード。
- **Title**: AIへ伝える改修内容を確認します
- **Core message**: ここに出ている文章がそのまま AI へ渡る。足しても消してもよい。
- **Content**: ①ひな形の「改修指示」が入った状態で出ます。そのまま使っても、自分の言葉を足しても、消してもかまいません。／②文字数が右上に出ます。／③下の「出力指示」は、返答のしかたを AI に伝える文面です。クリックすると中身を読めます。この文面は依頼文の末尾に自動で付いて送られます。補足「『自分で書く』を選んだ場合、出力指示は付きません（『出力指示はまだありません』と出ます）。」
- **Image**: s05-request-editor.png
- **Icons**: tabler-filled/edit

#### Slide 11 - 手順2-4 AIチャットへ渡す

- **Audience move**: 2 枚のカードを上から順に片付け、依頼文とコードファイルの両方を手元に用意する。
- **Layout**: `#45` 左に s06（番号ホットスポット 1〜3）、右に手順カード + 「なぜ分けるのか」の補足帯。
- **Title**: AIチャットへ改修を依頼します
- **Core message**: 依頼文はクリップボードへ、コードは添付ファイルへ。この 2 つを分けて渡すのが要点。
- **Content**: ①［依頼文をコピー］を押します。AI への依頼文がクリップボードへ入ります。コード本文はコピーされません。／②［ファイルの場所を開く］を押します。エクスプローラーが `source-code.md` を選んだ状態で開きます。これが添付するファイルです。／③両方が緑のチェックになると、［次へ］が押せます。補足帯「コードと依頼を分けて渡します。添付ファイルの中で指示文とコードが混ざると、チャット AI がコードを『全文を取得できない』と誤って判断することが実際にありました。」「この改修で作られるファイルは、すべて画面下に出ているフォルダにまとまります。」
- **Image**: s06-handoff.png
- **Icons**: tabler-filled/copy, tabler-filled/file-code

#### Slide 12 - AIチャットでの操作（この道具の外）

- **Audience move**: ブラウザ側で何をするかを把握し、返ってくる返答の形（改修サマリー + モジュールごとのコード）を予期する。
- **Layout**: 画面写真なし。左に 3 ステップの縦フロー（模式図）、右に「返ってくる形」のカード。`caution` 色の「画面写真なし（試作）」ラベルをページ上部に置く。
- **Title**: AIチャットでの操作（この道具の外）
- **Core message**: 依頼文を貼り、`source-code.md` を添付して送る。返答の冒頭にある「改修サマリー」が、このあとの作業指示書になる。
- **Content**: 左フロー ①チャットの入力欄に依頼文を貼り付ける（Ctrl+V）／②同じメッセージに `source-code.md` を添付する／③送信して返答を待つ。右カード「返ってくる形（同梱ひな形の出力指示を使った場合）」＝冒頭に「■ 改修サマリー」…どのモジュールをどう変えたかの箇条書き。まずここを読みます。／続けてモジュールごとに「■ モジュール名」の見出しと、改修後コード全文のコードブロック。／新しいモジュールは「■ 名前（新規）」。／変更していないモジュールは返りません。注記ラベル「画面写真なし（試作）— チャット AI はこの道具の管轄外です。正確な画面素材を用意できないため、模式図で示しています。」
- **Icons**: tabler-filled/message-chatbot, tabler-filled/info-circle

### Part 4: 手順3 — 返答を取り込む

#### Slide 13 - 手順3-1 返答コードを取り込む

- **Audience move**: モジュールを選んでコードを貼るという 1 往復の操作を身につけ、貼る前後の画面差を確認する。
- **Layout**: `#48` 上下 2 段の比較（左 s07「貼る前」／右 s08「貼ったあと」）、下に 4 ステップの手順帯。
- **Title**: AIの返答から、モジュールごとに取り込みます
- **Core message**: 「一覧から選ぶ → コードブロックを全文コピー → 取り込む」を、対象の数だけ繰り返す。
- **Content**: ①AI の返答の「■ 改修サマリー」で、変更されたモジュール名を確認します。／②左の一覧からそのモジュールを選びます。／③AI の返答のコードブロックを、先頭から末尾まで全文コピーします（コードブロックのコピーボタンを使うのが確実です）。／④［クリップボードから取り込む］を押します。Ctrl+V でも貼れます。ヒント「貼り付けたテキストは自動で整えられます。行頭の ``` や、先頭の `Attribute VB_` で始まる行は取り除かれます。」「取り込むと表示が『◯◯ のコードを取り込みました』に変わります。」
- **Image**: s07-intake.png, s08-intake-done.png
- **Icons**: tabler-filled/copy, tabler-filled/bulb

#### Slide 14 - 手順3-2 差分の読み方

- **Audience move**: 赤と緑の意味、行番号 2 列、ツールバーの各ボタンを理解し、変更内容を自力で追えるようになる。
- **Layout**: `#45` 左に s09（番号ホットスポット 1〜4）、右に「画面の読み方」カード。
- **Title**: AIの変更を、元のコードと見比べます
- **Core message**: 赤が消える行、緑が増える行。左の 2 列は変更前と変更後の行番号。
- **Content**: ①行番号は 2 列 — 左が「前」（元のコード）、右が「後」（AI が返したコード）です。／②赤い行は消える行、緑の行は増える行です。／③［↑ 前の変更］［↓ 次の変更］で、変更箇所を順に送れます。右の `1/n` が現在位置です。／④［変更箇所のみ］で変更のない行を隠せます（200 行を超えるモジュールは最初からオンです）。［折り返し］は長い行を折り返します。補足「左のモジュール一覧が、そのままモジュールツリーです。モジュールを選ぶ場所はここだけです。」
- **Image**: s09-diff.png
- **Icons**: tabler-filled/eye
- **Data class**: scenario（表示中のコードはデモ用の値）

#### Slide 15 - 手順3-2 採用するかを決める

- **Audience move**: 「貼っただけでは書き戻されない」ことを理解し、採用の意思決定を明示的に行う。
- **Layout**: `#46` s09→s10 の変化のうち、左一覧の「Main = 採用済み」部分を枠で拡大指示。右に決定カード 2 枚（採用する／使わない）と状態の凡例。
- **Title**: 採用するか、使わないかを決めます
- **Core message**: ［この変更を採用する］を押して初めてビルドの対象になる。貼っただけでは書き戻されない。
- **Content**: 決定カード「［この変更を採用する］— ビルドで書き戻す対象になります。」「［この変更を使わない］— 取り込みを取り消します。」状態の凡例＝未取り込み（まだ何もしていない）／取込済み・確認中（貼ったが、まだ決めていない）／採用済み（緑。ビルドで書き戻される）／変更なし（貼ったが元と同じだった）／対象外（対象から外した）。補足「採用すると左の一覧が緑の『採用済み』に変わり、［次へ］が押せます。」「まだ取り込むモジュールが残っていれば、前の画面に戻って同じ操作を繰り返します。」
- **Image**: s10-diff-accepted.png
- **Icons**: tabler-filled/circle-check

#### Slide 16 - 困ったときの2つの逃げ道

- **Audience move**: 写し間違いや新規モジュールに出会っても、AI へ戻らずその場で処理できると知る。
- **Layout**: 画面写真なし。左右 2 枚の大きめカード（手動修正 / 新しいモジュール）。上部に `caution` の「画面写真なし（試作）」ラベル。
- **Title**: 手直ししたいとき・新しいモジュールがあるとき
- **Core message**: 軽微な写し間違いはその場で直せる。AI が足した新しいモジュールも取り込める。
- **Content**: 左カード「［手動修正］— コードフェンスが混ざった、行が欠けた、といった軽微な写し間違いは、AI へ戻らずここで直せます。①［手動修正］を押すと右側が編集欄になります。②直して［修正を反映］を押すと、差分を見直せます。③未反映のまま画面を離れようとすると、確認が出ます。」右カード「［AIが追加したモジュール］— AI が新しい標準モジュールを返したときに使います。①左の一覧の下にあるボタンを押します（取り込みの画面でのみ押せます）。②AI の返答のコードブロックをコピーしておきます。③モジュール名を入力して［新規モジュールとして取り込む］を押します。」注意「追加できるのは標準モジュールだけです。モジュールの削除と名前の変更はできません。」ラベル「画面写真なし（試作）— これらは画面内の一時的な状態のため、正確な素材を用意できていません。」
- **Icons**: tabler-filled/edit, tabler-filled/bulb

#### Slide 17 - 手順3-3 採用した変更を確認する

- **Audience move**: 書き戻す対象が意図どおりか、集計 4 指標で最終確認する。
- **Layout**: `#45` 左に s11（番号ホットスポット 1〜4）、右に指標の読み方カード。
- **Title**: 採用した変更を確認します
- **Core message**: 「書き戻し」の件数が、これから新しいブックへ書き込まれる数。
- **Content**: ①書き戻し — 採用したモジュールの数。これがビルドで書き込まれます。／②変更なし — 貼ったが元と同じだった、または対象外にしたモジュール。／③未処理 — まだ決めていないモジュール。／④追加・削除 — 採用した変更の合計行数。補足「まだ取り込むものがあれば［別のモジュールを取り込む］で戻れます。」「1 件以上採用していれば［次へ］が押せます。」
- **Image**: s11-accepted-summary.png
- **Icons**: tabler-filled/circle-check
- **Data class**: scenario（集計値はデモ用の値）

### Part 5: 手順4 — ブックを作る

#### Slide 18 - 手順4 出力名を確認してビルドする

- **Audience move**: 出力名の規則を理解して確定し、［次へ］を押してビルドを開始する。
- **Layout**: `#48` 左に s12（出力名の確認）、右に s13（ビルド中）。下に規則カード 1 枚。
- **Title**: 出力ファイル名を確認して、ビルドします
- **Core message**: 出力は必ず別ファイル。元のブックは上書きされない。
- **Content**: 左「①既定の名前は『元のブック名 + _macrodesk + 元の拡張子』です。②変えてもかまいませんが、拡張子は元のままにします。`\ / : * ? " < > |` は使えません。120 文字までです。③下に、この改修専用のフォルダとその中にできる 4 つのファイルが並びます。」右「［次へ］を押すとビルドが始まります。通常 1〜2 秒です。書き戻したあと、ツールが自動でブックを読み直して、モジュール名とコードが意図どおり書き込まれたかを検証します。」規則カード「出力は常に別ファイルです。元のブックはここまでで一切変更されていません。」
- **Image**: s12-output-name.png, s13-building.png
- **Data class**: scenario（画面内のファイル名・パスはデモ用の値）

#### Slide 19 - 手順4 完成 — できあがる4つのファイル

- **Audience move**: 出力フォルダの 4 ファイルの役割を理解し、最後に Excel で動作確認する必要があると知る。
- **Layout**: `#45` 左に s14（番号ホットスポット 1〜4）、右に 4 ファイルの一覧カード + 最後の一言帯。
- **Title**: 改修済みブックができました
- **Core message**: 1 回の改修で作られたものは、すべて 1 つのフォルダにまとまっている。
- **Content**: ①`request.md` — 実際に AI へ渡した依頼文。／②`source-code.md` — 添付した VBA コード全文。／③改修済みブック — 前の画面で決めた名前。／④`diff-report.html` — 変更内容の確認レポート。ブラウザで開けます。左にモジュールツリー、右に画面と同じ差分が出ます。あとから見返す・共有するのに使えます。帯「最後に Excel で開いて、マクロの動作を確認してください。」「失敗したときは『ビルドできませんでした』と出て、モジュール別の結果表が出ます。出力ファイルは残りません。元のブックは無傷なので、［もう一度ビルドする］で何度でもやり直せます。」
- **Image**: s14-done.png
- **Icons**: tabler-filled/folder-open, tabler-filled/file-text, tabler-filled/circle-check

### Part 6: 参考

#### Slide 20 - うまくいかないとき

- **Audience move**: つまずいた症状から、次に見る場所を自分で引ける。
- **Layout**: 2 列の症状→対処表（角丸カード内）。下にログの場所の帯。
- **Title**: うまくいかないとき
- **Core message**: 元のブックは常に無傷なので、どの段階からでもやり直せる。
- **Content**: 起動しない・白い画面のまま → WebView2 ランタイム未導入の可能性。起動時のエラー案内に従ってください。／「マクロが見つかりません」 → そのブックにマクロ（VBAプロジェクト）が入っていません。／ブックを添付できない → 対象ブックを Excel で開いたままにしていないか確認してください。／ひな形のボタンが出ない → 手順2-2 の画面に理由が出ます。`# 名前` `## 改修指示` `## 出力指示` が揃っているか、UTF-8 で保存されているかを確認してください。／依頼テンプレートを読み込めない → `templates\request-template.txt` が UTF-8 で保存され、`{{REQUEST_TEXT}}` を含んでいるか確認してください。／AI の返答が思っていたものと違う → 手順2-3 へ戻って依頼を言い直せます。／貼り付けたコードに余計な行が混ざった → 手順3-2 の［手動修正］でその場で直せます。／ビルドに失敗した → 画面の指示に従ってください。元のファイルは無傷です。帯「ログ: `%LOCALAPPDATA%\MacroDesk\logs\` に動作ログが残ります。問い合わせのときは添付してください。起動そのものに失敗した場合も、その理由がこのログに記録されます。」
- **Icons**: tabler-filled/help-circle

#### Slide 21 - この試作版で仮置きにした箇所

- **Audience move**: レビュー担当者が「次に何を確定すればこの資料が完成するか」を、この 1 ページだけで判断できる。
- **Closing impact**: 読者が持ち帰るべき一点は「この資料のどこが未確定で、何が確定すれば配布できるか」。構成は、6 項目を `caution` 色の左罫を持つ 2 列カードに並べ、右下に「確定後は配布用マニュアルの下敷きとして再利用する」という 1 行の次アクションを置く。謝辞や連絡先だけの締めにはしない。
- **Layout**: 2 列 × 3 行の角丸カード。各カードに項目名 + 現状 + 確定に必要なこと。右下に次アクション帯。
- **Title**: この試作版で仮置きにした箇所
- **Core message**: 未確定は 6 点。いずれも本文の事実ではなく、名称と画面素材に関するもの。
- **Content**: ①製品名 — 本書は「Macro Studio（仮称）」。アプリ画面・ロゴ・ログの保存先は `MacroDesk` のまま。改名時に画面写真の差し替えが必要。／②画面写真 — アプリ同梱のデモ用データを実際に描画した現行 UI。ブック名・モジュール名・行数・日時はデモ用の値。UI デザインは開発中のため細部は変わりうる。／③AI チャット側の画面 — 外部サービスのためツールの管轄外。正確な素材を用意できず、模式図で代替（手順2-4 の次のページ）。／④手動修正・新規モジュールの画面 — 画面内の一時的な状態のため素材未整備。文章と模式図で代替。／⑤出力ファイル名 — 現行実装の `<ブック名>_macrodesk<拡張子>` を正とした。仕様書には旧案が残っており、実装と文書が一致していない。／⑥ひな形 — 同梱は 1 件のみ。運用時に増える想定。次アクション帯「確定後、この試作を配布用マニュアルおよび社内展開資料の下敷きとして再利用します。」
- **Icons**: tabler-filled/alert-triangle

## X. Speaker Notes Requirements

- **Filename**: match each SVG filename under `notes/`
- **Content**: 想定所要時間 25〜30 分（読者が実際に手を動かしながら読む前提）。語り口は conversational（丁寧だが硬すぎない、口頭で肩越しに教えるときの言い方）。目的は instruct。各ページのノートには、ページ本文に載せきれなかった補足・つまずきやすい点・次のページへのつなぎを書く。デモ用データに由来する数値には、実データではない旨を必ず添える。
