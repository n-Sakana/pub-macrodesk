<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- audience: 本編: VBAを知らない業務担当者（チャットAIは使える）。付録(P26-33): IT・管理担当者
- objective: 一つのサンプルと同じ手順で最初の一件を完了させ、アプリが守る範囲と人が確認する範囲を正確に理解させる（怖がらず・過信せず、diff と Excel での最終確認を自分の目で行えたら成功）
- core_message: AIチャットが使えればマクロは自分で直せる。元のブックはどの操作でも変わらず、何度でもやり直せる。最終確認はあなたが Excel で行う
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
- cover_title: 64
- code: 18

## icons
- library: tabler-filled
- inventory: file-code, message-chatbot, user, player-play, list-check, file-text, copy, clipboard-check, eye, folder-open, shield-check, circle-check, circle-arrow-right, search, alert-triangle, help-circle, settings, lock, shield-lock, key, shield, device-desktop

## images
- 21-done.png: P01 表紙ヒーロー（#4 右ブリード + #21 角丸 + #70 細枠、no-crop）／P20 完了画面（#19、no-crop）
- 01-mode.png: P05 二つの作業（#19、no-crop）
- 04-book-loaded.png: P09 画面の見かた（#45 ホットスポット、no-crop）／P11 読み込み後（#48 右、no-crop）
- 02-mode-selected.png: P10 作業を選ぶ（#19、no-crop）
- 03-book-empty.png: P11 読み込み前（#48 左、no-crop）
- 05-read.png: P12 読み取り結果（#48 左、no-crop）
- 06-read-open.png: P12 読み取った内容（#48 右、no-crop）
- 08-purpose-selected.png: P13 目的選択（#19、no-crop）
- 09-request.png: P14 依頼文既定（#48 左、no-crop）
- 10-request-open.png: P14 依頼文展開（#48 右、no-crop）
- 11-handoff.png: P15 受け渡し前（#48 左、no-crop）
- 12-handoff-done.png: P15 受け渡し済（#48 右、no-crop）
- 13-intake.png: P16 取り込み前（#48 左、no-crop）
- 14-intake-done.png: P16 取り込み成功（#48 右、no-crop）
- 15-intake-summary.png: P17 AIの説明（#48 左、no-crop）
- 16-review.png: P17 確認入口（#48 右、no-crop）
- 17-review-diff-timerutils.png: P18 diff 確認（#45 ホットスポット、no-crop）
- 19-output-name.png: P19 出力名（#48 左、no-crop）
- 20-building.png: P19 ビルド中（#48 右、no-crop）
- 40-report-light.png: P22 レポート明（#48 左、no-crop）
- 41-report-dark.png: P22 レポート暗（#48 右、no-crop）
- 31-purpose-diagnose.png: P23 相談の目的（#48 左、no-crop）
- 32-questions.png: P23 質問画面（#48 右、no-crop）
- 35-request-diagnose-open.png: P24 回答入り依頼文（#48 左、no-crop）
- 37-handoff-diagnose-done.png: P24 相談完了（#48 右、no-crop）

## page_rhythm
- P01: anchor
- P02: dense
- P03: breathing
- P04: dense
- P05: dense
- P06: dense
- P07: anchor
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
- P18: dense
- P19: dense
- P20: dense
- P21: breathing
- P22: dense
- P23: dense
- P24: dense
- P25: dense
- P26: anchor
- P27: dense
- P28: dense
- P29: dense
- P30: dense
- P31: dense
- P32: dense
- P33: dense
- P34: breathing

## page_charts
- P07: process_flow
- P29: process_flow

## pptx_structure
- mode: flat

## forbidden
- Mixing icon libraries
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters
