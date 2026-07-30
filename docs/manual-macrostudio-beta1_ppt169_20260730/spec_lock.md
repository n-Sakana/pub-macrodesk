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
- mode_behavior: 第一部（P01-P03）は導入を判断する立場の人に向けた紹介の調子。困りごと → できること → 安心できる理由 → 使いどころ、の順に運び、1ページ1メッセージ、見出しは断定形、余白を多めに取る。第二部（P04-P13）は実際に操作する人に向けた手順の調子。アプリの画面順にそのまま進み、各ページはまず「この画面で何を決めるか」を述べてから、実際の画面写真と操作を並べる。見出しにはアプリ画面の言葉をそのまま使う。改訂 r2 で区切りページを廃し、フッタの部表示（第一部/第二部）で読み手の立場の切り替えを示す

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
- diff_removed: #C25560
- diff_added: #4C9155

## typography
- font_family: 'Yu Gothic UI','Segoe UI',sans-serif
- body: 24
- title: 42
- subtitle: 32
- lead: 30
- annotation: 18
- footnote: 16
- cover_title: 72
- code_family: Consolas,monospace

## icons
- library: tabler-filled
- inventory: file-code, message-chatbot, circle-check, shield-check, player-play, circle-arrow-right, search, list-check, file-text, clipboard-check, eye, folder-open, alert-triangle, help-circle

## images
- 01-book-loaded.png: user | no-crop | P01,P05 | 表紙の主役（#4 はみ出し＋#70 細枠）／手順1の実画面（#19 枠）
- 02-mode.png: user | no-crop | P06 | どうしたいか選ぶ。#19 枠
- 03-purpose.png: user | no-crop | P07 | どんな改修をするか選ぶ。#19 枠
- 04-request.png: user | no-crop | P08 | 依頼文を確認する。#19 枠
- 05-handoff.png: user | no-crop | P09 | AIチャットへ渡す。#19 枠
- 06-intake.png: user | no-crop | P10 | 返答を取り込む。#19 枠
- 07-review.png: user | no-crop | P11 | 変更を確認する。#45 番号付きホットスポット 3 箇所＋右に凡例
- 08-output-name.png: user | no-crop | P12 | 出力名の確認。#48 左
- 09-done.png: user | no-crop | P12 | 作成完了と 4 ファイル。#48 右

## page_rhythm
- P01: anchor
- P02: dense
- P03: dense
- P04: anchor
- P05: dense
- P06: dense
- P07: dense
- P08: dense
- P09: dense
- P10: dense
- P11: dense
- P12: dense
- P13: dense

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
