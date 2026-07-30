# 申請データ検証.xlsm 改修メモ

- 実行日時: 2026-07-30 21:39:27
- 依頼の目的: Win32 API を使わない形へ直す
- 依頼番号: a19914fe-3f78-4492-bb89-e434000b2155
- 作成した改修済みブック: 申請データ検証-Modified-20260730.xlsm
- 元のブック: 申請データ検証.xlsm（変更していません）

## 改修内容

Win32 API（kernel32 の Sleep）への依存をなくしました。
・WaitUtils（新規）: VBA の標準機能だけで待ち時間を作る WaitMilliseconds を追加しました。
・TimerUtils: Sleep の Declare 宣言を削除しました。
・AppController / SystemInfo / TimerUtils / WindowUtils: Sleep の呼び出し（計 19 箇所）を WaitMilliseconds へ置き換えました。
処理の順番と結果は変えていません。待ち時間の作り方だけが変わっています。

## 変更したモジュール

| モジュール | 種類 | 追加 | 削除 |
|---|---|---|---|
| AppController | 標準モジュール | +4 | −6 |
| SystemInfo | 標準モジュール | +6 | −8 |
| TimerUtils | 標準モジュール | +1 | −9 |
| WindowUtils | 標準モジュール | +8 | −10 |
| WaitUtils（新規） | 標準モジュール | +18 | −0 |

## 変更しなかったモジュール

- Sheet1（ドキュメントモジュール）
- Sheet2（ドキュメントモジュール）
- Sheet3（ドキュメントモジュール）
- ThisWorkbook（ドキュメントモジュール）

## このフォルダのファイル

- request.md … AIへ渡した依頼文
- source-code.md … 改修前のコード全文
- 申請データ検証-Modified-20260730.xlsm … 改修済みブック
- 申請データ検証-Diff-Report-20260730.html … 変更内容（全モジュール）
- result.md … このメモ
