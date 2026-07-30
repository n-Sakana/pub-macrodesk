<!-- ppt-master-schema: design-spec/v1 -->
# manual-macrostudio-beta1 - Design Spec

> **改訂 r2（2026-07-30）**: 25 ページ → 13 ページへ圧縮。第一部 7＋区切り 1 → 3 ページ、第二部 17 → 10 ページ。
> スクリーンショットは全 26 枚を破棄し、現行アプリ（beta 1.0.0）を実操作して 9 枚を取り直した。
> 削った対象は、重複・画面を見れば分かる説明・実装経緯・他方式との比較・存在しない操作の否定。
> 各ページは「この場面で何をすればよいか」「判断に必要なこと」だけを持つ。

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | manual-macrostudio-beta1 |
| Canvas Format | PPT 16:9 (1280×720) |
| Page Count | 13（第一部 3 / 第二部 10） |
| Target Audience | 業務部門でマクロを預かっている担当者と、その導入を判断する立場の人。コードは読み書きできないが、AIチャット（Copilot Chat など）は日常的に使える。 |
| Communication Intent | 二部構成。第一部はサービス説明を要点だけで示す。第二部は操作マニュアルとして、画面どおりに一周させる。**説明量で親切さを表さない。** 操作順・押す場所・入力する内容が一目で分かることを優先し、それ以外は書かない。 |
| Desired Audience Outcome | 前半で「自分の部門のあのマクロに使えそうだ」と判断できる。後半で、ブックの読み込みから改修済みブックの作成まで、画面を見ながら迷わず一周できる。 |
| Core Message / Ask / Action | コードを読み書きできなくても、AIチャットが使えればマクロは直せる。開発画面を開く必要はなく、元のブックは変更されない。 |
| Delivery Context | 部門への紹介と配布を兼ねる。前半を投影で見せることも、後半を手元で参照することもある。 |
| Artifact Afterlife | 導入検討の説明材料。運用後は操作の参照先。beta 1.0.0 時点の画面の記録も兼ねる。 |
| Reading Mode | balanced（lock `consumption_mode: balanced`） |
| Content Strategy | `content_divergence` は空欄（バランス既定）。画面の見出し・ボタン名・案内文は実装から取った実物なので一字一句変更しない。原稿にない事実・数値は追加しない。**次のものは書かない**: 画面を見れば分かること／現在の実装と他方式との比較／存在しない操作の否定（例「黒い画面は出ません」「1つずつ貼る必要はありません」）／専門用語で認知負荷を増やす説明／実装経緯。 |
| Design Style | mode: custom「二部構成（紹介 → 手順）」 / visual_style: soft-rounded / 「実務の青」パレット |
| Created Date | 2026-07-30 |

- **Mode Behavior (confirmed)**: 第一部は導入を判断する立場の人に向けた紹介の調子。1ページ1メッセージ、見出しは断定形、余白を多めに取る。第二部は実際に操作する人に向けた手順の調子。アプリの画面順にそのまま進み、各ページは「左に画面写真・右に番号付きの操作」の骨格を最後まで崩さない。見出しにはアプリ画面の言葉をそのまま使う。改訂 r2 では区切りページを廃し、フッタの部表示で立場の切り替えを示す。

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280×720 |
| viewBox | `0 0 1280 720` |
| Margins | 上下左右 40px（安全域 1200×640） |
| Content Area | ヘッダ帯 y 44–118 / 本文域 y 144–652 / フッタ y 668–700 |

## III. Visual Theme

### Theme Style

- **Mode**: custom —「二部構成（紹介 → 手順）」（§I の Mode Behavior が実行契約）
- **Visual style**: soft-rounded
- **Theme**: 社内で配れる実務書。角丸カード、控えめな段差、装飾なし。
- **Tone**: 落ち着いて、脅かさない。断定形で短く。

