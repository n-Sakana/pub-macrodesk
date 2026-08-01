# β1.10 実査結果と事実台帳

- 実査日: 2026-08-01
- 対象 commit: `f9edca70034f4bb6192b90c71a38d3a43647e4d8`（main / working tree clean / origin/main と同期）
- 実査者: opus-architect（読取のみ）。IPC・状態遷移・テスト前提の一部は codex-implementer の独立実読と突き合わせ済み

この文書は β2.00 の全決定の出典である。ここに事実として書かれていない前提を
SPEC / PLAN で使ってはならない。

---

## 1. β1.10 の構造（実読）

### 1.1 実行構成

`launch.vbs` → `macrostudio.ps1` が `src/*.cs` を名前順に連結し `Add-Type` →
`MacroStudio.App.Run(baseDir)`。dotnet SDK 不要。WebView2 DLL は `lib/` に同梱
（SDK 1.0.3856.49、実機ランタイム 150.0.4078.105）。UI は WebView2 内の
`assets/index.html` と `assets/js/*.js`。

| ファイル | 役割 | 実サイズ |
|---|---|---|
| `src/01_App.cs` | エントリ、AssemblyResolve、STA、ランタイム確認 | 4.6 KB |
| `src/02_MainWindow.cs` | WPF 窓 + WebView2 + 仮想ホスト + D&D | 13.8 KB |
| `src/02_WebViewSecurity.cs` | 信頼 origin 判定と WebView2 の締め | 6.2 KB |
| `src/03_MessageRouter.cs` | id 付き request/response IPC | 15.7 KB |
| `src/04_HostServices.cs` | ダイアログ・クリップボード・ファイル出力・presets/template 読み・ログ | 39.0 KB |
| `src/05_Ole2.cs` | OLE2(CFB) リーダ/ライタ | 69.9 KB |
| `src/06_VbaCompression.cs` | MS-OVBA 2.4.1 展開・圧縮 | 21.8 KB |
| `src/07_VbaProject.cs` | dir を正本としたモジュール一覧・書き戻し計画 | 83.7 KB |
| `src/08_BookIO.cs` | zip/OLE2 入出力・ビルド・検証 | 72.4 KB |

`assets/js/`: `app.js`(148 KB) / `state.js`(28 KB) / `screens.js`(20 KB) /
`response-package.js`(23 KB) / `diff-report.js`(25 KB) / `diff-view.js`(16 KB) /
`preset-document.js`(13 KB) / `prompt-template.js`(8.8 KB) / `diff.js`(5.1 KB) /
`host-bridge.js`(6.1 KB) / `vba-highlight.js`(5.1 KB) / `theme.js`(2.0 KB)。

### 1.2 IPC 契約（現行 13 action）

envelope は JS→host `{id, action, params}`、host→JS 成功 `{id, status:"ok", data}` /
失敗 `{id, status:"error", code, message, data?}`。host→page イベントは `{event, data}`。
`03_MessageRouter` は `e.Source` を **本文を読む前に** `WebViewSecurity.IsTrustedSource`
で検査し、非 trusted は WARN ログだけ残して無応答で破棄する。

| action | 備考（β2 で触るか） |
|---|---|
| `resolveDroppedFiles` | D&D。Dispatch 外の特例経路 | 変更なし |
| `getAppInfo` | `{version, presets:[{file,content,error?}], buildFileLabel}` | **変更**（presets の 2 階層化、環境定義の版を返す） |
| `pickBook` | OpenFileDialog | 変更なし |
| `attachBook` | `{book, modules, warning, read}`。副作用として添付パスと内容署名を保存 | 変更なし |
| `readPreset` | presets 配下 containment + `.md` + strict UTF-8 | **変更**（サブフォルダ許可） |
| `readRequestTemplate` | `templates/request-template.txt` を毎回 strict UTF-8 | **変更**（診断用テンプレートを追加） |
| `writeRequestFiles` | 実行フォルダ作成 + `request.md` / `source-code.md`（UTF-8 BOM） | **変更**（段階別ファイル名） |
| `readClipboard` / `writeClipboard` | STA 経路。書き込むのは依頼文のみ | 変更なし |
| `buildBook` | 添付時署名の再照合 → 別名 copy → 再読検証。`timeout=0` | 変更なし |
| `revealPath` | dir を開く / file を select | 変更なし |
| `writeLog` | `%LOCALAPPDATA%\MacroStudio\logs\macrostudio_<yyyyMMdd>.log` | 変更なし |

`buildBook` だけが client timeout を持たない（120 秒で `onSlow` を出すが reject しない）。
**処理の正本は host の応答**という規律は β2 でも変えない。

### 1.3 画面遷移（現行 3 経路）

`assets/js/screens.js` が唯一の正本。画面番号 0〜11。

- **詳細・改修**: 0 mode → 1 book → 2 read → 3 purpose →（質問あれば 4）→ 5 request →
  6 handoff → 7 intake → 8 review → 9 output → 10 build → 11 done
- **詳細・診断**: 0 → 1 → 2 → 3 →（4）→ 5 → 6 で終端（7 以降へ行かない）
- **簡易**: `startSimple` が `mode=refactor / simple=true` で 0 → 1 →（2/3/4 を飛ばして）
  5 → 6 → 7 → 8 →（9 を飛ばして）10 → 11

`nextIndex` の分岐は 3 か所だけ（simple の 1→5 と 8→10、質問無しの 3→5）。
［戻る］は history stack で実通過経路を逆走。10（build）中のみ戻れない。

**β2 が消すのはこの 3 経路の入口分岐であって、画面の中身ではない。**

### 1.4 AI 返答契約（`response-package.js`）

- 依頼 ID は UUID v4。`crypto.getRandomValues` 優先、無ければ `Math.random` fallback。
- 区切り行は行頭空白除去後の `'@MACROSTUDIO`。ID は小文字 hex UUID の正規表現一致。
- whole 形式: `SUMMARY BEGIN/END` →（`BEGIN <kind> <name>` … `END <kind> <name>`）×n →
  `COMPLETE <count>`。kind は `standard|class|form|document`。
  名前は 1〜31 文字、Unicode letter 相当で開始、case-insensitive 重複拒否。
- **1 個でも別 request id の sentinel があれば全体を拒否。**
- `NOCHANGE` は「SUMMARY 非空 + `NOCHANGE UNNECESSARY|IMPOSSIBLE` + `COMPLETE 0`」の
  3 要素が揃って初めて 0 件成功。無言の 0 件は truncated として拒否。
- split 形式: 各返答に `PART nn OF total` と厳密に 1 module。index は 0-based、
  total は全 part で固定。同 index の再送は name/kind/code が完全同一のときだけ冪等。
  全番号が揃った時点で index 順に merge し、**whole 経路とまったく同じ適用処理へ合流**する。

#### 1.4.1 現行契約に見つかった弱点（β2 で直す）

| # | 事実 | 影響 | β2 での扱い |
|---|---|---|---|
| A1 | `COMPLETE` の数値比較が `Number()` 変換のため、`1.0` / `0x2` / `1e0` でも module 数と一致すれば受理する | 厳格契約の穴。AI の出力揺れを黙って許す | **正準 10 進表記 `/^(0\|[1-9][0-9]*)$/` ＋ `String(実件数)` との文字列一致**に締める（`/^\d+$/` だけでは `01` が通るため足りない）。`PART` は既存挙動のまま。SPEC §4.5.1 / §5.4 R1 |
| A2 | 新規 module の kind 制限（standard 以外を拒否）が `response-package.js` ではなく `app.js` の `applyWholePackage` にある | 契約の実装が 2 か所に割れている。DEVELOPMENT.md §3 の「契約は response-package.js だけが持つ」に反する | 契約検査を `response-package.js` へ寄せる。SPEC §5.4 |
| A3 | 依頼 ID の生成が `Math.random` へ fallback しうる | 乱数品質が落ちる経路が黙って存在する | fallback を残しつつ、fallback を使ったことをログへ残す |

