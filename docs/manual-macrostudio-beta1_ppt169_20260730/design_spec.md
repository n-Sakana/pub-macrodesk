<!-- ppt-master-schema: design-spec/v1 -->
# manual-macrostudio-beta1 - Design Spec

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | manual-macrostudio-beta1 |
| Canvas Format | PPT 16:9 (1280×720) |
| Page Count | 25 (confirmed range 22-26) |
| Target Audience | 業務部門でマクロを預かっている担当者と、その導入を判断する立場の人。コードは読み書きできないが、AIチャット（Copilot Chat など）は日常的に使える。部門ごとに独自マクロを抱えていて、身近にマクロへ詳しい人がいない状況を想定。 |
| Communication Intent | 二部構成にする。第一部はサービス説明（これがあると何ができるか／何が特徴か／どんな場面で使うか）。第二部は操作マニュアル（画面どおりに一周できる手順）。第一部は長々と説明せず要点だけにする。売りは「コードを読み書きできなくても、AIチャットが使えればマクロを直せる」こと。第一部には仕組みの説明を持ち込まない。『まとめて取り込む』『番号で取り違えない』のような作り手側の理屈ではなく、読み手にとって何ができるようになり何を心配しなくてよくなるかで書く。仕組みが要る話は第二部に置く。専門用語や開発ツールの固有名詞は出さず、『開発画面』のような普通の言葉で言い換える。 |
| Desired Audience Outcome | 前半で『自分の部門のあのマクロに使えそうだ』『これなら自分にもできそうだ』と判断できる。後半で、実際にブックの読み込みから改修済みブックの作成まで、画面を見ながら迷わず一周できる。改修せずに診断・相談だけしたいときの終わり方も分かる。 |
| Core Message / Ask / Action | コードを読み書きできなくても、AIチャットが使えればマクロは直せる。開発画面を開く必要はなく、元のブックは変更されない。 |
| Delivery Context | 部門への紹介と配布を兼ねる。説明会で投影して前半を見せることもあれば、手元でアプリを操作しながら後半を参照することもある。 |
| Artifact Afterlife | 導入を検討するときの説明材料。運用が始まってからは操作の参照先。ベータ版1.0.0時点の画面の記録も兼ねる。 |
| Reading Mode | balanced（`delivery_purpose: balanced` / lock `consumption_mode: balanced`）— 投影でも手元参照でも成立する密度。ページが主張を持ち、話者・ノートが補足する |
| Content Strategy | `content_divergence` は空欄（バランス既定）。原稿 `sources/macrostudio-manual-source.md` を再構成し、第一部（同ファイル A〜G 節）と第二部（同ファイル 1〜10 節）へ振り分ける。画面の見出し・ボタン名・案内文は実装から抽出した実物なので**一字一句変更しない**。第一部は仕組みの説明を持ち込まず、読み手にとって何ができるようになり何を心配しなくてよくなるかで書く。「VBE」「モジュール」「Win32 API」等の固有名詞・専門語は第一部では使わず、第二部でも画面に実際に出る語だけを使う。原稿にない事実・数値は追加しない |
| Design Style | mode: custom「二部構成（紹介 → 手順）」 / visual_style: soft-rounded / 「実務の青」パレット / 読みやすいゴシック |
| Created Date | 2026-07-30 |

- **Mode Behavior (confirmed)**: 第一部は導入を判断する立場の人に向けた紹介の調子。困りごと → できること → 安心できる理由 → 使いどころ、の順に運び、1ページ1メッセージ、見出しは断定形、余白を多めに取る。第二部は実際に操作する人に向けた手順の調子。アプリの画面順にそのまま進み、各ページはまず「この画面で何を決めるか」を述べてから、実際の画面写真と操作を並べる。見出しにはアプリ画面の言葉をそのまま使う。第一部と第二部のあいだに区切りページを1枚置き、読み手の立場が切り替わることを明示する。

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280×720 |
| viewBox | `0 0 1280 720` |
| Margins | 上下左右 40px（安全域 1200×640） |
| Content Area | x: 40–1240 / y: 40–680。ページ見出し帯は y 40–130、本文域は y 150–660、右下にページ番号 |

## III. Visual Theme

### Theme Style

- **Mode**: custom —「二部構成（紹介 → 手順）」（§I の Mode Behavior が実行契約）
- **Visual style**: soft-rounded
- **Theme**: 社内で配れる実務書。角丸カード、控えめな段差、装飾なし。第二部は「左に短い説明・右に画面写真」の骨格を最後まで崩さない
- **Tone**: 落ち着いて、脅かさない。断定形で短く。第一部は余白多め、第二部は情報密度を上げる

### Color Scheme

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | `#FFFFFF` | 全ページの地。画面写真の白と地続きにして写真が浮かないようにする |
| Secondary background | `#F1F5F9` | カード面・表の縞・写真の敷き板・区切りページの地 |
| Primary | `#1F4E79` | 見出し、手順番号、区切りページの地、強い罫 |
| Accent | `#E07B39` | 注意点、押すボタンの指示、「ここだけは」の強調。1ページ 1〜2 箇所まで |
| Secondary accent | `#4A87C4` | 流れの矢印、補助ラベル、進捗の既読部分 |
| Body text | `#1F2933` | 本文（`#FFFFFF` 上で 14:1 以上） |
| Surface | `#F8FAFC` | 淡い面（`secondary_bg` より一段淡い） |
| Field | `#F4F6F8` | 画面写真を載せる敷き板（写真の白と地の白を分ける） |
| Grid | `#E2E8F0` | 表の罫線・カード境界・見出し下のヘアライン |
| Divider | `#CBD5E1` | セクション区切りの実線 |
| Muted text | `#5B6B7C` | 注釈・キャプション・ページ番号 |
| Positive | `#2E7D5B` | 「壊れない」「やり直せる」を伝えるコールアウトの枠とアイコン（状態色。Strategist 導出） |

- 60-30-10: `#FFFFFF`/`#F1F5F9` が地、`#1F4E79` が構造、`#E07B39` は 1ページ 1〜2 箇所。1ページの色数は 4 色まで。
- soft-rounded は面を重ねる style なので `surface` と `grid` を確定させる。影は使わず、面の切り替えは背景色の段差で表す。

## IV. Typography System

### Font Plan

| Role | Chinese | English | Fallback tail |
| --- | --- | --- | --- |
| Title | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Body | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Emphasis | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Code | Consolas | Consolas | `Consolas,monospace` |

- Title: Yu Gothic UI（見出し。太さで階層を出し、字を大きくしすぎない）
- Body: Yu Gothic UI（同上。日本語の可読性を優先し、明朝は使わない）
- Emphasis: same as Body（太字と `accent` 色で処理）
- Code: Consolas（ファイル名・フォルダ構成・拡張子など、画面に出る文字列そのまま）

### Font Size Hierarchy

| Purpose | Size |
| --- | --- |
| Body | 24px |
| Page title | 42px |
| Subtitle | 32px |
| Lead | 30px |
| Annotation | 18px |
| Footnote / page number | 16px |
| Cover title | 72px |
| Section number (区切り) | 96px |

- 確定値（`body 24` / `title 42` / `subtitle 32` / `annotation 18`）は再導出しない。`lead 30` と `footnote 16` は §IX の実使用から追加宣言。
- 表の中身は 20px まで下げてよい（P04 / P19 / P24 の表のみ）。それ以外は 24px を下限とする。

## V. Layout Principles

### Page Structure

- **Header band**: y 44–118。左端 x=40 に手順ラベルのピル（`primary` 塗り・角丸 18・白 18px 太字）、その右 24px から見出し 42px。y=118 に `grid` のヘアラインを全幅（40–1240）で引く。ページの核心メッセージは帯にせず、版面内のコールアウト（色枠＋アイコン）で伝える
- **Content area**: y 144–652。手順ページは「左 680px の画面写真＋その下のコールアウト／右 504px の番号付き手順」の二段組を最後まで崩さない
- **Footer area**: y 668–700。左に「第一部 サービス説明」／「第二部 操作マニュアル」、右にページ番号（16px, `muted`）。表紙・区切りページには置かない

### Spacing Specification

| Element | Current Project |
| --- | --- |
| Safe margin | 40px（版面 40–1240 × 40–680、1200×640） |
| 画面写真の版 | 敷き板 680×386（`field`）／写真 672×378（角丸 10 でクリップ、`grid` の細枠） |
| Content block gap | 24px（カード間）／20px（箇条書き行間） |
| Icon-text gap | 12px（アイコン 26–28px 角） |
| コールアウト | 角丸 14・地は `background`・枠 2px（安心＝`positive` / 注意＝`accent`）・左にアイコン |

## VI. Icon Usage Specification

ライブラリは `tabler-filled` に統一（soft-rounded の丸みと合う塗りアイコン）。`icon_sync.py` で 20 個をプロジェクトへ複製済み。ここに無いアイコンは使わない。

| Purpose | Icon Path | Page |
| --- | --- | --- |
| マクロ入りのブック・コード | `tabler-filled/file-code` | P02, P03, P11 |
| AIチャット | `tabler-filled/message-chatbot` | P03, P09, P17, P23 |
| できる・完了 | `tabler-filled/circle-check` | P03, P04, P21 |
| 注意・つまずき | `tabler-filled/alert-triangle` | P11, P19, P24 |
| 出力フォルダ | `tabler-filled/folder-open` | P17, P21, P22 |
| コピー・取り込み | `tabler-filled/clipboard-check` | P17, P18 |
| 確認する | `tabler-filled/eye` | P12, P20 |
| 差分レポート | `tabler-filled/file-diff` | P20, P22 |
| 次へ・流れ | `tabler-filled/circle-arrow-right` | P09, P13, P25 |
| 元のブックは無傷 | `tabler-filled/shield-check` | P03, P04, P12, P20 |
| ひな形・選択肢 | `tabler-filled/list-check` | P14, P24 |
| 質問・聞く | `tabler-filled/help-circle` | P15, P23 |
| 仕様・決まりごと | `tabler-filled/settings` | P24 |
| 担当者 | `tabler-filled/user` | P02, P05 |
| 順番待ち・時間 | `tabler-filled/clock` | P02 |
| 使いどころ | `tabler-filled/bulb` | P05 |
| 依頼文 | `tabler-filled/file-text` | P16, P22 |
| やらないこと | `tabler-filled/circle-x` | P07 |
| 起動 | `tabler-filled/player-play` | P06, P10 |
| 診断・調べる | `tabler-filled/search` | P05, P23 |

## VII. Visualization Reference List

| Page | Template | Path | Summary-quote | Usage |
| --- | --- | --- | --- | --- |
| P04 | comparison_table | templates/charts/comparison_table.svg | "Pick for 2-4 plans/products compared across many feature rows (dense matrix). Skip for pricing-tier marketing layout (use comparison_columns)." | 「今までの心配」「このツールでは」の 2 列 × 6 行を密度のある対照表として置く。製品比較ではなく心配→答えの対なので、列見出しは製品名ではなく状態名にし、右列だけ `secondary_bg` で受ける |
| P05 | vertical_list | templates/charts/vertical_list.svg | "Pick for 3-6 numbered key points each with a short description — design principles, core tenets, action items, key takeaways, recommendations, executive summary points. Skip for icon-style cards (use icon_grid) or sequential steps (use numbered_steps)." | 想定する使い方 5 件。番号＋見出し＋一行説明。右端に「改修／聞くだけ」の別を小さなラベルで付ける |
| P09 | process_flow | templates/charts/process_flow.svg | "Pick for 3-8 sequential steps connected by simple arrows — approval workflows, customer onboarding, request handling, lifecycle stages. Skip if cyclical (use circular_stages) or stages produce named outputs (use pipeline_with_stages)." | 改修の 4 手順を横一列の矢印で。手順 1 の直後から「聞くだけ」の分岐を下へ引き、手順 2 で終わることを示す。テンプレートの等間隔列を分岐に合わせて崩す |
| P22 | no-template-match | — | — | フォルダ 1 つ＋ファイル 5 つの実体一覧。フォールバックはカスタムレイアウト（Consolas のツリー表記＋各ファイルの役割カード）。`top_down_tree` は組織図・OKR 分解の意味づけが強く、ファイル一覧の読み方と合わないため不採用 |

Runners-up considered:

- `pros_cons_chart` | rejected for P04: 2 列が「良い／悪い」の評価ではなく、同じ 1 行の前後（心配 → 解消）の対なので、賛否の版面にすると意味がずれる
- `segmented_wheel` | rejected for P04: 6 項目を円周へ均等配置すると読み順が消え、対の関係が見えなくなる
- `arc_anchored_list` | rejected for P05: 5 件は並列の使い道であって、中心となる 1 つの核から派生していない
- `agenda_list` | rejected for P05: 目次・議事の版面で、所要時間や担当の欄が余る
- `chevron_process` | rejected for P09: 方法論のフェーズ表現で、分岐して途中で終わる道を描けない
- `pipeline_with_stages` | rejected for P09: 各手順の成果物名を並べる版面になり、P22 の出力ファイル一覧と役割が重複する
- `top_down_tree` | rejected for P22: 上記のとおり階層の意味づけが階層構造そのものではなくファイル一覧のため

**Native-preset note**: P09 の分岐矢印は PowerPoint 標準のシェブロン／ブロック矢印が素直に当たる。Executor の native-shape 分岐で判断すること。

## VIII. Image Resource List

素材はすべて実機から取得した操作画面。**加工・切り抜きは行わない**（文字がつぶれるため）。原寸 2732×1536 / 比 1.78 のまま、`surface` 面の内側に余白付きで置く。第一部は 1 枚のみ、残りは第二部。人物写真・ストック写真・AI 生成画像は使わない。

| Filename | Dimensions | Ratio | Purpose | Type | Layout pattern | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 05-mode.png | 2732x1536 | 1.78 | 「このマクロをどうしたいか選びます」— 利用者の仕事は選ぶことだけ、と示す第一部唯一の実画面 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 2 枚のカードが並ぶ選択画面。第一部では操作説明ではなく「選ぶだけ」の証拠として置く | none | local |
| 01-drop.png | 2732x1536 | 1.78 | 画面の見かた（進捗の帯・左下の案内・テーマ切替・対応形式）を指し示す | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 起動直後の読み込み画面。番号付きの丸を 4 箇所に置き、右の凡例で各部位を説明する | none | local |
| 02-book-loaded.png | 2732x1536 | 1.78 | ブックを読み込めた状態（ファイル名・パスが出て［次へ］が青くなる） | Screenshot | #19 Image floating in whitespace with thin frame and caption | user | Existing | 読み込み後の画面。［次へ］が有効化された箇所に `accent` の細枠を重ねる | none | local |
| 03-read.png | 2732x1536 | 1.78 | 読み取り結果の要約（モジュール数・行数） | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 閉じた状態。左側 | none | local |
| 04-read-open.png | 2732x1536 | 1.78 | 「読み取った内容を見る」を開いた状態 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 開いた状態。右側。開閉が対であることを示す | none | local |
| 06-mode-refactor.png | 2732x1536 | 1.78 | 「マクロを改修する」を選んだ状態。選んでも自動では進まない | Screenshot | #19 Image floating in whitespace with thin frame and caption + #46 Bordered "lens" rectangle | user | Existing | 選択済みカードと右下［次へ］の 2 箇所をレンズ枠で示す | none | local |
| 07-purpose-refactor.png | 2732x1536 | 1.78 | 「どんな改修をするか選びます」— 同梱ひな形の一覧 | Screenshot | #80 Side hero image + staggered evidence cards | user | Existing | 画面を右の主役に置き、左に 6 つのひな形の説明カードを段違いに配置 | none | local |
| 22-questions.png | 2732x1536 | 1.78 | 質問画面（選択式の問） | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 1 枚目。上の丸が進捗 | none | local |
| 23-questions-text.png | 2732x1536 | 1.78 | 質問画面（自由記述の問） | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 2 枚目。複数行で書ける | none | local |
| 24-questions-last.png | 2732x1536 | 1.78 | 質問画面（最後の問） | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 3 枚目。中間の丸が省略される様子 | none | local |
| 08-request.png | 2732x1536 | 1.78 | 「AIへ送る依頼文を用意しました」— そのまま進んでよい | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 閉じた状態。左側 | none | local |
| 09-request-open.png | 2732x1536 | 1.78 | 「依頼文を確認・編集」を開いた状態 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 開いた状態。右側。依頼番号が本文に埋まっていることを注記する | none | local |
| 10-handoff.png | 2732x1536 | 1.78 | 「AIチャットへ改修を依頼します」— 2 つのボタンを押す前 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 押す前。左側。［次へ］はまだ使えない | none | local |
| 11-handoff-done.png | 2732x1536 | 1.78 | 2 つのボタンを押したあと（［次へ］が使える） | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 押したあと。右側。両方押して初めて進めることを示す | none | local |
| 12-intake.png | 2732x1536 | 1.78 | 「AIの返答をまとめて取り込みます」— 取り込む前 | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 1 枚目 | none | local |
| 13-intake-done.png | 2732x1536 | 1.78 | 取り込み結果（件数と既存・新規の内訳） | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 2 枚目 | none | local |
| 14-intake-summary.png | 2732x1536 | 1.78 | 「AIが書いた改修内容を見る」を開いた状態 | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 3 枚目。日本語で読めることを示す | none | local |
| 15-review.png | 2732x1536 | 1.78 | 「取り込んだ変更を確認します」— 要約 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 閉じた状態。左側。採用ボタンが無いことを注記する | none | local |
| 16-review-diff.png | 2732x1536 | 1.78 | 「変更内容を見る」を開いた状態（モジュール一覧＋差分） | Screenshot | #48 Side-by-side comparison + #46 Bordered "lens" rectangle | user | Existing | 開いた状態。右側。左のツリーの増減表記と右の色分けをレンズ枠で指す | none | local |
| 17-output-name.png | 2732x1536 | 1.78 | 「作成する改修済みブックを確認します」— 出力名 | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 1 枚目 | none | local |
| 18-building.png | 2732x1536 | 1.78 | 「改修済みブックをビルドしています」 | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 2 枚目。自動で進む | none | local |
| 19-done.png | 2732x1536 | 1.78 | 「改修済みブックを作成しました」 | Screenshot | #47 Small multiples + #21 Rounded rectangle crop | user | Existing | 3 枚組の 3 枚目。右下が［完了］になる | none | local |
| 20-mode-diagnose.png | 2732x1536 | 1.78 | 「マクロについてAIに聞く」を選んだ状態 | Screenshot | #50 Tiled grid (2×2) + #21 Rounded rectangle crop | user | Existing | 2×2 の 1 枚目 | none | local |
| 21-purpose-diagnose.png | 2732x1536 | 1.78 | 「AIに何を聞くか選びます」 | Screenshot | #50 Tiled grid (2×2) + #21 Rounded rectangle crop | user | Existing | 2×2 の 2 枚目 | none | local |
| 25-request-diagnose.png | 2732x1536 | 1.78 | 聞くだけの場合の依頼文画面 | Screenshot | #50 Tiled grid (2×2) + #21 Rounded rectangle crop | user | Existing | 2×2 の 3 枚目 | none | local |
| 26-handoff-diagnose.png | 2732x1536 | 1.78 | 「AIチャットへ質問します」— 右下が［完了］で終わる | Screenshot | #50 Tiled grid (2×2) + #46 Bordered "lens" rectangle | user | Existing | 2×2 の 4 枚目。［完了］をレンズ枠で示す | none | local |

**Image-as-Canvas + Native Overlay の適用**: P10 が `#45`（番号付きホットスポット＋凡例）。画面写真の上に番号の丸と引き出しを SVG で描き、説明文は SVG テキストで持つ。他ページは切り抜き不可のスクリーンショットが主題そのものであり、写真を背景として扱うと文字が読めなくなるため、枠付き配置と対比配置を採る。

**画像に文字を焼き込まない**: すべての注記・番号・キャプションはネイティブ SVG テキストで描く（`text_policy: none`）。

## IX. Content Outline

### Part 1: サービス説明 — このツールがあると何ができるか（P01–P08）

#### Slide 01 - 表紙

- **Audience move**: 「コードが読めない自分の話だ」と気づき、続きを読む構えになる
- **Cover impact**: フック＝「コードは読めなくていい。」という否定形の断言を巨大に置く。構成戦略＝typographic poster。全面白地に 76px の主題を左寄せで置き、その下に `primary` の太い横罫 1 本、罫の下に副題。右下に小さく製品名とベータ表記。画面写真もカード群も置かない（表紙で内容ページの型を出さない）
- **Layout**: タイポグラフィック・ポスター（全面白地、左寄せ、右下に版表記）
- **Title**: コードは読めなくていい。
- **Core message**: AIチャットが使えれば、マクロは直せる
- **Content**:
  - 主題（76px）: 「コードは読めなくていい。」
  - 副題（32px）: 「AIチャットが使えれば、Excel マクロは直せます。開発画面は開きません。」
  - 版表記（18px, muted, 右下）: 「MacroStudio ベータ版 1.0.0 ／ サービス説明と操作マニュアル」

#### Slide 02 - 困りごと

- **Audience move**: 自部門の状況が言い当てられていると認め、他人事をやめる
- **Layout**: 4 分割カード（2×2）。各カードにアイコン＋一行
- **Title**: マクロは残っているのに、直せる人がいない
- **Core message**: 直せないのは能力の問題ではなく、直すのに開発の知識が要るから
- **Content**:
  - カード1（`file-code`）: 業務マクロは部門ごとに育ち、作った人はもう居ないことが多い。
  - カード2（`user`）: 直すには開発画面を開いてコードを読む必要があり、担当者には手が出ない。
  - カード3（`alert-triangle`）: 端末やファイルの置き場所が変わると動かなくなる。
  - カード4（`clock`）: 詳しい人に頼むと順番待ちになり、業務が止まる。

#### Slide 03 - できるようになること

- **Audience move**: 「自分にもできそうだ」と判断する（第一部の核）
- **Layout**: 左 500px に見出し＋5 行の箇条書き、右 700px に実画面 1 枚（`#19` 枠＋キャプション）
- **Title**: 直しかたを考えるのは AI。こちらは選ぶだけ
- **Core message**: コードを読み書きできなくても、マクロは直せる
- **Content**:
  - **コードを読み書きできなくても、マクロを直せる。** 直しかたを考えるのは AI。こちらは画面に出てくることに答えるだけ。（`circle-check`）
  - **開発画面を一度も開かない。** 案内どおりに［次へ］を押していけば終わる。（`circle-check`）
  - **元のブックはそのまま残る。** 直したものは別名の新しいブックとして作られる。（`shield-check`）
  - **鵜呑みにしなくていい。** どこが変わったのかを見てから、作るかどうかを決められる。（`eye` 相当は `circle-check` で統一）
  - **直さずに、聞くだけでもいい。** 「新しい端末で動くか」「どう直すのが良いか」を AI に相談するところで終わってもよい。（`message-chatbot`）
  - 画像: `05-mode.png` ／ キャプション「利用者がすることは、この 2 枚から選ぶこと」

#### Slide 04 - 心配しなくてよくなること

