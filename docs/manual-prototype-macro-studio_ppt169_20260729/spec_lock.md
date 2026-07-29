<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- audience: VBA・開発の知識を持たない業務担当者と、本試作の品質を見るレビュー担当者
- objective: 初めて触る人が画面を見ながらブック取り込みからビルドまでを自力で完走できるように教え、あわせて名称と画面素材のどこが仮置きかを判別できる状態にする
- core_message: どこをどう直すかを決めるのはAI。Macro Studioは判断材料を運び結果を安全に書き戻す道具にすぎず、元のブックは一切変わらない
- consumption_mode: balanced

## mode
- mode: instructional

## visual_style
- visual_style: soft-rounded

## colors
- bg: #FFFFFF
- bg_secondary: #F2F6FB
- primary: #2B5C96
- accent: #4C9155
- secondary_accent: #C25560
- text: #1F2A37
- surface: #FFFFFF
- field: #F4F6F8
- grid: #E2E7EC
- muted_text: #5D6B7A
- caution: #A2701C

## typography
- font_family: "Meiryo", "Segoe UI", sans-serif
- title_family: "Yu Gothic UI", "Segoe UI", sans-serif
- body_family: "Meiryo", "Segoe UI", sans-serif
- emphasis_family: "Yu Gothic UI", "Segoe UI", sans-serif
- code_family: Consolas, monospace
- body: 24
- title: 42
- subtitle: 32
- lead: 30
- annotation: 18
- footnote: 16
- cover_title: 72

## icons
- library: tabler-filled
- inventory: file-upload, message-chatbot, file-code, circle-check, folder-open, alert-triangle, bulb, copy, help-circle, edit, eye, clipboard-list, info-circle, file-text, circle-number-1, circle-number-2, circle-number-3, circle-number-4

## images
- s01_book_drop: images/s01-book-drop.png | no-crop
- s02_book_loaded: images/s02-book-loaded.png | no-crop
- s03_method: images/s03-method.png | no-crop
- s04_preset_list: images/s04-preset-list.png | no-crop
- s05_request_editor: images/s05-request-editor.png | no-crop
- s06_handoff: images/s06-handoff.png | no-crop
- s07_intake: images/s07-intake.png | no-crop
- s08_intake_done: images/s08-intake-done.png | no-crop
- s09_diff: images/s09-diff.png | no-crop
- s10_diff_accepted: images/s10-diff-accepted.png | no-crop
- s11_accepted_summary: images/s11-accepted-summary.png | no-crop
- s12_output_name: images/s12-output-name.png | no-crop
- s13_building: images/s13-building.png | no-crop
- s14_done: images/s14-done.png | no-crop

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
- P14: dense
- P15: dense
- P16: dense
- P17: dense
- P18: dense
- P19: dense
- P20: dense
- P21: anchor

## pptx_structure
- mode: flat

## forbidden
- Mixing icon libraries
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters
