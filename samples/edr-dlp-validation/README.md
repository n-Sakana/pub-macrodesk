# MacroStudio EDR / DLP validation sample

Excel と VBA の正規操作が EDR / DLP に検知・遮断されるかを、操作経路ごとに切り分けるための標本です。検知を回避するものではありません。

`MacroStudio-EDR-DLP-Validation.xlsm` を Excel で開き、`Alt+F8` から一件ずつ明示的にマクロを実行します。実行前の確認画面には、操作、入力元、出力先、期待結果が表示されます。自動実行マクロはありません。

このフォルダを一式で使用してください。A 系のローカル fixture は `vba/FixturePlain.bas` と `vba/FixturePtrSafe.bas` です。

## 安全境界

- `Workbook_Open`、`Auto_Open`、シートイベントなどの自動実行はありません。
- ネットワーク通信、プロセス起動、Shell / PowerShell 呼び出し、外部 exe / DLL の実行、レジストリ操作、永続化、難読化はありません。
- `FixturePtrSafe.bas` には `Sleep` の Win32 API 宣言が静的な標本文字列としてありますが、呼び出すコードはありません。
- 入力 fixture を書込みで開きません。A3 / A4 は `output/` に存在しない名前のコピーだけを作成し、全バイトを再読して照合します。
- B3 / B4 は元ブックを保存せず、`SaveCopyAs` で作った新規 `.xlsm` だけへ新しい標準モジュールを書き、保存・再オープン後にソースを照合します。
- C1 は Excel の可視セルを `Range.Copy` します。D1 は C1 または別の Excel セルからコピーされたテキストを `xlPasteValues` で可視セルへ取り込みます。任意の外部クリップボード形式は対象外で、対応できない場合は失敗として表示します。
- このブックは自分自身を自動保存しません。実行ログとD1の貼付内容はメモリ上のブックに残るため、閉じるときに保存しなければ配布時の状態へ戻ります。
- 実行中に作ったファイルを削除するマクロはありません。

重要: `FixturePtrSafe` は最初からブック内に含まれます。したがって、ブックを開いた時点で静的宣言を読み込むこと自体が EDR の観測対象になる可能性があります。各ケースの実行前に「ブックを開いただけ」の基準時刻を取り、個別操作の時刻と分けてください。

## 必要設定

1. Windows 版 Microsoft Excel で開きます。
2. 組織のポリシーに従って、この既知のローカル標本の VBA マクロ実行を許可します。「すべてのマクロを有効化」は推奨しません。
3. B1〜B4 を実行するときだけ、Excel の「VBA プロジェクト オブジェクト モデルへのアクセスを信頼する」が必要です。A1〜A4、C1、D1 はこの設定を使いません。

Trust Access は既定で拒否される開発者向け設定です。Microsoft の説明と設定場所は、[Excel のマクロ セキュリティ設定](https://support.microsoft.com/en-us/office/change-macro-security-settings-in-excel-a97c09d2-c082-46b8-b19f-e8621e8fe373)を参照してください。B3 / B4 が使う `CodeModule.AddFromString` の仕様は、[Microsoft Learn](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/addfromstring-method-vba-add-in-object-model)にあります。

設定を変更できない環境では変更せず、B1〜B4を未実行または失敗として記録してください。設定変更のためにレジストリを操作する手順は、この標本にはありません。

## 一件ずつ実行する

1. ブックを開いた時刻を控え、EDR / DLP 側で開封だけのイベントを確認します。
2. `Alt+F8` を押します。
3. 下表のマクロを一つだけ選び、［実行］を押します。
4. 確認画面の入力元・出力先・期待結果を読み、実行する場合だけ［OK］を押します。
5. 結果画面と `RunLog` シートを確認します。
6. `RunLog` の開始・終了時刻と同じ時間帯を EDR / DLP 管理画面で照合してから、次の一件へ進みます。

| ケース | `Alt+F8` で選ぶマクロ | 操作 | 期待結果 | 書込み | Trust Access |
|---|---|---|---|---|---|
| A1 | `A1_ReadBinary_Plain` | plain fixture を `Open For Binary` で読む | byte数と内容 previewを表示 | なし | 不要 |
| A2 | `A2_ReadBinary_PtrSafeText` | 静的 `PtrSafe Sleep` 宣言を含む fixture を読む | byte数と内容 previewを表示 | なし | 不要 |
| A3 | `A3_WriteBinaryCopy_Plain` | plain fixture を新規コピーへ書く | 全byte一致 | 新規 `.bas` | 不要 |
| A4 | `A4_WriteBinaryCopy_PtrSafeText` | 静的宣言fixtureを新規コピーへ書く | 全byte一致 | 新規 `.bas` | 不要 |
| B1 | `B1_VBProject_Read_Plain` | `FixturePlain` を `VBComponents` / `CodeModule` で読む | sourceと文字数を表示 | なし | 必要 |
| B2 | `B2_VBProject_Read_PtrSafeText` | `FixturePtrSafe` を同じ経路で読む | sourceと文字数を表示 | なし | 必要 |
| B3 | `B3_VBProject_WriteCopy_Plain` | 新規ブックコピーへplain componentを追加 | 再オープン後もsource一致 | 新規 `.xlsm` | 必要 |
| B4 | `B4_VBProject_WriteCopy_PtrSafeText` | 新規ブックコピーへ静的宣言componentを追加 | 再オープン後もsource一致 | 新規 `.xlsm` | 必要 |
| C1 | `C1_CopyFixedText_ToClipboard` | 固定の無害な依頼文相当テキストをコピー | 104文字をclipboardへ配置 | clipboard | 不要 |
| D1 | `D1_ReadClipboardText_Explicit` | Excelセル由来のclipboard textを明示取込 | 内容、文字数、成否を表示 | 可視セル | 不要 |

C1 の固定テキストは次のとおりです。

> Review this harmless validation sample and summarize its visible inputs, outputs, and safety boundaries.

## ログと EDR / DLP の照合

`RunLog` シートには次が一行ずつ入ります。

- 開始・終了のローカル時刻
- ケースIDと `PASS` / `FAIL`
- 入力元と出力先
- byte数、文字数、全byte一致、再オープン後source一致などの要点

`PASS` は Excel / VBA 側で期待結果まで到達したことだけを意味します。「EDR / DLP が検知しなかった」という意味ではありません。管理コンソールの alert、block、audit event は同じ時刻で別途照合してください。製品側がプロセスを終了・遮断した場合、VBAへ制御が戻らず `RunLog` が残らないこともあります。

実行時の絶対パスやD1で取り込んだ内容は、ローカルのシートやB3 / B4のブックコピーに残り得ます。実データや秘密をclipboardへ置かず、ログや出力コピーを公開・添付する前に必ず確認してください。

## 成果物

```text
MacroStudio-EDR-DLP-Validation.xlsm  手動実行するブック
vba/                                  監査・再生成用のVBA export
  ValidationCommon.bas
  ValidationFileIO.bas
  ValidationVBProject.bas
  ValidationClipboard.bas
  FixturePlain.bas
  FixturePtrSafe.bas
output/                               A3/A4/B3/B4の新規出力先
VALIDATION.md                         このリポジトリでの実機確認結果
SHA256SUMS.txt                        配布ブックとVBA exportのSHA-256
```

`output/` の実行生成物は Git の対象外です。`.gitkeep` だけを配布物に含めています。

## VBA ソースから再生成する

外部生成ツールを配布物へ持ち込まないため、生成スクリプトは同梱していません。VBA export がコードの正本です。

1. 新しいマクロ有効ブックを作り、`Control`、`ClipboardFixture`、`RunLog` の3シートを用意します。
2. VBE の［ファイル］→［ファイルのインポート］で `vba/*.bas` の6ファイルを取り込みます。
3. `ThisWorkbook` と各sheet moduleにはコードを追加しません。
4. ブックをこのREADME、`vba/`、`output/` と同じ配置へ `.xlsm` で保存します。
5. Controlシートに上表を置きます。ボタンは必須ではなく、`Alt+F8` の明示マクロだけで全ケースを実行できます。
6. `FixturePtrSafe` を読んで、`Sleep` を呼ぶprocedureが存在しないことを確認します。

再生成や監査では、Office文書プロパティ、VBA source、シート、外部リンクを確認し、ユーザー名、端末名、組織名、ユーザー／リポジトリ固有の絶対パス、秘密を残さないでください。ExcelがVBA projectの標準参照として記録するOffice / VBA / OLE library pathは、製品共通の参照情報として別に確認します。

## 未検証範囲

- 32-bit Excel
- Trust Accessを無効にした状態でのB1〜B4の実機失敗表示
- Excelセル以外の任意clipboard形式
- 署名済みVBA project
- 各組織のEDR / DLP管理コンソールでのalert名・event ID・反映遅延

このリポジトリで確認した範囲は [`VALIDATION.md`](./VALIDATION.md) に記録しています。
