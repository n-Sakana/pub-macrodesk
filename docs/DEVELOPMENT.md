# MacroStudio 開発ガイド

仕様は [SPEC.md](SPEC.md) が正本。本書はビルド制約、リポジトリ規約、テストの走らせ方を
まとめたもの。仕様と本書が食い違ったら SPEC.md を優先する。

---

## 1. 言語・構文の制約（守らないと動かない）

MacroStudio は dotnet SDK を必要としない。ホストの C# は Windows PowerShell 5.1 の
`Add-Type` がコンパイルするため、使える構文に上限がある。

| 対象 | 制約 |
|---|---|
| `src/*.cs` | **C# 5.0 構文のみ**（PowerShell 5.1 の Add-Type が使うコンパイラの上限）。禁止: 文字列補間 `$"..."`、null 条件 `?.` `??=`、`nameof`、expression-bodied member、`out var`、パターンマッチング、タプル構文。**async/await は可**（C# 5.0 機能）。文字列連結は `+` か `string.Format` |
| `src/*.cs` | **ASCII のみ**（コメントも英語）。日本語の UI 文言はすべて `assets/` 側に置く。ホスト（C#）が直接表示する日本語文言は `assets/messages/*.txt` に置き、読み込んで表示する |
| `src/05〜08`（エンジン） | **WPF / WebView2 に依存させない**（`using System.Windows` 禁止。System.IO / System.Text / System.IO.Compression まで）。`tests/` からエンジンだけを Add-Type してヘッドレス検証するため |
| `*.ps1` | **Windows PowerShell 5.1 互換**（三項演算子・`??`・`pwsh` 前提機能は禁止） |
| `assets/*` | HTML/CSS/JS（フレームワーク・ビルドツール不使用。日本語 OK） |
| JSON | C# 側は `System.Web.Script.Serialization.JavaScriptSerializer`（参照アセンブリ `System.Web.Extensions`。`MaxJsonLength = int.MaxValue` を設定） |

## 2. リポジトリ規約

- `src/` は番号付きファイル名（`01_App.cs` …）。`macrostudio.ps1` が名前順に連結し、
  using を先頭へ集約して 1 回の `Add-Type` でコンパイルする。
- 名前空間は `MacroStudio`。WebView2 仮想ホスト名は `macrostudio.local`。
  この 1 つが唯一の信頼 origin で、値は `WebViewSecurity.TrustedHost` が持つ
  （SPEC §7.1.1）。新しい仮想ホストを足すと、そのページはホスト操作を
  呼べないまま画面にも出せない。
- ユーザーデータ: `%LOCALAPPDATA%\MacroStudio\WebView2Cache`、ログ: 同 `\logs`。
- `lib/` の WebView2 DLL 4 本は NuGet パッケージ `Microsoft.Web.WebView2`
  （SDK 1.0.3856.49）の再配布 DLL。差し替える場合は 4 本の版を揃えること。

### ファイル構成

```
macrostudio/
├── launch.vbs               # 本番起動（黒画面なし）
├── launch.bat               # 開発起動（コンソールあり）
├── macrostudio.ps1            # ホスト: src/*.cs を集約 → Add-Type → App.Run
├── src/                     # C#（ホスト + エンジン）
│   ├── 01_App.cs            # エントリ。AssemblyResolve、STA スレッド、WebView2 ランタイム確認
│   ├── 02_MainWindow.cs     # WPF 窓 + WebView2 + 仮想ホスト + D&D 受け
│   ├── 02_WebViewSecurity.cs # 信頼 origin の判定、遷移・新窓・frame の拒否、DevTools 無効化（SPEC §7.1.1）
│   ├── 03_MessageRouter.cs  # JS⇔C# の id 付き request/response IPC（信頼外 origin のメッセージは破棄）
│   ├── 04_HostServices.cs   # ダイアログ、クリップボード、explorer、実行フォルダと成果物の出力、template / presets 読み、ログ
│   ├── 05_Ole2.cs           # OLE2(CFB) リーダ/ライタ
│   ├── 06_VbaCompression.cs # MS-OVBA 2.4.1 展開・圧縮
│   ├── 07_VbaProject.cs     # dir の MODULE レコードを正本とするモジュール一覧・コード取得・コードページ・書き戻し計画
│   └── 08_BookIO.cs         # xlsm/xlam/xlsb(zip) の入出力、コピー生成、ビルド、検証
├── assets/                  # UI 実体
│   ├── fonts/               # Noto Sans JP / UDEV Gothic の TTF と OFL
│   ├── css/                 # variables / layout / flow / module-list / diff
│   └── js/                  # screens（画面表）/ state / app / diff-* / preset-document
├── presets/                 # 依頼の正本（*.md、1 ファイル = 1 ボタン。SPEC §5.2.1）
├── templates/               # 依頼文（チャット貼付用）の中立な組み立て枠
├── lib/                     # WebView2 DLL（4 本）
├── docs/                    # SPEC.md / DEVELOPMENT.md（本書）
└── tests/                   # ヘッドレス検証スクリプト
```

## 3. アーキテクチャ上の要点

- **エンジンはホストと同じ Add-Type でコンパイルする C# クラス**として `src/` 内に持つ
  （子プロセスや別モジュールを作らない）。理由は SPEC §2.3。
- **エンジン（05〜08）は UI に依存しない**。この分離があるので、`tests/` は
  エンジンだけを Add-Type してヘッドレスに検証できる。
- **画面フローの正本は `assets/js/screens.js`**。画面の順序・見出し・「次へ」を
  有効化する条件はこの表だけが持ち、`state.js` は現在地と履歴、`app.js` は描画と
  操作を担当する。画面を足すときはまず screens.js を直す。画面番号を JS の中へ
  literal で書かず、`screens.js` が公開する名前（`modeScreen` / `bookScreen` /
  `readScreen` / `intakeScreen` など）を使う。
- **最初の画面は「作業を選んでください」**（`modeScreen === 0`）で、ブックの読み込みは
  その次（`bookScreen === 1`）。`setBook` は**選んだ作業を消さず**、画面を
  `bookScreen` に置く。順序を変えるときは `screenBuilders` の並びも同時に直す。
- **用途は 3 つ（改修 / 診断 / 相談）**。診断と相談は AI へ渡すファイルを作って
  終わり、取り込みもビルドも通らない（SPEC §4）。分岐は `nextIndex` の 2 か所だけで、
  ここ以外に用途による条件分岐を増やさない。
- **ツールは判断を持たない**（SPEC §1.2）。SPEC に列挙のない正規化・解釈・自動判定を
  実装中に追加しないこと。貼り付けテキストの正規化規則は SPEC §8 が全量。
- **ひな形の解釈は `assets/js/preset-document.js` だけが持つ**（SPEC §5.2.1）。
  ホスト（C#）は `presets/*.md` の列挙とテキスト読み出しに徹し、H1 も節も解釈しない。
  改修指示・出力指示の文面を `templates/` や `src/` や `assets/js/` へ複製しないこと
  （`tests\test-preset-migration.js` が門番として検査する）。
  モジュール単位出力の文面も同じ扱いで、任意の `## 出力指示（モジュール単位）` 節が
  正本である。持たないひな形では画面に選択肢を出さず、代わりの文面を補わない
  （`tests\test-module-split.js` が門番として検査する）。
- **返答パッケージの解釈は `assets/js/response-package.js` だけが持つ**（SPEC §6.5）。
  区切り行の書式・依頼 ID の検証・拒否理由はここにまとめ、`app.js` は結果を
  画面へ出すだけにする。ホスト（C#）はクリップボードの文字列を渡すだけで、
  区切りを解釈しない。モジュール単位出力（SPEC §6.6）の `PART` 行、受け取り済みの
  照合、統合（`addPart` / `mergeParts`）も同じファイルが持つ。`app.js` は
  「全部そろったら統合結果をワンペーストと同じ経路へ流す」だけにする。
- **取り込みの単位はパッケージ 1 つで、適用は必ず置き換え**（SPEC §5.3 / §10.2）。
  `importPackage` は先に `clearImportedModules` で前回分を取り消してから適用する。
  検証は `getBookModules()`（= ブック由来のモジュール）に対して行い、前回の返答が
  追加した新規モジュールを既存扱いしない。取り込み済み状態は `intakeRequestId` で
  依頼 ID に結び付け、`screens.isIntakeCurrent` が古い取り込みで先へ進むのを止める。
- **ビルドだけは固定の client timeout を持たない**（SPEC §7.5）。
  `host-bridge.js` の既定 120 秒 reject は他の action のためのもので、`buildBook` は
  `timeoutMilliseconds: 0` + `onSlow` で送る。処理の正本は host の応答であり、
  120 秒経過は「まだ続いている」という表示にしかしない。ここへ client 側の
  失敗確定を戻さないこと（監査 P2-3 の再発になる）。
- **読み取り警告は「何が起きたか」を分けて持つ**（SPEC §5.1.2）。
  `HasReadWarnings` は約70か所から立つ1つの真偽値で、それだけでは原因も影響範囲も
  言えない。そこで `Ole2File.HasShortStreamRead`（ストリームが短く返った）、
  `VbaProjectData.PartialSourceModules` / `RecoveredOffsetModules` /
  `UnreadableModules` / `ContainerFallback` / `Salvaged` を別に記録し、
  `HasSourceDoubt()` が「コードに疑いがあるか」を判定する。`attachBook` は
  `read.level`（`clean` / `structureOnly` / `sourceDoubt`）として返し、文言の選択は
  `app.js` の `describeReadResult` だけが持つ。**新しい警告条件を足すときは、
  どちらの段階に属するかを必ず決めること**（増やして一括警告へ戻さない）。
  外部リンク等 VBA 以外のパートは読まないので、この記録には現れない。
- **差分 HTML は確認画面の閲覧専用版で、画面と同じ実装を同梱する**（SPEC §5.4.1）。
  `diff.js` / `vba-highlight.js` / `diff-view.js` と `variables.css` / `flow.css` /
  `module-list.css` / `diff.css` を無加工でインラインし（`@font-face` の除去だけが
  例外）、行生成・文脈行数・変更ブロック・`変更箇所のみ`・折り返し・前後移動はすべて
  画面側の実装が動く。`diff-report.js` は枠（モジュール一覧・ツールバー・テーマ・
  実行データ）だけを持ち、**diff の第 2 実装を置かない**
  （`tests\test-diff-report-toggle.js` が、同梱バンドルと画面の出力一致と、
  `expandRow` 等が `diff-report.js` に無いことを検査する）。
  同梱アセットは `app.js` の `loadReportAssets()` が同一オリジンから読み、
  `buildReport({assets})` へ渡す。アセットが無ければレポート生成はエラーにする
  （縮小版で代替しない）。**外部通信・CDN・編集操作は入れないこと。**
- **添付時点の VBA 内容署名をビルド直前に照合する**（SPEC §9.1-0）。
  `BookIO.CreateSourceSignature` が正本で、`HostServices` が添付時の値を保持し、
  `BookIO.BuildCopy` が自分で読み直した project と比較する。不一致は E-BUILD-04 で、
  出力を作らない。署名はハッシュではなく正規化テキストの完全一致で、engine を
  `System.IO` / `System.Text` / `System.IO.Compression` の範囲に保つ。
- **既存モジュールの種類はブックが正本**（SPEC §6.5 / §13.3）。返答の `<種類>` で
  既存モジュールの型を変えないこと。新規追加は標準モジュールのみで、これを
  広げる場合は writer・読み直し検証・ひな形の出力指示を同時に直す必要がある。

## 4. テストデータ（`testdata/`。git 管理外）

`.gitignore` で `testdata/` を除外している。ローカルに以下を用意する。

| 置き名 | 用意の仕方 | 用途 |
|---|---|---|
| `testdata\test_large.xlsm` | 複数モジュールを含むマクロ付きブックを Excel で作成 | 標準ケース |
| `testdata\synthetic_difat_v3.cfb` | `tests\test-ole2.ps1` が生成 | DIFAT 継続（ヘッダ 109 参照超の FAT）の読み・再構築検証 |
| `testdata\test.xlsb` / 保護付き `.xlsm` | Excel で作成（任意） | xlsb・プロジェクト保護の検証（SPEC §15 の未検証項目） |

