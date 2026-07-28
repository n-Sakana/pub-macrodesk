# MacroDesk 開発ガイド

仕様は [SPEC.md](SPEC.md) が正本。本書はビルド制約、リポジトリ規約、テストの走らせ方を
まとめたもの。仕様と本書が食い違ったら SPEC.md を優先する。

---

## 1. 言語・構文の制約（守らないと動かない）

MacroDesk は dotnet SDK を必要としない。ホストの C# は Windows PowerShell 5.1 の
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

- `src/` は番号付きファイル名（`01_App.cs` …）。`macrodesk.ps1` が名前順に連結し、
  using を先頭へ集約して 1 回の `Add-Type` でコンパイルする。
- 名前空間は `MacroDesk`。WebView2 仮想ホスト名は `macrodesk.local`。
- ユーザーデータ: `%LOCALAPPDATA%\MacroDesk\WebView2Cache`、ログ: 同 `\logs`。
- `lib/` の WebView2 DLL 4 本は NuGet パッケージ `Microsoft.Web.WebView2`
  （SDK 1.0.3856.49）の再配布 DLL。差し替える場合は 4 本の版を揃えること。

### ファイル構成

```
macrodesk/
├── launch.vbs               # 本番起動（黒画面なし）
├── launch.bat               # 開発起動（コンソールあり）
├── macrodesk.ps1            # ホスト: src/*.cs を集約 → Add-Type → App.Run
├── src/                     # C#（ホスト + エンジン）
│   ├── 01_App.cs            # エントリ。AssemblyResolve、STA スレッド、WebView2 ランタイム確認
│   ├── 02_MainWindow.cs     # WPF 窓 + WebView2 + 仮想ホスト + D&D 受け
│   ├── 03_MessageRouter.cs  # JS⇔C# の id 付き request/response IPC
│   ├── 04_HostServices.cs   # ダイアログ、クリップボード、explorer /select、依頼・差分ファイル出力、template / presets 読み、ログ
│   ├── 05_Ole2.cs           # OLE2(CFB) リーダ/ライタ
│   ├── 06_VbaCompression.cs # MS-OVBA 2.4.1 展開・圧縮
│   ├── 07_VbaProject.cs     # dir の MODULE レコードを正本とするモジュール一覧・コード取得・コードページ・書き戻し計画
│   └── 08_BookIO.cs         # xlsm/xlam/xlsb(zip) の入出力、コピー生成、ビルド、検証
├── assets/                  # UI 実体
├── presets/                 # 改修マニュアル（*.md、1 ファイル = 1 ボタン）
├── templates/               # 依頼ファイル全体の編集可能なテンプレート
├── lib/                     # WebView2 DLL（4 本）
├── docs/                    # SPEC.md / DEVELOPMENT.md（本書）
└── tests/                   # ヘッドレス検証スクリプト
```

## 3. アーキテクチャ上の要点

- **エンジンはホストと同じ Add-Type でコンパイルする C# クラス**として `src/` 内に持つ
  （子プロセスや別モジュールを作らない）。理由は SPEC §2.3。
- **エンジン（05〜08）は UI に依存しない**。この分離があるので、`tests/` は
  エンジンだけを Add-Type してヘッドレスに検証できる。
- **ツールは判断を持たない**（SPEC §1.2）。SPEC に列挙のない正規化・解釈・自動判定を
  実装中に追加しないこと。貼り付けテキストの正規化規則は SPEC §8 が全量。

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-compression.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-ole2.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-vbaproject.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-extract.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-roundtrip.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-bookio.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-build.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-hostservices.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p3-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p4-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p5-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p6-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p8-webview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-p9-distribution.ps1
```

Node test（UI ロジックの単体検証）:

```powershell
node tests\test-build-payload.js
node tests\test-diff.js
node tests\test-diff-report.js
node tests\test-host-bridge.js
node tests\test-p4-state.js
node tests\test-p6-state.js
node tests\test-p7-state.js
node tests\test-p8-lecture.js
node tests\test-paste-normalize.js
node tests\test-prompt-template.js
node tests\test-vba-highlight.js
```

補助 runner:

- `tests\test-p9-preset.ps1` は `test-p9-distribution.ps1` から呼ばれる helper。
- `tests\test-excel-macro.ps1` は Excel 実機確認用。`WorkbookPath` と `MacroName` の
  明示指定が必要。

注意:

- `*-webview.ps1` と `test-p9-distribution.ps1` は MacroDesk のウィンドウと Explorer を
  一時的に表示し、通常の製品ログを `%LOCALAPPDATA%\MacroDesk\logs` に書く。
  途中で中断した場合は、MacroDesk 以外のプロセスを巻き込まないよう対象 PID を確認すること。
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
| xlsb 未検証 | xlsb 添付で失敗 | 実物入手までは E-ATTACH-05 の明示エラーで受ける |
| D&D でパスが取れない | UX 低下のみ | ファイル選択ボタン（方式C）を常設 |
| Add-Type の C# 5.0 制約違反の混入 | 起動不能 | §1 を各ファイル着手前に再確認。`tests\test-app-compile.ps1` で検出できる |