- **Audience move**: 導入前に浮かぶ不安を 6 つ潰し、反論の材料を失う
- **Layout**: 2 列 × 6 行の対照表（`comparison_table` を心配→答えの対に読み替え）。左列は `background`、右列は `secondary_bg` で受ける。表内は 20px
- **Title**: 心配しなくてよくなること
- **Core message**: 手間も、事故も、あとの説明も、この道具の側で受け持つ
- **Content**:
  - 列見出し: 「今までの心配」／「このツールでは」
  - 何をどう頼めばいいか分からない → 頼みたいことを選べば、AI へ渡す文章はこちらで用意される
  - コピペを間違えそう → 貼り付けは 1 回だけ。中身を仕分けて写す作業はない
  - 直った内容が正しいか分からない → 変わった場所を見てから、作るかどうかを決められる
  - 元のブックを壊しそう → 元のファイルには触れない。作り直せば何度でもやり直せる（`shield-check`）
  - 後で誰も説明できない → 何を頼み、何が変わったのかが 1 か所に残る
  - 部門ごとにやり方が違う → よく頼む内容は、自分たちのひな形として増やせる

#### Slide 05 - 想定する使い方

- **Audience move**: 自部門の具体的な案件を 1 つ思い浮かべる
- **Layout**: `vertical_list`（番号＋見出し＋一行説明、5 行）。右端に「改修／聞くだけ」の小ラベル
- **Title**: こんなときに使います
- **Core message**: 直すときだけでなく、調べたい・決めたいときにも使える
- **Content**:
  1. **端末の入れ替えに備える** — 新しい環境で動かなくなる箇所を洗い出してもらう。〔聞くだけ〕（`search`）
  2. **動かなくなったマクロを直す** — 使えなくなった機能を、標準機能だけの形へ置き換える。〔改修〕
  3. **担当者しか触れないマクロを整理する** — 動きを変えずに読みやすく直す。〔改修〕
  4. **どう直すか決める** — いくつかの質問に答えて、進め方を AI と相談する材料を作る。〔聞くだけ〕（`bulb`）
  5. **中身を知りたい** — このマクロが何をしているのかを聞く。〔聞くだけ〕

#### Slide 06 - 使う前に必要なもの

- **Audience move**: 導入の障壁が無いことを確認し、「試せる」と結論づける
- **Layout**: 4 つの横並びカード＋下に 1 行の補足帯（`secondary_bg`）
- **Title**: 用意するものは 4 つだけ
- **Core message**: 特別な権限も、インストール作業も要らない
- **Content**:
  - Windows の PC と Excel
  - 使える AI チャット（Microsoft 365 Copilot Chat など、社内で許可されているもの）
  - 直したいマクロ入りのブック
  - `launch.vbs` をダブルクリックするだけ（`player-play`）
  - 補足帯（`accent` 文字）: 特別な権限やインストール作業は不要です。

#### Slide 07 - このツールがやらないこと

- **Audience move**: 過大な期待を持たずに済み、かえって信用する
- **Layout**: 4 行の箇条書き（各行 `circle-x`）。右に 1 枚の引用帯で「だから安全side」を短く
- **Title**: このツールがやらないこと
- **Core message**: 判断と最終確認は人と AI に残す。だから壊れない
- **Content**:
  - どこをどう直すかを決めること。それは AI に聞く。
  - 元のブックを書き換えること。必ず別名で作る。
  - マクロを勝手に増やして構造を変えること。増やせる範囲は限ってある（詳しくは第二部）。
  - 直ったマクロを実際に動かして確かめること。最後に Excel で開いて確認するのは人。

#### Slide 08 - 区切り（第二部へ）

- **Audience move**: 読み手としての立場を「検討する人」から「操作する人」へ切り替える
- **Layout**: 全面 `primary` 地。左肩に 96px の「2」、中央左寄せに部の題、下に一行
- **Title**: 第二部 — 操作マニュアル
- **Core message**: ここから先は、画面のとおりに進めば終わります
- **Content**:
  - 部の題（52px, 白）: 「第二部 操作マニュアル」
  - 一行（30px, 白 80%）: 「ここからは、実際に操作する人向けです。画面の順にそのまま進みます。」

### Part 2: 操作マニュアル — 画面のとおりに一周する（P09–P25）

#### Slide 09 - 全体の流れ

- **Audience move**: 自分がどちらの道を通るのか、どこで終わるのかを先に把握する
- **Layout**: `process_flow` を横一列に。手順 1 の直後から下方向へ分岐線を引き、手順 2 で終わる短い道を併記。上に 2 択の説明帯
- **Title**: まず、どちらかを選びます
- **Core message**: ブックを書き換えるのは「改修する」だけ。聞くだけなら手順 2 で終わる
- **Content**:
  - 2 択（`secondary_bg` の帯 2 本）:
    - 「マクロを改修する」— AI の返答を取り込み、改修済みブックを作る → 5 ファイルができる
    - 「マクロについて AI に聞く」— 依頼文とコード全文を作る → 2 ファイルができる（`message-chatbot`）
  - 流れ（4 ステップ、`circle-arrow-right` で接続）: 1 ブックを読み込む → 2 AI へ依頼する → 3 返答を取り込む → 4 ブックを作る
  - 分岐注記（`accent`）: 「聞くだけの場合は、手順 2 で［完了］が出ます。」

#### Slide 10 - 画面の見かた

- **Audience move**: 起動後にどこを見ればよいか分かり、迷子にならない
- **Layout**: `#45` — 実画面 1 枚を大きく置き、4 箇所に番号付きの丸、右に凡例
- **Title**: 起動と、画面の見かた
- **Core message**: 上の帯が進捗、左下が「いま何をすればよいか」
- **Content**:
  - 起動: `launch.vbs` をダブルクリック。黒いコマンド画面は出ません。小さな読み込み画面のあと本画面になります。
  - ホットスポット1（上部の帯）: 進捗です。**最初は「ブックを読み込む」だけが表示され**、目的を選ぶとその先の手順が現れます。改修なら 4 手順、聞くだけなら 2 手順。
  - ホットスポット2（左下）: 「いま何をすればよいか」が 1 行で出ます。
  - ホットスポット3（右上の月／太陽）: ライト・ダークを切り替えられます。選択は次回も維持されます。
  - ホットスポット4（右上の形式表示）: 対応形式は `.xlsm` / `.xlam` / `.xlsb` / `.xls`。
  - 画像: `01-drop.png`

#### Slide 11 - 手順 1・1/3 ブックを読み込む

- **Audience move**: 対象のブックを実際に読み込ませる
- **Layout**: 左 460px 説明 ／ 右 700px 画面写真（以降 P21 まで同じ骨格）
- **Title**: Excelブックを読み込みます
- **Core message**: ドラッグして落とすだけ。まだ何も書き込まれない
- **Content**:
  - 画面中央へ Excel ファイルをドラッグ＆ドロップします。クリックして選ぶこともできます。
  - 案内文はこう出ます: 「改修したいブックを、ここへドラッグするか選んでください。」
  - 読み込めると、ファイル名とパスが表示され、右下の［次へ］が青くなります。
  - 選び直したいときは［選び直す］。
  - つまずき（`alert-triangle`, `accent`）: マクロを含まないブックを選ぶと「このブックにはマクロが無い」旨のカードが出ます。ファイルを間違えていないか確認してください。
  - 画像: `02-book-loaded.png`

#### Slide 12 - 手順 1・2/3 読み取り結果を確認する

- **Audience move**: 読めた量を確かめ、元のブックが無事だと理解する
- **Layout**: `#48` — 左「閉じた状態」／右「開いた状態」を同じ大きさで並べ、中央に細い区切り線
- **Title**: 読み込んだマクロを確認します
- **Core message**: ここではまだ、元のブックに一切書き込んでいない
- **Content**:
  - 「受注管理.xlsm から 4モジュール・412行を読み込みました」のように結果が出ます。
  - 中身を見たいときは **「読み取った内容を見る」** を開くと、モジュール名と行数の一覧が出ます。（`eye`）
  - ここでは元のブックには一切書き込んでいません。（`shield-check`）
  - 画像: `03-read.png`（左・閉じた状態）／ `04-read-open.png`（右・開いた状態）

#### Slide 13 - 手順 1・3/3 どうしたいか選ぶ

- **Audience move**: 2 枚のカードから 1 つ選び、［次へ］で確定する
- **Layout**: 左 460px 説明（2 枚のカード文言を転記）／ 右 700px 画面写真＋レンズ枠 2 箇所
- **Title**: このマクロをどうしたいか選びます
- **Core message**: 選んでも自動では進まない。［次へ］で確定する
- **Content**:
  - 「マクロを改修する」— AIの返答を取り込んで、改修済みのブックをこのアプリで作ります。
  - 「マクロについてAIに聞く」— AIチャットへ渡す依頼文とコードを作ります。ブックは変更しません。
  - 注意（`accent`）: **選んでも自動では進みません。**［次へ］で確定します。
  - 選ぶと、画面上部の進捗にその先の手順が現れます。（`circle-arrow-right`）
  - 画像: `06-mode-refactor.png`

#### Slide 14 - 手順 2・1/3 依頼の内容を選ぶ

- **Audience move**: 6 つのひな形から目的に合うものを選ぶ
- **Layout**: `#80` — 右に画面写真、左に 6 件の説明カードを段違いに 2 列
- **Title**: どんな改修をするか選びます
- **Core message**: 一覧に出るのはファイル名ではなく、ひな形の見出し
- **Content**:
  - 〔改修〕VBAリファクター（動きを変えずに整理・改善する）— 動作を変えずに、読みやすさ・速さ・壊れにくさを直します
  - 〔改修〕Win32 API を使わない形へ直す — 依存した箇所を、VBA 標準機能だけの形へ置き換えます
  - 〔改修〕自分で改修内容を書く — 改修してほしい内容を自分の言葉で書きます
  - 〔聞く〕新しい端末で動くかを調べてもらう — 動かなくなる箇所と直し方の方針を挙げてもらいます
  - 〔聞く〕相談用の依頼文を作る（進め方を決めたいとき）— 質問に答え、AI と方針を決めるための 1 通目を作ります
  - 〔聞く〕聞きたいことを自分で書く — 聞きたいことを自分の言葉で書きます
  - 注記（`list-check`）: 「AIに聞く」を選んだ場合、この画面の見出しは「AIに何を聞くか選びます」になります。ひな形は自分で増やせます（P24）。
  - 画像: `07-purpose-refactor.png`

#### Slide 15 - 手順 2・2/3 いくつか答える

- **Audience move**: 分かる範囲だけ答えて先へ進む
- **Layout**: `#47` — 同じ枠の 3 枚組を横一列。各枚の下に一行キャプション
- **Title**: いくつか教えてください（ひな形に質問がある場合だけ）
- **Core message**: 1 問ずつ。分かるところだけで大丈夫
- **Content**:
  - 質問が **1 問ずつ** 出ます。上の丸（番号入り）が進捗で、答えた問は色が付きます。
  - 移動は左右の矢印、または丸を直接クリック。問数が多いときは中間の丸が省略されます。
  - 選択式の問はボタンを 1 回押すだけ。自由記述の問は複数行で書けます。
  - 分かるところだけで大丈夫です。1 問以上答えると［次へ］が使えます。（`help-circle`）
  - 答えた内容は、次の画面の依頼文に【質問への回答】として折り込まれます。
  - 画像: `22-questions.png`（選択式）／ `23-questions-text.png`（自由記述）／ `24-questions-last.png`（最後の問）

#### Slide 16 - 手順 2・3/3 依頼文を確認する

- **Audience move**: そのまま進むか、直すかを決める
- **Layout**: `#48` — 左「そのままの状態」／右「開いて編集できる状態」
- **Title**: AIへ送る依頼文を用意しました
- **Core message**: できあがっているので、そのまま進んで構わない
- **Content**:
  - 依頼文はできあがっています。**そのまま進んで構いません。**
  - 直したいときだけ **「依頼文を確認・編集」** を開きます。全文が編集できます。（`file-text`）
  - 依頼文には、この依頼だけの **依頼番号**（毎回変わる長い英数字）が埋め込まれます。返答を取り込むときの照合に使うので、消さないでください。（`accent`）
  - 画像: `08-request.png`（左）／ `09-request-open.png`（右）

#### Slide 17 - 手順 2・4/4 AIチャットへ渡す

- **Audience move**: コピーとファイル添付を実際に行い、AIへ送る
- **Layout**: `#48` — 左「押す前」／右「押したあと」。下に 3 手順の帯
- **Title**: AIチャットへ改修を依頼します
- **Core message**: 依頼文を貼り、コードのファイルを添える。両方のボタンを押すまで進めない
- **Content**:
  - ［次へ］を押した時点で、この改修専用のフォルダが作られ、2 つのファイルが書き出されます。（`folder-open`）
  - 1. ［依頼文をコピー］→ クリップボードに依頼文が入ります（`clipboard-check`）
  - 2. ［ファイルの場所を開く］→ エクスプローラーでフォルダが開きます
  - 3. チャット AI に依頼文を貼り付け（Ctrl+V）、`source-code.md` を添付して送信します（`message-chatbot`）
  - 注意（`accent`）: **両方のボタンを押すまで［次へ］は使えません。**
  - 画面の案内: 「マクロが読み書きするExcelシートやファイルがあれば、それも一緒にAIチャットへ添付すると、より正確な回答が得られます。」
  - 聞くだけの場合はここで終わりです。右下が［完了］になります。
  - 画像: `10-handoff.png`（左・押す前）／ `11-handoff-done.png`（右・押したあと）

#### Slide 18 - 手順 3・1/2 返答を取り込む

- **Audience move**: 返ってきたコードブロックをコピーし、1 回のボタンで取り込む
- **Layout**: `#47` — 3 枚組（取り込む前 / 結果 / 要約を開いた状態）
- **Title**: AIの返答をまとめて取り込みます
- **Core message**: コードブロックをコピーして、ボタンを 1 回押すだけ
- **Content**:
  - AI は、変更したモジュールと新しく作ったモジュールの全文を **1 つのコードブロック**にまとめて返します。
  - そのコードブロックをコピーして、**［クリップボードからAIの返答を取り込む］を 1 回押すだけ**。Ctrl+V でも同じです。（`clipboard-check`）
  - **モジュールを選ぶ必要も、1 つずつ貼る必要もありません。**
  - 取り込めると「2個のモジュールを取り込みました」と結果が出て、既存・新規の内訳も出ます。
  - AI が書いた改修内容の要約も一緒に取り込まれます。**「AIが書いた改修内容を見る」** を開くと日本語で読めます。
  - 画像: `12-intake.png`／`13-intake-done.png`／`14-intake-summary.png`

#### Slide 19 - 取り込めないとき

- **Audience move**: 表示された文言から原因を引き、その場で直す
- **Layout**: 3 列 × 5 行の表（表示されること／意味／どうするか）。表内 20px。上に 1 行の安心帯
- **Title**: 取り込めないとき
- **Core message**: 取り込めなかったときは何も取り込まれない。そのままやり直せる
- **Content**:
  - 安心帯（`shield-check`, `secondary_bg`）: どの場合も何も取り込まれないので、そのままやり直せます。
  - 別の依頼への返答のようです ／ 依頼番号が今回のものと違う ／ 依頼文をコピーし直して AI へ送り直す
  - 返答が途中で切れているようです ／ 終わりの行が無い ／ コードブロック全体をコピーし直す
  - 取り込める形のコードが見つかりませんでした ／ 区切り行が無い ／ コードブロック全体（区切り行を含む）をコピーし直す
  - 同じモジュールが2回入っていました ／ 重複 ／ AI へ、モジュールごとに 1 つだけ返すよう伝える
  - クリップボードが空でした ／ コピーできていない ／ コードブロックのコピーボタンで取り直す

#### Slide 20 - 手順 3・2/2 変更を確認する

- **Audience move**: 変わった場所を見て、進むか取り込み直すかを決める
- **Layout**: `#48` — 左「要約」／右「変更内容を開いた状態」＋レンズ枠 2 箇所
- **Title**: 取り込んだ変更を確認します
- **Core message**: 取り込めた内容が、そのまま書き戻す対象。採用ボタンは無い
- **Content**:
  - まず結果の要約が出ます。**取り込めた内容が、そのまま書き戻す対象**です。採用ボタンはありません。
  - 中身を見たいときは **「変更内容を見る」** を開きます。（`eye`）
    - 左: モジュール一覧。標準 / クラス / シートで区分され、`+5 −2` のように増減行数が出ます。
    - 右: インライン差分。削除行は赤、追加行は緑、左に行番号が 2 列。（`file-diff`）
    - ［変更箇所のみ］［折り返し］［↑前の変更］［↓次の変更］で確認できます。
  - 写し間違いなど軽微な修正は **［手動修正］** でその場で直せます。
  - 「これは違う」と思ったら［戻る］で取り込みの画面へ戻り、取り込み直せます。元のブックは何も変わりません。（`shield-check`）
  - 画像: `15-review.png`（左）／ `16-review-diff.png`（右）

#### Slide 21 - 手順 4 改修済みブックを作る

- **Audience move**: 出力名を確かめてビルドし、できあがりを受け取る
- **Layout**: `#47` — 3 枚組（出力名 / ビルド中 / 完了）。下に 3 行の説明
- **Title**: 改修済みブックを作ります
- **Core message**: 別名の新しいブックができる。元のブックは最後まで変わらない
- **Content**:
  - 出力名を確認します。既定は `<ブック名>_macrostudio.xlsm`。名前はファイル名だけを入れます。`\` `/` などの区切り文字や、元と違う拡張子は使えません。
  - ビルドは自動で進みます（通常 1〜2 秒）。書き戻したあとブックを読み直して、意図どおり書き込まれたかを検証しています。
  - できあがると右下が **［完了］** になります。押すと最初の画面へ戻り、次のブックに移れます。（`circle-check`）
  - 最後に Excel で開いて、マクロの動作を確認してください。（`accent`）
  - 画像: `17-output-name.png`／`18-building.png`／`19-done.png`

#### Slide 22 - できあがるもの

- **Audience move**: 成果物の置き場所と各ファイルの役割を覚え、あとで人に説明できるようになる
- **Layout**: `no-template-match` のフォールバック。左に Consolas のフォルダ構成、右に 5 件の役割カード（縦積み）
- **Title**: できあがるもの
- **Core message**: 依頼から結果まで、1 つのフォルダに全部残る
- **Content**:
  - フォルダ構成（Consolas, 20px）:
    - `<元のブックのフォルダ>\MacroStudio\<ブック名>_<日付_時刻>\`
    - `request.md` / `source-code.md` / `<ブック名>_macrostudio.xlsm` / `diff-report.html` / `result.md`
  - `request.md` — AIへ渡した依頼文（`file-text`）
  - `source-code.md` — 元マクロのコード全文
  - `<ブック名>_macrostudio.xlsm` — 改修済みブック
  - `diff-report.html` — 変更内容の確認レポート。ブラウザで開ける自己完結のファイルで、**変更しなかったモジュールも含めて全モジュール**が入っています。改修後のブックの記録としてそのまま保管できます。（`file-diff`）
  - `result.md` — 改修の概要メモ（何をどう直したか）
  - ［出力フォルダをエクスプローラーで開く］でそのフォルダを開けます。（`folder-open`）

#### Slide 23 - 改修せずに、聞くだけのとき

- **Audience move**: 改修しない道の終わり方を理解し、診断・相談だけでも使えると分かる
- **Layout**: `#50` — 2×2 のタイル。各タイルの下に一行キャプション。右下タイルにレンズ枠
- **Title**: 改修せずに、聞くだけのとき
- **Core message**: 手順 2 で［完了］。ブックは何も変わらない
- **Content**:
  - 手順 1-3 で「マクロについてAIに聞く」を選びます。（`message-chatbot`）
  - 次の画面の見出しは「AIに何を聞くか選びます」になります。（`search`）
  - 依頼文の作られ方は改修のときと同じです。質問のあるひな形なら、先に 1 問ずつ答えます。（`help-circle`）
  - 「AIチャットへ質問します」で終わりです。右下が **［完了］** になります。できるのは依頼文とコード全文の 2 ファイルだけで、ブックは変更されません。
  - 画像: `20-mode-diagnose.png`／`21-purpose-diagnose.png`／`25-request-diagnose.png`／`26-handoff-diagnose.png`

#### Slide 24 - 覚えておくとよいこと

- **Audience move**: 制約と拡張のしかたを知り、部門で運用する準備ができる
- **Layout**: 上下 2 段。上段＝制約 2 件のカード、下段＝ひな形の書き方（Consolas の骨組み）と「うまくいかないとき」の 4 行表（20px）
- **Title**: 覚えておくとよいこと
- **Core message**: 増やせるのは決まった範囲だけ。依頼のひな形は部門で増やせる
- **Content**:
  - 制約（`settings`）: 既存のクラスモジュールやシートのモジュールを**直す**ことはできます。新しいクラスやユーザーフォームを含む返答は取り込みません。新しく増やせるのは標準モジュールだけです。
  - ひな形（`list-check`）: `presets` フォルダに Markdown ファイル（UTF-8）を置くと、ファイル 1 つにつき 1 件、目的の画面に自動で現れます。アプリの再起動は不要です。
    - 最初の `# ...` が一覧に出る名前です。
    - `## 用途` に `改修` か `診断` と書くと、その使いかたの一覧に並びます（省略すると改修）。
    - `## 質問` を書くと、1 問ずつ質問する画面が出ます。
    - 書式が足りないファイルは選べず、理由付きで一覧の下に出ます。
  - うまくいかないとき（`alert-triangle`, 表 4 行）:
    - 起動しない・白い画面のまま ／ WebView2 ランタイムが未導入の可能性。起動時のエラー案内に従う
    - 返答を取り込めない ／ コードブロック全体（区切り行を含む）をコピーし直す。それでも駄目なら依頼文をコピーし直して送り直す
    - ひな形が一覧に出ない ／ その Markdown の見出しが揃っているか確認する。画面に理由が出る
    - ビルドに失敗した ／ 画面の指示に従う。元のファイルは変更されていないので何度でもやり直せる

#### Slide 25 - まず一本、通してみる

- **Audience move**: この資料を閉じたあと、実際に自分のブックで一周する
- **Closing impact**: 持ち帰る一点＝「失敗しても失うものが無いから、まず試せる」。構成＝白地に短い断言を大きく置き、その下に 3 つの但し書きを小さく添える。表紙の否定形（「コードは読めなくていい。」）に呼応する肯定形で閉じ、連絡先や「ありがとうございました」は置かない
- **Layout**: 中央左寄せの断言（52px）＋下に但し書き 3 行（18px, muted）＋右下に版表記
- **Title**: まず一本、通してみてください
- **Core message**: 元のブックは変わらない。だから何度でもやり直せる
- **Content**:
  - 断言（52px）: 「うまくいかなくても、元のブックは無傷です。」（`circle-arrow-right`）
  - 一行（30px）: 「気になっているマクロを 1 つ選んで、読み込むところから始めてください。」
  - 但し書き（18px, muted）:
    - 画面は MacroStudio **beta 1.0.0** のものです。ベータ版のため、画面の文言や配置は今後変わることがあります。
    - 掲載しているスクリーンショットは、サンプルのブック（受注管理.xlsm）を読み込んだ実画面です。フォルダのパスや日時は説明用の例です。
    - 判断は AI が行います。最後に Excel で開いて動作を確認するのは人です。

## X. Speaker Notes Requirements

- **Filename**: match each SVG filename under `notes/`
- **Content**:
  - 想定時間: 第一部 6〜8 分、第二部 12〜15 分（通しで約 20 分）
  - 語り口: 平易・会話的。専門語を使わず、画面に出る言葉で言う
  - 目的: 第一部は inform + persuade（試す判断をしてもらう）、第二部は instruct（手を動かせるようにする）
  - 各ページのノートには「この画面で決めること」「よくある詰まり」「次の画面への渡し方」を書く
  - 第二部のノートには、画面写真では読み取れない補足（ボタンの位置、押す順序、押せない条件）を入れる
  - 分割後のノートに `#` 見出し行を含めない（`notes/total.md` のみ `#` を使う）
