<!-- ppt-master-schema: design-spec/v1 -->
# manual-macrostudio-beta1-production-r2 - Design Spec

> **r2（2026-07-31）**: 先生の初回レビュー（Luca 経由、Room #5）を全面反映した改稿版。
> 34 ページ → 22 ページ。語りかけ・コピー調を全廃して平明・中立・具体の文体へ統一。
> 事実整合（元ブック / 生成コピー / 相談成果物の区別、ローカル処理の範囲）を全ページで
> 明確化。技術・運用付録（旧 P26–33）は削除し、動作要件・ローカル処理範囲・仕組みの
> 要点だけを 1 ページ（P22）へ圧縮。旧 34 ページ版
> （manual-macrostudio-beta1-production_ppt169_20260730）は比較用に無変更で保持。

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | manual-macrostudio-beta1-production-r2 |
| Canvas Format | PPT 16:9 (1280×720) |
| Page Count | 22（表紙 1 / 概要 4 / 操作 14 / 相談 1 / 参考 2） |
| Target Audience | VBA や Office ファイルの内部構造を知らない業務担当者。ファイル添付ができるチャット AI（Copilot Chat など）は業務で使用できる。 |
| Communication Intent | 操作手順の説明（teach）が主: 初回利用者が一件（改修または相談）を完了できるようにする。並行して、アプリが行う処理と保証範囲を事実として正確に伝える（explain）。 |
| Desired Audience Outcome | 読者が本書の手順どおりに、ブックの読み込みから改修済みブックの作成・動作確認までを完了できる。アプリが検証する範囲と、利用者が確認する範囲を区別して理解している。 |
| Core Message / Ask / Action | MacroStudio は、元のブックのファイルには書き込まず、AI の返答を機械的に検証してから、元のブックのコピーである改修済みブックを別ファイルとして作成する。改修後のマクロが業務要件どおり動作するかは、利用者が Excel で確認する。 |
| Delivery Context | 配布して手元で読みながら操作する（reader-led）。 |
| Artifact Afterlife | 操作の参照先。beta 1.0.0 時点の仕様記録。 |
| Reading Mode | text（read-close。lock `consumption_mode: text`） |
| Content Strategy | content_divergence: 事実は sources/macrostudio-production-manual-facts.md（2026-07-31 再検証済み）に厳密準拠。画面の見出し・ボタン名・案内文・ファイル名は一字一句実物。**文体規則（r2 で全面適用）**: (1) 平明・中立・具体。です・ます調。 (2) 禁止: 読者への語りかけ（「あなた」等の二人称強調）、コピー調・比喩的な見出し（「〜の道」等）、情緒的表現（「怖がらず」「安心」「大丈夫です」等）、主観的条件（「納得できなければ」等）。 (3) 見出しは内容を述べる名詞句、または画面表題そのまま。 (4) 条件と操作は「〜の場合は、〜します」の形式で、判断可能な状態を条件にする。 (5) 保証・保護は雰囲気でなく処理内容の事実として書く。**事実整合規則**: (a) 「元のブックのファイルにはどの作業でも書き込まない」と「改修済みブック＝元のブックのコピーである別ファイルを新規作成する」を混同せず、両方を明記する。 (b) 作業別の成果物を正確に区別する（改修 = 実行フォルダに request.md / source-code.md / 改修済みブック / Diff レポート / result.md、相談 = request.md / source-code.md のみでブックは作らない）。 (c) 「ローカル」は MacroStudio 自体の処理範囲（通信機能を持たず、抽出・検証・生成を端末内で行い、コードを自動送信しない）に限定して書く。AI チャットへの受け渡しは利用者の操作であり、チャット AI は外部サービスであることを明示する。 (d) 断言しすぎない: 実測済み・見込み・未検証を区別する。書かないもの: 画面を見れば分かることの重複説明、存在しない操作の否定、実装経緯、技術用語の羅列。 |
| Design Style | mode: instructional / visual_style: soft-rounded / 配色は r1 と同一（製品 UI の実装トークンに調和） |
| Created Date | 2026-07-31 |

- **構成**: 概要（P02–05）で用途・役割・作業と成果物・保護範囲を事実として示し、操作（P06–19）で一つのサンプルを最初から動作確認まで通す。相談（P20）、参考（P21 トラブル時の対処、P22 動作要件と仕組み）で閉じる。付録は設けない。

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280×720 |
| viewBox | `0 0 1280 720` |
| Margins | 上下左右 48px（安全域 1184×624） |
| Content Area | ヘッダ帯 y 44–120 / 本文域 y 140–650 / フッタ y 668–700 |

## III. Visual Theme

### Theme Style

- **Mode**: instructional — 手順ページは「左に実画面・右または下に番号付き操作」の骨格。見出しにはアプリ画面の表題をそのまま使う。
- **Visual style**: soft-rounded — 角丸カード・控えめな段差。製品 UI と同じ設計言語。装飾は情報の区別に必要なものだけ。
- **Theme**: 業務用アプリの操作マニュアル。
- **Tone**: 平明・中立・具体。断定は事実に限る。

### Color Scheme

（r1 と同一。製品 assets/css/variables.css ライトテーマに調和）

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | `#FFFFFF` | 全ページの地 |
| Secondary background | `#F2F6FB` | カード面・画面写真の敷き板 |
| Primary | `#24507F` | 見出し、手順番号、強い罫 |
| Accent | `#C05B21` | 操作対象の指示、注意。1 ページ 1〜2 箇所まで |
| Secondary accent | `#2B5C96` | 矢印、補助ラベル |
| Body text | `#1F2A37` | 本文 |
| Surface | `#FAFBFC` | 淡い面 |
| Grid | `#E2E7EC` | 罫線・カード境界 |
| Divider | `#CFD7DE` | 区切り |
| Muted text | `#5D6B7A` | 注釈・キャプション・ページ番号 |
| Positive | `#3A7A47` | 保護・維持に関する事実表示 |
| Diff removed | `#C25560` | 凡例「赤 = 削除される行」（製品実装値） |
| Diff added | `#4C9155` | 凡例「緑 = 追加される行」（製品実装値） |

## IV. Typography System

### Font Plan

（r1 と同一）

| Role | Chinese | English | Fallback tail |
| --- | --- | --- | --- |
| Title | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Body | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Emphasis | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif`（weight 700） |
| Code | Consolas | Consolas | `Consolas,monospace` |

### Font Size Hierarchy

| Purpose | Size |
| --- | --- |
| Body | 22px |
| Page title | 40px |
| Subtitle | 30px |
| Lead | 26px |
| Annotation | 18px |
| Note | 17px |
| Caption | 16px |
| Small | 15px |
| Footnote / page number | 14px |
| Cover title | 54px |
| Code / file name | 18px |

- 確定値は再導出しない。折り返しは明示的に決め打ち、1 文字落ち・見出し途中改行・不自然な分かち書きを作らない。手順テキストは 1 行 21 字以内目安。
- 表紙は r1 の 64px キャッチコピーを廃止し、製品名 54px のタイトルに変更。

## V. Layout Principles

### Page Structure

- **Header area**: y 44–120。左端 x=48 に区分ピル（`primary` 塗り・角丸 14・白 14px。概要 / 操作 / 相談 / 参考）、操作ページは「手順 n」の白抜きピルを併置。見出しベースライン y=106（40px）。y=120 ヘアライン。
- **Content area**: y 140–650。手順ページの骨格: 単画面ページ「左 704×396 写真 + 右 432px 手順」、対比ページ「560×315 の 2 枚 + 下段手順」、注釈ページ「840×472 または 880×495 + 右凡例」。
- **Footer area**: y 668–700。左「MacroStudio 操作マニュアル（ベータ版）」、右にページ番号（14px, muted）。表紙には置かない。

### Spacing Specification

（r1 と同一: 敷き板 +8px・角丸 14 / 写真 角丸 10・`grid` 1.5px 枠 / 手順番号 直径 30px 円 / コールアウト 角丸 12・枠 1.5px）

## VI. Icon Usage Specification

ライブラリは `tabler-filled`（icons/ へ複製済み）。

| Purpose | Icon Path | Page |
| --- | --- | --- |
| マクロ入りブック・コード | `tabler-filled/file-code` | P03, P07, P22 |
| チャット AI | `tabler-filled/message-chatbot` | P03, P13, P20 |
| 利用者 | `tabler-filled/user` | P03 |
| 起動 | `tabler-filled/player-play` | P08 |
| ひな形一覧 | `tabler-filled/list-check` | P11 |
| 依頼文 | `tabler-filled/file-text` | P12 |
| コピー | `tabler-filled/copy` | P13 |
| 取り込み | `tabler-filled/clipboard-check` | P14 |
| 確認 | `tabler-filled/eye` | P15, P19 |
| 出力フォルダ | `tabler-filled/folder-open` | P17 |
| 保護・維持の事実 | `tabler-filled/shield-check` | P04, P05, P17 |
| 完了・確認項目 | `tabler-filled/circle-check` | P05, P18 |
| 流れ | `tabler-filled/circle-arrow-right` | P06 |
| 相談 | `tabler-filled/search` | P20 |
| 注意・条件 | `tabler-filled/alert-triangle` | P05, P14, P21 |
| トラブル対処 | `tabler-filled/help-circle` | P21 |
| 動作要件 | `tabler-filled/device-desktop` | P22 |

## VII. Visualization Reference List

| Page | Template | Path | Summary-quote | Usage |
| --- | --- | --- | --- | --- |
| P06 | process_flow | templates/charts/process_flow.svg | "Pick for 3-8 sequential steps connected by simple arrows — approval workflows, customer onboarding, request handling, lifecycle stages. Skip if cyclical (use circular_stages) or stages produce named outputs (use pipeline_with_stages)." | 4 手順の横一列（番号ピル + 手順名 + rightArrow×3）。各手順に含まれる画面を下段に列挙。相談は手順 2 で完了する旨を 1 行で添える |

Runners-up considered:
- pipeline_with_stages | rejected for P06: 各段が名前付き成果物を持つ形が前提。本書の手順は段階遷移で、成果物は最終段に集中する
- no-template-match（P22 の仕組みミニ図）: 包含関係（ブック ⊃ vbaProject.bin ⊃ マクロのコード）の 3 段入れ子はカスタム描画。カタログの階層テンプレート（layered_architecture=水平レイヤ、pyramid_chart=序列）は不適合

**Native-preset note**: P06 の手順間矢印は PowerPoint 標準 rightArrow を `preset_shape_svg.py` で生成して使う（r1 P07 と同じ）。

## VIII. Image Resource List

素材はすべて 2026-07-31 に現行アプリ（beta 1.0.0）を実操作して撮り直したスクリーンショット（sources/ の capture-rig で再生成可能）。原寸 2732×1536 / 比 1.78。加工・切り抜きをしない（no-crop）。使用 20 枚で目視確認済み: エラー・警告・失敗・処理途中の異常表示・実在の個人名・実ユーザーパスは写っていない（ブックは製品同梱の `sample_win32_sleep.xlsm`。フォルダ `C:\Tools\MacroStudio\sample-book` は展開先の例）。

| Filename | Dimensions | Ratio | Purpose | Type | Layout pattern | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 21-done.png | 2732x1536 | 1.78 | P01 表紙の実画面パネル／P17 完了画面 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 完了画面。作成された 5 ファイルの一覧 | none | hero_page |
| 01-mode.png | 2732x1536 | 1.78 | P04 作業選択画面 | Screenshot | #19 + #21 | user | Existing | AIで改修する / AIで相談する の 2 カード | none | local |
| 02-mode-selected.png | 2732x1536 | 1.78 | P09 作業選択済み | Screenshot | #48 Side-by-side comparison + #21 | user | Existing | AIで改修する選択済み・次へ有効 | none | local |
| 04-book-loaded.png | 2732x1536 | 1.78 | P08 画面構成注釈／P09 読み込み後 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 ／ #48 + #21 | user | Existing | 進捗バー・見出し・作業領域・下部固定領域が写る | none | local |
| 05-read.png | 2732x1536 | 1.78 | P10 読み取り結果 | Screenshot | #48 + #21 | user | Existing | 8モジュール・484行 | none | local |
| 06-read-open.png | 2732x1536 | 1.78 | P10 読み取った内容 | Screenshot | #48 + #21 | user | Existing | モジュール名と行数の一覧 | none | local |
| 08-purpose-selected.png | 2732x1536 | 1.78 | P11 目的選択済み | Screenshot | #19 + #21 | user | Existing | Win32 API を使わない形へ直す 選択済み | none | local |
| 09-request.png | 2732x1536 | 1.78 | P12 依頼文（既定） | Screenshot | #48 + #21 | user | Existing | モジュール単位出力の選択肢も写る | none | local |
| 10-request-open.png | 2732x1536 | 1.78 | P12 依頼文（展開） | Screenshot | #48 + #21 | user | Existing | 依頼文全文の編集欄 | none | local |
| 11-handoff.png | 2732x1536 | 1.78 | P13 受け渡し前 | Screenshot | #48 + #21 | user | Existing | 2 枚のカード | none | local |
| 12-handoff-done.png | 2732x1536 | 1.78 | P13 受け渡し済み | Screenshot | #48 + #21 | user | Existing | コピーしました / フォルダを開きました | none | local |
| 13-intake.png | 2732x1536 | 1.78 | P14 取り込み前 | Screenshot | #48 + #21 | user | Existing | 取り込みボタンと 3 ステップ案内 | none | local |
| 14-intake-done.png | 2732x1536 | 1.78 | P14 取り込み成功 | Screenshot | #48 + #21 | user | Existing | 5個のモジュールを取り込みました | none | local |
| 17-review-diff-timerutils.png | 2732x1536 | 1.78 | P15 差分確認（注釈付き） | Screenshot | #45 + #21 | user | Existing | モジュール一覧・赤緑の差分・ツールバー | none | local |
| 19-output-name.png | 2732x1536 | 1.78 | P16 出力名確認 | Screenshot | #48 + #21 | user | Existing | 集計と出力ファイル名 | none | local |
| 20-building.png | 2732x1536 | 1.78 | P16 ビルド中 | Screenshot | #48 + #21 | user | Existing | 検証中の表示 | none | local |
| 40-report-light.png | 2732x1536 | 1.78 | P19 レポート（ライト） | Screenshot | #48 + #21 | user | Existing | ブラウザで開いた確認レポート | none | local |
| 41-report-dark.png | 2732x1536 | 1.78 | P19 レポート（ダーク） | Screenshot | #48 + #21 | user | Existing | ダークにする で切替えた状態 | none | local |
| 31-purpose-diagnose.png | 2732x1536 | 1.78 | P20 相談の選択画面 | Screenshot | #48 + #21 | user | Existing | AIに何を聞くか選びます | none | local |
| 37-handoff-diagnose-done.png | 2732x1536 | 1.78 | P20 相談の受け渡し完了 | Screenshot | #48 + #21 | user | Existing | AIチャットへ質問します・完了表示 | none | local |

**Image-as-Canvas + Native Overlay の適用**: P08 と P15 が `#45`（番号ホットスポット + 凡例）。注記・番号・キャプションはすべてネイティブ SVG（text_policy: none）。

## IX. Content Outline

文体規則・事実整合規則（§I Content Strategy）を全ページに適用する。旧 34 枚版からの対応は各ページ末尾の（旧: Pxx）で示す。

### Part 0: 表紙

#### Slide 01 - 表紙

- **Audience move**: 本書の対象（MacroStudio ベータ版の操作説明）と版を確認する。
- **Cover impact**: フックはキャッチコピーではなく実物提示 — 製品の完了画面スクリーンショットを右パネルに置き、左に製品名・版・対象読者を置く二分割構成。装飾は色面 1 つまで。
- **Layout**: 左テキストスタック（製品名 54px / 副題 / 説明 2 行 / 版表記）+ 右に 21-done.png のパネル（#19 枠 + 敷き板）。
- **Title**: MacroStudio 操作マニュアル
- **Core message**: 本書は MacroStudio ベータ版（beta 1.0.0）の操作手順を説明する。
- **Content**: 製品名「MacroStudio 操作マニュアル」。副題「ベータ版（beta 1.0.0 対応）」。説明「Excel マクロ（VBA）の確認・診断・改修を、チャット AI と MacroStudio で行うための手順を説明します。対象は、VBA の知識がない業務担当者です。」版表記「2026-07-31 版」。（旧: P01。キャッチコピー「コードは、読めなくていい。」は削除）
- **Image**: 21-done.png

### Part 1: 概要（P02–P05）

#### Slide 02 - 本書の構成

- **Audience move**: 本書の範囲と読む順序を把握する。
- **Layout**: 構成表（区分 / 内容 / ページ）4 行 + 前提 2 行。装飾バッジなし。
- **Title**: 本書の構成
- **Core message**: 概要 → 操作 → 相談 → 参考の 4 区分で構成する。
- **Content**: 表: 概要（P03–05）— MacroStudio の役割分担・作業の種類と成果物・保護機能 ／ 操作（P06–19）— サンプルブックを使った改修の全手順（読み込みから動作確認まで）／ 相談（P20）—「AIで相談する」の操作 ／ 参考（P21–22）— トラブル時の対処・動作要件と仕組み。前提「操作の説明は、P07 のサンプルブックで通して行います。本書で引用する画面の見出し・ボタン名・案内文は、実際の表示と同一です。」（旧: P02。「付き添う手引き」「ここを通す」等の表現は削除）

#### Slide 03 - MacroStudioの役割分担

- **Audience move**: チャット AI・利用者・MacroStudio が行う処理をそれぞれ把握する。
- **Layout**: 上に定義 2 行。下に三者の役割カード（3 列。アイコン + 名称 + 担当 3 行）。
- **Title**: MacroStudioの役割分担
- **Core message**: 改修内容の判断とコード作成はチャット AI、選択と確認は利用者、コードの抽出・検証・書き戻しは MacroStudio が行う。
- **Content**: 定義「MacroStudio は、Excel マクロ（VBA）を、VBE（開発画面）を開かずに確認・診断・改修するためのツールです。改修内容の判断は行わず、チャット AI との受け渡しと検証を担当します。」カード: チャットAI — 改修箇所と改修方法の判断 ／ 改修後コードの作成 ／ 改修内容の説明文の作成。利用者 — 作業と目的の選択 ／ 依頼文とコードファイルの受け渡し ／ 差分の確認と、改修後の動作確認。MacroStudio — ブックからのコード抽出 ／ 返答の機械的な検証 ／ 別ファイルへの書き戻しと再読検証。（旧: P03+P04 統合。「選ぶのはあなた」「あなたには回ってきません」等を削除し、役割を事実として記述。困りごとカードは削除）

#### Slide 04 - 二つの作業と作成されるファイル

- **Audience move**: 「AIで改修する」と「AIで相談する」の違いを、作成されるファイルで区別する。
- **Layout**: 左に 01-mode.png（#19）。右に作業別の成果物カード（2 段）。下に共通事実 1 行。
- **Title**: 二つの作業と作成されるファイル
- **Core message**: どちらの作業でも元のブックのファイルには書き込まない。改修は元のブックのコピーである改修済みブックと関連ファイルを作成し、相談は AI へ渡す 2 ファイルのみを作成する。
- **Content**: AIで改修する — AI の返答を取り込み、改修済みブックを作成する。作成: request.md（依頼文）／source-code.md（コード全文）／改修済みブック（元のブックのコピーに変更を書き込んだ別ファイル）／Diff レポート／result.md。手順 4 まで進む。／ AIで相談する — 診断や質問のための依頼文とコード全文を作成する。作成: request.md と source-code.md の 2 つのみ。ブックは作成しない。手順 2 で完了する。／ 共通「元のブックのファイルには、どちらの作業でも書き込みません。作成されるファイルはすべて、元のブックとは別の新規ファイルです。」（旧: P05。「ブックを作り替えるのは〜だけ」を成果物の列挙へ置き換え、見かけ上の矛盾を解消）
- **Image**: 01-mode.png

#### Slide 05 - アプリの保護機能と、利用者が確認する範囲

- **Audience move**: アプリが検証する範囲と、利用者が確認する範囲を区別する。
- **Layout**: 左に保護機能 4 項目の大カード。右に「検証しない範囲」「利用者が確認すること」カード。下に復旧可能性の事実 1 行。
- **Title**: アプリの保護機能と、利用者が確認する範囲
- **Core message**: アプリは受け渡しと書き戻しの正確さを検証する。改修後のマクロの動作は検証対象外で、利用者が確認する。
- **Content**: 保護機能 ①元のブックのファイルには書き込まない。出力は常に別ファイル ②コードを外部へ自動送信しない。MacroStudio は通信機能を持たず、受け渡しは利用者の操作で行う ③ビルド開始時に、読み込み時点と元のブックの VBA が一致することを確認する。不一致の場合は中止し、出力を作らない ④書き戻したブックを読み直し、取り込んだコードがそのとおり書き込まれ、それ以外が変更されていないことを照合する。照合するのは書き込みの正確さであり、マクロの動作は確認しない。照合に失敗した場合は出力ファイルを削除する。検証しない範囲「AI の返答の内容、つまり改修後のマクロが業務要件どおり動作するかは、アプリでは検証できません。」利用者が確認すること「差分の確認（P15）と、Excel での動作確認（P18）を行います。」下段「途中で中止した場合も、ビルドに失敗した場合も、元のブックは読み込み時のままです。操作は最初からやり直せます。」（旧: P06。語りかけ表現を削除。先生レビュー2で返答パッケージの機械的検査＝内部仕様の項目を削除し、読み直し照合の対象を SPEC 9.1-6 に沿って明示）

### Part 2: 操作（P06–P19）

#### Slide 06 - 作業全体の流れ

- **Audience move**: 4 手順の並びと、各手順に含まれる画面を把握する。
- **Layout**: process_flow: 4 手順の横一列（番号ピル + 手順名 + rightArrow×3、各手順の画面を下段に列挙）。下に補足 2 行。
- **Title**: 作業全体の流れ
- **Core message**: 改修は 4 手順で構成される。画面は 1 つずつ進み、必要な入力が揃うと［次へ］が有効になる。
- **Content**: 1 作業とブックを選ぶ（作業を選ぶ／ブックを読み込む／読み取り結果を確認）／2 AIへ依頼する（目的を選ぶ／依頼文を確認／AIチャットへ渡す）／3 返答を取り込む（返答を取り込む／変更内容を確認）／4 ブックを作る（出力名を確認／ビルド／完了）。補足「『AIで相談する』を選んだ場合は、手順 2 で完了になります（P20）。」「［戻る］で通過した画面へ戻れます。ビルド中の画面のみ戻れません。」（旧: P07）

#### Slide 07 - 本書で使用するサンプル

- **Audience move**: 操作説明で使うサンプルブックの内容と、行う改修を把握する。
- **Layout**: 左にブック概要カード（ファイル名・内容・モジュール表）。右に「改修の背景」「実施する改修」カード。下に注記。
- **Title**: 本書で使用するサンプル
- **Core message**: sample_win32_sleep.xlsm（8 モジュール・484 行）に対し、「Win32 API を使わない形へ直す」の改修を行う。
- **Content**: 概要: sample_win32_sleep.xlsm — 申請一覧シートの内容を検証し、結果とログを書き込むマクロ。8 モジュール・484 行。モジュール表: AppController 103 行（検証全体の進行）／SystemInfo 157 行（シート構成の確認と設定の読み取り）／TimerUtils 14 行（待機と経過時間）／WindowUtils 210 行（申請 1 行ずつの検証と結果の書き込み）／ほか 4 つ 0 行（シート側のモジュール）。改修の背景「このマクロは待機処理に Win32 API（kernel32 の Sleep）を 19 か所で使用しています。Win32 API を使用できない端末では動作しません。」実施する改修「目的『Win32 API を使わない形へ直す』で AI に依頼し、改修済みブックの作成と動作確認まで行います。」注記「以降の画面写真はすべてこのサンプルの実操作です。ブック名とフォルダは架空の例で、実在の業務データは含みません。」（旧: P08。「困りごと」を「改修の背景」へ変更）

#### Slide 08 - 起動と画面構成

- **Audience move**: 起動方法と画面の 5 つの構成要素を把握する。
- **Layout**: `#45`: 04-book-loaded.png（840×472）+ 番号ホットスポット 5 つ + 右凡例。上に起動の 1 行。
- **Title**: 起動と画面構成
- **Core message**: launch.vbs で起動する。画面は 5 つの領域で構成され、下部の 1 行に次に行う操作が表示される。
- **Content**: 起動「フォルダ内の launch.vbs をダブルクリックすると起動します。インストールは不要です。」凡例 ①進捗バー — 現在の手順を表示 ②画面の見出し — この画面で行う操作 ③作業領域 — 選択と入力はこの領域で行う ④次にすること — 次に行う操作が表示される ⑤［戻る］［次へ］ — 画面の移動。必要な入力が揃うと［次へ］が有効になる。注記「右上のボタンでライト／ダーク表示を切り替えられます。［最初から］を押すと、全状態を破棄して最初の画面に戻ります。」（旧: P09。「迷ったらここを読む」等を平文化）
- **Image**: 04-book-loaded.png

#### Slide 09 - 手順1 作業の選択とブックの読み込み

- **Audience move**: 作業を選択し、対象ブックを読み込む。
- **Layout**: `#48`: 左 02-mode-selected.png / 右 04-book-loaded.png。下に手順 3 件 + 対応形式の注記。
- **Title**: 作業の選択とブックの読み込み
- **Core message**: ［AIで改修する］を選択して［次へ］、続けてブックをドラッグまたはクリックで読み込む。
- **Content**: ①最初の画面で［AIで改修する］を選択し、［次へ］を押します。②次の画面で、対象のブックを点線の枠へドラッグします。クリックしてファイルを選択することもできます。③ファイル名とパスが表示されたら読み込み完了です。［選び直す］で別のブックに変更できます。［次へ］で進みます。注記「対応形式は .xlsm / .xlam / .xlsb / .xls です。Excel で開いたままのブックも読み込めます。読み込みで元のブックのファイルは変更されません。」（旧: P10+P11 統合）
- **Image**: 02-mode-selected.png, 04-book-loaded.png

#### Slide 10 - 手順1 読み取り結果の確認

- **Audience move**: モジュール数・行数を確認し、読み取り時の案内 2 種類の意味を区別する。
- **Layout**: `#48`: 左 05-read.png / 右 06-read-open.png。下に手順 + 案内 2 種類の対比カード。
- **Title**: 読み込んだマクロを確認します
- **Core message**: モジュール数と行数を確認して［次へ］。読み取り時の案内は 2 種類で、いずれも読み込みは成功している。
- **Content**: 手順「『8モジュール・484行を読み込みました』のように件数が表示されます。『読み取った内容を見る』でモジュール名と行数を確認し、［次へ］で進みます。」案内が表示された場合の区別: 「マクロのコードは全モジュール読み取れています。」— ブック内部の管理情報が標準と異なっていた場合の表示。コードはすべて読み取れており、対処は不要 ／「一部をバイナリレベルで読み取れませんでした。」— コードが最後まで読み取れたかをアプリ側で確定できなかった場合の表示（内訳が得られない場合にも表示される）。念のため P15 の差分確認で、改修前コードの途切れがないか確認する。いずれの場合も読み込みは成功しており、先へ進めます。（旧: P12。「何もしなくて大丈夫です」を「対処は不要」に変更）
- **Image**: 05-read.png, 06-read-open.png

#### Slide 11 - 手順2 目的の選択

- **Audience move**: 3 つの改修目的から 1 つを選択する。
- **Layout**: 左に 08-purpose-selected.png（#19）。右に目的一覧（3 段）+ 手順 2 件。下に質問画面の注記。
- **Title**: 目的を選んでください
- **Core message**: 改修の目的を 1 つ選択して［次へ］。本書のサンプルでは「Win32 API を使わない形へ直す」を選択する。
- **Content**: 一覧（画面の表示と同一。ひな形の追加で増減する）: VBAリファクター（動きを変えずに整理・改善する）— 今の動きを変えないまま、コードを読みやすく直してもらいます。／Win32 API を使わない形へ直す — Win32 API を使っている箇所を、新しい端末でも動く書き方へ置き換えてもらいます。／自分で改修内容を書く — どう直してほしいかを、この後の画面で自分の言葉で書きます。手順 ①目的を 1 つ選択します。該当する目的がない場合は「自分で改修内容を書く」を選択し、次の画面で内容を記入します。②［次へ］を押します。注記「ひな形に質問が定義されている場合は、先に質問画面が表示されます（相談の例: P20）。回答は依頼文に挿入されます。」（旧: P13）
- **Image**: 08-purpose-selected.png

#### Slide 12 - 手順2 依頼文の確認

- **Audience move**: 依頼文の内容と、編集・モジュール単位出力の使用条件を把握する。
- **Layout**: `#48`: 左 09-request.png / 右 10-request-open.png。下に手順 2 件 + モジュール単位出力の条件。
- **Title**: AIへ送る依頼文を用意します
- **Core message**: 依頼文は選択した目的から自動生成される。編集が不要な場合はそのまま［次へ］。
- **Content**: ①内容を変更しない場合は、そのまま［次へ］を押します。②書き足す場合は「依頼文を確認・編集」を開いて編集します。この依頼文と、返答形式の指示、コード全文ファイルが AI へ渡ります。条件「コードが長く、AI の返答が途中で切れる場合のみ、［モジュール単位出力（コードが長い時用）］にチェックを付けます。AI は 1 回の返答に 1 モジュールずつ返し、届いた順に取り込みます。通常は使用しません。」（旧: P14）
- **Image**: 09-request.png, 10-request-open.png

#### Slide 13 - 手順2 AIチャットへの受け渡し

- **Audience move**: 依頼文のコピーとコードファイルの添付を行い、AI へ送信する。
- **Layout**: `#48`: 左 11-handoff.png / 右 12-handoff-done.png。下に手順 3 件 + 注記。
- **Title**: AIチャットへ改修を依頼します
- **Core message**: ［依頼文をコピー］で依頼文を貼り付け、［ファイルの場所を開く］で source-code.md を添付して送信する。
- **Content**: ①［依頼文をコピー］を押し、チャット AI の入力欄に貼り付けます（Ctrl+V）。②［ファイルの場所を開く］を押すと、この改修専用のフォルダが開きます。フォルダ内の source-code.md（マクロのコード全文）をチャットに添付します。③送信して返答を待ちます。マクロが読み書きする Excel シートやファイルがある場合は、あわせて添付すると回答の精度が上がります。注記「両方の操作が完了すると［次へ］が有効になります。コードの受け渡しはこの操作で行われ、MacroStudio が自動で送信することはありません。」（旧: P15）
- **Image**: 11-handoff.png, 12-handoff-done.png

#### Slide 14 - 手順3 返答の取り込み

- **Audience move**: AI の返答を取り込み、取り込めない場合の対処と AI の説明の確認方法を把握する。
- **Layout**: `#48`: 左 13-intake.png / 右 14-intake-done.png。下に手順 3 件 + 取り込めない場合のカード。
- **Title**: AIの返答をまとめて取り込みます
- **Core message**: AI の返答のコードブロックを全文コピーし、取り込みボタンを 1 回押す。
- **Content**: ①AI の返答にあるコードブロックを、先頭から末尾まで全文コピーします。②［クリップボードからAIの返答を取り込む］を押します（Ctrl+V でも同じ動作です）。③「5個のモジュールを取り込みました」のように件数が表示されたら取り込み完了です。「AIが書いた改修内容を見る」を開くと、AI が記載した改修内容の説明を確認できます。［次へ］で差分確認へ進みます。取り込めない場合「コピー範囲の不足や、別の依頼への返答などの場合は何も取り込まれず、対処方法が 1 文で表示されます。取り込み前の状態は保持されます。コードブロック全体をコピーし直して、もう一度取り込みます。」（旧: P16+P17 統合）
- **Image**: 13-intake.png, 14-intake-done.png

#### Slide 15 - 手順3 変更内容の確認

- **Audience move**: 差分表示の読み方と、差分に問題があった場合の対処を把握する。
- **Layout**: `#45`: 17-review-diff-timerutils.png（880×495）+ 番号ホットスポット 4 つ + 右凡例。下に条件と対処。
- **Title**: 取り込んだ変更を確認します
- **Core message**: 「変更内容を見る」でモジュールごとの差分を確認する。赤が削除される行、緑が追加される行。
- **Content**: 凡例 ①取り込んだモジュール — 変更行数付きの一覧。選択すると右の差分が切り替わる ②赤 = 削除される行 ③緑 = 追加される行 ④ツールバー — ［変更箇所のみ］で変更部分に絞り込み。［↑前の変更］［↓次の変更］で変更箇所を順に移動。条件と対処「差分に想定外の変更や不足がある場合は、［戻る］で取り込み画面へ戻り、AI に修正を依頼して新しい返答を取り込み直します。取り込みは全体が置き換わります。コピー時に混入した記号など軽微な崩れは、［手動修正］で修正して［修正を反映］を押します。差分に問題がなければ［次へ］で作成へ進みます。」（旧: P18。「納得できなければ」を判断可能な条件に変更）
- **Image**: 17-review-diff-timerutils.png

#### Slide 16 - 手順4 出力ファイル名の確認とビルド

- **Audience move**: 出力ファイル名を確認してビルドを開始する。
- **Layout**: `#48`: 左 19-output-name.png / 右 20-building.png。下に手順 2 件。
- **Title**: 作成する改修済みブックを確認します
- **Core message**: 出力ファイル名を確認して［次へ］を押すと、ビルドと検証が自動で実行される。
- **Content**: ①出力ファイル名を確認します。既定値は「sample_win32_sleep-Modified-20260731.xlsm」のように「元の名前-Modified-日付」です（日付はブックを読み込んだ日）。変更する場合もファイル名のみとし、拡張子は変更できません。②［次へ］でビルドが開始されます。書き戻し後にブックを読み直して検証するまで自動で実行されます（通常は数秒）。「時間がかかっています」と表示された場合も処理は継続しています。（旧: P19）
- **Image**: 19-output-name.png, 20-building.png

#### Slide 17 - 手順4 作成されるファイル

- **Audience move**: 出力フォルダの場所と 5 つのファイルの内容を把握する。
- **Layout**: 左に 21-done.png（#19）。右にフォルダ構成（パス + 5 ファイル + 説明）。下に事実 1 行。
- **Title**: 出力されたフォルダを確認します
- **Core message**: 元のブックのフォルダ内の MacroStudio フォルダに、この改修の 5 ファイルが作成される。
- **Content**: フォルダ「元のブックのフォルダ\MacroStudio\sample_win32_sleep_日付_時刻\」。ファイル: request.md — AI へ渡した依頼文 ／ source-code.md — 改修前のコード全文 ／ sample_win32_sleep-Modified-20260731.xlsm — 改修済みブック ／ sample_win32_sleep-Diff-Report-20260731.html — 変更内容の確認レポート（P19）／ result.md — 改修の概要メモ。操作「［出力フォルダをエクスプローラーで開く］でフォルダが開きます。［完了］で最初の画面に戻ります。」下段「元のブックは、読み込み時のまま元の場所にあります。」（旧: P20）
- **Image**: 21-done.png

#### Slide 18 - 改修後の動作確認

- **Audience move**: ビルド検証の範囲を把握し、Excel での動作確認を実施する。
- **Layout**: 上に検証範囲の 2 行。中央に確認手順 4 件（番号 + 見出し + 補足）。
- **Title**: 改修後の動作確認
- **Core message**: ビルドの検証はコード書き込みの正確さまでを確認する。改修後のマクロが期待どおり動作するかは、利用者が Excel で確認する。
- **Content**: 検証範囲「ビルド時の検証で確認されるのは、取り込んだコードがそのまま書き込まれたこと、それ以外の部分が変更されていないことです。改修後のマクロが業務要件どおり動作するかは、以下の動作確認で判断します。」手順 ①改修済みブック（-Modified- が付いたファイル）を Excel で開きます ②対象のマクロを通常の手順で実行します ③実行結果（出力・集計・保存されるファイル）が期待どおりであることを確認します ④問題がある場合は、元のブックで業務を継続し、P21 の対処に従って改修をやり直します。動作確認が済むまで、元のブックは削除せずに残します。（旧: P21。「最後の確認は、あなたの目で」を削除し、操作と責任範囲を平文で記述）

#### Slide 19 - 変更内容の確認レポート

- **Audience move**: Diff レポートの開き方と機能を把握する。
- **Layout**: `#48`: 左 40-report-light.png / 右 41-report-dark.png。下に説明 3 件。
- **Title**: 変更内容の確認レポート
- **Core message**: 出力フォルダの Diff-Report をブラウザで開くと、アプリと同じ差分表示を閲覧できる。
- **Content**: ①出力フォルダの sample_win32_sleep-Diff-Report-20260731.html をダブルクリックすると、ブラウザで開きます。表示内容はアプリの「変更内容を見る」と同一の実装です。②左の一覧には変更しなかったモジュールも含めて全モジュールが収録されます。［前の変更］［次の変更］［変更箇所のみ］［折り返し］と、ツールバー右端の明暗を切り替えるボタンが使用できます。③このファイルは単体で完結し、外部への通信や編集機能はありません。改修内容の確認を他の担当者へ依頼する場合は、このファイルを渡します。（旧: P22）
- **Image**: 40-report-light.png, 41-report-dark.png

