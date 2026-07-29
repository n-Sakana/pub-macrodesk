# input_monthly_report — 一般リファクタ用の入力サンプル

`testdata\input_monthly_report.xlsm` を作るための素材一式です。
`testdata\` は git 管理外なので、**正本はこのディレクトリの VBA ソース**で、
ブックは `tests\make-input-monthly-report.ps1` がいつでも作り直します。

既存の `input_win32_sleep.xlsm`（Win32 API 除去用）とは用途が違うので、
置き換えではなく別サンプルとして足しています。

## 何のマクロか

総務課が毎月まわしている売上集計マクロ、という想定です。
入口は `RunMonthlyReport`（標準モジュール `MonthlyReport`）。

- 入力: `売上明細`（158 行）、`商品マスタ`、`支店マスタ`、`設定`、`ひな形`（非表示）
- 出力: `月次集計`、`支店別レポート`、`点検リスト`、`担当者別`、`報告書`
- 対象年月は `設定!B2` = `202606`。外部ファイル・ネットワーク・Shell・
  Win32 API・WMI・ファイル削除は一切使いません。
- ブックは「先月（202605）を流した直後」の状態で配布されます。判定列と
  出力シートに前月の結果が残っているので、実行すると置き換わるのが見えます。

数字は固定です（純売上 15,996,900 円、売上 121 件 / 返品 16 件、点検 20 件）。
唯一動くのは `月次集計!B3` の作成日時だけで、検証はそこを除外します。

## 意図的に残してある改善余地

**わざとらしい教材にはしていません。** マクロの記録、継ぎ足し、コピペで
何年か育った実務マクロとして自然に見える形にしてあります。

| 改善余地 | 主な場所 | リファクタ後の姿 |
|---|---|---|
| セル単位の読み書き（write 114 / read 33 か所） | 全体 | 2 次元 Variant で一括取得・一括書き戻し |
| 値だけなのに Copy / PasteSpecial | `CoverSheet` | 必要な箇所だけ Range 直接代入 |
| Select / Activate / Selection / ActiveSheet / ActiveWorkbook / 無修飾 Range・Cells | `ReportFormatting`, `CoverSheet` | 明示的な Workbook・Worksheet・Range 参照 |
| ループ内の `ReDim Preserve` | `StaffSummary` | 事前確保または一定単位の拡張 |
| 同じキーの線形探索・二重ループ照合 | `CommonUtil`, `BranchReport`, `StaffSummary` | 配列 + Dictionary の索引 |
| 高速化設定を無条件に切り、正常経路でしか戻さない | `MonthlyReport` | 元状態を保存し、エラー時も単一 Cleanup で復元 |
| 長大手続き（`RunMonthlyReport` 281 行）、重複集計、薄い変数名、広いスコープ、暗黙 Variant / Public、魔法の数値、広すぎる `On Error Resume Next` | 全体 | 意味のある単位への分割・命名、エラー範囲の限定 |

クラスモジュール `CReportRow` は脇役です。支店 1 行分を持ち、
`BranchReport` が `New` して純売上・達成率・判定を実際に引いています
（飾りではなく実行経路上）。既存クラスが改修往復で壊れないかの確認用で、
リファクタの主題ではありません。

## 「やりすぎ」を不正解と判定できるようにしてある

一律置換で壊れる仕掛けを、業務上自然な形で入れてあります。
検出は `tests\test-monthly-report-equivalence.ps1` が行います
（実測: 下記 4 つはいずれも検出され、無変更の対照群だけが通ります）。

| 誤った改修 | 何が壊れるか | 検出例 |
|---|---|---|
| Copy を全部やめる | ひな形からの貼り付けが書式と数式を運んでいる | `cover formula survived the paste: expected [=月次集計!H11], got [0]`（10 件失敗） |
| `.Value` / `.Text` を全部 `.Value2` にする | 計上日が Double になり `IsDate` が落ちる。表示文字列も桁区切りを失う | `summary B01 / 文具: expected [53040], got [0]`（299 件失敗） |
| 高速化設定を無条件に入れる | 元の状態へ戻さなくなる | `Application.Calculation restored: expected [-4135], got [-4105]`（2 件失敗） |
| 順序を持つ処理まで索引化する | 担当者別は出現順で累計を出している | `staff 伊藤 running total: expected [1240960], got [16007100]`（8 件失敗） |

逆に、**Dictionary 化してよい箇所**（商品・支店・担当者の突き合わせ、
伝票番号の重複検出）と、**してはいけない箇所**（担当者別の出現順と累計）が
両方あります。

## 固定した観測点

リファクタ後も同一であることを機械検証する対象です。

- 入口 `RunMonthlyReport`（**モジュール名で修飾せず呼ぶ**ので、モジュールを
  分割・改名しても検証は壊れません）
- 対象シート名とセル位置、見出し文字列
- 集計値・件数・金額、支店別の達成率と判定、上位商品、点検リストの全行
- 表示まわり: 判定セルの塗り、見出しの塗り、数値書式、達成率の `0.0%`、
  表紙の数式・塗り・文字サイズ、`.Text` 由来の表示文字列
- 完了メッセージ（`報告書!B13`）
- 実行前後の `Application.Calculation` / `ScreenUpdating` / `EnableEvents` /
  `StatusBar` / `CutCopyMode`

## 使い方

```powershell
# 1. ブックを作る（Excel が必要。AccessVBOM = 1）
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\make-input-monthly-report.ps1

