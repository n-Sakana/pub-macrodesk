# MacroStudio EDR / DLP validation sample

> **最初に開くファイル**
>
> `FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm`
>
> **手動で開いてはいけない／直接開く必要がない標本**
>
> `fixtures/fixture-01.xlsm`、`fixtures/fixture-02.xlsm`、
> `fixtures/diagnostic/item-02.dat`、`item-03.dat`、`item-04.bas`
>
> 標本を手動でダブルクリック、Excelへimport、内容表示しないでください。
> 必要な標本へ触れるのは、上記runnerでユーザーが一件ずつ明示実行した
> ケースだけです。`fixtures/source-mirror/*.bas` もExcelへ手動importする
> 必要はありません。

このサンプルは、Excel / VBAの正規操作がEDR / DLPに検知・遮断される
地点を、操作経路と標本形態ごとに観測するものです。検知回避を目的と
しません。

## 今回の追加診断の前提

先生の本番環境で確認済みの正本結果は次のとおりです。

| 結果 | 既存ケース |
|---|---|
| PASS | A1、B1、D1、E1、E2 |
| FAIL | A2、B2、D2、F1、F2 |
| 判定不能 | C2（RunLog記録なし） |
| 未報告 | C1 |

既存A2は`Workbooks.Open`ではありません。Excel.exe内の純VBAで
`Dir$`、`Open ... For Binary`、`Get Byte()`を順に実行します。
したがって、現時点で確認できているのは「既存A2/B2で
`fixture-02.xlsm`を扱えなかった」ことだけです。

Excel単体の純VBAバイナリ読取り・再構築そのものが不成立とは、まだ
結論しません。追加したXケースは、Excelが強制終了しても最後に完了した
境界を外部ログで特定するための診断器です。

## runnerと標本の分離

runnerと検知対象は物理的に別ファイルです。runnerのVBAとworksheetには、
検知対象の宣言本文、`Declare`、`PtrSafe`、DLL名、対象関数名を
含めていません。標本を起動時に読み込まず、自動実行もしません。

既存標本の対応は次のとおりです。

| fixture ID | 閉じた標本 | source mirror | 内容 |
|---|---|---|---|
| `01` | `fixtures/fixture-01.xlsm` | `fixtures/source-mirror/fixture-01.bas` | Win32 API宣言を含まない通常標本 |
| `02` | `fixtures/fixture-02.xlsm` | `fixtures/source-mirror/fixture-02.bas` | Win32 API宣言だけを持つ検知標本 |

`fixture-02`はVBA7用と旧VBA用の`Sleep`宣言だけを持ち、呼出し
procedureを持ちません。両標本とも自動実行コードを持ちません。

### Xケースの4形態

同一由来の検知標本を物理的に分離し、runnerからは中立ID
`item-01`〜`item-04`で選びます。

| X item | 実ファイル | 形態 | bytes | SHA-256 |
|---|---|---|---:|---|
| `01` | `fixtures/fixture-02.xlsm` | 元の宣言入り`.xlsm` | 11,847 | `D8C4EEF261568D5EC42735A153B0192D5012A66CF6F5C4BA52E800430263CB09` |
| `02` | `fixtures/diagnostic/item-02.dat` | item-01のバイト同一コピーを中立拡張子へ変更 | 11,847 | `D8C4EEF261568D5EC42735A153B0192D5012A66CF6F5C4BA52E800430263CB09` |
| `03` | `fixtures/diagnostic/item-03.dat` | item-01から抽出した`vbaProject.bin`単体、中立名 | 10,752 | `9A3ED06A0D19DFF34DDCFA9BA70A0B9CABF64F66049E4DD210CB9CDC3BA5DE42` |
| `04` | `fixtures/diagnostic/item-04.bas` | 宣言を含むsource mirrorの物理コピー | 232 | `C54C7F13A5A004FDDE401B4A7C3B58D96290A28FF8BEF83FC502DBD36975BCFE` |

item-01とitem-02のハッシュは同一です。内容を変えず、ファイル名と
拡張子だけの差を比較できます。期待値の安全な一覧は
`fixtures/diagnostic/EXPECTED-SHA256.txt`にもあります。

期待sizeと期待SHA-256はrunnerに安全なメタデータとして保持しています。
各ケースはこの期待値を**標本内容へ触れる前**にログへ記録します。
存在確認でSHA-256をその場で計算しているわけではありません。実SHA-256は
全体読取り後、メモリ上のbyte配列だけを純VBAで解析して記録します。

## 安全境界

- `Workbook_Open`、`Auto_Open`、worksheet eventなどの自動実行はありません。
- Win32 APIを呼ぶコードはありません。検知標本にも宣言を呼ぶprocedureはありません。
- runner実行時にShell、PowerShell、外部exe、プロセス起動、ネットワーク、
  外部送信、レジストリ操作を使いません。
- Xの読取りはExcel.exe内の純VBA `Open For Binary`と`Get`が主経路です。
  比較用に`InputB$`を一経路だけ追加しています。
- 元標本は開いて書かず、上書きしません。
- file出力は`output/`配下の一意な新規名だけです。既存fileを置換しません。
- マクロはfileを削除しません。途中で遮断されたpartial outputも証跡として残します。
- X/YケースにTrust Accessは不要です。既存C1/C2/D1/D2だけが
  「VBAプロジェクト オブジェクト モデルへのアクセスを信頼する」を必要とします。
- E/Y実行後の標本文とRunLogはrunnerのメモリに残ります。runnerは保存せず閉じます。
- 検知標本が隔離・欠落してもrunnerのオンディスク内容は独立しています。
  Excelへ制御が戻れば、そのケースをFAILとして記録し、通常系を続行できます。
  Excel.exe自体が終了した場合はrunnerだけを再度開き、別の個別ケースを選べます。

## 外部プレーンログ

追加診断は次へappendします。

```text
output/diagnostic-progress.tsv
```

一行書くたびにVBAの`Open For Append`、`Print #`、`Close`を完了します。
既存ログを消去・truncateしません。Excel.exeが強制終了しても、最後に
Close済みの行まで残ります。列は次のとおりです。

```text
timestamp  session  case  item  stage  result  detail
```

- timestamp: ローカル日時、millisecond表示
- session: Excel起動中の診断session ID
- case / item: 中立ID
- stage: 完了または開始した境界
- result: `START`、`OK`、`PRESENT`、`MISSING`、`PASS`、`FAIL`
- detail: size、SHA-256、出力先、エラー番号など。標本文そのものは記録しません。

X00は新しいsession境界をappendするだけです。ログを消しません。
RunLogがExcel終了で残らなくても、このTSVとEDR / DLPイベント時刻を
照合してください。絶対pathが記録されるため、外部共有前に確認が必要です。

### 主なstage

| stage | 到達したこと |
|---|---|
| `TEST_START` | 個別ケースのVBA本体へ入った |
| `EXPECTED_METADATA` | 事前の期待size/hashを記録した。標本内容は未読 |
| `EXISTS_CHECK_START` | `Dir$`直前 |
| `EXISTS_RESULT` | `Dir$`がpresent/missingを返した |
| `SIZE_RESULT` | `FileLen`取得と期待size比較が終わった |
| `OPEN_ATTEMPT` | inputの`Open For Binary`直前 |
| `OPEN_BINARY_OK` | inputの`Open For Binary`成功直後。`LOF`より前 |
| `OPEN_SIZE_CHECK_START` / `OPEN_SIZE_RESULT` | open済みstreamの`LOF`開始／完了 |
| `READ_1_BYTE_OK` | `Get`で1 byte取得済み |
| `READ_UP_TO_4096_OK` | `Get`で最大4 KiB取得済み |
| `READ_ALL_OK` | 全体をbyte配列へ取得済み |
| `CLOSE_OK` | inputをClose済み |
| `ANALYSIS_START` / `ANALYSIS_OK` | Close後の純VBA SHA-256開始／完了 |
| `INPUTB_READ_UP_TO_4096_OK` | 比較経路`InputB$`で最大4 KiB取得済み |
| `OUTPUT_OPEN_*` / `WRITE_*` / `OUTPUT_CLOSE_OK` | 新規outputのopen、1 byte、4 KiB、全体、Close |
| `VERIFY_*` | 新規outputの再open、全体読取り、Close、hash/byte比較 |
| `PASTE_*` / `BOOK_*` / `SAVE_*` | clipboardの貼付、新規book、保存の各境界 |
| `CASE_END` | Excel側の個別ケース結果 |

## Xケース一覧

すべて`Alt+F8`から一件だけ明示実行します。run-all macroはありません。

| ケース | 公開macro | item | 操作 |
|---|---|---|---|
| X00 | `X00_StartDiagnosticSession` | - | append-only session境界 |
| X01〜X04 | `X01_Item01_ExistenceOnly`〜`X04_Item04_ExistenceOnly` | 01〜04 | 存在とsizeだけ。内容をopen/readしない |
| X05〜X08 | `X05_Item01_OpenClose`〜`X08_Item04_OpenClose` | 01〜04 | binary open-close、内容をreadしない |
| X09〜X12 | `X09_Item01_GetOneByte`〜`X12_Item04_GetOneByte` | 01〜04 | `Get`で1 byte |
| X13〜X16 | `X13_Item01_GetUpTo4096`〜`X16_Item04_GetUpTo4096` | 01〜04 | `Get`で最大4 KiB |
| X17〜X20 | `X17_Item01_GetAllAndHash`〜`X20_Item04_GetAllAndHash` | 01〜04 | 1 byte、4 KiB、全体、Close、純VBA SHA-256 |
| X21〜X24 | `X21_Item01_InputBUpTo4096`〜`X24_Item04_InputBUpTo4096` | 01〜04 | `InputB$`で最大4 KiB |
| X25 | `X25_Item01_RebuildNeutral` | 01 | staged read、新規`.dat`再構築、再open検証 |
| X26 | `X26_Item01_RebuildBookExtension` | 01 | staged read、新規`.xlsm`再構築、再open検証 |
| X27 | `X27_Item02_RebuildNeutral` | 02 | staged read、新規`.dat`再構築、再open検証 |
| X28 | `X28_Item03_RebuildNeutral` | 03 | staged read、新規`.dat`再構築、再open検証 |
| X29 | `X29_Item04_RebuildNeutral` | 04 | staged read、新規`.dat`再構築、再open検証 |
| X30 | `X30_VerifyHashEngine` | - | fixtureに触れず既知ベクトルで純VBA hashを自己検査 |

全体読取りケースは、一回のopen中に1 byte、4 KiB、全体をそれぞれ
position 1から読み直します。各境界を外部ログへCloseしてから次へ進みます。
これとは別に1 byteのみ、4 KiBのみを独立ケースにしているため、前段で
Excelが終了しても次の起動で別ケースを選べます。

### 既存ケースとの対応

| 既存ケース | 追加診断で近い経路 | 切り分け |
|---|---|---|
| A2 | X01、X05、X09、X13、X17（item-01） | `Dir$`、open、read量、Close、解析のどこか |
| B2 | X25とX26 | source read、output write量、neutral/.xlsm拡張子、再openのどこか |
| A1 / B1 | 既存A1 / B1を引き続き基準に使う | 通常標本の同系統経路 |
| C2 | 既存C2を別途一件で再実行 | `Workbooks.Open`とVBProject経路。Xでは代替しない |
| D2 | 既存D2を別途一件で再実行 | source mirrorとVBProject書込み。Xでは代替しない |
| F1 / F2 | Y01〜Y06 | clipboard貼付、新規book、saveを分離 |

C2がRunLogなしだったことをA2/B2のbinary経路と混同しません。
C/DだけTrust Accessが必要です。

## Yケース: F1/F2の独立診断

既存F1/F2は、clipboardだけでなく次の処理を一つのケースで行います。

1. 対応source mirrorを再読取り
2. 新規workbookを作成
3. clipboardを貼り付け
4. `.xlsx`へ保存
5. source mirrorと比較

本番では通常標本のF1も失敗しているため、F1/F2をAPI検知だけで説明
しません。Yケースは外部標本を再読取りせず、直前のExcel-cell clipboard
だけを使います。

| ケース | 公開macro | 直前に必ず実行 | 診断する境界 |
|---|---|---|---|
| Y01 | `Y01_Fixture01_PasteToRunnerOnly` | E1 | runnerのvisible cellへmemory貼付だけ |
| Y02 | `Y02_Fixture01_PasteToNewBookNoSave` | E1 | 新規book作成＋貼付、保存せずClose |
| Y03 | `Y03_Fixture01_PasteToNewBookAndSave` | E1 | 新規book作成＋貼付＋新規`.xlsx`保存 |
| Y04 | `Y04_Fixture02_PasteToRunnerOnly` | E2 | runnerのvisible cellへmemory貼付だけ |
| Y05 | `Y05_Fixture02_PasteToNewBookNoSave` | E2 | 新規book作成＋貼付、保存せずClose |
| Y06 | `Y06_Fixture02_PasteToNewBookAndSave` | E2 | 新規book作成＋貼付＋新規`.xlsx`保存 |

EとYの間に別のcopy操作を挟まないでください。Yを一件試すたびに、
対応Eを改めて実行します。

- Y01/Y04で落ちる: clipboard paste自体またはrunner cellへの取込み
- Y01/Y04は通りY02/Y05で落ちる: 新規workbook作成か新規bookへのpaste
- Y02/Y05は通りY03/Y06で落ちる: SaveAsまたは保存fileの検査
- fixture-01だけ通る: clipboard内容依存の可能性
- 両fixtureが同じ境界で落ちる: 内容固有より共通paste/workbook/save経路の可能性

Yの文字数期待値は事前メタデータです。Y本体はsource mirrorを読みません。

## 先生の本番PCでの推奨順

各ケースは一件ごとに開始時刻を控え、外部ログと管理コンソールを照合して
から次へ進みます。Excelが終了した場合、同じケースを自動再試行せず、
runnerを再度開いてX00で新session境界を記録し、計画した次の個別ケースを
選びます。

1. `SHA256SUMS.txt`で配布物を照合する。
2. EDR / DLP管理コンソールの時刻ずれとイベント反映遅延を確認する。
3. runnerだけを開く。標本は手動で開かない。
4. `R0_RecordRunnerBaseline`を実行し、runner単体の開封を記録する。
5. X00、X30を一件ずつ実行する。
6. 既知の通常系A1を一件実行し、今回も通常binary readが動くか確認する。
7. X01〜X04を一件ずつ実行し、事前隔離・欠落・size変化を確認する。
8. X05〜X08、X09〜X12、X13〜X16、X17〜X20の順に、一件ずつ実行する。
9. X21〜X24を一件ずつ実行し、同じ最大4 KiBを`InputB$`で比較する。
10. read-only診断の照合後、X25〜X29を一件ずつ実行する。
11. clipboard診断はE1→Y01、E1→Y02、E1→Y03、
    E2→Y04、E2→Y05、E2→Y06の組で行う。
12. C1/C2/D1/D2を行う場合は、X/Yと分けてTrust Access条件を記録する。

途中でExcelが終了しても、前のsessionの最後のClose済みログ行を保存し、
次の起動後に通常A1を再確認できます。危険側fixtureが欠落していても
通常A1とhash自己検査は独立しています。

## 停止地点から分かること

| 最後の観測 | 主に示す範囲 |
|---|---|
| `TEST_START`なし | macro開始前、runner側の実行許可、またはrunner自体の遮断 |
| `TEST_START`まで、`EXISTS_RESULT`なし | `Dir$`前後またはExcel process終了 |
| `EXISTS_RESULT=MISSING` | 読取り開始前の隔離・削除・配布欠落 |
| `SIZE_RESULT`まで、`OPEN_BINARY_OK`なし | `Open For Binary`での遮断または失敗 |
| `OPEN_BINARY_OK`まで、`OPEN_SIZE_RESULT`なし | open成功後の`LOF`境界 |
| `OPEN_SIZE_RESULT`まで、`READ_1_BYTE_OK`なし | 最初の`Get`での遮断または失敗 |
| 1 byteは通り4 KiBが未到達 | read量または先頭4 KiB内の検査差 |
| 4 KiBは通り`READ_ALL_OK`が未到達 | 後続内容またはread量の差 |
| `READ_ALL_OK`まで、`CLOSE_OK`なし | input Close境界 |
| `CLOSE_OK`まで、`ANALYSIS_OK`なし | file I/O後の純VBA解析処理 |
| `ANALYSIS_OK`でhash不一致 | 標本が事前期待値から変化 |
| `WRITE_*`途中で停止 | 新規outputへの書込み量の境界 |
| `OUTPUT_CLOSE_OK`後、`VERIFY_*`途中で停止 | 再構築物の再open/read検査 |

形態間では次を比較します。

- item-01とitem-02: byte同一なので、`.xlsm`対neutral拡張子・path扱いの差
- item-02とitem-03: Office container全体対抽出済みproject binaryの差
- item-03とitem-04: compiled project binary対source textの差
- X13〜X16とX21〜X24: 同じExcel.exe内・同じbinary openで、
  `Get Byte()`対`InputB$`の差
- X25とX26: 同一source bytesをneutral拡張子対`.xlsm`へ書く差

`Get`だけ失敗し`InputB$`が通る場合はGet/Byte配列経路固有の可能性が
上がります。同じitemが両方で同じopen/read境界までに失敗する場合は、
read primitiveよりfile、内容、Excel processへの検査の可能性が上がります。
これは観測からの切り分けであり、製品内部原因の断定ではありません。

## Excel側結果とEDR / DLPイベントの照合

`RunLog`と外部TSVの`TEST_START`／`CASE_END`時刻を使い、管理コンソールの
alert、block、audit eventを検索します。イベントがあれば、少なくとも
次を試験記録へ転記します。

- case ID、session ID、開始・最後のstage・終了時刻
- event時刻、製品名、alert名、event ID
- 処置（audit、block、quarantine、terminateなど）
- 対象pathと、実行前後の存在・size・hash
- Excel.exeが継続、エラー復帰、強制終了のどれだったか

Excel側の`PASS`は処理が期待境界まで完了したという意味だけです。
EDR / DLPが非検知だった、検知した、許可したという意味ではありません。
ローカルExcelの成功を先生の本番EDR成功として扱いません。

## 後片付け

1. RunLog、`diagnostic-progress.tsv`、EDR / DLP event ID、
   必要なscreenshot、partial outputを先に保全します。
2. runnerは**保存せず**閉じます。
3. `output/`を確認し、不要な生成物は組織の手順で手動削除します。
   runnerのマクロは削除しません。
4. 必要ならclipboardを無害な内容で上書きします。

## 成果物

```text
FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm  最初に開くrunner
runner-vba/                                  runner埋込みVBAの監査用export
  RunnerDiagnostic.bas                      X公開入口
  RunnerDiagnosticCore.bas                  staged log/read/rebuild core
  RunnerHash.bas                            純VBA SHA-256
  RunnerClipboardDiagnostic.bas             Y公開入口とcore
fixtures/
  fixture-01.xlsm                           閉じた通常標本
  fixture-02.xlsm                           閉じた宣言入り標本／X item-01
  source-mirror/
    fixture-01.bas                          通常標本source mirror
    fixture-02.bas                          宣言入りsource mirror
  diagnostic/
    item-02.dat                             item-01のbyte同一neutral copy
    item-03.dat                             抽出済みproject binary
    item-04.bas                             宣言入りsource mirror copy
    EXPECTED-SHA256.txt                     中立IDの期待size/hash
output/                                     append logと新規copy専用、Git対象外
VALIDATION.md                               ローカル検証記録
SHA256SUMS.txt                              配布物のSHA-256
```

runner埋込みVBAの正本は`runner-vba/*.bas`です。埋込み内容との一致、
静的検査、ローカルExcel実測は[`VALIDATION.md`](./VALIDATION.md)に
記録しています。

## 未検証範囲

- 先生の本番EDR / DLP環境での追加X/Yケースの検知・遮断・event照合
- 先生の本番結果で判定不能だったC2と、未報告のC1
- 32-bit Excel
- Trust Access無効時のC1/C2/D1/D2
- 署名済みVBA project
- 組織固有のalert名、event ID、反映遅延