### Part 3: 相談（P20）

#### Slide 20 - AIで相談する

- **Audience move**: 「AIで相談する」の用途・操作・成果物を把握する。
- **Layout**: `#48`: 左 31-purpose-diagnose.png / 右 37-handoff-diagnose-done.png。下に相談の種類 3 行 + 手順 3 件 + 補足。
- **Title**: AIで相談する
- **Core message**: 「AIで相談する」は、依頼文とコード全文を作成して AI へ渡すまでを行う。ブックは作成せず、手順 2 で完了する。
- **Content**: 種類（画面の表示と同一）: 新しい端末で動くかを調べてもらう — コードは直さず、新しい端末で困りそうな箇所を洗い出してもらいます。／相談用の依頼文を作る（進め方を決めたいとき）— いくつかの質問に答えると、進め方を相談する依頼文ができます。／聞きたいことを自分で書く — マクロについて聞きたいことを、この後の画面で自分の言葉で書きます。手順 ①最初の画面で［AIで相談する］を選択し、ブックを読み込みます。②相談の種類を選択します。「相談用の依頼文を作る」では質問画面が表示され、回答が依頼文に挿入されます。回答は分かる項目のみで進められます。③改修と同様に、依頼文をコピーして貼り付け、source-code.md を添付して送信します。両方の操作が完了すると右下が［完了］になり、押すと最初の画面へ戻ります。補足「作成されるのは request.md と source-code.md のみです。AI の返答はチャット上で確認します。返答で改修方針が決まった場合は、『AIで改修する』の『自分で改修内容を書く』にその方針を記入して改修を行えます。」（旧: P23+P24 統合。「聞くだけの道」等を削除）
- **Image**: 31-purpose-diagnose.png, 37-handoff-diagnose-done.png

### Part 4: 参考（P21–P22）

#### Slide 21 - トラブル時の対処

- **Audience move**: 発生した状況から対処と戻り先を引けるようにする。
- **Layout**: 対処表（状況 / 対処）7 行 + 下段に共通事項。
- **Title**: トラブル時の対処
- **Core message**: いずれの状況でも元のブックは変更されていない。状況に応じた画面へ戻って操作をやり直す。
- **Content**: 表: 返答を取り込めない → コードブロック全体をコピーし直し、もう一度取り込む（P14）／取り込んだ内容が依頼と異なる → ［戻る］で取り込み画面へ戻り、AI に修正を依頼して新しい返答を取り込み直す。前の取り込みは全体が置き換わる／コピー時の記号混入など軽微な崩れ → 確認画面の［手動修正］で修正し［修正を反映］（P15）／「元のブックのマクロが、読み込んだときから変わっています」→ 読み込み後に元のブックのマクロが保存し直された状態。出力は作成されていない。ブックを読み込み直し、依頼から作り直す／「ビルドできませんでした」→ ［もう一度ビルドする］を実行する。再発する場合はログを添えて配布元へ連絡する／「時間がかかっています」→ 処理は継続している。終了まで待つ／依頼を作り直したい → 目的を選び直すと依頼番号が更新される。依頼文を AI へ送り直してから、新しい返答を取り込む。共通「最初からやり直す場合は右上の［最初から］を押します。動作記録は %LOCALAPPDATA%\MacroStudio\logs に保存されます（貼り付けたコードの本文は記録されません）。」（旧: P25）

#### Slide 22 - 動作要件と処理の仕組み

- **Audience move**: 動作要件、MacroStudio のローカル処理の範囲、マクロを直接読み書きする仕組みの要点を把握する。
- **Layout**: 左に動作要件カード（5 行 + 配布 1 行）。右上に「MacroStudioのローカル処理」カード、右下に仕組みカード（3 段入れ子のミニ図 + 説明 2 行）。
- **Title**: 動作要件と処理の仕組み
- **Core message**: 動作要件は Windows 標準構成のみ。MacroStudio は通信機能を持たず、コードの抽出・検証・生成を端末内で行う。
- **Content**: 動作要件 — Windows 10 / 11 ／ Windows PowerShell 5.1（OS 標準）／ WebView2 ランタイム（Windows 11 は標準搭載）／ .NET Framework 4.7.2 以降（OS 標準）／ Excel はツール自体には不要（動作確認時に使用）。インストールは不要で、フォルダをコピーして使用します。ローカル処理「MacroStudio 自体は通信機能を持たず、コードの抽出・返答の検証・改修済みブックの作成を端末内で行います。コードが端末の外へ出るのは、利用者が依頼文の貼り付けと source-code.md の添付をチャット AI（外部サービス）に対して行ったときだけです。」仕組み（ミニ図: ブック（.xlsm）⊃ xl/vbaProject.bin ⊃ マクロのコード）「マクロ全体は、ブック内の xl/vbaProject.bin という 1 ファイルに、Microsoft の公開仕様どおりに格納されています。MacroStudio はこのファイルを直接読み取ります。書き戻しは元のブックのコピーに対して行い、書き戻し後に読み直して検証します。シートの値・書式・数式には触れません。」（旧: P26+P27 の要点を 1 ページに圧縮。旧 P28–P33 は削除）

## X. Speaker Notes Requirements

- **Filename**: match each SVG filename under `notes/`
- **Content**: 各ページのノートは、本文に書かなかった出典（実装事実・検証日）と改訂時の注意点のみを 2〜4 行で書く。本文の読み上げ直しや語りかけはしない。文体は本文と同じく平明なです・ます調。