`tests\test-extract.ps1` は、抽出結果を別途用意した期待値ディレクトリと突き合わせる
オラクル照合に対応している。`-OracleDir` を指定したときだけ有効になる（省略可）。

## 5. テストの走らせ方

Windows PowerShell 5.1 の fresh process で、各 runner を個別に実行する。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-app-compile.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-design-system.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-compression.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-ole2.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-vbaproject.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-extract.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-roundtrip.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-bookio.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-build.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-hostservices.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-flow-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-split-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-diff-report-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-webview-security.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-encrypted-book.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-window-icon.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p9-distribution.ps1
```

Node test（UI ロジックの単体検証）:

```powershell
node tests\test-audit-fixes.js
node tests\test-build-payload.js
node tests\test-diff.js
node tests\test-file-drop.js
node tests\test-diff-view.js
node tests\test-diff-report.js
node tests\test-diff-report-toggle.js
node tests\test-read-report.js
node tests\test-host-bridge.js
node tests\test-flow-state.js
node tests\test-module-split.js
node tests\test-p6-state.js
node tests\test-p7-state.js
node tests\test-paste-edit.js
node tests\test-paste-normalize.js
node tests\test-preset-document.js
node tests\test-preset-description.js
node tests\test-attach-blocked.js
node tests\test-preset-migration.js
node tests\test-prompt-template.js
node tests\test-vba-highlight.js
```

回帰の見張り番:

- `tests\test-audit-fixes.js` … 2026-07-30 監査の UI 側 4 件（旧パッケージ混入、
  ［取り込み直す］の到達性、`resultError` の表示、長いビルドの扱い）。
- `tests\test-module-split.js` … モジュール単位出力（SPEC §6.6）の区切り行・
  複数回の取り込み・統合・全拒否経路・ひな形が文面を持つこと・既定経路の非回帰。
- `tests\test-hostservices.ps1` … 添付後に元ブックが変わった場合の E-BUILD-04 と、
  同一 run の再ビルドが自分の成果物だけを世代交換すること。
- `tests\test-host-bridge.js` … `buildBook` が client の時計で失敗確定しないこと。
- `tests\test-read-report.js` … 読み取り結果の 2 段階（SPEC §5.1.2）。
  管理情報だけの不整合に「コードを確認してください」を出さないこと、
  内訳が無いときは控えめな文言へ落ちること。
- `tests\test-diff-report-toggle.js` … レポートが同梱したバンドルを取り出して実行し、
  画面側と同じ文脈行数・同じ行・同じ変更ブロックになることを突き合わせる。
  併せて `diff-report.js` に diff の第 2 実装が無いことを検査する。
- `tests\test-diff-report-webview.ps1` … 書き出した実ファイルを WebView2 で開き、
  前／次・変更箇所のみ・折り返し・テーマ・モジュール切替を実クリックし、
  高さ制限が無いこと・編集要素が 0 であることを確認。
- `tests\test-hostservices.ps1` … 正常ブックが `clean`、EOCD を壊したブックが
  `structureOnly`、vbaProject.bin を切り詰めたブックが `sourceDoubt` になること。
  併せてカードの並びがファイル名の数値順であること（`10_` が `2_` の後ろ）。
- `tests\test-encrypted-book.ps1` … ファイル全体が暗号化されたブック（SPEC §2.5.1）。
  製品自前の OLE2 ライタで容器を組み立てるので Excel は要らない。`EncryptionInfo` と
  `EncryptedPackage` の両方がある場合だけ E-ATTACH-04 になること、片方だけ・VBA
  プロジェクトのロック（DPB/CMG）・破損ファイル・ヘッダだけの OLE2 が暗号化と
  判定されないことを見る。`-EncryptedBookPath` を渡すと Excel が実際に作った
  暗号化ファイルにも同じ検査を掛ける。
- `tests\test-window-icon.ps1` … ウィンドウが自前のアイコンを持つこと。
  アプリと同じ手順で窓を作り、そのアイコンを 32px へラスタライズして
  画素を数える（角丸・起動画面と同じ地の色・文字が出ていること）。
  設定を外すと落ちる。
- `tests\test-attach-blocked.js` … 暗号化ブックが画面上のカードで止まり、
  「全モジュール読み取れています」を出さないこと。
- `tests\test-webview-security.ps1` … WebView2 の境界（SPEC §7.1.1）。信頼 origin の
  判定表に加えて、実動する窓で「別 origin のページが同じ bridge へ投げても
  ホスト操作が動かない」「https / file / data / about / 別ホストへ遷移できない」
  「新しいウィンドウが開かない」「frame が読み込まれない」「DevTools・
  ブラウザキー・既定コンテキストメニューが無効」を確認する。
  いずれも結果を見る検査で、`e.Cancel` / `e.Handled` を外すと落ちる。
- `tests\test-preset-description.js` と `tests\test-flow-webview.ps1` …
  目的カードの 1 行が、ひな形の `## 説明` そのものであること（SPEC §5.2.1）。
  改修指示から作り直す実装に戻すと両方が落ちる。同梱ひな形のファイル名が
  H1 と一致していることも見張る。

