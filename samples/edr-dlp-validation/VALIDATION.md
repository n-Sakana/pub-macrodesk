# Validation record

検証日: 2026-07-30（ローカル時刻）

対象: `MacroStudio-EDR-DLP-Validation.xlsm`

## 結果

Windows 64-bit上の Excel 16.0 build 20228 でブックを生成・保存・再オープンし、A1〜D1の10ケースを実行しました。Excel / VBA 側の期待結果は全件 `PASS` でした。

| ケース | 実測結果 |
|---|---|
| A1 | 257 bytesを読取り |
| A2 | 431 bytesを読取り |
| A3 | 257 bytesを書込み、全byte一致 |
| A4 | 431 bytesを書込み、全byte一致 |
| B1 | 229文字を `CodeModule.Lines` で読取り |
| B2 | 406文字を `CodeModule.Lines` で読取り |
| B3 | 229文字を新規ブックコピーへ追加し、保存・再オープン後にsource一致 |
| B4 | 406文字を新規ブックコピーへ追加し、保存・再オープン後にsource一致 |
| C1 | 固定テキスト104文字をclipboardへ配置 |
| D1 | 同じ104文字を可視セルへ値として取り込み、内容一致 |

最終通し実行のローカル時刻は 2026-07-30 13:39:38〜13:39:39 でした。各ケースは同じExcel instanceで一件ずつ順に実行し、`RunLog` に10行の `PASS` を確認しました。

## 検証方法

- 配布ブックをExcelで再オープンして実行しました。
- 自動試験では、確認ダイアログだけを省略するため、各公開入口が呼ぶ同一のcore functionへ `interactive=False` を渡しました。ファイルI/O、VBProject、clipboardの操作経路は公開入口と同一です。
- B1〜B4の実行環境では、ExcelのVBA project object modelへのprogrammatic accessが許可されていました。
- B3 / B4は `SaveCopyAs` の新規コピーだけを変更し、保存後に閉じて再オープンし、追加componentのsourceを照合しました。
- 通し実行前後の配布 `.xlsm` のSHA-256は一致し、実行ログや貼付内容を配布ブックへ保存していません。

配布ブックの通し実行前後SHA-256:

```text
589CA98F77101A96F6FD08B3BE59CA652906D95FB5CE0B8A930AA6250E9040CF
```

## 構造と公開情報の確認

- workbook内の6 standard moduleと `vba/*.bas` は、`Attribute VB_Name` と行末差を除き全文一致。
- `ThisWorkbook` と3つのsheet document moduleは0行。
- 可視sheetは `Control`、`ClipboardFixture`、`RunLog` の3枚。hidden sheetは0。
- external link source、defined name、shape / ActiveX controlは0。
- 自動実行procedureは0。
- Office core propertyのcreator / lastModifiedByは空、extended propertyのCompanyも空。
- 配布sourceとOffice packageに、ユーザー名、ホームディレクトリ、端末名、組織固有名、秘密、ユーザー／リポジトリ固有の絶対パスを残していません。
- `xl/vbaProject.bin` にはExcelが標準参照として書く Office / VBA / OLE type libraryの製品共通絶対パスがあります。ユーザー領域やこのリポジトリを指すものではなく、標準VBA projectの参照情報です。

## 境界

この記録で `PASS` としたのはExcel / VBA側の機能結果です。EDR / DLPの管理コンソール、alert、event IDはこの作業環境から直接照合していません。したがって、検知なしとは判定していません。実運用では、READMEの手順どおり `RunLog` の時刻をEDR / DLP側で照合してください。

次は未検証です。

- 32-bit Excel
- Trust Access無効時のB1〜B4
- 任意の外部clipboard形式
- 署名済みVBA project
- 組織ごとのEDR / DLP telemetry