### Color Scheme

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | `#FFFFFF` | 全ページの地 |
| Secondary background | `#F1F5F9` | カード面・写真の敷き板 |
| Primary | `#1F4E79` | 見出し、手順番号、強い罫 |
| Accent | `#E07B39` | 押すボタンの指示、注意。1ページ 1〜2 箇所まで |
| Secondary accent | `#4A87C4` | 流れの矢印、補助ラベル |
| Body text | `#1F2933` | 本文 |
| Surface | `#F8FAFC` | 淡い面 |
| Field | `#F4F6F8` | 画面写真の敷き板 |
| Grid | `#E2E8F0` | 罫線・カード境界 |
| Divider | `#CBD5E1` | セクション区切り |
| Muted text | `#5B6B7C` | 注釈・キャプション・ページ番号 |
| Positive | `#2E7D5B` | 「やり直せる」「元のまま」を伝えるコールアウト |
| Diff removed | `#C25560` | P11 の凡例「赤 ＝ 消える行」。アプリ実装の削除レール色（`--l-red-3`）に一致させる |
| Diff added | `#4C9155` | P11 の凡例「緑 ＝ 増える行」。アプリ実装の追加レール色（`--l-green-3`）に一致させる |

- 60-30-10: `#FFFFFF`/`#F1F5F9` が地、`#1F4E79` が構造、`#E07B39` は 1ページ 1〜2 箇所。1ページの色数は 4 色まで。

## IV. Typography System

### Font Plan

| Role | Chinese | English | Fallback tail |
| --- | --- | --- | --- |
| Title | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Body | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Emphasis | Yu Gothic UI | Segoe UI | `'Yu Gothic UI','Segoe UI',sans-serif` |
| Code | Consolas | Consolas | `Consolas,monospace` |

「Chinese」列はスキーマ由来の見出し。本デッキの CJK は日本語であり、Windows 標準の Yu Gothic UI のみを使う。

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

- 確定値（`body 24` / `title 42` / `subtitle 32` / `annotation 18` / `footnote 16` / `lead 30` / `cover_title 72`）は再導出しない。
- 改訂 r2 で `section_number 96`（区切りページ用）と `table_body 20` は使用ページが無くなったため lock から外す。
- **折り返し方針（r2）**: 手順ページの右カラムは本文 24px・1 行 18 字以内で改行位置を明示的に決め打つ。1 文字だけが次行に落ちる折返しと、見出しの途中改行を作らない。

## V. Layout Principles

### Page Structure

- **Header band**: y 44–118。左端 x=40 に手順ラベルのピル（`primary` 塗り・角丸 18・白 18px 太字・幅 168）、その右 x=228 から見出し 42px。y=118 に `grid` のヘアラインを全幅で引く。
- **Content area**: y 144–652。手順ページは「左 680px の画面写真＋右 504px の番号付き手順」の二段組を最後まで崩さない（r1 で成立していた実寸をそのまま維持）。
- **Footer area**: y 668–700。左に「第一部 サービス説明」／「第二部 操作マニュアル」、右にページ番号（16px, `muted`）。表紙には置かない。

### Spacing Specification

| Element | Current Project |
| --- | --- |
| Safe margin | 40px |
| 画面写真の版 | 敷き板 680×386（`field`）／写真 672×378（角丸 10 でクリップ、`grid` の細枠） |
| Content block gap | 24px（カード間）／20px（箇条書き行間） |
| Icon-text gap | 12px（アイコン 26–28px 角） |
| コールアウト | 角丸 14・地は `background`・枠 2px（安心＝`positive` / 注意＝`accent`）・左にアイコン |

## VI. Icon Usage Specification

ライブラリは `tabler-filled` に統一。`icon_sync.py` で複製済みの集合から、r2 で実際に使う 14 個だけを参照する。

