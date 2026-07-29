<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- audience: コードは読めないが AIチャットは日常的に使う業務部門のマクロ担当者と、その導入を判断する立場の人
- objective: 前半のサービス説明で「自分の部門のあのマクロにも使えそうだ」と判断させ、後半の操作マニュアルでブックの読み込みから改修済みブックの作成まで迷わず一周させる。第一部には仕組みの説明を持ち込まず、読み手にとって何ができるようになり何を心配しなくてよくなるかで書く。専門用語や開発ツールの固有名詞は使わず「開発画面」のような普通の言葉に言い換える
- core_message: コードを読み書きできなくても、AIチャットが使えればマクロは直せる。開発画面を開く必要はなく、元のブックは変更されない
- consumption_mode: balanced

## mode
- mode: custom
- mode_behavior: 第一部（P01-P08）は導入を判断する立場の人に向けた紹介の調子。困りごと → できること → 安心できる理由 → 使いどころ、の順に運び、1ページ1メッセージ、見出しは断定形、余白を多めに取る。第二部（P09-P25）は実際に操作する人に向けた手順の調子。アプリの画面順にそのまま進み、各ページはまず「この画面で何を決めるか」を述べてから、実際の画面写真と操作を並べる。見出しにはアプリ画面の言葉をそのまま使う。P08 を区切りページとし、読み手の立場が切り替わることを明示する

## visual_style
- visual_style: soft-rounded

## colors
- bg: #FFFFFF
- secondary_bg: #F1F5F9
- primary: #1F4E79
- accent: #E07B39
- secondary_accent: #4A87C4
- text: #1F2933
- surface: #F8FAFC
- field: #F4F6F8
- grid: #E2E8F0
- divider: #CBD5E1
- muted: #5B6B7C
- positive: #2E7D5B

## typography
- font_family: 'Yu Gothic UI','Segoe UI',sans-serif
- body: 24
- title: 42
- subtitle: 32
- lead: 30
- annotation: 18
- footnote: 16
- cover_title: 72
- section_number: 96
- table_body: 20
- code_family: Consolas,monospace

## icons
- library: tabler-filled
- inventory: file-code, message-chatbot, circle-check, alert-triangle, folder-open, clipboard-check, eye, file-diff, circle-arrow-right, shield-check, list-check, help-circle, settings, user, clock, bulb, file-text, circle-x, player-play, search

## images
- 05-mode.png: user | no-crop | P03 | 「このマクロをどうしたいか選びます」実画面。第一部唯一の写真。#19 枠＋キャプション
- 01-drop.png: user | no-crop | P10 | 画面の見かた。#45 番号付きホットスポット 4 箇所＋右に凡例
- 02-book-loaded.png: user | no-crop | P11 | 読み込み完了。#19 枠。［次へ］が青くなる箇所に accent の細枠
- 03-read.png: user | no-crop | P12 | 読み取り結果（閉）。#48 左
- 04-read-open.png: user | no-crop | P12 | 読み取り結果（開）。#48 右
- 06-mode-refactor.png: user | no-crop | P13 | 「マクロを改修する」選択済み。#19＋#46 レンズ枠 2 箇所
- 07-purpose-refactor.png: user | no-crop | P14 | ひな形一覧。#80 右に主役画像、左に段違いカード
- 22-questions.png: user | no-crop | P15 | 質問（選択式）。#47 の 1/3
- 23-questions-text.png: user | no-crop | P15 | 質問（自由記述）。#47 の 2/3
- 24-questions-last.png: user | no-crop | P15 | 質問（最後の問）。#47 の 3/3
- 08-request.png: user | no-crop | P16 | 依頼文（閉）。#48 左
- 09-request-open.png: user | no-crop | P16 | 依頼文（開・編集可）。#48 右
- 10-handoff.png: user | no-crop | P17 | 受け渡し（押す前）。#48 左
- 11-handoff-done.png: user | no-crop | P17 | 受け渡し（押したあと）。#48 右
- 12-intake.png: user | no-crop | P18 | 取り込み前。#47 の 1/3
- 13-intake-done.png: user | no-crop | P18 | 取り込み結果。#47 の 2/3
- 14-intake-summary.png: user | no-crop | P18 | AIが書いた改修内容。#47 の 3/3
- 15-review.png: user | no-crop | P20 | 変更確認（要約）。#48 左
- 16-review-diff.png: user | no-crop | P20 | 変更確認（差分）。#48 右＋#46 レンズ枠 2 箇所
- 17-output-name.png: user | no-crop | P21 | 出力名。#47 の 1/3
- 18-building.png: user | no-crop | P21 | ビルド中。#47 の 2/3
- 19-done.png: user | no-crop | P21 | 作成完了。#47 の 3/3
- 20-mode-diagnose.png: user | no-crop | P23 | 「AIに聞く」選択。#50 の 1/4
- 21-purpose-diagnose.png: user | no-crop | P23 | 「AIに何を聞くか選びます」。#50 の 2/4
- 25-request-diagnose.png: user | no-crop | P23 | 聞くだけの依頼文。#50 の 3/4
- 26-handoff-diagnose.png: user | no-crop | P23 | 「AIチャットへ質問します」。#50 の 4/4＋#46 レンズ枠

## page_rhythm
- P01: anchor
- P02: dense
- P03: anchor
- P04: dense
- P05: dense
- P06: breathing
- P07: breathing
- P08: breathing
- P09: anchor
- P10: anchor
- P11: dense
- P12: dense
- P13: dense
- P14: dense
- P15: dense
- P16: dense
- P17: dense
- P18: dense
- P19: dense
- P20: dense
- P21: anchor
- P22: dense
- P23: dense
- P24: dense
- P25: breathing

## page_charts
- P04: comparison_table
- P05: vertical_list
- P09: process_flow

## pptx_structure
- mode: flat

## forbidden
- Mixing icon libraries
- スクリーンショットの切り抜き・拡大縮小による比率変更（すべて no-crop、原寸比のまま）
- 画面の見出し・ボタン名・案内文の書き換え（実装から抽出した実物をそのまま使う）
- 第一部での仕組み説明、専門用語、開発ツールの固有名詞
- 実在しない画面・数値・機能の記載
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters
