# MacroStudio EDR / DLP validation sample

> **最初に開くファイル**
>
> `FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm`
>
> **手動で開いてはいけない／直接開く必要がない標本**
>
> `fixtures/fixture-01.xlsm` と `fixtures/fixture-02.xlsm`
>
> 標本を手動でダブルクリックしないでください。必要な場合だけ、上記ランナーの明示ケースが対象を読み取り専用で開きます。`fixtures/source-mirror/*.bas` は監査用テキストであり、Excelへ手動インポートする必要はありません。

Excel / VBA の正規操作が EDR / DLP に検知・遮断されるかを、操作経路と標本の種類ごとに切り分けるためのサンプルです。検知を回避するものではありません。

## 分離設計と標本の対応

実行用ランナーと検知対象は物理的に別ファイルです。ランナーは中立名 `fixture-01` / `fixture-02` だけを参照し、次の対応関係をランナーのVBAソースやシートへ埋め込んでいません。

| 中立ID | 閉じた標本 | 監査用source mirror | 内容 |
|---|---|---|---|
| `01` | `fixtures/fixture-01.xlsm` | `fixtures/source-mirror/fixture-01.bas` | Win32 API宣言を含まない通常標本 |
| `02` | `fixtures/fixture-02.xlsm` | `fixtures/source-mirror/fixture-02.bas` | `Sleep` のWin32 API宣言だけを含む標本 |

`fixture-02` はVBA7用の `Private Declare PtrSafe Sub Sleep Lib "kernel32"` と旧VBA用の対応宣言だけを持ちます。呼出しprocedureはなく、`Sleep` は宣言行以外に出現しません。両標本とも自動実行コードを持ちません。

ランナーのオンディスクVBAには、上記宣言本文、`Declare`、`PtrSafe`、`kernel32`、`Sleep` を含みません。標本ファイルを起動時に読み込まず、ケースを一件ずつユーザーが明示実行して初めて選択された外部標本へ触れます。

## 安全境界

- `Workbook_Open`、`Auto_Open`、sheet eventなどの自動実行は、ランナーにも標本にもありません。
- Win32 APIを呼ぶコードはありません。`fixture-02` の宣言は静的標本であり、呼び出されません。
- ネットワーク通信、外部送信、Shell / PowerShell、プロセス起動、外部exe実行、レジストリ操作、永続化、難読化はありません。
- 元標本を上書きしません。ファイル出力は `output/` の新規コピーだけで、既存名を置換しません。
- ファイルを削除するマクロはありません。後片付けは証跡保全後に手動で行います。
- C1 / C2は、選択した閉じた標本をイベント無効・読み取り専用で開き、VBProjectを読んだ後、保存せず閉じます。
- D1 / D2は、選択した外部source mirrorを実行時に初めて読み、新しい `.xlsm` を `output/` に作って標準モジュールを書きます。ランナーや元標本には書きません。
- E1 / E2は、選択した外部source mirrorを実行時に初めて読み、ランナーの `ClipboardBuffer!B2` とclipboardへ置きます。F1 / F2はclipboard値を新しい `output/*.xlsx` へ貼り付けます。
- Eケース実行後はランナーのメモリ上に選択した標本文が残りますが、ランナー自身は自動保存されません。テスト後は必ず保存せず閉じてください。
- 標本が隔離・欠落し、Excelへ制御が戻る場合は、そのケースを `FAIL` として記録しランナーを継続できます。製品がExcelプロセス自体を終了した場合も、オンディスクのランナーには対象コードがないため、再度ランナーだけを開いて未実施ケースから続けられます。

## 必要設定

1. Windows版 Microsoft Excelを使います。
2. このフォルダを配置どおり一式で使い、`output/` へ書き込めることを確認します。
3. 組織ポリシーに従い、既知のローカルファイル `FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm` だけVBA実行を許可します。「すべてのマクロを有効化」は推奨しません。
4. C1、C2、D1、D2だけ、Excelの「VBAプロジェクト オブジェクト モデルへのアクセスを信頼する」が必要です。R0、A、B、E、Fは使いません。

Trust Accessを変更できない環境では無理に変更せず、C1 / C2 / D1 / D2を未実行、または設定起因の `FAIL` として記録してください。設定変更のためにレジストリを操作する手順やコードは含まれません。

## 実施手順

1. `SHA256SUMS.txt` で配布物を照合します。
2. EDR / DLP管理コンソールを開き、時刻ずれとイベント反映遅延を確認します。
3. **ランナーだけ**を開きます。標本は手動で開きません。
4. ランナーを開いたローカル時刻を控え、標本へ触れていない基準イベントとして管理コンソールを確認します。
5. `Alt+F8` から `R0_RecordRunnerBaseline` を実行します。
6. 下表の順に、毎回 `Alt+F8` から一件だけ選びます。確認画面の入力元・出力先・期待結果を読み、実行する場合だけ［OK］を押します。
7. 結果画面と `RunLog` の開始・終了時刻を確認し、同じ時間帯の管理コンソールを照合してから次へ進みます。

通常標本の6経路を先に完了し、その後にAPI宣言標本へ進む推奨順です。EとFは必ず連続実行してください。

| 順 | ケース／`Alt+F8` マクロ | 経路 | 入力 | Excel側の期待結果 | 出力 | Trust Access |
|---:|---|---|---|---|---|---|
| 1 | R0 `R0_RecordRunnerBaseline` | runner基準 | runnerのみ | fixture accessなしを記録 | RunLog（メモリ） | 不要 |
| 2 | A1 `A1_ReadClosedFixture01` | binary読出し | 閉じた01 | byte数を取得 | なし | 不要 |
| 3 | B1 `B1_CopyClosedFixture01` | binary書出し | 閉じた01 | 全byte一致 | 新規 `.xlsm` | 不要 |
| 4 | C1 `C1_ReadProjectFixture01` | VBProject読出し | 閉じた01 | componentを読取 | なし | 必要 |
| 5 | D1 `D1_WriteProjectFixture01` | VBProject書込み | mirror 01 | 保存・再開封後source一致 | 新規 `.xlsm` | 必要 |
| 6 | E1 `E1_CopyFixture01ToClipboard` | clipboard出力 | mirror 01 | 選択sourceをcopy | clipboard | 不要 |
| 7 | F1 `F1_ImportClipboardForFixture01` | clipboard取込 | E1直後のclipboard | mirror 01と一致 | 新規 `.xlsx` | 不要 |
| 8 | A2 `A2_ReadClosedFixture02` | binary読出し | 閉じた02 | byte数取得、または製品による遮断 | なし | 不要 |
| 9 | B2 `B2_CopyClosedFixture02` | binary書出し | 閉じた02 | 全byte一致、または製品による遮断 | 新規 `.xlsm` | 不要 |
| 10 | C2 `C2_ReadProjectFixture02` | VBProject読出し | 閉じた02 | component読取、または製品による遮断 | なし | 必要 |
| 11 | D2 `D2_WriteProjectFixture02` | VBProject書込み | mirror 02 | source一致、または製品による遮断 | 新規 `.xlsm` | 必要 |
| 12 | E2 `E2_CopyFixture02ToClipboard` | clipboard出力 | mirror 02 | 選択sourceをcopy、または製品による遮断 | clipboard | 不要 |
| 13 | F2 `F2_ImportClipboardForFixture02` | clipboard取込 | E2直後のclipboard | mirror 02と一致、または製品による遮断 | 新規 `.xlsx` | 不要 |

E / Fの間に別のcopy操作を挟まないでください。Fケースが失敗するとExcelのcopy状態を解除するため、再試行時は対応するEケースからやり直します。

## RunLogとEDR / DLPの照合

`RunLog` は一件につき一行で、次を記録します。

- 開始・終了のローカル時刻（秒単位）
- ケースID
- Excel側の `PASS` / `FAIL`
- 入力元と出力先
- byte数、文字数、全byte一致、保存・再開封後source一致などの要点
- 管理者が記入する `EDR/DLP event` 欄

`PASS` はExcel / VBA側が期待処理へ到達したことだけを意味します。EDR / DLPが検知しなかった、または検知に成功したという意味ではありません。

各ケースについて管理コンソールの alert / block / audit eventを開始・終了時刻で検索し、表示された場合はイベント時刻、製品名、alert名、event ID、処置（audit / block / terminateなど）を `EDR/DLP event` 欄または別の試験記録へ転記します。製品がExcelを終了してRunLogが残らない場合は、実行直前に控えた時刻、対象ケース、作成途中のoutput有無を使って照合してください。

製品固有のalert名、event ID、反映遅延はこのリポジトリでは未検証です。イベント未照合を成功扱いしないでください。

## 後片付け

1. RunLog、管理コンソールのevent ID、必要なスクリーンショットを組織の手順で保全します。
2. 絶対パスやclipboard内容が証跡・outputに残り得るため、公開・添付前に内容を確認します。実データや秘密をclipboardへ置かないでください。
3. ランナーは**保存せず**閉じます。これによりRunLogと `ClipboardBuffer` の実行時内容は配布時状態へ戻ります。
4. `output/` の生成物を確認し、保管不要なら組織の手順で手動削除します。マクロは削除しません。
5. 必要に応じてclipboardを無害な内容で上書きします。

## 成果物

```text
FIRST-OPEN-MacroStudio-EDR-DLP-Runner.xlsm  最初に開く実行用ブック
runner-vba/                                  ランナー埋込みVBAの監査用export
fixtures/
  fixture-01.xlsm                           閉じた通常標本
  fixture-02.xlsm                           閉じたAPI宣言標本
  source-mirror/
    fixture-01.bas                          通常標本の監査・書込み用source
    fixture-02.bas                          API宣言標本の監査・書込み用source
output/                                     新規出力専用（実行生成物はGit対象外）
VALIDATION.md                               このリポジトリでの検証記録
SHA256SUMS.txt                              配布物のSHA-256
```

ランナー埋込みVBAの正本は `runner-vba/*.bas`、標本の正本は `fixtures/source-mirror/*.bas` です。埋込み内容との一致と静的検査結果は [`VALIDATION.md`](./VALIDATION.md) に記録しています。

## 未検証範囲

- 先生の本番EDR / DLP環境での検知・遮断・管理コンソール照合
- 32-bit Excel
- Trust Access無効時のC1 / C2 / D1 / D2の製品別エラー表示
- 署名済みVBA project
- 組織ごとのalert名、event ID、event反映遅延