| Purpose | Icon Path | Page |
| --- | --- | --- |
| マクロ入りのブック・コード | `tabler-filled/file-code` | P02, P05 |
| AIチャット | `tabler-filled/message-chatbot` | P02, P09 |
| できる・完了 | `tabler-filled/circle-check` | P02, P12 |
| 元のブックは無傷 | `tabler-filled/shield-check` | P02, P12 |
| 起動・必要なもの | `tabler-filled/player-play` | P03 |
| 次へ・流れ | `tabler-filled/circle-arrow-right` | P04 |
| 聞くだけの道 | `tabler-filled/search` | P04, P06 |
| ひな形・選択肢 | `tabler-filled/list-check` | P07 |
| 依頼文 | `tabler-filled/file-text` | P08 |
| コピー・取り込み | `tabler-filled/clipboard-check` | P10 |
| 確認する | `tabler-filled/eye` | P11 |
| 出力フォルダ | `tabler-filled/folder-open` | P12 |
| 注意・つまずき | `tabler-filled/alert-triangle` | P10, P13 |
| 質問・困ったとき | `tabler-filled/help-circle` | P13 |

## VII. Visualization Reference List

| Page | Template | Path | Summary-quote | Usage |
| --- | --- | --- | --- | --- |
| P04 | no-template-match | — | — | 4 手順の横一列＋「聞くだけ」の分岐。数量データを持たない構造情報であり、カタログの chart テンプレートは軸・凡例・系列を前提とするため当たらない。フォールバックはカスタムレイアウト（番号ピル＋ネイティブ矢印プリセット＋分岐の下段） |

改訂 r2 でデータ可視化ページは無くなった（旧 P04 の対照表・旧 P05 の縦リストは圧縮により廃止）。したがって `spec_lock.md` の `page_charts` セクションは書かない。

**Native-preset note**: P04 の流れの矢印は PowerPoint 標準のブロック矢印が素直に当たるため、`preset_shape_svg.py` で `rightArrow` を生成して使う。

## VIII. Image Resource List

素材はすべて **改訂 r2 で取り直した** 現行アプリ（beta 1.0.0）の実操作画面。旧 26 枚は破棄した。
取得方法は `sources/capture_screenshots.py`（WebView2 ホストモックを注入し、実際のボタンをクリックして遷移させるハーネス）。原寸 2732×1536 / 比 1.78 のまま、加工・切り抜きをしない。
**採用条件（全 9 枚で目視確認済み）**: エラー・警告・失敗通知・処理途中の異常表示が写っていないこと。実在の個人名・組織名・実ユーザーパスが写っていないこと（ブックは架空の `C:\Tools\macrostudio-sample\売上集計マクロ.xlsm`）。

| Filename | Dimensions | Ratio | Purpose | Type | Layout pattern | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01-book-loaded.png | 2732x1536 | 1.78 | 手順1。ブックを読み込めた状態 | Screenshot | #4 Right image bleeding off the canvas edge + #21 Rounded rectangle crop + #70 Thin colored matte frame | user | Existing | 表紙の主役および手順1の実画面。ファイル名とパスが出て［次へ］が使える | none | hero_page |
| 02-mode.png | 2732x1536 | 1.78 | 手順1。「マクロを改修する」を選んだ状態 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 2 択の選択画面。改修する側が選択済み | none | local |
| 03-purpose.png | 2732x1536 | 1.78 | 手順2。「どんな改修をするか選びます」 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 同梱ひな形の一覧。先頭が選択済み | none | local |
| 04-request.png | 2732x1536 | 1.78 | 手順2。「AIへ送る依頼文を用意しました」 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 依頼文は閉じたまま進める既定状態。モジュール単位出力の印も写る | none | local |
| 05-handoff.png | 2732x1536 | 1.78 | 手順2。2 つのボタンを押したあと | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 両方が済んで［次へ］が使える状態 | none | local |
| 06-intake.png | 2732x1536 | 1.78 | 手順3。取り込みが済んだ状態 | Screenshot | #19 Image floating in whitespace with thin frame and caption + #21 Rounded rectangle crop | user | Existing | 「2個のモジュールを取り込みました」 | none | local |
| 07-review.png | 2732x1536 | 1.78 | 手順3。変更内容を開いた状態 | Screenshot | #45 Background image + numbered hotspots with sidebar legend + #21 Rounded rectangle crop | user | Existing | 左にモジュールの増減、右に消える行・増える行。番号付きホットスポットで読み方を指す | none | local |
| 08-output-name.png | 2732x1536 | 1.78 | 手順4。出力ファイル名の確認 | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 2 枚組の左。書き戻し件数と出力名 | none | local |
| 09-done.png | 2732x1536 | 1.78 | 手順4。作成完了と 4 つのファイル | Screenshot | #48 Side-by-side comparison + #21 Rounded rectangle crop | user | Existing | 2 枚組の右。出力フォルダとファイル一覧 | none | local |

**Image-as-Canvas + Native Overlay の適用**: P11 が `#45`（番号付きホットスポット＋凡例）。画面写真の上に番号の丸を置き、説明は SVG テキストで持つ。他ページは切り抜き不可のスクリーンショットが主題そのもののため、枠付き配置（#19）と対比配置（#48）を採る。

**画像に文字を焼き込まない**: 注記・番号・キャプションはすべてネイティブ SVG テキスト（`text_policy: none`）。

## IX. Content Outline

### Part 1: サービス説明（P01–P03）

#### Slide 01 - 表紙

- **Audience move**: 「コードが読めなくてもマクロが直せる」という約束を 1 行で受け取る。
- **Cover impact**: フックは中核主張そのもの——「コードは読めなくていい。」。構成は `#4 Right image bleeding off the canvas edge`：左 2/3 に 72px の主題、右から実画面（01-book-loaded）が角丸＋細枠で画面外へはみ出す。箇条書きは置かない。
- **Layout**: 左テキストスタック（タイトル 72 / リード 30 / 版表記）＋右に写真がはみ出す。左下に `secondary_bg` の広い角丸面。
- **Title**: コードは読めなくていい。
- **Core message**: AIチャットが使えれば、部門のマクロは自分で直せる。
- **Content**: サブタイトル「Macro Studio 操作マニュアル」。リード「ブックを読み込み、AIへ依頼し、返答を取り込む。改修済みブックはこのアプリが作ります。」右下に版表記「beta 1.0.0 ／ 2026-07-30」。
- **Image**: 01-book-loaded.png

#### Slide 02 - できること

- **Audience move**: 3 点だけで「自分にもできそうだ」と判断する。
- **Layout**: 3 枚の角丸カードを横並び。各カードはアイコン＋見出し 32px＋本文 24px 2 行。
- **Title**: このアプリでできること
- **Core message**: 選んで押すだけで、改修済みのブックが別ファイルとして手に入る。
- **Content**: ①「AIチャットに任せる」— どこをどう直すかはAIが決めます。／②「開発画面は開かない」— 画面に出る選択肢を選び、［次へ］で進みます。／③「元のブックは変わらない」— 改修済みブックは別のファイルとして作られます。
- **Icons**: message-chatbot, file-code, shield-check, circle-check

#### Slide 03 - 使う前に

- **Audience move**: 手元に必要なものを確かめ、自分のマクロが対象か判断する。
- **Layout**: 左に「用意するもの」3 行、右に「向いているマクロ」3 行。2 枚の角丸カード。
- **Title**: 使う前に
- **Core message**: 用意するのはブックとAIチャットだけ。
- **Content**: 用意するもの — 改修したいブック（.xlsm / .xlam / .xlsb / .xls）／ファイルを添付できるAIチャット／Windows 10・11（インストールは不要）。向いているマクロ — 部門で使っている独自のマクロ／新しい端末で動かなくなったマクロ／作った人がいなくなったマクロ。
- **Icons**: player-play, file-code

### Part 2: 操作マニュアル（P04–P13）

