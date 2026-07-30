<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- audience: VBAを知らない業務担当者（チャットAIは業務で使用できる）
- objective: 初回利用者が一件（改修または相談）を本書の手順どおりに完了でき、アプリが検証する範囲と利用者が確認する範囲を区別して理解している状態にする
- core_message: MacroStudio は元のブックのファイルには書き込まず、AI の返答を機械的に検証してから、元のブックのコピーである改修済みブックを別ファイルとして作成する。改修後のマクロの動作確認は利用者が Excel で行う
- consumption_mode: text

## mode
- mode: instructional

## visual_style
- visual_style: soft-rounded

## colors
- bg: #FFFFFF
- secondary_bg: #F2F6FB
- primary: #24507F
- accent: #C05B21
- secondary_accent: #2B5C96
- text: #1F2A37
- surface: #FAFBFC
- grid: #E2E7EC
- divider: #CFD7DE
- muted: #5D6B7A
- positive: #3A7A47
- diff_removed: #C25560
- diff_added: #4C9155

## typography
- font_family: 'Yu Gothic UI','Segoe UI',sans-serif
- code_family: Consolas,monospace
- body: 22
- title: 40
- subtitle: 30
- lead: 26
- annotation: 18
- note: 17
- caption: 16
- small: 15
- footnote: 14
- cover_title: 54
- code: 18

## icons
- library: tabler-filled
- inventory: file-code, message-chatbot, user, player-play, list-check, file-text, copy, clipboard-check, eye, folder-open, shield-check, circle-check, circle-arrow-right, search, alert-triangle, help-circle, device-desktop

## images
- 21-done.png: P01 表紙パネル（#19 + #21、no-crop）／P17 完了画面（#19、no-crop）
- 01-mode.png: P04 作業選択画面（#19、no-crop）
- 02-mode-selected.png: P09 作業選択済み（#48 左、no-crop）
- 04-book-loaded.png: P08 画面構成注釈（#45、no-crop）／P09 読み込み後（#48 右、no-crop）
- 05-read.png: P10 読み取り結果（#48 左、no-crop）
- 06-read-open.png: P10 読み取った内容（#48 右、no-crop）
- 08-purpose-selected.png: P11 目的選択済み（#19、no-crop）
- 09-request.png: P12 依頼文既定（#48 左、no-crop）
- 10-request-open.png: P12 依頼文展開（#48 右、no-crop）
- 11-handoff.png: P13 受け渡し前（#48 左、no-crop）
- 12-handoff-done.png: P13 受け渡し済（#48 右、no-crop）
- 13-intake.png: P14 取り込み前（#48 左、no-crop）
- 14-intake-done.png: P14 取り込み成功（#48 右、no-crop）
- 17-review-diff-timerutils.png: P15 差分確認（#45、no-crop）
- 19-output-name.png: P16 出力名（#48 左、no-crop）
- 20-building.png: P16 ビルド中（#48 右、no-crop）
- 40-report-light.png: P19 レポート明（#48 左、no-crop）
- 41-report-dark.png: P19 レポート暗（#48 右、no-crop）
- 31-purpose-diagnose.png: P20 相談の選択（#48 左、no-crop）
- 37-handoff-diagnose-done.png: P20 相談の完了（#48 右、no-crop）

## page_rhythm
- P01: anchor
- P02: dense
- P03: dense
- P04: dense
- P05: dense
- P06: anchor
- P07: dense
- P08: dense
- P09: dense
- P10: dense
- P11: dense
- P12: dense
- P13: dense
- P14: dense
- P15: dense
- P16: dense
- P17: dense
- P18: breathing
- P19: dense
- P20: dense
- P21: dense
- P22: dense

## page_charts
- P06: process_flow

## pptx_structure
- mode: flat

## forbidden
- Mixing icon libraries
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters
