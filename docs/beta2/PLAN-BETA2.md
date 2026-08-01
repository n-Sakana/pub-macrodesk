# β2.00 実装計画

- 正本: [SPEC-BETA2.md](SPEC-BETA2.md)。実装中に仕様の疑義が出たら SPEC を読み、
  それでも一意でなければ Room Chat で opus-architect に判断を求める。**自分で仕様を決めない。**
- 判断の記録: [DECISIONS-BETA2.md](DECISIONS-BETA2.md)。ここに答えがある論点を蒸し返さない。

---

## 0. 作業規律

| 項目 | 規則 |
|---|---|
| 書込範囲 | `C:\repos\pub\macrostudio` 配下のみ。`C:\repos\pub` の他 repo は**読み取り専用** |
| 変更禁止 | `public-release/**`（[DECISIONS-BETA2.md](DECISIONS-BETA2.md) D-08）、`docs/releases/**`、`docs/manual-*/**` |
| git | commit / push / tag / branch / Release / PR / force 操作を**一切行わない**。β2.00 は main の作業ツリーに置いたままにする |
| 委任 | Task / Agent 等で Room 外へ委任しない |
| 報告 | 各 WP の完了時に Room Chat へ「触ったファイル・追加/更新したテスト・実行結果（本数と時間）・残課題」を事実で投げる |
| gate の失効 | **完了報告のあとに製品コードを触ったら、先の gate 数字は失効する**（§0.2） |
| 判断待ち | 仕様が一意に決まらないときだけ止まる。それ以外は止まらない |

### 0.2 gate 数字はいつの時点のものかを曖昧にしない

WP-01 で実際に起きたこと: 完了報告（Node 24/24・PS 13/13・flow 3/3）のあと、
レビュー指摘を受けて `src/04_HostServices.cs` と `test-hostservices.ps1` を変更した。
**その時点で報告済みの数字は現在のコードを保証しなくなった。**

規律:

- **レビュー修正を当てたら、その WP の gate 数字は失効したと自分で宣言する。**
  併せて「その場で回し直す」のか「次の gate で再確立する」のかを述べる。
- **隔離のための stash / commit はしない。** commit 禁止の作業ツリーでは
  切り出しの失敗による作業消失のほうが危険が大きい。
  次の WP の gate で、前の WP の分もまとめて再確立する。
- **初回の数字を消して上書きしない。** 最終履歴には
  「初回 green は修正前の測定、再確立は WP-0n 完了時」と両方を残す。
  緑の数字が「いつの時点のものか」が後から分からなくなる書き方をしない。

### 0.1 テストを緩めない（要件 G）

- 期待値の緩和・アサーションの削除・`skip` の追加で緑にしない。
- テスト用の AI 応答 fixture は、**製品の `diagnosis-package.js` / `response-package.js` を
  実際に通す**。テスト側に第 2 のパーサや簡易検証を書かない。
- 契約検査（SPEC §4.5 **D01〜D28**、§5.4 R1〜R3、§7.6 **M01〜M04**、
  §3.5.1 **`ENV-*` 10 種**）は、
  **通る fixture と落ちる fixture の両方**を各検査に 1 件ずつ持ち、
  落ちる側は**返ってきた `validationId` が期待した ID と一致すること**まで検査する（§4.1-2）。
  「同じエラーコードで落ちた」だけでは足りない。**どの条件で落ちたか**まで固定する。
- 実 WebView2 のクリップボード操作だけは有界再試行を許す（SPEC §8.5）。
  再試行を尽くした失敗は**試験失敗**とする。再試行回数はログへ出す。

---

## 1. 基準線（β1.10・codex-implementer 実測 2026-08-01）

| 群 | 結果 | 時間 |
|---|---|---|
| Node 24 本 | **24/24 PASS** | 1.06 秒 |
| PowerShell ヘッドレス 12 本（WebView / Excel 実機を除く） | **12/12 PASS** | 20.76 秒 |
| 実 WebView2 6 本 | **5/6 PASS** | — |

実 WebView2 の唯一の失敗は `test-flow-webview.ps1` が 3 回連続。
原因は製品アサーション到達前の `Clipboard.SetText/GetText` が `0x800401D0`
（`CLIPBRD_E_CANT_OPEN`）を返したこと。試験後の `GetOpenClipboardWindow` は 0 で、
恒常的な占有者はいない。**製品の欠陥ではなく一時競合**と判定し、
WP-01 でクリップボードの有界再試行を入れて解消する（SPEC §8.5）。

**この 3 群が β2 の回帰基準である。** 各 WP の完了時に該当群を回し、
基準を下回ったら次の WP へ進まない。

---

## 2. 作業単位（WP）と依存

```
WP-01 契約の締め直し + クリップボード耐性        （独立・最初）
   ↓
WP-02 環境定義の実データ化
   ↓
┌─ 原子グループ A ─────────────────────────┐
│ WP-04 ひな形の 2 階層化と新セクション（先）  │
│ WP-03 診断契約（後。WP-02 と WP-04 に依存）  │
└──────────────────────────────────────────┘
   ↓
┌─ 原子グループ B ─────────────────────────┐
│ WP-05 画面骨格（screens.js / state.js）      │
│ WP-06 画面 0/1/2                             │
│ WP-07 画面 3/4                               │
│ WP-08 画面 5/6/7                             │
└──────────────────────────────────────────┘
   ↓
WP-09 決定的置換エンジン
   ↓
WP-10 実 WebView2 テスト
   ↓
WP-11 ドキュメント統合
```

### 2.1 原子グループの規律（緑を保てる単位）

「各 WP 完了時に Node + PowerShell 全 green」は、**単独では成立しない WP がある**。

- **WP-03 は WP-04 に依存する。** 診断ひな形は新しい見出し
  （`## 出力指示（分割）`）を持ち、prompt fixture もそれを通る。
  その見出しを解釈する `preset-document.js` の変更は WP-04 にある。
  **したがってグループ A の中では WP-04 を先に完了させる。**
- **WP-05 は単独では画面を壊す。** 旧ビルダーを外した時点で、
  作り直しが終わる WP-08 まで実画面が存在しない。
  この間に全 green を要求すると、テストを緩めるしかなくなる。

したがって:

| 単位 | 全 green を要求する時点 |
|---|---|
| WP-01 / WP-02 / WP-09 / WP-10 / WP-11 | **その WP の完了時** |
| 原子グループ A（WP-04 → WP-03） | **グループの完了時**（途中で完了報告はするが、gate はグループ単位） |
| 原子グループ B（WP-05 → 06 → 07 → 08） | **グループの完了時** |

- グループの内側では、**その時点で意味のあるテストだけを回して報告する**
  （例: グループ B の途中では `test-flow-state.js` と Node の非画面系）。
  「全 green です」とは言わない。**何を回して何を回していないかを毎回明記する。**
- グループを完了せずに次のグループへ進まない。
- グループの途中で作業を止める必要が出たら、Room Chat へ「グループ B の
  WP-06 まで完了・グループ未完・全 green 未達」と事実で報告する。
  **未完のグループを完了扱いにしない。**

---

### WP-01 契約の締め直しとクリップボード耐性

**目的**: 2 本目の機械契約（診断）を足す前に、1 本目の穴を塞ぐ。

| # | 変更 | 出典 |
|---|---|---|
| 1 | `response-package.js`: `COMPLETE <n>` を**正準 10 進表記＋文字列一致**で判定（SPEC §4.5.1）。`1.0` / `01` / `0x2` / `1e0` を拒否。`PART` は既存挙動のまま | AUDIT §1.4.1 A1 / SPEC §5.4 R1 |
| 2 | 新規モジュールの種別制限を `app.js` `applyWholePackage` から `response-package.js` へ移す | AUDIT §1.4.1 A2 / SPEC §5.4 R2 |
| 3 | 依頼 ID の生成を `createRequestIdentity() -> {id, secure}` にする | AUDIT §1.4.1 A3 |
| 4 | `04_HostServices.cs`: `Clipboard.SetText` / `GetText` を**最大 10 回呼び出す**（待ちは 9 回・各 50ms・合計 450ms）。**再試行するのは `0x800401D0`（`CLIPBRD_E_CANT_OPEN`）だけ**で、他の例外は 1 回目で即失敗。最終失敗は `E-GEN-03` / 新設 `E-GEN-04`。**例外を空文字へ潰さない**。再試行の中身は delegate で差し替えられる内部ヘルパーにする | SPEC §8.5 |
| 5 | コピー失敗トーストに［もう一度コピー］、取り込み失敗トーストに「`Ctrl+V` でも貼り付けられます」を添える | SPEC §8.5-3 |

**R2 の API 形（これを決めずに移せない）**

「新規か既存か」はブックのモジュール一覧が無いと判定できないので、
純粋な解析関数のままでは移せない。**文脈を受け取る 1 本の契約関数**にする。

```
describe(parsedPackage, existingModules) -> 
  { ok: true,  modules: [...], warnings: [...] }
  { ok: false, validationId: "R2", reason: "..." }
```

- 既存モジュール（case-insensitive 一致）: **ブック側の種別が正本**。
  返答の種別が食い違えば**ブックの種別へ補正し、`warnings` に何を読み替えたかを積む**
  （β1.10 §6.5 の既存挙動を変えない）。
- 存在しないモジュール: `standard` だけ受理。`class` / `form` / `document` は
  `ok:false` / `validationId:"R2"`。
- **`NEEDDECISION` も同じ文脈で検証する**（`MODULE` のブック実在、
  `FINDING` の診断実在。SPEC §5.4.1）。文脈を渡す入口を 2 つ作らない。
- `app.js` は結果を受け取るだけになり、種別の判断を持たない。

**R3 の請求元**: `createRequestIdentity()` は `{id, secure}` を返すだけで、
**自分ではログを書かない**（純粋な関数のままにする）。
`secure:false` を見た `app.js` が best-effort で `writeLog` する。
ログの書き込みに失敗しても**依頼の生成は止めない**。
テストは crypto 無しの文脈で `secure:false` が返ること、UUID の形であること、
WARN が 1 回だけ出ることを検査する。

**触るファイル**: `assets/js/response-package.js` / `assets/js/app.js` /
`src/04_HostServices.cs`。`E-GEN-04` の利用者向け文面は `app.js` を正本とし、
host から重複注入しない。

**テスト**
- 更新: `tests/test-module-split.js`（`COMPLETE 1.0` / `01` が**落ちる**ことを追加）
- 更新: `tests/test-no-change.js`（`COMPLETE 0` の厳密比較）
- 更新: `tests/test-response-package.js`（**新規作成しない**。この既存テストが
  `vm` で `assets/js/response-package.js` を読み `window.MacroStudioResponse` を
  叩く house style を持っているので、R1 / R2 の通る・落ちる fixture をここへ足す。
  `diagnosis-package.js` も同じ IIFE-on-`window` 形にして、同じ読み込み方ができるようにする）
- 新規: `tests/test-clipboard-retry.ps1`
  - **主経路は decision-deterministic**: 操作を delegate で受ける内部ヘルパーへ、
    「n 回 `0x800401D0` を投げてから成功する」「常に `0x800401D0`」
    「1 回目に別の HRESULT」を注入し、**呼び出し回数と待ち回数**を検査する
    （成功パターン / 10 回で尽きて `E-GEN-03` / `E-GEN-04` /
    別例外は 1 回で即失敗）。**別スレッド占有の再現に依存しない**
  - 補助として実クリップボードでの往復を 1 件だけ持ち、
    **`finally` で元の内容を復元する**（試験が利用者のクリップボードを奪わない）
- 更新: `tests/test-hostservices.ps1`（`readClipboard` が例外を空文字へ潰さない）

**完了条件**: Node 全本 + PowerShell ヘッドレス全本 green。
`test-flow-webview.ps1` を 3 回連続で回して 3/3 PASS。

**「連続」の定義（[DECISIONS-BETA2.md](DECISIONS-BETA2.md) D-14 で再定義）**:
**前のプロセスが完全に終了してから、次を fresh process として起動する**こと。
プロセスの終了処理と次の起動が重なった状態は製品が想定していない条件であり、
そこでの失敗を製品の欠陥として数えない。**数えないだけで、記録からは消さない。**

**着手順**: 上限を動かす前に、まず**占有者を測る**（SPEC §8.5-1）。
再試行の各回で `GetOpenClipboardWindow()` → プロセス名 / PID を取り、最終失敗で WARN。

- 掴んでいたのが**直前の試験プロセス**なら → `test-flow-webview.ps1` 側で
  完全終了を待つ（**ハーネスの正しさの修正**であって試験の緩和ではない）。
- 掴んでいたのが**無関係な常駐アプリ**なら → 環境の事実。製品は回復導線へ落ちており正しい。
  D-14 のとおり上限は変えない。

いずれの場合も **`04_HostServices.cs` の再試行上限（10 回 / 450ms）は変更しない。**

---

### WP-02 想定動作環境の実データ化

**目的**: 環境の前提を、ひな形の散文からアプリが実際に読むファイルへ移す。

**新規ファイル**
- `environment/target-environment.json` — SPEC §3.2 のスキーマ。初期内容は
  AUDIT §2.1 / §2.2 の 3 出典から抽出。`basis` は全件 `declared` か `inferred`
  （[DECISIONS-BETA2.md](DECISIONS-BETA2.md) D-03）
- `environment/SOURCES.md` — 出典・軸の意味・`basis` の使い分け・改訂手順・改訂履歴
- `assets/js/target-environment.js` — 検証（SPEC §3.5）と `renderForPrompt()`（§3.6）。
  **唯一の実装**。第 2 実装を作らない

**変更**
- `src/04_HostServices.cs`: `getTargetEnvironment` action を追加（strict UTF-8 で読むだけ。
  **中身を解釈しない**）
- `src/03_MessageRouter.cs`: dispatch へ追加
- `assets/js/app.js`: `E-ENV-01` のカード表示（トーストにしない。診断へ進めない）

**制約に必ず入れる項目**（AUDIT §2.1 / §2.2 から抽出。過不足は SOURCES.md で説明する）

