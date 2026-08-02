# 第5段階 — E2E と画面の証跡

2026-08-01。実 Excel（`16.0.20228.20124` x64 / OS x64）、実 WebView2、
実 MacroStudio ホストで採った結果。

## 1. 10 本すべてを実ホストで通した

```
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\test-guide-sample-flow.ps1 -EvidenceDir docs\beta2\evidence\e2e
```

ブラウザでもスタブでもありません。製品と同じ WPF ウィンドウ、同じ
WebView2、同じ `MessageRouter` と `HostServices` です。各サンプルを
**添付 → 診断依頼 → 返答取り込み → 分類表示 → 指摘の選択 → 改修依頼 →
返答取り込み → 再生成 → 読み直し → 差分と成果物** まで通しました。

```
test-guide-sample-flow: PASS
samples=10, each attached, diagnosed, categorised, repaired, rebuilt and
read back through the real WebView2 host
  S01 key=FIXED_DRIVE_LETTER      screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S02 key=UNC_PATH                screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S03 key=BOOK_PATH_IS_URL        screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S04 key=WIN32API_BLOCKED        screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S05 key=SHELL_EXEC_BLOCKED      screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S06 key=DLL_LOAD_BLOCKED        screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S07 key=CONNECTION_STRING       screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S08 key=LEGACY_UI_AUTOMATION    screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S09 key=-                       screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
  S10 key=-                       screens=0-9, diagnosis=1, selected=1, package=2, artifacts=7, source=unchanged
```

`source=unchanged` は 10 本すべてで、**元のブックが一度も書き換わって
いない**ことを毎回ハッシュで確かめた結果です。

`key=` は診断が名指しした環境制約で、その分類の下に指摘がまとまり、
その分類に対応するひな形に ★推奨 が付くところまでを通っています。
`key=-` の 2 本は「対象環境の指定がない指摘」という分類を通ります。

## 2. 画面（画像で読んだもの）

| 画像 | どこで撮ったか | 見た点 |
| --- | --- | --- |
| `real-host-diagnose-with-key.png` | **実 WebView2 ホスト**、既定の 4:3（1120×840） | 塗りつぶしボタンが 1 つだけ。文字切れ・重なり・横はみ出し・二重スクロールなし |
| `real-host-diagnose-no-key.png` | 同上（環境キーを名指ししないサンプル） | 上と同じ。分岐しても画面は崩れない |
| `screen-findings-4x3.png` | 実ブラウザ 1104×795（4:3 ウィンドウの内側寸法） | 結論が先頭 1 行。13 件の Sleep 指摘が **1 問題・該当 11 か所**にまとまる。詳細は 4 つの折り畳み |
| `screen-nextstep-4x3.png` | 同上 | ひな形は固定順。★推奨 は右端のラベルだけ |
| `screen-repairinput-4x3.png` | 同上 | 診断と同じ分類。1 問題 1 チェック。「追加の要望を書く」は鉛筆と沈んだ地色で、折り畳まれたままでも記入欄と分かる |

S02–S08・S10 の実ホスト画像は撮って確認したうえで**残していません**。
この時点の診断画面はブックの内容に依存せず、10 枚がほぼ同一だからです。
各サンプルを実際に通した証拠は上の実行結果の方にあります。

## 3. 自動計測

使い捨ての計測ハーネス（`measure()`）を全画面に当て、
横方向のはみ出し・内側スクロール・過大なボタン・1 文字幅へ潰れた行を
検出。**画面 0〜5 すべてで 0 件**。ハーネス自体は残していません
（`testdata/` は掃除される作業場で、この記録が指し続けられる場所ではない）。
同じ計測は 2026-08-02 の実 GUI 走行で作り直し、そちらは駆動スクリプトごと
リポジトリの外に置いてあります。

ただし自動計測が緑でも合格とはしません。上の 5 枚は目で読んでいます。

## 4. Nani（https://nani.now/ja）と比べて直したこと

実サイトを開いて、入口・結果画面・FAQ の折り畳みを見たうえでの比較です。

| Nani が守っていること | β2 で直したこと |
| --- | --- |
| 主操作の塗りつぶしボタンは 1 画面に 1 つ | 診断画面で「依頼文をコピー」と「取り込む」が**両方**塗りつぶしだった。依頼を出す前はコピー、出した後は取り込み、返答が入ったら footer の［次へ］、と 1 つずつに直した（改修画面も同じ） |
| 無いものの話をしない | 結論の帯に「不具合 0」「前提 0」が並んでいた。**0 件の種別は出さない**ようにした |
| 折り畳みはラベルで中身が分かる | 「追加の要望を書く」が他の折り畳みと同じ山形アイコンで、開くまで記入欄と分からなかった。鉛筆アイコンと沈んだ地色にした（「気になっていることを書き足す」も同じ） |
| 結果が先、解説は下、詳細は要求されたら | 既に満たしている。診断画面の先頭が「対象環境で対処が必要な問題が N 件あります（該当 M か所）」 |
| 短いラベル | 既に満たしている。「依頼文をコピー」「該当箇所を見る」「選び直す」 |

### 意図的に Nani と違えている点

- **上部の 4 段階インジケータ。** Nani には工程が無いので出しません。
  MacroStudio は工程そのものが成果物（どこまで進んだか・元のブックは
  無事か）なので残します。
- **「診断を飛ばして、直したいことを自分で書く」を主操作の上に置く。**
  Nani なら任意設定は入力欄の中に畳みます。ここは設定ではなく分岐で、
  以降の手順が変わるため、手順 1 の前に置いています。

## 5. 既知の未確認点

1. **第 1 段階の AI 診断そのものは通していません。** 上の 10 本は
   実ホストを通っていますが、診断結果は台本です。`docs\beta2\guide-sample-map.md`
   の「期待される環境キー」列は依然として**期待**であり、実際の AI が
   同じキーを挙げるかは未確認です。
2. **S08 の ActiveX はこの端末で作れません。** 端末が挿入を拒否します。
   信頼センターは緩めません。棚卸しの ActiveX 件数 0 は検査側で
   `UNBUILT` として明示しています。
3. **Power Query の接続は結線していません。** 結線には Excel による
   クエリ評価が要り、外部へ出る可能性があります。外部ブックリンクで
   代替しており、`connections` 経由の検出は未確認です。
4. **クリップボードの取り合い。** WebView 系の smoke は実クリップボードを
   借りて返します。26 本を連続実行すると、前の WebView がまだ握っている
   ところへ次が入り、コピーが完了しないことがあります（単体では通ります）。
   `test-guide-sample-flow.ps1` はサンプル間に 1.5 秒の待ちを入れています。
   suite 全体としては、1 回失敗した runner を 1 度だけ再実行して全 26 本緑。
5. **ダークテーマの画像確認は今回していません。** smoke は暗色の
   スクリーンショットも撮りますが、この証跡には残していません。