#### Slide 04 - 全体の流れ

- **Audience move**: 4 手順の並びと、聞くだけで終わる道の存在を把握する。
- **Layout**: 上段に 4 手順の横一列（番号ピル＋見出し＋ネイティブ `rightArrow` プリセット 3 本）。下段に分岐の一行。
- **Title**: 全体の流れ
- **Core message**: 手順は 4 つ。［次へ］が押せたら、その画面は終わっている。
- **Content**: 1 ブックを読み込む／2 AIへ依頼する／3 返答を取り込む／4 ブックを作る。分岐「手順1で『マクロについてAIに聞く』を選んだときは、手順2で終わります。」
- **Icons**: circle-arrow-right, search

#### Slide 05 - 手順1 ブックを読み込む

- **Audience move**: ブックを読み込ませ、次の画面へ進む。
- **Layout**: 左に写真（#19 枠＋敷き板）、右に番号付き操作 3 件。
- **Title**: ブックを読み込みます
- **Core message**: 枠へドラッグして、［次へ］。
- **Content**: ①改修したいブックを、点線の枠へドラッグします。クリックして選んでもかまいません。／②ファイル名が出たら［次へ］。／③次の画面にモジュール数と行数が出ます。そのまま［次へ］。
- **Image**: 01-book-loaded.png
- **Icons**: file-code

#### Slide 06 - 手順1 どうしたいか選ぶ

- **Audience move**: 2 択のどちらかを選ぶ。聞くだけなら手順2で終わると理解する。
- **Layout**: 左に写真、右に 2 つの選択肢カード＋一行の注記。
- **Title**: このマクロをどうしたいか選びます
- **Core message**: 改修するか、聞くだけか。
- **Content**: 「マクロを改修する」— AIの返答を取り込んで、改修済みブックをこのアプリで作ります。／「マクロについてAIに聞く」— AIへ渡す依頼文とコードを作ります。手順2で終わります。／ひとつ選ぶと［次へ］が使えます。
- **Image**: 02-mode.png
- **Icons**: search

#### Slide 07 - 手順2 どんな改修をするか選ぶ

- **Audience move**: 一覧からひとつ選ぶ。質問が出る場合があると知る。
- **Layout**: 左に写真、右に番号付き操作 3 件。
- **Title**: どんな改修をするか選びます
- **Core message**: 近いものをひとつ選んで［次へ］。
- **Content**: ①したい改修に近いものをひとつ選びます。／②迷ったら「自分で改修内容を書く」を選び、次の画面に内容を書きます。／③選んだものによっては、いくつか質問が出ます。分かるところだけ答えれば進めます。
- **Image**: 03-purpose.png
- **Icons**: list-check

#### Slide 08 - 手順2 依頼文を確認する

- **Audience move**: そのまま進めてよいと分かる。長いコードのときの対処を知る。
- **Layout**: 左に写真、右に番号付き操作 3 件。
- **Title**: AIへ送る依頼文を用意しました
- **Core message**: 直すところが無ければ、そのまま［次へ］。
- **Content**: ①そのままでよければ［次へ］。／②書き換えるときは「依頼文を確認・編集」を開きます。／③コードが長くて返答が途中で切れるときは「モジュール単位出力」に印を付けます。
- **Image**: 04-request.png
- **Icons**: file-text

#### Slide 09 - 手順2 AIチャットへ渡す

- **Audience move**: 依頼文とファイルの 2 つをチャットへ渡す。
- **Layout**: 左に写真、右に番号付き操作 3 件＋注記。
- **Title**: AIチャットへ改修を依頼します
- **Core message**: 依頼文を貼り、source-code.md を添付して送る。
- **Content**: ①［依頼文をコピー］を押し、チャットの入力欄に貼り付けます（Ctrl+V）。／②［ファイルの場所を開く］を押し、source-code.md をチャットへ添付します。／③送信して返答を待ちます。注記「マクロが読み書きするExcelシートやファイルがあれば、それも添付すると回答が正確になります。」
- **Image**: 05-handoff.png
- **Icons**: message-chatbot

#### Slide 10 - 手順3 返答を取り込む

- **Audience move**: 返答をコピーして取り込む。取り込めないときの対処を知る。
- **Layout**: 左に写真、右に番号付き操作 3 件＋注意コールアウト。
- **Title**: AIの返答をまとめて取り込みます
- **Core message**: コードブロックを全文コピーして、ボタンを押す。
- **Content**: ①AIの返答のコードブロックを、先頭から末尾まで全文コピーします。／②［クリップボードから取り込む］を押します。／③取り込めた件数が出たら［次へ］。注意「取り込めないときは、コードブロック全体をもう一度コピーして押し直します。」
- **Image**: 06-intake.png
- **Icons**: clipboard-check, alert-triangle

#### Slide 11 - 手順3 変更を確認する

- **Audience move**: 何が変わるかを自分の目で確かめる。
- **Layout**: `#45` 左に写真＋番号付きホットスポット 3 箇所、右に凡例。
- **Title**: 取り込んだ変更を確認します
- **Core message**: 赤が消える行、緑が増える行。
- **Content**: ①「変更内容を見る」を開きます。／②左の一覧に、モジュールごとの増減が出ます。／③右に、消える行と増える行が並びます。赤が消える行、緑が増える行です。確かめたら［次へ］。
- **Image**: 07-review.png
- **Icons**: eye

#### Slide 12 - 手順4 ブックを作る

- **Audience move**: 出力名を確認してビルドし、できたファイルの場所を知る。
- **Layout**: `#48` 左右 2 枚の写真＋下に 3 行の操作と安心コールアウト。
- **Title**: 改修済みブックを作ります
- **Core message**: 数秒で、フォルダに 4 つのファイルができる。
- **Content**: ①出力ファイル名を確認して［次へ］。拡張子はそのままにします。／②数秒で作成が終わります。／③［出力フォルダをエクスプローラーで開く］で場所を開きます。できるファイルは、依頼文（request.md）、コード全文（source-code.md）、改修済みブック、変更内容の確認レポート（diff-report.html）。コールアウト「元のブックはそのまま残ります。最後にExcelで開いて動作を確認してください。」
- **Image**: 08-output-name.png, 09-done.png
- **Icons**: folder-open, shield-check, circle-check

#### Slide 13 - 覚えておくこと

- **Audience move**: つまずいたときに自分で戻れる道を持って終わる。
- **Closing impact**: 読み手が持ち帰る一点は「どこで止まっても元のブックは無事で、やり直せる」。構成は 4 行のカードを 2×2 で置き、最下段に［最初から］の一行を置く。謝辞や連絡先だけの締めにはしない。
- **Layout**: 2×2 の角丸カード＋下段に一行帯。
- **Title**: 覚えておくこと
- **Core message**: どこで止まっても、元のブックは無事。やり直せる。
- **Content**: ①依頼文と返答は 1 対 1 — 依頼文を作り直したら、返答も取り直します。／②途中でやめてよい — 元のブックは変わりません。／③変更内容はあとから読める — 出力フォルダの diff-report.html をブラウザで開きます。／④分からない画面が出たら — 画面左下の一行に、次にすることが出ています。下段「画面右上の［最初から］で、いつでも最初の画面に戻れます。」
- **Icons**: help-circle, alert-triangle

## X. Speaker Notes Requirements

- **Filename**: match each SVG filename under `notes/`
- **Content**: 想定所要時間 12〜15 分（前半の紹介 3 分＋後半を手元で操作しながら）。語り口は conversational。目的は instruct。各ページのノートは、ページ本文に書かなかった補足とページ間のつなぎだけを持つ。ページに書いたことを読み上げ直さない。画面内のブック名・パスは架空のサンプルである旨を必要な箇所で一度だけ添える。