| axis | 例 |
|---|---|
| `execution` | Win32 API `Declare` 不可 / `Shell`・`WScript.Shell`・`cmd`・PowerShell・VBScript・`mshta` 起動不可 / WMI 経由の起動不可 |
| `storage` | ブックが SharePoint・OneDrive 上に置かれ `ThisWorkbook.Path` が `https://` を返す / 固定ドライブ文字 / UNC / ユーザーフォルダ / Desktop・Documents / AppData / Program Files / `Dir()` の存在確認 / `CurDir` / `ChDir` |
| `host` | 固定プリンタ名 / 固定 IP / 固定接続ホスト / 接続文字列 |
| `components` | DAO / DDE / IE 自動操作 / 旧式コントロール / `SendKeys` / `AppActivate` / `VarPtr`・`ObjPtr`・`StrPtr` / ハンドルを `Long` で受ける 32 ビット前提 |
| `office` | Excel COM の可用性（`datadesk/envtest/05-office.ps1` の軸） |
| `platform` | Windows 10/11 / PowerShell 5.1 / .NET Framework |

**テスト**
- 新規 `tests/test-target-environment.js`
  - 正常な JSON を読める
  - SPEC §3.5 の**各 fail-fast 条件ごとに 1 件ずつ**落ちる fixture
    （欠落 / 不正 UTF-8 / 不正 JSON / `schemaVersion:2` / 必須欠落 / 列挙外 /
    `key` 重複 / `key` 命名違反 / 未知 `sourceId` / `constraints` 0 件）
  - `renderForPrompt()` の出力を**バイト単位で固定**（並び順が axis 定義順 → key 昇順、
    `examples` 無しの項目で「例:」行が出ない）
  - 同梱の `environment/target-environment.json` **実ファイル**が検証を通ること
- 更新 `tests/test-hostservices.ps1`（`getTargetEnvironment` が strict UTF-8 で読み、
  BOM 付き / 不正バイト列で失敗すること）

**完了条件**: 上記 green。`environment/target-environment.json` の全 `key` が
`/^[A-Z][A-Z0-9_]{2,39}$/` を満たし一意であること（テストが検査）。

---

### WP-03 診断契約

**新規**
- `assets/js/diagnosis-package.js` — SPEC §4.4〜4.7 の唯一の実装。
  解析・検証・0 件・分割の受理と統合。`app.js` は結果を受け取るだけ
- `templates/diagnose-template.txt` — `{{TARGET_ENVIRONMENT}}` を必須変数に持つ
- `presets/01_診断/01_動作環境の事実監査.md` — `# 名前` / `## 説明` /
  `## 改修指示` / `## 出力指示` / `## 出力指示（分割）`。
  **`presets/04` の「見つけかたと報告のしかた」を出自として書き直す**。
  環境の前提は書かない（それは `{{TARGET_ENVIRONMENT}}` が運ぶ）

**変更**
- `assets/js/prompt-template.js`: `{{TARGET_ENVIRONMENT}}` / `{{DIAGNOSIS}}` /
  `{{SELECTED_FINDINGS}}` を既知変数へ追加。未知変数の E-GEN-02 は維持
- `src/04_HostServices.cs`: `readRequestTemplate` に `{name}` パラメータ
  （`[a-z-]+` に限定・パス区切り禁止・containment 検査）

**テスト**
- 新規 `tests/test-diagnosis-package.js`
  - **D01〜D28 の各検査に、通る fixture と落ちる fixture を 1 件ずつ**
    （落ちる側は `validationId` の一致まで検査する）
  - `CLASS`×`CONFIDENCE` の整合（D11）と `BLOCKER`→`ENVKEY` 必須（D12）
  - `MODULE` / `ENVKEY` の実在照合（D13/D14）— 実在しない値で落ちること
  - 0 件（`SCOPE_CLEAR` / `INSUFFICIENT`）の受理と、無言 0 件の拒否（D20）
  - `LINES` の書式（`12` / `12,13` / `12-20` / 逆順範囲は拒否）
  - `DIAG COMPLETE 1.0` / `01` が落ちること（WP-01 と同じ厳密さ）
- 新規 `tests/test-diagnosis-split.js`
  - `PART` の受理・欠番検出・`<合計>` 不一致の拒否・同番号異内容の拒否
  - 同番号同内容の再送が冪等
  - part 01 以降に `SECTION` があれば拒否
  - **統合後にもう一度 §4.5 の全検査を通ること**
  - 統合結果が「一度で受け取った場合」と**同一の内部形式**になること（要件 A）
- 更新 `tests/test-prompt-template.js`
  - 診断テンプレートの生成結果を**バイト単位で固定**
  - `{{TARGET_ENVIRONMENT}}` 不在で E-GEN-02

**完了条件**: 上記 green ＋ Node/PowerShell 基準線維持。

---

### WP-04 ひな形の 2 階層化と新セクション

**移動・新規**
```
presets/01_診断/01_動作環境の事実監査.md            （WP-03 で作成済み）
presets/02_改修/01_VBAリファクター（…）.md          （01 から移動）
presets/02_改修/02_Win32 API を使わない形へ直す.md   （02 から移動）
presets/02_改修/03_固定パスを新環境へ置き換える.md   （新規。## エンジン: 固定パス置換）
presets/02_改修/04_自分で改修内容を書く.md           （03 から移動・改題）
```
`presets/04` / `05` / `06` は削除する。価値の移設先は SPEC §9.3 の表のとおり。

**変更**
- `assets/js/preset-document.js`
  - `## エンジン`（`AI` / `固定パス置換`）
  - `## 希望動作の候補`（`- 文` の箇条書き）
  - `## 出力指示（分割）` を**診断ひな形専用**として新設。
    **改修側の `## 出力指示（モジュール単位）` は β1.10 のまま存続させる**（改称しない）。
    2 つは別プロパティ（`splitDiagnosisOutput` / `splitOutput`）として持ち、
    **段階に合わない側が現れたら E-PRESET-01**（SPEC §9.2）
  - `## 用途` を**廃止**。存在したら E-PRESET-01（「使わなくなりました」を message に）
  - `## エンジン: 固定パス置換` のときだけ `## 改修指示` / `## 出力指示` を任意にする
- `src/04_HostServices.cs`: `getAppInfo` の `presets` を `{diagnose:[], repair:[]}` へ。
  列挙は現在 `Directory.GetFiles(presetRoot, "*.md", SearchOption.TopDirectoryOnly)` で
  平坦なので、2 つのサブフォルダを個別に列挙する形へ替える。
  **`readPreset` は変更しない**（既存の containment がサブパスを既に正しく扱う。
  opus-architect 実読で確認済み。SPEC §8.2）
- `assets/js/app.js`: `E-PRESET-02`（診断ひな形が 1 つでない）

**テスト**
- 更新 `tests/test-preset-document.js`: 新セクション（`## エンジン` /
  `## 希望動作の候補` / `## 維持すること` / `## 出力指示（分割）`）の解析、
  `## 用途` の拒否、**段階に合わない分割見出しの拒否**（診断側の
  `## 出力指示（モジュール単位）` と改修側の `## 出力指示（分割）` が各々 E-PRESET-01）、
  `固定パス置換` ひな形の必須項目差分
- 更新 `tests/test-preset-migration.js`: **同梱ひな形の実ファイルがすべて解析を通ること**、
  診断フォルダに有効ファイルがちょうど 1 つあること、
  改修フォルダの各ファイルが期待する `## エンジン` を持つこと
- 新規 `tests/test-preset-value-migration.js`: SPEC §9.3 の移設が**実際に効いている**こと
  — 画面 1 の「ほかに気になっていること」に書いた文が `diagnose-request.md` へ載り、
  画面 4 の「追加の要望」が `repair-request.md` へ載る（状態レベルで検査）
  - **このテストは原子グループ B へ繰り延べる。** 検査対象である画面 1 / 画面 4 の
    state API が WP-05 / WP-06 まで存在せず、グループ A の時点では書けないため
    （codex-implementer が実装中に指摘、opus-architect 承認）。
  - **繰り延べであって取り下げではない。** グループ B の完了 gate は、
    このテストが存在して green であることを含む。
    §9.3 の移設が口約束で終わっていないことを固定する唯一のテストなので、
    落とすなら「β1.10 の相談機能の価値を吸収した」という主張自体が根拠を失う。
- 更新 `tests/test-hostservices.ps1`: `getAppInfo` の 2 群、`readPreset` のサブフォルダと
  containment（`..` や `presets` 外を弾く）

---

### WP-05 画面骨格

**変更**
- `assets/js/screens.js`: SPEC §2.2 の 11 画面表へ差し替え。進捗は常に 4 手順。
  分岐は §2.3 の 2 か所だけ。`isDiagnose` / `isSimple` / `isChatOnly` /
  `DIAGNOSE_MAJORS` / `SIMPLE_MAJORS` / `MODE_SCREEN` を削除
- `assets/js/state.js`: 2 段階の依頼 ID と帰属（SPEC §2.6）。
  `state.mode` / `state.simple` を削除。`state.diagnosis` / `state.selectedFindings` /
  `state.desiredBehaviour` / `state.pathMap` を新設。`startSimple` / `setMode` を削除

**画面番号の残存リテラルに注意（opus-architect 実読で確認した実在の罠）**

`state.js:241` と `state.js:537` に `state.screen = api ? api.bookScreen : 1;` がある。
この `1` は β1.10 で `bookScreen === 1` だったときの fallback リテラルで、
**β2 では `bookScreen === 0` になるため誤りになる**。
`screens.js` の読み込みに失敗した状態でしか発火しないが、
`DEVELOPMENT.md` §3 が自ら禁じている「画面番号を JS の中へ literal で書く」の実例である。

- この 2 か所を含め、`state.js` / `app.js` の画面番号リテラルを**全数洗い出して潰す**。
- fallback が必要な箇所は数値ではなく `0`（＝最初の画面）に統一するか、
  `screenApi()` が無いときは操作自体を行わない形にする。
- 履歴スタック自体は `push(state.screen)` / `pop()` の添字方式で
  画面の意味に依存しないため、**構造としては壊れない**。危険なのは残存リテラルだけである。
- `assets/js/app.js`: 削除した画面のビルダーを外す（中身は WP-06〜08 で作り直す）

**テスト**
- 更新 `tests/test-flow-state.js`: 新しい 11 画面の遷移グラフ、
  ［戻る］の逆走、画面 9 で戻れないこと、2 段階の依頼 ID の帰属
  （新しい診断 ID で診断以降が全部落ちる／新しい改修 ID で改修だけ落ちる）
- 更新 `tests/test-p6-state.js` / `tests/test-p7-state.js`: 画面番号の付け替え
- 削除ではなく**作り替え** `tests/test-simple-mode.js` →
  `tests/test-shortest-path.js`（[DECISIONS-BETA2.md](DECISIONS-BETA2.md) D-09 を試験で固定）
  - **正しい診断パッケージの取り込みを必ず通る**こと。
    「診断を読まない」は**画面上で指摘の第二層を開かない**という意味であって、
    診断段階を飛ばすという意味ではない
  - その状態から画面 3 でひな形を選び、希望動作を 1 行書いてビルドまで到達できること
  - **診断を飛ばす入口が存在しないこと**を assert する
    （画面 0 から画面 3 以降へ直接遷移できない。`nextIndex` が診断を経ない経路を返さない）

---

### WP-06 画面 0 / 1 / 2

| 画面 | 実装内容 |
|---|---|
| 0 `book` | β1.10 画面 1+2 の統合。ドロップゾーン、添付カード、「読み取った内容を見る」の折りたたみ、`read.level` の 2 段階の伝え分け（**β1.10 §5.1.2 をそのまま維持**） |
| 1 `diagnoseRequest` | 環境定義の読み込みと `E-ENV-01`、診断 ID 発行、実行フォルダ作成、`source-code.md` + `diagnose-request.md` 生成、コピー／フォルダを開く、任意欄「ほかに気になっていること」、分割受理のチェック |
| 2 `diagnoseIntake` | 貼り付け受理、`diagnosis-package.js` 検証、`E-DIAG-01`、分割の受け取り状況（何番が足りないか）、受理後に `diagnosis.md` 書き出し |

**変更**: `src/04_HostServices.cs` の `writeRequestFiles` に `stage`、
新 action `writeDiagnosisFile`。

**テスト**
- 新規 `tests/test-diagnose-flow.js`: 画面 1→2 の状態遷移、`E-ENV-01` で進めないこと、
  分割の受け取り状況表示のデータ、`diagnosis.md` に渡す整形テキスト
- 更新 `tests/test-read-report.js`: 画面統合後も `read.level` の 2 段階が変わらないこと
- 更新 `tests/test-attach-blocked.js`: 暗号化ブックが画面 0 のカードで止まること
- 更新 `tests/test-hostservices.ps1`: `stage` 別の書き出し、`writeDiagnosisFile`

---

### WP-07 画面 3 / 4（AI 経路）

| 画面 | 実装内容 |
|---|---|
| 3 `findings` | 結論帯（件数チップ＋想定環境チップ）、概要 4 行、指摘一覧（分類順・第二層に証拠）、`INFO` は畳む、ひな形カード |
| 4 `repairInput` | 質問（あれば）、指摘の選択＋行内の希望動作入力＋候補チップ、追加の要望、維持すること |

**新規 CSS**: `assets/css/findings.css`（分類チップ・確度チップ・第二層のレール・
一覧の内部スクロール）。色は `variables.css` の既存トークンだけを使い、
**新しい hex を他 CSS へ直書きしない**（`test-design-system.ps1` の門番が効く）。

**テスト**
- 新規 `tests/test-findings-view.js`: 分類の並び順が §4.4.3 で固定、
  `INFO` の既定畳み、第二層に出す項目、0 件のときの表示
- 新規 `tests/test-repair-input.js`: 選択と希望動作の状態、
  ［次へ］条件（SPEC §2.4）、候補チップがひな形由来であること
  （**JS に文面を持たないこと**を検査）
- 更新 `tests/test-design-system.ps1`: 新 CSS も直書き禁止の対象

---

### WP-08 画面 5 / 6 / 7（AI 経路の実行と確認）

**変更**
- 画面 5: 改修 ID 発行、`repair-request.md` 生成、`{{DIAGNOSIS}}` / `{{SELECTED_FINDINGS}}` の整形
- 画面 6: 既存 `response-package.js` 経路 ＋ `NEEDDECISION`（SPEC §5.4.1）
- 画面 7: **β1.10 画面 8 のまま**。触るのは到達経路だけ

**テスト**
- 新規 `tests/test-need-decision.js`: `NEEDDECISION` の受理と各拒否条件、
  受理後に `[次へ]` が開かないこと、［改修の入力へ戻る］で画面 4 の該当行へ
  質問が引用されること
- 更新 `tests/test-prompt-template.js`: 改修テンプレートの生成結果をバイト単位で固定、
  `{{SELECTED_FINDINGS}}` が 0 件のとき見出しごと消えないこと
- 更新 `tests/test-build-payload.js`: 画面 7 → ビルドの payload が変わっていないこと

---

### WP-09 決定的置換エンジン

**新規**
- `assets/js/vba-lexer.js` — SPEC §7.3
- `assets/js/path-map.js` — SPEC §7.4〜7.8
- 画面 4 のマッピング表レイアウト（同じ画面の別コンテンツ。**別画面を作らない**）

**テスト**
- 新規 `tests/test-vba-lexer.js`（最低限これらを持つ）
  - `"Don't"` の中のアポストロフィでコメントが始まらない
  - `REM` コメント（行頭 / `:` の直後 / ラベル `Label1:` の後 /
    `REMark` という識別子は**コメントでない** / `REM` 単独行）
  - `""` の連続によるエスケープ、空文字列 `""`
  - 文字列中の `'` と、コメント中の `"` が互いに干渉しない
  - **角括弧識別子** `[My Sheet!A1]` `[Don't]` の中で `'` も `"` も特別扱いされない
  - **日付リテラル** `#2026-08-01#` が後続の字句解析を乱さない
  - **条件付きコンパイル** `#If`〜`#End If` の内側の出現に印が付く
  - 行継続 `_` の論理行結合（文字列中・コメント中・角括弧中の `_` は継続でない）
  - 閉じない文字列の行に `unterminatedString`、閉じない `]` の行に
    `unterminatedBracket` が立ち、その行の候補が `ambiguous` になる
  - **可逆性**: トークン列を連結すると元の物理行が
    **UTF-16 文字列として完全一致で**復元できる（SPEC §7.3.1）
    （`tests/fixtures/monthly-report/*.bas` の全行と、§4.5 の経路で用意した実ブック由来
    fixture の全行で確認）
- 新規 `tests/test-path-map.js`
  - 8 クラスの検出（SPEC §7.4）と判定順
  - **コメント内・識別子内のパス文字列が候補にならないこと**
  - `&` で連結された `fragment` の検出（論理行をまたぐ場合を含む）
  - 同一値の集約（`groupKey` は**値のみ**。class は鍵に入れない）と、
    グループの class が出現の中で最も優先度の高いものになること。
    **大小無視トグルは存在しない**ので、`C:\Data` と `c:\data` が 2 行になること
  - M01〜M04 の検証（各 1 件の通る／落ちる ＋ `validationId` の一致）。
    **M05 は存在しない**（「2 行が同じ新しい値を指してよい」は不変条件であり
    失敗 fixture を持たない。SPEC §7.6 末尾）
  - `applied` が既定 false であること、false の行が検証も置換もされないこと
  - 適用: トークンスパンだけが変わり、同じ行の他の部分が
    **UTF-16 文字列として完全一致のまま**であること
  - **根拠表示の強調範囲が `vba-lexer.js` のスパンから来ていること**
    （`vba-highlight.js` の判定を使っていないこと。SPEC §7.5.2）
  - `"` を含む新しい値が `""` へ退避されること
  - **E-MAP-02**: 記録位置のトークンが変わっていたら全体中止（部分適用しない）
  - 未入力の行が置換されないこと
- 更新 `tests/test-flow-state.js`: 画面 4 → 7 の分岐（engine 別）

**完了条件**: 上記 green ＋ 基準線維持。
**盲目的な全置換の経路が存在しないこと**をテストで固定する
（任意文字列を受け取る置換 API が公開されていないことの検査を 1 件置く）。

---

### WP-10 実 WebView2 テスト

| 対象 | 内容 |
|---|---|
| 新規 `DiagnoseFlowSmoke` + `test-diagnose-webview.ps1` | 一本道の①②③: 実ブック添付 → 診断依頼生成 → 診断応答の貼り付け → 指摘一覧の表示 → 指摘選択と希望動作入力 → 改修依頼生成 |
| 新規 `PathMapSmoke` + `test-path-map-webview.ps1` | 固定パスひな形 → 候補検出と集約の表示 → 旧→新の入力 → preview diff → 画面 7 → ビルド → 出力 |
| 改修 `P10FlowSmoke` | β2 の 11 画面通し（診断 → 改修 → diff → 出力）。2 段階の依頼 ID を検証 |
| 改修 `SplitOutputSmoke` | 改修の分割に加え、**診断の分割**（欠番・重複・統合）を追加 |
| 改修 `NoChangeSmoke` | `UNNECESSARY` / `IMPOSSIBLE` / **`NEEDDECISION`** と、**診断 0 件**（`SCOPE_CLEAR` / `INSUFFICIENT`） |
| 改修 `EditorFocusSmoke` | 希望動作欄・追加の要望欄・マッピングの新値欄で、IME 変換中の Enter が［次へ］を発火させないこと。フォーカス復帰。1366×768 で縦スクロールが出ないこと |
| 改修 `SimpleModeSmoke` → `ShortestPathSmoke` | 簡易モードの入口が無いこと、および最短経路が実機で通ること |
| 改修 `WebViewSecuritySmoke` / `P9WebViewSmoke` | **境界と期待値は変えない**が、実コードが `appInfo.presets.length` を直接参照しているため、2 群になった `presets` へ追随させる必要がある。「維持」ではなく「期待値を変えない更新」 |
| 改修 `test-p9-distribution.ps1` | β2 のファイル一式（`environment/` を含む）がコピーだけで動くこと。**配布ステージの除外リストに `public-release` / `docs` / `tests` / `_audit` / `.playwright-mcp` を足す**（現在は `.git` と `testdata` だけを除外しており、凍結した β1.10 配布物が入れ子でコピーされている）。preset の件数検査（`:258-264`）は現在トップレベルだけを数えるので、2 階層の合計を数える形へ直す |

**クリップボード**: 全 smoke のクリップボード操作に SPEC §8.5 の有界再試行を入れる。
再試行回数を試験ログへ出す。**尽きたら失敗**。

**完了条件**: 実 WebView2 全本 green。合計所要時間を計測して報告する
（基準線は 8 本で hard timeout 合計 17 分 45 秒。β2 は 10 本前後になる見込み）。

---

### WP-11 ドキュメント統合

- `docs/SPEC.md` を β2.00 の正本へ統合する（[DECISIONS-BETA2.md](DECISIONS-BETA2.md) D-12）。
  β1.10 のままの節は残し、SPEC-BETA2 が述べた節だけを置き換える