これらは β1.10 の実害としては未観測だが、β2 が診断契約という **2 本目の機械契約**を
足す前に締めておかないと、同じ穴を 2 つ作ることになる。

### 1.5 ひな形（`presets/*.md`）の現行仕様

`preset-document.js` だけが解釈する。認識する見出しは 6 つ:

| 見出し | 必須 | 意味 |
|---|---|---|
| `# 名前` | 必須 | カードの名前 |
| `## 説明` | 任意 | カードの 1 行（選ぶ人へ向けた唯一の文） |
| `## 用途` | 任意 | `改修`(既定) / `診断` |
| `## 質問` | 任意 | `- 質問文` と字下げした選択肢 |
| `## 改修指示` | 必須 | 依頼文へ入る本文 |
| `## 出力指示` | 必須 | 返答のしかた |
| `## 出力指示（モジュール単位）` | 任意 | 分割返答用。あるときだけ画面に選択肢が出る |

同梱 6 ファイルの現状:

| ファイル | 用途 | β2 での行き先 |
|---|---|---|
| `01_VBAリファクター（動きを変えずに整理・改善する）.md` | 改修 | 改修ひな形として存続 |
| `02_Win32 API を使わない形へ直す.md` | 改修 | 改修ひな形として存続 |
| `03_自分で改修内容を書く.md` | 改修 | 改修ひな形として存続（自由記述枠） |
| `04_新しい端末で動くかを調べてもらう.md` | 診断 | **第 1 段階の診断そのものへ昇格**。前提の散文は環境定義ファイルへ実データ化 |
| `05_相談用の依頼文を作る（進め方を決めたいとき）.md` | 診断 | 廃止し、**診断画面の任意欄「ほかに気になっていること」**へ吸収 |
| `06_聞きたいことを自分で書く.md` | 診断 | 廃止し、**改修画面の任意欄「追加の要望」**へ吸収 |

**04 は β2 の設計上もっとも重要な既存資産である。** その `## 改修指示` は
「新しい業務端末では次のことが起きます」として 5 つの前提を散文で持っている。
これが現在 MacroStudio が想定している動作環境の実体であり、コード内ではなく
ひな形ファイルの中に文章として埋まっている。β2 はこれを機械可読な実データへ移す。

### 1.6 出力とフォルダ契約

```
<元ブックのフォルダ>\MacroStudio\<ブック名>_<yyyyMMdd_HHmmss>\
    request.md / source-code.md
    <ブック名>-Modified-<yyyyMMdd><元の拡張子>
    <ブック名>-Diff-Report-<yyyyMMdd>.html
    result.md
```

日付は**ブックを読み込んだ時点**で 1 度だけ決める。再ビルドは同じフォルダ内の
自分が作った成果物だけを 1 世代として置き換える。アプリが作っていない同名ファイルは
触らず E-BUILD-03 で止まる。**β2 でもこの契約を変えない。**

### 1.7 テスト資産（現行）

- PowerShell ヘッドレス: 21 本（`test-app-compile` / `test-ole2` / `test-vbaproject` /
  `test-roundtrip` / `test-build` / `test-hostservices` ほか）
- Node: 23 本（`test-flow-state` / `test-module-split` / `test-preset-document` /
  `test-prompt-template` / `test-no-change` ほか）
- 実 WebView2 smoke: 8 本（`*Smoke.cs` を `test-*-webview.ps1` が駆動）

#### 1.7.1 テスト一覧の欠落（実測で発見）

- `tests/` の `test-*.js` はディスク上に **24 本**ある。
- `docs/DEVELOPMENT.md` §5 の実行一覧に載っているのは **23 本**である。
- 載っていない 1 本は **`tests/test-response-package.js`** — つまり
  **製品でもっとも重要な機械契約（AI 返答パッケージ）を守るテストが、
  実行手順書から漏れている**。

codex-implementer がディレクトリを全列挙したため 24/24 を回せたが、
`DEVELOPMENT.md` に従った人は 23 本を回して、この 1 本を静かに飛ばす。
実害は出ていない（β1.10 の契約は他テストからも部分的に触られている）が、
**「テストを外さずに静かに走らせなくする」経路が実在した**ことになる。

→ β2 はこれを機械で塞ぐ（[PLAN-BETA2.md](PLAN-BETA2.md) §4.1-3）。
WP-11 で `DEVELOPMENT.md` へ追記する。

実 WebView2 smoke の hard timeout（実測ではなく上限値。codex-implementer 実読）:

| smoke | outer / inner | 既定ブック |
|---|---|---|
| P9WebViewSmoke | 45s / 35s | 不要 |
| DiffReportSmoke | 60s / 50s | 不要 |
| SplitOutputSmoke | 60s / 50s | `testdata/test_large.xlsm` |
| P10FlowSmoke | 120s / 100s | 同上 |
| WebViewSecuritySmoke | 120s / 110s | 不要 |
| SimpleModeSmoke | 180s / 170s | 同上 |
| NoChangeSmoke | 240s / 230s | 同上 |
| EditorFocusSmoke | 240s / 230s | 同上 |

**合計上限 17 分 45 秒。** β2 は 3 本（診断・第 2 依頼・決定的置換）を足すため、
上限は 25 分前後になる見込み。実行前提は Windows PowerShell 5.1 の fresh process、
WPF/STA、対話デスクトップ。

### 1.8 配布物 `public-release/package/`

git 追跡下（63 ファイル）。repo ルートの `assets` / `lib` / `presets` /
`macrostudio.ps1` / `launch.vbs` / `README.md` / `LICENSE` / `sample-book` /
`THIRD-PARTY-LICENSES` の**静的コピー**であり、公開済み GitHub Release
`v1.1.0-beta.1` の ZIP 内容と一対一に対応する。
`tests/test-p9-distribution.ps1` はこのフォルダを参照せず、自分で repo ルートから
コピーを作って検査する（`ProductRoot` は `testdata` 内であることを要求する）。

→ **判断: β2 開発中も `public-release/package/` は β1.10 snapshot のまま凍結する。**
理由は [DECISIONS-BETA2.md](DECISIONS-BETA2.md) D-08。

---

## 2. 外部 repo の実査（すべて読取のみ・変更なし）

`C:\repos\pub` 配下 21 ディレクトリを表記揺れ込みで走査した。
「VBA DevDesk」「DataDesk」に相当する実体は次の 2 つである。

### 2.1 `pub/vba-devkit`（README 上の名称は **CTU Toolkit**）— DevDesk 相当

Excel を起動せずに VBA を調査・抽出・比較・サニタイズする Windows ツール集。
`Analyze.bat` / `Extract.bat` / `Diff.bat` / `Sanitize.bat` / `Unlock.bat`。
必要環境は Windows 10/11 + PowerShell 5.1（Unlock のときだけ Excel）。

**MacroStudio にとっての価値は `config/analyze.json` と `lib/Analyze.ps1` である。**
これは「新しい端末で VBA の何が問題になるか」を 3 軸で列挙した実データで、
MacroStudio の `presets/04` の散文と**独立に作られながら同じ結論に達している**。

| 軸 | 項目数 | 内容 |
|---|---|---|
| `edr` | 3 | Win32 API (Declare) / Shell・process / PowerShell・WScript |
| `compat` | 13 | DLL loading, SendKeys, AppActivate, PtrSafe, 64bit ハンドル, VarPtr/ObjPtr/StrPtr, DDE, IE Automation, Legacy Controls, DAO, DefType, GoSub, While/Wend |
| `path` | 22 | 固定ドライブ文字, UNC, ユーザーフォルダ, Desktop/Documents, AppData, Program Files, プリンタ名, IP, 接続ホスト, localhost, 接続文字列, 外部ブック open, Dir() 存在確認, パス連結, SaveAs, 外部ブック参照, BeforeSave, AfterSave, LinkSources/UpdateLink, Workbooks.Open(変数), CurDir, ChDir |

