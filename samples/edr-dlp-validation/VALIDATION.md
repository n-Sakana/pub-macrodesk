# Validation record

検証日: 2026-07-30（Asia/Tokyo）

対象入口: `FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm`

環境: Windows 64-bit、Microsoft Excel 16.0 build 20228

## 判定の境界

この記録の `PASS` はExcel / VBA側の機能結果だけです。EDR / DLP管理コンソール、alert、block、audit event、event IDはこの作業環境から照合していません。

特に `fixture-02` を扱うケースがローカルExcelで完走したことを、EDR / DLPの「非検知」または「検知成功」として扱いません。先生の本番環境での判定はすべて未検証です。

## ランナー単体の基準試験

ランナーだけを、`fixtures/` が存在しない一時ディレクトリへコピーし、マクロを実行可能なExcel instanceで開きました。

- 開封: 成功
- worksheet: 3
- 開封直後のRunLog: header 1行だけ
- fixture読込み・実行: 0
- document module code: 0行

その後、配布配置のランナーを読み取り専用で開き、R0と12ケースを一件ずつ独立して実行しました。自動実行やrun-all入口は使っていません。

## Excel実機結果

最終通し実行: 2026-07-30 15:24:42〜15:24:44（ローカル時刻）

| ケース | Excel側の実測結果 |
|---|---|
| R0 | `runner_opened=true; fixture_access=false` |
| A1 | fixture-01を11,622 bytes読取り |
| B1 | 11,622 bytesを書込み、全byte一致 |
| C1 | fixture-01のcomponentを80文字読取り |
| D1 | mirror 01の78文字を書込み、保存・再開封後にsource一致 |
| E1 | mirror 01の78文字をclipboardへ配置 |
| F1 | 78文字を新規 `.xlsx` へ取込み、mirror 01と一致 |
| A2 | fixture-02を11,847 bytes読取り（Excel機能結果のみ） |
| B2 | 11,847 bytesを書込み、全byte一致（Excel機能結果のみ） |
| C2 | fixture-02のcomponentを201文字読取り（Excel機能結果のみ） |
| D2 | mirror 02の195文字を書込み、保存・再開封後にsource一致（Excel機能結果のみ） |
| E2 | mirror 02の195文字をclipboardへ配置（Excel機能結果のみ） |
| F2 | 195文字を新規 `.xlsx` へ取込み、mirror 02と一致（Excel機能結果のみ） |

13行すべてでRunLogの開始・終了時刻が秒単位表示され、EDR / DLP管理者記入欄は空欄でした。

最終実行の前後でオンディスクのランナーSHA-256は一致しました。

```text
E3D8E1CB8E72FC5F85B37A22A38ABE0576743C6A7ADF85FD510F31B6907B01F6
```

生成された6ファイルは次のとおりで、すべて `output/` 配下でした。

- B1 / B2: 閉じた標本のbinary copy 2件
- D1 / D2: source mirrorをVBProject経由で書いた `.xlsm` 2件
- F1 / F2: clipboard値を貼り付けた `.xlsx` 2件

検証後、再生成可能な6ファイルは手動削除し、配布ツリーには `output/.gitkeep` だけを残しました。サンプルのマクロは削除処理を実行していません。

## 静的・構造検査

### ランナー

- standard module: 4
- `ThisWorkbook` と3 sheet moduleのcode: 合計0行
- `runner-vba/*.bas` とExcelから再exportした4 module: 全件一致
- sourceと再exportの `Declare` / `PtrSafe` / `kernel32` / `Sleep`: 0件
- ZIP内部の同対象語句: 0件
- `Workbook_Open` / `Auto_Open` / sheet event: 0件
- 公開入口: R0と12ケースの計13件
- external link / connection / ActiveX / drawing: 各0件
- core propertyのcreator / lastModifiedBy、extended propertyのCompany: 空
- ユーザー名、repo絶対パス、組織固有名: 0件

ランナーの埋込みVBAをExcelから再exportし、監査用sourceと一致した後、その再exportにも対象語句がないことを確認しています。これにより、監査用sourceだけでなく実行ブックの埋込み内容も対象コードを持たないことを確認しました。

### 標本

- fixture-01 / fixture-02: 各standard module 1、document module code 0行
- 各source mirrorとExcelから再exportした埋込みmodule: 一致
- fixture-01の対象語句: 0件
- fixture-02のWin32 API宣言: 2行
- fixture-02で対象関数名が宣言行以外に出現: 0件
- 自動実行procedure: 0件
- external link / connection / ActiveX / drawing: 各0件
- identity metadataとrepo絶対パス: 0件

fixture-02は宣言だけを持ち、呼出しprocedureを持ちません。

### Office標準参照

ランナーのVBA projectは次の製品標準参照4件だけでした。

- Visual Basic For Applications
- Microsoft Excel 16.0 Object Library
- OLE Automation
- Microsoft Office 16.0 Object Library

これらの製品共通library path以外に、ユーザー領域やrepoを指す参照はありませんでした。

## 対象標本欠落の隔離試験

ランナー、fixture-01、mirror 01だけを一時配置し、fixture-02とmirror 02が存在しない状態を模擬しました。これはEDR検知試験ではなく、隔離・欠落時の制御継続試験です。

- A2 / B2 / C2 / D2 / E2 / F2: 期待どおり `FAIL`
- 各失敗後のA1 / B1 / C1 / D1: 同じExcel instanceで `PASS`
- F2失敗後にE1を再実行し、E1 / F1: `PASS`
- 全失敗をRunLogへ記録
- 出力は一時配置の `output/` だけ

したがって、対象標本が利用不能でもランナーのオンディスク状態と通常標本ケースは独立しています。製品がExcelプロセス自体を終了する挙動はこの模擬には含まれません。

## 検証方法の注記

自動検証では、各公開入口が呼ぶ同一core functionを一件ずつ `interactive=False` で呼び、確認ダイアログだけを省略しました。binary I/O、VBComponents / CodeModule、保存・再開封、clipboardの操作経路は公開入口と同一です。公開入口はすべて別macroで、run-all macroと自動起動はありません。

C1 / C2 / D1 / D2の検証環境ではTrust Accessが有効でした。他ケースはこの設定を使いません。

## 未検証

- 先生の本番EDR / DLP環境のalert / block / audit event
- 32-bit Excel
- Trust Access無効時のC1 / C2 / D1 / D2
- 署名済みVBA project
- 組織固有のevent名、event ID、反映遅延