- `docs/DEVELOPMENT.md`: 新ファイルの責務（`target-environment.js` /
  `diagnosis-package.js` / `vba-lexer.js` / `path-map.js` が**唯一の実装**であること）、
  新しいテストの走らせ方、`environment/` の保守
- `README.md`: 一本道の説明へ差し替え。`docs/releases/` は**触らない**
- `docs/beta2/` は履歴として残す

---

## 3. 回帰表（各 WP 完了時に確認する）

[AUDIT-BETA1.md](AUDIT-BETA1.md) §3 の S1〜S12 を、どのテストが守っているかで固定する。

| # | 性質 | 守るテスト |
|---|---|---|
| S1 | 原本非破壊 | `test-bookio.ps1` / `test-build.ps1` |
| S2 | 添付時署名一致（E-BUILD-04） | `test-hostservices.ps1` |
| S3 | 書き戻し後の読み直し検証 | `test-build.ps1` / `test-roundtrip.ps1` |
| S4 | all-or-nothing | `test-build.ps1` |
| S5 | 依頼 ID の帰属 | `test-flow-state.js` / `test-diagnosis-package.js` |
| S6 | 厳格契約 | `test-response-package.js` / `test-diagnosis-package.js` / `test-diagnosis-split.js` / `test-module-split.js` / `test-contract-singleton.js` |
| S7 | 全モジュールを渡す | `test-prompt-template.js` |
| S8 | ブックの VBA ソースを外向きに write / log しない（返答の**読み取り**は対象外） | `test-hostservices.ps1` / `test-path-map.js`（値をログに出さない） |
| S9 | WebView2 境界 | `test-webview-security.ps1` |
| S10 | Attribute の保存・再付与 | `test-vbaproject.ps1` / `test-build.ps1` |
| S11 | 文字コード変換の厳密性 | `test-vbaproject.ps1` |
| S12 | 実行フォルダ内だけへ出力 | `test-hostservices.ps1` / `test-p9-distribution.ps1` |

---

## 4. 完了ゲート（すべて green で β2.00 完成）

| G | 内容 |
|---|---|
| G1 | Node 全本 green（基準線 24 本 + 新規。緩和ゼロ） |
| G2 | PowerShell ヘッドレス全本 green（基準線 12 本 + 新規） |
| G3 | 実 WebView2 全本 green（クリップボード再試行込み。尽きた失敗は失敗） |
| G4 | 回帰表 S1〜S12 がすべて対応テストで green |
| G5 | 実 WebView2 で**一本道の通し**: 読み込む → 診断 → 指摘選択と希望動作 → 改修依頼 → 取り込み → diff → 出力 |
| G6 | 実 WebView2 で**分岐系の通し**: 診断 0 件 / `INSUFFICIENT` / `NEEDDECISION` / 分割応答（診断・改修） / 決定的置換 |
| G7 | focus / IME / キーボードのみ / 1366×768 縦スクロール無し を実 WebView2 で確認 |
| G8 | すべての AI 応答 fixture が製品の契約実装を実際に通っている（テスト専用パーサ 0 件）。§4.1 の機械検査で固定 |
| G9 | `public-release/**` 無変更・git 外部操作 0 件・他 repo 無変更 |
| G10 | `environment/target-environment.json` が実ファイルとして検証を通り、アプリが実行時に読んでいる（コードへの埋め込み 0 件）。§4.2 の機械検査で固定 |

### 4.1 G8 を機械で守る — `tests/test-contract-singleton.js`（新規）

「テストを緩めない」を人の善意に頼らず、次の 3 つを機械で検査する。

**当初 opus-architect が提案した grep 方式（「マーカーがあれば実装ファイル名を含むこと」
「検査 ID 文字列がどこかにあること」）は採らない。** どちらも `require` の文字列や
コメントだけで通ってしまい、**実行を担保しない**。codex-implementer の指摘を採用し、
実行経路そのものを検査する方式へ差し替える。

1. **成果物に印を付ける（brand）— これが本体**
   `response-package.js` / `diagnosis-package.js` は、自分が返す解析結果オブジェクトを
   モジュール内に閉じた `WeakSet` へ登録する（外から作れない印）。
   `state.js` / `app.js` の受け取り側は、**印の無いオブジェクトを拒否する**。
   - 自前パーサが作った「それらしい形」のオブジェクトは、印が無いので製品経路へ入れない。
   - したがってテストは製品 API を通るしかなくなる。**構造的な保証**であり、
     文字列検査のような回避余地が無い。
   - 印の検査自体を検査するテストを 1 本置く（印無しオブジェクトが拒否されること）。
2. **負例が「正しい理由で」落ちたことを検査する**
   契約の失敗は `{ok:false, validationId:"D11", ...}` の形で理由を返す。
   各負例テストは、落ちたことだけでなく**返ってきた `validationId` が期待した ID と
   一致すること**を assert する。
   - 「何かの理由で落ちた」を「その検査が効いている」と誤認しない。
   - 検査 ID のコメントを書くだけでは通らない。**実際にその分岐へ到達する必要がある。**
3. **第 2 実装の静的禁止**
   `assets/js/` と `tests/` に、区切り行の directive を分岐する `switch` / 
   `readSentinel` 相当の第 2 実装が現れないことを検査する
   （`response-package.js` / `diagnosis-package.js` の 2 ファイルを除く）。
   加えて次の 2 つを検査する（WP-01 のレビューで見つかった侵食経路）:
   - **`assets/js/**` が `createRequestId(` を呼ばないこと。**
     依頼 ID を作る製品経路は `createRequestIdentity()` だけであり、
     `secure` を観測しない mint 口を残さない
     （`createRequestId` はテスト用の薄い包みとして export に残っている）。
   - **利用者向け文面が `assets/messages/*.txt` と `assets/js/app.js` の
     両方に存在しないこと。** 同じ文が 2 か所にあると、片方だけが表示され
     もう片方が黙って腐る（WP-01 の `E-GEN-04` が実際にそうなっていた）。
4. **C# / WebView fixture の扱い**
   `*Smoke.cs` は実 WebView2 で製品ページを読み込むため、
   **製品 UI 経由であることが構造的に保証されている**。この経路だけを whitelist し、
   ページを介さずに fixture を検証する C# 経路は作らない。
5. **テストが実際に走っていること**
   `tests/*.js` のすべてが末尾で `<自分の名前>: PASS` を出力し、かつ
   `docs/DEVELOPMENT.md` §5 の実行一覧に載っていることを検査する
   （[AUDIT-BETA1.md](AUDIT-BETA1.md) §1.7.1 の欠落を再発させない）。
   - **`skip` / `TODO` の grep 禁止は採らない。** 実読の結果、
     `test-monthly-report-roundtrip.ps1:237` の `$skipped` は
     「無変更のモジュールを書き戻さなかった件数」という正当な変数名であり、
     素朴な grep は偽陽性を出す。**偽陽性を出す門番は、いずれ無視される。**

### 4.2 G10 を機械で守る — `tests/test-environment-not-embedded.js`（新規）

`environment/target-environment.json` を読み、その `constraints[].key` の**すべて**が
`src/**/*.cs` と `assets/js/**/*.js` の**どこにも文字列リテラルとして現れない**ことを
検査する（`assets/js/target-environment.js` を含む。同ファイルは key を総称的に
扱うだけで、特定の key を知ってはならない）。

併せて、`environment/target-environment.json` の `title` / `detail` の各文が
`src/**` `assets/**` `templates/**` に現れないことも検査する
（散文がコードやテンプレートへ二重化していないこと）。

**この 2 本が落ちたら、環境定義が「実ファイルを読んでいる体裁」に退化している。**

### 4.3 既存テスト資産の移行表

着手前実査で、`tests/` にある `test-*.*` と `*Smoke.cs` は **59 本**だった。
次の表は 59 本を重複なく 1 回ずつ列挙する（更新 32、改名・作り替え 3、維持 24）。
`make-input-monthly-report.ps1` は fixture 生成器であり、この 59 本には含めない。

| # | ファイル | 扱い | β2.00 での理由・守るもの |
|---:|---|---|---|
| 1 | `DiffReportSmoke.cs` | **維持** | 差分レポートの WebView 操作は不変 |
| 2 | `EditorFocusSmoke.cs` | **更新** | 新しい希望動作・追加要望・マッピング欄、IME、`.screen-body` の高さを検査 |
| 3 | `NoChangeSmoke.cs` | **更新** | 診断 0 件と `NEEDDECISION`、11 画面の遷移へ追随 |
| 4 | `P10FlowSmoke.cs` | **更新** | 診断→改修→diff→出力の一本道と 2 段階 ID へ作り替える |
| 5 | `P9WebViewSmoke.cs` | **更新** | `appInfo.presets.length` を 2 群の計数へ変更。期待する preset 契約は維持 |
| 6 | `SimpleModeSmoke.cs` | **改名・作り替え** → `ShortestPathSmoke.cs` | 簡易入口を廃し、診断を必ず通る最短経路を検査 |
| 7 | `SplitOutputSmoke.cs` | **更新** | 既存の改修分割に、診断の `parsePart` / `mergeParts` を追加 |
| 8 | `WebViewSecuritySmoke.cs` | **更新** | 2 群 preset 参照へ追随。WebView2 境界の期待値は変えない |
| 9 | `test-app-compile.ps1` | **維持** | `src/*.cs` の C# 5.0 コンパイル門番。新規 source も列挙で自動対象 |
| 10 | `test-attach-blocked.js` | **更新** | 統合後の画面 0 で暗号化ブックが止まることを検査 |
| 11 | `test-audit-fixes.js` | **更新** | request identity と新 screen 定数へ追随し、既存監査 4 件を保持 |
| 12 | `test-bookio.ps1` | **維持** | 原本非破壊・再読検証のエンジン回帰 |
| 13 | `test-build-payload.js` | **更新** | review が画面 7 になった後も build payload が同一であることを検査 |
| 14 | `test-build.ps1` | **維持** | all-or-nothing、世代交換、再読検証を保持 |
| 15 | `test-class-roundtrip.ps1` | **維持** | class module の実 Excel ラウンドトリップ（任意実機） |
| 16 | `test-compression.ps1` | **維持** | MS-OVBA 圧縮・展開は不変 |
| 17 | `test-design-system.ps1` | **更新** | `findings.css` と新画面 CSS も token・ASCII 規律の対象にする |
| 18 | `test-diff-report-toggle.js` | **維持** | 差分実装 singleton と toggle の一致を保持 |
| 19 | `test-diff-report-webview.ps1` | **維持** | 自己完結差分 HTML の実 WebView2 操作は不変 |
| 20 | `test-diff-report.js` | **維持** | 差分レポート生成契約は不変 |
| 21 | `test-diff-view.js` | **維持** | review の diff renderer 自体は不変 |
| 22 | `test-diff.js` | **維持** | 共通 diff engine は不変 |
| 23 | `test-editor-focus.ps1` | **更新** | `EditorFocusSmoke` の新入力欄・IME・1366×768 検査を起動 |
| 24 | `test-encrypted-book.ps1` | **維持** | OLE2 暗号化判定は不変 |
| 25 | `test-excel-macro.ps1` | **維持** | 明示指定の Excel 実機確認 runner は不変 |
| 26 | `test-extract.ps1` | **維持** | VBA 読取 6 経路と optional oracle は不変 |
| 27 | `test-file-drop.js` | **更新** | 添付先を統合後の画面 0 とし、drop の境界は保持 |
| 28 | `test-flow-state.js` | **更新** | 11 画面、history、2 段階 ID、snapshot 無効化、engine 分岐を検査 |
| 29 | `test-flow-webview.ps1` | **更新** | `P10FlowSmoke` と clipboard retry を使う β2 一本道 runner へ |
| 30 | `test-host-bridge.js` | **維持** | envelope・trusted source・`buildBook` 無 timeout の橋渡し契約は不変 |
| 31 | `test-hostservices.ps1` | **更新** | 新 action、2 群 preset、stage 別 atomic write、clipboard 例外を検査 |
| 32 | `test-input-monthly-report.ps1` | **維持** | 月次 fixture の入力契約は不変 |
| 33 | `test-input-sample.ps1` | **維持** | sample 入力の検査は不変 |
| 34 | `test-module-split.js` | **更新** | 正準 `COMPLETE`、改修分割の非回帰、flat preset/state 参照を移行 |
| 35 | `test-monthly-report-equivalence.ps1` | **維持** | 実 Excel の業務結果同値性（任意実機）は不変 |
| 36 | `test-monthly-report-roundtrip.ps1` | **維持** | 月次ブックのモジュール単位 roundtrip は不変 |
| 37 | `test-no-change-webview.ps1` | **更新** | `NoChangeSmoke` で 0 件診断と 3 verdict を検査 |
| 38 | `test-no-change.js` | **更新** | `NEEDDECISION` の構造・文脈検証と正準 `COMPLETE 0` を追加 |
| 39 | `test-ole2.ps1` | **維持** | CFB 読み書きは不変 |
| 40 | `test-p6-state.js` | **更新** | β2 の screen 定数と受理済み変更の状態不変条件へ追随 |
| 41 | `test-p7-state.js` | **更新** | β2 の review/output/build 状態へ画面番号を付け替える |
| 42 | `test-p9-distribution.ps1` | **更新** | 凍結物の除外、environment 同梱、2 階層 preset、stage 実行を検査 |
| 43 | `test-p9-preset.ps1` | **更新** | staged product の 2 群 preset を実 WebView2 で検査 |
| 44 | `test-paste-edit.js` | **更新** | review=7 へ追随し、未反映編集の破棄防止を保持 |
| 45 | `test-paste-normalize.js` | **維持** | 貼り付け正規化 4 規則は増減させない |
| 46 | `test-preset-description.js` | **更新** | flat preset 列挙を repair 群へ替え、H1/説明の正本性を保持 |
| 47 | `test-preset-document.js` | **更新** | engine・候補・維持条件・段階別分割見出し・`## 用途` 拒否 |
| 48 | `test-preset-migration.js` | **更新** | 2 階層の同梱実ファイルと価値移設を検査 |
| 49 | `test-prompt-template.js` | **更新** | 新変数 3 種と診断/改修テンプレートをバイト固定 |
| 50 | `test-read-report.js` | **更新** | 画面 0 統合後も `read.level` の 2 段階表現を保持 |
| 51 | `test-response-package.js` | **更新** | R1/R2/R3、brand、context validation を製品 IIFE へ直接検査。DEVELOPMENT に追加 |
| 52 | `test-roundtrip.ps1` | **維持** | 全 stream の無変更 roundtrip は不変 |
| 53 | `test-simple-mode.js` | **改名・作り替え** → `test-shortest-path.js` | valid 診断を通る最短経路と skip 入口 0 件を検査 |
| 54 | `test-simple-webview.ps1` | **改名・作り替え** → `test-shortest-path-webview.ps1` | `ShortestPathSmoke` の実 WebView2 runner |
| 55 | `test-split-webview.ps1` | **更新** | `SplitOutputSmoke` の診断/改修両分割と retry ログを検査 |
| 56 | `test-vba-highlight.js` | **維持** | review の VBA 表示 lexer は置換 lexer と別責務で不変（SPEC §7.5.2）。`vba-highlight.js` は触らない |
| 57 | `test-vbaproject.ps1` | **更新** | 既存の Attribute/encoding 回帰を保持し、実ブック由来 lexer fixture と hash を照合 |
| 58 | `test-webview-security.ps1` | **更新** | grouped preset へ参照だけ追随し、security 境界の期待値は維持 |
| 59 | `test-window-icon.ps1` | **維持** | window icon の形・色・文字は不変 |

