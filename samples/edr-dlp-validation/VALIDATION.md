# Validation record

検証日: 2026-07-30（Asia/Tokyo）

対象入口: `FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm`

環境: Windows 64-bit、Microsoft Excel 16.0 build 20228

runner SHA-256:

```text
1DA3EE7A510E3D39CCD854FC8A3AABB3E28332FE8B9A192822001DEB2878808C
```

## 判定の境界

この記録の`PASS`はローカルExcel / VBA側の機能結果だけです。
先生の本番EDR / DLP管理コンソール、alert、block、audit event、
event IDはこの環境から照合していません。

先生の本番正本結果は次のとおりです。

- PASS: A1、B1、D1、E1、E2
- FAIL: A2、B2、D2、F1、F2
- C2: RunLogなしで判定不能
- C1: 未報告

追加X/Yケースは先生の本番環境では未実行です。ローカルで完走したことを、
本番EDRでの非検知、検知成功、許可成功として扱いません。

## 作業前の正本とdirty保護

作業開始時にlocal HEAD、`origin/main`、取得済みremote mainが次で一致して
いることを確認しました。

```text
2137ed439587abf8f9e1192fe2ee6a40cc62a73b
```

開始時の`edr-dlp-validation`領域はcleanでした。リポジトリにはこの領域外に
158件の既存dirty entryがありましたが、内容を取込み、変更、stageして
いません。この追加診断でもcommit、push、rebase、force操作をしていません。

## 診断標本の構造検査

同一由来の4形態を次のとおり確認しました。

| item | bytes | SHA-256 |
|---|---:|---|
| item-01 `fixture-02.xlsm` | 11,847 | `D8C4EEF261568D5EC42735A153B0192D5012A66CF6F5C4BA52E800430263CB09` |
| item-02 `diagnostic/item-02.dat` | 11,847 | `D8C4EEF261568D5EC42735A153B0192D5012A66CF6F5C4BA52E800430263CB09` |
| item-03 `diagnostic/item-03.dat` | 10,752 | `9A3ED06A0D19DFF34DDCFA9BA70A0B9CABF64F66049E4DD210CB9CDC3BA5DE42` |
| item-04 `diagnostic/item-04.bas` | 232 | `C54C7F13A5A004FDDE401B4A7C3B58D96290A28FF8BEF83FC502DBD36975BCFE` |

- item-01とitem-02: byte同一を確認
- item-03: item-01の`xl/vbaProject.bin`を抽出した単体file
- item-04と`source-mirror/fixture-02.bas`: byte同一を確認
- item-02 / item-03は中立拡張子と中立名
- 期待値を`EXPECTED-SHA256.txt`、runnerの中立ID metadata、
  `SHA256SUMS.txt`で照合可能

期待hashの事前記録は配布前にこの安全な環境で算出した値です。
本番の存在確認ケースは内容をhashするために先読みしません。実hashは
全体read後にだけ算出します。

## runner単体と隔離耐性

runner、通常`fixture-01.xlsm`、通常source mirrorだけを一時配置し、
`fixture-02`と`fixtures/diagnostic/`全体がない状態でExcel実機試験を
行いました。

- runner open: 成功
- open直後のRunLog: header 1行だけ
- open直後のfixture access: 0
- 純VBA SHA-256既知ベクトル自己検査: PASS
- item-01存在確認: controlled `False`、外部TSVへ`MISSING`と`CASE_END FAIL`
- 欠落ケース後のR0 runner baseline: PASS
- 欠落ケース後の通常A1 binary read: PASS
- 外部TSV: 作成・Close済み
- 一時配置: 検証後に削除

したがって、検知側標本の事前隔離・配布欠落があっても、runner open、
hash engine、通常系A1は独立しています。製品がExcel.exe自体を終了する
実挙動はこの欠落模擬には含まれません。

## Excel実機の追加診断結果

最終通し実行:

```text
2026-07-30 17:36:30.480 ～ 17:36:35.750
```

公開macroと同じcore functionを一件ずつ`interactive=False`で呼び、
確認dialogだけを省略しました。read、write、hash、clipboard、
workbook作成、SaveAsの処理は公開入口と同一です。run-all macroと
自動起動はありません。

### X read-onlyケース

| 分類 | item-01 | item-02 | item-03 | item-04 |
|---|---|---|---|---|
| 存在・sizeのみ | PASS | PASS | PASS | PASS |
| binary open-close | PASS | PASS | PASS | PASS |
| `Get` 1 byte | PASS | PASS | PASS | PASS |
| `Get` 最大4 KiB | PASS | PASS | PASS | PASS |
| `Get`全体＋純VBA SHA-256 | PASS | PASS | PASS | PASS |
| `InputB$`最大4 KiB | PASS | PASS | PASS | PASS |

全体readの実SHA-256は4 itemとも事前期待値と一致しました。
`InputB$`は同じExcel.exe内、同じ`Open For Binary`を使い、
`Get Byte()`との差だけを比較する限定経路です。

純VBA SHA-256は、空byte列とASCII 3 byteの公開既知ベクトルでも
自己検査し、両方一致しました。

### X rebuildケース

| ケース | source | output | bytes | 結果 |
|---|---|---|---:|---|
| X25 | item-01 | 新規`.dat` | 11,847 | sourceとSHA-256・全byte一致 |
| X26 | item-01 | 新規`.xlsm` | 11,847 | sourceとSHA-256・全byte一致 |
| X27 | item-02 | 新規`.dat` | 11,847 | sourceとSHA-256・全byte一致 |
| X28 | item-03 | 新規`.dat` | 10,752 | sourceとSHA-256・全byte一致 |
| X29 | item-04 | 新規`.dat` | 232 | sourceとSHA-256・全byte一致 |

各ケースでinputの1 byte、4 KiB、全体、Close、hash、新規outputのopen、
1 byte、4 KiB、全体、Close、再open、全体read、Close、hashと全byte比較を
個別stageとして記録しました。元標本をwriteしていません。

### Y clipboardケース

各Yの直前に対応Eを再実行しました。Y本体はsource mirrorを再読取りません。

| fixture | runner memoryへpaste | 新規bookへpaste・保存なし | 新規bookへpaste・保存 |
|---|---|---|---|
| fixture-01（Y01/Y02/Y03） | PASS | PASS | PASS |
| fixture-02（Y04/Y05/Y06） | PASS | PASS | PASS |

stage logで`PASTE_OK` 6件、`SAVE_OK` 2件を確認しました。保存した2件は
`output/`配下の新規`.xlsx`だけです。既存F1/F2と異なり、Yでは
external source mirrorの再readを除外しています。

### 外部progress log

最終通しでは次を記録しました。

| 項目 | 実測 |
|---|---:|
| TSV rows | 489 |
| session | 1 |
| case ID | 36（X00 session markerを含む） |
| `CASE_END` | 35 |
| `CASE_END PASS` | 35 |
| `FAIL` result row | 0 |
| `OPEN_BINARY_OK` | 25 |
| `OPEN_SIZE_RESULT` | 25 |
| `READ_1_BYTE_OK` | 13 |
| `READ_UP_TO_4096_OK` | 13 |
| `READ_ALL_OK` | 9 |
| `INPUTB_READ_UP_TO_4096_OK` | 4 |
| `WRITE_ALL_OK` | 5 |
| `VERIFY_ANALYSIS_OK` | 5 |
| `VERIFY_OPEN_BINARY_OK` | 5 |
| `VERIFY_SIZE_RESULT` | 5 |
| `PASTE_OK` | 6 |
| `SAVE_OK` | 2 |

X00はsession markerなので`CASE_END`を持ちません。log routineは一stage
ごとに`Open For Append`、一行出力、`Close`を完了します。標本文は
ログへ出さず、neutral ID、path、size、hash、境界、errorだけを記録します。

25件のinput openすべてで、`OPEN_BINARY_OK`のdetailが
`file_open=true`として`LOF`より先にClose済みでした。その後の
`OPEN_SIZE_RESULT`も25件です。rebuild outputの再open 5件でも、
`VERIFY_OPEN_BINARY_OK`を`LOF`より先に記録し、別の
`VERIFY_SIZE_RESULT`を5件記録しました。これによりopen成功と`LOF`失敗を
同じstageへ混在させていません。

全追加ケース完了後、同じExcel instanceで既存通常A1を再実行しPASSでした。

## runnerの静的・埋込み検査

### VBA構造

- standard module: 8
  - 既存: RunnerCommon、RunnerBinary、RunnerProject、RunnerClipboard
  - 追加: RunnerHash、RunnerDiagnosticCore、RunnerDiagnostic、
    RunnerClipboardDiagnostic
- document module: ThisWorkbook＋4 worksheet、すべて0行
- worksheet: Control、ClipboardBuffer、RunLog、Diagnostic
- `runner-vba/*.bas`とExcelから再exportした8 module:
  EOL正規化後に全件exact match
- source exportとExcel再exportの対象語句:
  `Declare` / `PtrSafe` / `kernel32` / `Sleep`すべて0件
- non-binary ZIP entryの同対象語句: 0件
- `Workbook_Open` / `Auto_Open` / worksheet event: 0件
- Shell / PowerShell / WScript / CreateObject / GetObject: 0件
- network URL / WinHTTP / XMLHTTP / socket: 0件
- file deletion (`Kill` / `RmDir` / `DeleteFile`): 0件
- external link / connection / ActiveX / drawing: 各0件

既存RunnerProjectにはD1/D2用の`CodeModule.AddFromString`が実コード1件、
説明文字列1件あります。これは外部source mirrorを明示Dケースで
新規outputへ書く既存VBProject経路であり、Trust Accessを必要とします。
追加X/Yケースはこの経路を呼びません。

### 埋込み内容の証拠

Excelから実runnerのstandard moduleを再exportし、次を確認しました。

1. 8 moduleが監査用`runner-vba/*.bas`と一致
2. document module codeが合計0行
3. 監査用sourceと再exportの両方に検知対象語句がない
4. worksheet XML等のnon-binary partにも検知対象語句がない

したがって、監査用sourceだけでなく実行bookの埋込みVBAとworksheetにも、
検知標本の宣言本文や対象名を事前保持していないことを確認しています。

## outputの後片付け

実機試験で作成した次を検証しました。

- staged rebuild 5件
- clipboard保存2件
- `diagnostic-progress.tsv`
- 静的検査用一時export

rebuild 5件は外部`Get-FileHash`でもsource期待値と一致しました。
結果をこの記録へ転記した後、再生成可能な実機試験outputと一時exportは
手動で削除し、配布treeの`output/`は`.gitkeep`だけに戻します。
サンプルのVBAは削除処理を持たず、実行していません。

## 未検証

- 先生の本番EDR / DLP環境でのX01〜X30、Y01〜Y06
- 各停止stageと本番管理コンソールeventの照合
- 本番結果で判定不能のC2、未報告のC1
- 32-bit Excel
- Trust Access無効時のC1/C2/D1/D2
- 署名済みVBA project
- 組織固有のalert名、event ID、event反映遅延