補助 runner:

- `tests\test-flow-webview.ps1` が 12 画面の通し検証（実ブック → 実行フォルダ →
  ビルド → 差分レポート）を担う。旧 P3〜P8 の個別スモークはこの 1 本へ統合した。
- `tests\test-split-webview.ps1` は同じ WebView2 実動経路で、モジュール単位出力の
  チェックボックス・書き出された `request.md`・1 モジュールずつの取り込み・
  取り込み後の［取り込み直す］到達性を検証する。**クリップボードを一切使わない**
  ので、`Clipboard.SetText` が使えない環境（他プロセスがクリップボードを
  掴んでいる場合の `CLIPBRD_E_CANT_OPEN` など）でも実動確認ができる。
- `tests\test-p9-preset.ps1` と `tests\test-flow-webview.ps1` は
  `test-p9-distribution.ps1` からも呼ばれ、配布物のコピーへ同じ検証を回す。
- `tests\test-excel-macro.ps1` は Excel 実機確認用。`WorkbookPath` と `MacroName` の
  明示指定が必要。

注意:

- `test-flow-webview.ps1` と `test-p9-distribution.ps1` は MacroStudio のウィンドウを
  一時的に表示し、通常の製品ログを `%LOCALAPPDATA%\MacroStudio\logs` に書く。
  途中で中断した場合は、MacroStudio 以外のプロセスを巻き込まないよう対象 PID を確認すること。
- テストは production と同じ `src/*.cs` を Add-Type する。エンジンの検証は
  UI を起動せずに行える。

## 6. リリースゲート

書き戻しエンジンは出力ブックを壊す可能性がある唯一の箇所であり、次の 3 点を
満たすまでリリースしない（SPEC §9.2）。

1. **ラウンドトリップ試験**（`test-roundtrip.ps1`）: 無変更で再構築 → 全ストリーム
   byte 一致・木構造等の論理情報一致。毎ビルドが同じ経路を通るため、この試験が
   本番経路そのものを検証する。
2. **ビルド後の読み直し検証**（SPEC §9.1-6。全ストリーム対象）。
3. **Excel 実機確認**: 再構築した出力を Excel で開き、マクロ動作を確認する。

## 7. リスクと対応

| リスク | 影響 | 対応 |
|---|---|---|
| CFB シリアライザの作り込み不足 | 出力ブック破損 | 上記リリースゲート 3 点 + all-or-nothing（検証を通らない出力は必ず破棄） |
| MS-OVBA 圧縮器の不具合 | ビルド不能/破損 | 圧縮・展開のラウンドトリップ試験を必須。非圧縮チャンク格納の代替経路は要実機確認 |
| xlsb 未検証 | 読み取れるモジュールが限定される可能性 | 解析警告を表示し、読める範囲のモジュールを返す |
| 容器（ZIP / CFB）の破損 | 解析不能で添付できない | SPEC §5.1.1 の 6 経路で読み直し、最後は生バイト走査で復元する。読めたソースは必ず保持し、警告は一度だけ |
| D&D でパスが取れない | UX 低下のみ | ファイル選択ボタン（方式C）を常設 |
| Add-Type の C# 5.0 制約違反の混入 | 起動不能 | §1 を各ファイル着手前に再確認。`tests\test-app-compile.ps1` で検出できる |