新規テスト資産は既存 59 本とは別に、該当 WP で次を追加する。

| WP | 新規ファイル |
|---|---|
| WP-01 | `test-clipboard-retry.ps1` |
| WP-02 | `test-target-environment.js` / `test-environment-not-embedded.js` |
| WP-03 | `test-diagnosis-package.js` / `test-diagnosis-split.js` / `test-contract-singleton.js` |
| WP-04 →**グループ B へ繰り延べ** | `test-preset-value-migration.js`（画面 1 / 4 の state API が WP-05/06 まで無いため。グループ B の完了 gate に含める） |
| WP-06 | `test-diagnose-flow.js` |
| WP-07 | `test-findings-view.js` / `test-repair-input.js` |
| WP-08 | `test-need-decision.js` |
| WP-09 | `test-vba-lexer.js` / `test-path-map.js` / `tests/fixtures/lexer/**` |
| WP-10 | `DiagnoseFlowSmoke.cs` / `test-diagnose-webview.ps1` / `PathMapSmoke.cs` / `test-path-map-webview.ps1` |

**DEVELOPMENT 同期ゲート**:

- 現在 `docs/DEVELOPMENT.md` §5 に欠けている `test-response-package.js` を WP-01 で追加する。
- テストの追加・改名と同じ WP で §5 の実行一覧も同期する。WP-11 まで先送りしない。
  そうしないと `test-contract-singleton.js` の「全 Node test が一覧にある」が途中 gate で落ちる。
- 各 gate でディスク上の `tests/test-*.js` と §5 の Node 一覧を機械比較し、
  **欠落 0・余剰 0・各 runner の `PASS` 0 漏れ**を要求する。

### 4.4 transaction のテスト要件（SPEC §2.6.1 / §7.7 に対応）

「失敗しても何も変わらない」は、**変わっていないことを検査して初めて主張できる**。

- ホストが `writeRequestFiles` / `writeDiagnosisFile` を失敗で返したとき、
  **状態オブジェクトが呼び出し前と deep-equal** であること
  （依頼 ID・スナップショット・下流の成果物が 1 つも変わっていない）。
- 同じく**ディスク上のファイルが呼び出し前と一致**すること
  （旧 `diagnose-request.md` が壊れていない）。
- `E-MAP-02` で中止したとき、入力のモジュールオブジェクト群と
  staged changes が呼び出し前と deep-equal であること（SPEC §7.7 相 1）。
- 書き出し中に前進ボタンが `disabled` であること（二重押下で 2 つの実行を作らない）。

### 4.5 字句解析 fixture の入手経路（Node だけでは足りない）

`test-vba-lexer.js` の「実ブックの全行で可逆性を確認する」は、
**Node からはブックを開けない**（VBA の抽出は C# の `BookIO` にある）。

- `testdata/test_large.xlsm` から抽出したモジュール本文を、
  PowerShell / C# 側のテスト（`test-vbaproject.ps1` の経路）で書き出し、
  `tests/fixtures/lexer/` へ**ファイルとして置く**。
  （β2.00 では commit しない。作業ツリーに dirty のまま残す。§0 の git 規律）
- fixture には**出自（どのブックの、どのモジュール）と内容ハッシュ**を添える。
  `testdata/` は git 管理外なので、出自だけでは再現できないため。
- 併せて `tests/fixtures/monthly-report/*.bas`（既にコミット済み）の全行も対象にする。
- 合成 fixture（CRLF / LF / 末尾改行なし / 日本語 / サロゲートペア /
  数字行ラベル / `REM` / 角括弧 / 条件付きコンパイル）は手で作って同じ場所へ置く。

---

## 5. リスクと対応

| リスク | 影響 | 対応 |
|---|---|---|
| 診断契約が冗長すぎて実チャット AI が守れない | 一本道の②で止まる | ひな形の `## 出力指示` に**完全な記入例**を 1 件載せる。分割受理（§4.7）で長さの問題を分ける。実運用の追従率は先生の実機テストで測る（SPEC §12-1） |
| `app.js` が 148KB でさらに増える | 保守不能 | WP-06〜09 で画面ごとにビルダーを切り出す。**新しい画面ロジックを `app.js` へ足さず**、`assets/js/screens/*.js` へ置く。既存部分の全面リファクタは β2 のスコープ外 |
| VBA 字句解析の取りこぼし | 誤置換 | 候補を出さない（安全側）方向へ倒す。`ambiguous` は既定で鍵付き。適用直前の再解析（E-MAP-02）で最後の砦を張る |
| 実 WebView2 テストが 25 分超になる | 開発が回らない | 群を分けて回せるようにする（`-Only diagnose` 等）。全本は WP 完了時とゲート時だけ |
| クリップボード競合が再発 | E2E フレーク | WP-01 で有界再試行。再試行回数をログへ出して見えなくしない |
| `presets` の移動で利用者の自作ひな形が迷子になる | 既存利用者の混乱 | β2.00 は未公開であり実利用者はいない。`README.md` と `SOURCES.md` に配置を書く |

---

## 6. 先生が最初に触るときの起動方法

```
エクスプローラーで C:\repos\pub\macrostudio\launch.vbs をダブルクリック
```

開発中にコンソールを見たい場合は `launch.bat`。
ログは `%LOCALAPPDATA%\MacroStudio\logs\macrostudio_<yyyyMMdd>.log`。

`environment\target-environment.json` を編集したら、
**アプリの再起動は不要**（画面 1 へ入るたび読み直す）。