# 2. 入力サンプルとして妥当か（MacroStudio の抽出経路で読めるかも見る）
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\test-input-monthly-report.ps1

# 3. 業務結果の同一性（改修の前後で同じものを使う）
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\test-monthly-report-equivalence.ps1

# 4. MacroStudio の書き戻し往復（クラス改修を含む）
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\test-monthly-report-roundtrip.ps1 -RunEquivalence
```

改修版の挙動を測るときは、**MacroStudio のビルド結果ではなく**、改修後の
ソースからブックを作り直して 3 を回します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\make-input-monthly-report.ps1 `
  -SourceDir <改修後の .bas/.cls があるフォルダ> `
  -OutPath testdata\refactored.xlsm
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests\test-monthly-report-equivalence.ps1 `
  -BookPath testdata\refactored.xlsm
```

理由は次節のとおりです。

## 注意: 再ビルドしたブックは「元のコード」で動きます

SPEC 9.3 のとおり、MacroStudio は `_VBA_PROJECT` と各モジュール先頭の
PerformanceCache を触らず、再コンパイルを Excel に任せています。
**この環境（Office16 / 同一マシン・同一ビット）では Excel は再コンパイルせず、
キャッシュ済み p-code をそのまま実行します。**

実測（`tests\test-monthly-report-roundtrip.ps1` の canary）:

- 書き戻したソースはディスク上正しく入れ替わっている（`BookIO.ReadProject` で確認）
- しかし VBE に表示されるのも、実行されるのも元のコード
- そのため再ビルドしたブックで実行検証しても、**新しいコードを測れていない**

`-RunEquivalence` は「再ビルドしたブックがまだ開いて動く」ことの確認までで、
機能同等性の証明ではありません。往復テストはソース水準（種別・属性・コード）を
検証し、この挙動は canary が毎回報告します。

## ファイル

| ファイル | 役割 |
|---|---|
| `*.bas` / `*.cls` | VBA ソース（正本）。UTF-8 で置き、生成時に VBIDE 経由で流し込む |
| `workbook-data.json` | 日本語のシート名・見出し・マスタ・設定。`tests\*.ps1` を ASCII のまま保つため |
| `expected.json` | 出力の golden 指紋（154 項目）。`-WriteExpected` でのみ更新する |

`.bas` / `.cls` は属性行を持ちません。標準モジュールは
`VBComponents.Add(1)`、クラスは `VBComponents.Add(2)` で作り、
`Attribute VB_Name` などのクラス属性は **Excel 自身に生成させています**
（OLE メタデータを手で書いた箇所はありません）。