`lib/Analyze.ps1` は各項目に `Basis` を持つ。`observed`（検証で実際に起きた）と
`inference`（設計上そうなるはず）を区別している。**この区別を β2 の環境定義へ
そのまま持ち込む。**

さらに `lib/VBAToolkit.psm1` は各項目の検出正規表現を持つ。例:

```
'Fixed drive letter' → (?mi)^[^''\r\n]*"[A-Z]:\\"
'UNC path'           → (?mi)^[^''\r\n]*"\\\\[^"]+\\
```

**重要な監査所見**: この `^[^'\r\n]*` は「行頭からアポストロフィが出るまで」で
コメントを避けようとする素朴な近似であり、**文字列リテラル中のアポストロフィ
（`"Don't"`）で誤爆し、`REM` コメントを避けられず、行継続 `_` で分断された
パス連結も追えない**。調査ツールとしては許容範囲だが、
**コードを書き換える β2 の置換エンジンにこの方式を流用してはならない。**
β2 は本物の VBA 字句解析器を持つ（SPEC §7）。

### 2.2 `pub/datadesk` — DataDesk 相当

Dataverse 向け社内フロントエンドの初期 repo。`src/` は空（`.gitkeep` のみ）で、
現在の製品面は `envtest/` である。README の思想:

> This repository starts with environment discovery before application code so the
> implementation can fit the actual company Windows environment instead of guessing
> at available runtimes, Office integration, or network constraints.

`envtest/modules/` の 11 軸が、**環境事実集合の語彙**を与える:

| モジュール | 軸 |
|---|---|
| `01-runtime.ps1` | OS / PowerShell / .NET Framework |
| `02-build-tools.ps1` | ビルドツール |
| `03-package-managers.ps1` | パッケージマネージャ |
| `04-databases.ps1` | データベースドライバ |
| `05-office.ps1` | **Excel / Word / Outlook / Access の COM 可用性** |
| `06-webview.ps1` | WebView2 ランタイム |
| `07-containers.ps1` | コンテナ |
| `08-security.ps1` | 証明書ストア・セキュリティ |
| `09-network.ps1` | TCP / HTTP 到達性 |
| `10-exe.ps1` | 実行ファイル起動 |
| `11-communication.ps1` | 通信 |

結果の型は `{name, status, value, details, error}`、`status` は
`ok` / `missing` / `error`、モジュール集約は `ok` / `partial`。
`AGENTS.md` の規律「**record unsupported or blocked checks explicitly; do not hide
them**」は β2 の環境定義の fail-fast 方針と同じ思想である。

#### 2.2.1 決定的に重要な欠落事実

- `envtest/results/` は `.gitignore` されており、**実測結果は 1 件も存在しない**。
- README と `AGENTS.md` が参照する `.repos/CONSTRAINTS.md` は
  `C:\repos\pub` 配下のどこにも**存在しない**（全再帰検索で 0 件）。

→ **したがって「実測された動作環境データ」はこの世に無い。**
β2 の環境定義は *宣言された想定* であり、*測定された事実* ではない。
この区別を環境定義ファイルの各項目が `basis` として自分で名乗る
（`declared` / `inferred` / `observed`）。測っていないものを測ったように書かない。

### 2.3 その他 repo（参考として読み、β2 は依存しない）

| repo | 実体 | β2 との関係 |
|---|---|---|
| `_macrodesk_design/DESIGN.md` | MacroStudio の前身 MacroDesk の UI 再設計仕様（v1.1, 2026-07-28） | 意味トークン対照表・状態辞書（青=作業中/緑=完了/灰=未処理/赤=削除失敗）は現 `variables.css` の出典。β2 も同じ語彙を使う |
| `pub-macrodesk` | 前身の実装ツリー | 参照のみ |
| `casedesk` / `vba-toolbox` / `xltoolrack` / `vbcode` / `toolrack` / `watchbox` / `markpad` | 別目的の VBA/Excel/ツール系 repo | 依存なし |

### 2.4 UI 参考: https://nani.now/ja（実確認）

実際に取得して確認した。β2 が参考にするのは次の 4 点で、見た目の複製はしない。

1. **中央作業面がページの主役**。宣伝文ではなく道具そのものが最初に来る。
2. **段階的開示**。基本機能 → 語調の変化 → 画像対応 → 詳細調整の順に現れ、
   「もっと表示する」で以降を保留する。認知負荷を最初に払わせない。
3. **主結果が先、調整は後**。翻訳結果が出てから調整ボタンが現れる。
   最初から全部の操作を並べない。
4. **速い人と使い倒す人の両立**。ログイン不要で即使える一方、
   文体タグのような上級機能が同じ面の中にあり、別画面へ追い出されていない。

β2 の「主結果を先に、証拠・技術詳細を淡い第二層に」「任意データはその場で展開」は
この 4 点の翻案である。

---

## 3. β1.10 が持っていて β2 が保つ安全性（削除禁止リスト）

実装が進むうちに落ちやすい順に列挙する。PLAN の回帰表はこの表を親に持つ。

| # | 性質 | 現在の実装位置 | 落ちたときの症状 |
|---|---|---|---|
| S1 | 原本非破壊（元ブックを開いてもロックしない・書き換えない） | `08_BookIO.cs` の共有読み取り | 元ファイル破損 |
| S2 | 添付時点からの VBA 内容署名一致（E-BUILD-04） | `04_HostServices.cs` + `08_BookIO.cs` | 別世代のコードへ書き戻す |
| S3 | 書き戻し後の読み直し検証（失敗なら出力破棄・E-BUILD-02） | `08_BookIO.cs` | 壊れたブックを成功として渡す |
| S4 | all-or-nothing（1 モジュール失敗で全体失敗、作業ファイルも残さない） | `08_BookIO.cs` | 半分だけ改修されたブック |
| S5 | 依頼 ID による返答の帰属検証 | `response-package.js` | 別依頼の返答を取り込む |
| S6 | 厳格契約（部分・不正形式を黙って受理しない） | `response-package.js` | 途中で切れた返答をビルドする |
| S7 | 全モジュールを常に渡す（人に選ばせない） | `app.js` のコードファイル生成 | AI が文脈を欠いた改修を返す |
| S8 | **ブックの VBA ソースを外向きに書き出さない**（クリップボードへ `writeClipboard` しない、ログへ書かない）。AI 返答の**読み取り**はコードを含むのが当然なので対象外 | `04_HostServices.cs` / §7.6 | 情報漏洩 |
| S9 | WebView2 境界（信頼 origin・遷移拒否・DevTools 無効・host object 無し） | `02_WebViewSecurity.cs` | 任意ページからの host 呼び出し |
| S10 | Attribute ヘッダの保存と再付与 | `app.js` + `07_VbaProject.cs` | `VB_PredeclaredId` 等の消失 |
| S11 | 文字コード変換の厳密性（表現できない文字はビルド失敗） | `07_VbaProject.cs` | 置換文字がブックへ入る |
| S12 | 実行フォルダ内だけに出力し、自分が作っていない同名ファイルを触らない | `04_HostServices.cs` | 利用者のファイルを上書き |

---

## 4. 未検証事項の引き継ぎ

SPEC §15.2 の 13 項目は β2 でも未検証のまま引き継ぐ（`.xlsb` 実ファイル、
VBA プロジェクト保護、`.xlam` 実 fixture、CFB v4 書き出し、120 秒超ビルド実測ほか）。
β2 はこれらを解決しない。**解決したふりもしない。** SPEC-BETA2 §12 に再掲する。
