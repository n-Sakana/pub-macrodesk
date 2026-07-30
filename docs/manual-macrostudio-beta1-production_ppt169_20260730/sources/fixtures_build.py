"""Builds the screenshot fixture for the production manual.

Real data end to end: the module list is the engine's own extraction of
testdata/input_win32_sleep.xlsm (the repository's designated input sample),
shown under a neutral reader-facing name. The "AI answer" is a faithful
Win32-API removal of exactly that code, produced by mechanical transforms
so the shown diff is the diff a correct answer would produce.
"""
import json
import pathlib
import re

HERE = pathlib.Path(__file__).parent
REPO = pathlib.Path(r"C:\repos\pub\macrostudio")
SRC_JSON = HERE / "win32sleep-modules.json"

BOOK_NAME = "申請データ検証.xlsm"
BOOK_DIR = r"C:\Tools\申請チェック"
RUN_STAMP = "20260730_103000"

raw = json.loads(SRC_JSON.read_text(encoding="utf-8"))
modules = raw["modules"]
if not isinstance(modules, list):
    raise SystemExit("unexpected JSON shape")

# The extraction script's own Japanese literals were mangled (PowerShell
# 5.1 reads BOM-less scripts as CP932), so the labels come from the
# product's message files instead - the same source the real host uses.
TYPE_LABELS = {
    kind: (REPO / "assets" / "messages" /
           ("module-type-%s.txt" % kind)).read_text(
        encoding="utf-8").strip()
    for kind in ("standard", "class", "form", "document")
}
for module in modules:
    module["typeLabel"] = TYPE_LABELS[module["type"]]


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


# ---- the corrected code: remove the Win32 dependency ---------------------
WAITUTILS = crlf(
    "Option Explicit\n"
    "\n"
    "' Win32 API の Sleep の代替。VBA の標準機能だけで指定ミリ秒待つ。\n"
    "' Timer は日付をまたぐと 0 に戻るため、その場合も待ち続けないよう補正する。\n"
    "Public Sub WaitMilliseconds(ByVal milliseconds As Long)\n"
    "    Dim startedAt As Single\n"
    "    Dim waitSeconds As Single\n"
    "    Dim elapsed As Single\n"
    "\n"
    "    If milliseconds <= 0 Then Exit Sub\n"
    "    startedAt = Timer()\n"
    "    waitSeconds = milliseconds / 1000!\n"
    "    Do\n"
    "        DoEvents\n"
    "        elapsed = Timer() - startedAt\n"
    "        If elapsed < 0! Then elapsed = elapsed + 86400!\n"
    "    Loop While elapsed < waitSeconds\n"
    "End Sub\n")

DECLARE_BLOCK = re.compile(
    r"#If VBA7 Then\r\n"
    r"\s*Public Declare PtrSafe Sub Sleep Lib \"kernel32\" "
    r"\(ByVal dwMilliseconds As Long\)\r\n"
    r"#Else\r\n"
    r"\s*Public Declare Sub Sleep Lib \"kernel32\" "
    r"\(ByVal dwMilliseconds As Long\)\r\n"
    r"#End If\r\n\r\n")

SLEEP_CALL = re.compile(r"\bSleep (\d+)\b")

changed = {}
call_counts = {}
for module in modules:
    if module["type"] != "standard":
        continue
    code = module["code"]
    new_code = code
    if module["name"] == "TimerUtils":
        new_code = DECLARE_BLOCK.sub("", new_code)
    new_code, count = SLEEP_CALL.subn(r"WaitMilliseconds \1", new_code)
    if new_code != code:
        changed[module["name"]] = new_code
        call_counts[module["name"]] = count

total_calls = sum(call_counts.values())
order = [n for n in ("AppController", "SystemInfo", "TimerUtils",
                     "WindowUtils") if n in changed]

summary_lines = [
    "Win32 API（kernel32 の Sleep）への依存をなくしました。",
    "・WaitUtils（新規）: VBA の標準機能だけで待ち時間を作る "
    "WaitMilliseconds を追加しました。",
    "・TimerUtils: Sleep の Declare 宣言を削除しました。",
    "・AppController / SystemInfo / TimerUtils / WindowUtils: "
    "Sleep の呼び出し（計 %d 箇所）を WaitMilliseconds へ置き換えました。" % total_calls,
    "処理の順番と結果は変えていません。待ち時間の作り方だけが変わっています。",
]

package_modules = [
    {"kind": "standard", "name": name, "code": changed[name]}
    for name in order
] + [{"kind": "standard", "name": "WaitUtils", "code": WAITUTILS}]

fixture = {
    "book": {
        "name": BOOK_NAME,
        "path": BOOK_DIR + "\\" + BOOK_NAME,
        "ext": ".xlsm",
        "totalLines": raw["book"]["totalLines"],
    },
    "modules": [
        {
            "name": m["name"],
            "type": m["type"],
            "typeLabel": m["typeLabel"],
            "ext": m["ext"],
            "lineCount": m["lineCount"],
            "code": m["code"],
            "attributes": m["attributes"],
            "pastedCode": None,
            "status": "pending",
            "changedLineCount": 0,
            "showChangesOnly": m["lineCount"] > 200,
            "wrapDiff": True,
            "written": False,
        }
        for m in modules
    ],
    "warning": False,
    "read": {"level": "clean", "partialModules": [],
             "recoveredOffsetModules": [], "unreadableModules": [],
             "containerFallback": False, "salvaged": False,
             "shortStream": False},
    "presets": [
        {"file": p.name, "content": p.read_text(encoding="utf-8")}
        for p in sorted(REPO.glob("presets/*.md"))
    ],
    "requestTemplate": (REPO / "templates" / "request-template.txt")
    .read_text(encoding="utf-8"),
    "runFolder": BOOK_DIR + "\\MacroStudio\\申請データ検証_" + RUN_STAMP,
    "summaryLines": summary_lines,
    "packageModules": package_modules,
}

out = HERE / "fixture.json"
out.write_text(
    json.dumps(fixture, ensure_ascii=False, indent=1), encoding="utf-8")
print("fixture written:", out)
print("changed modules:", {k: call_counts[k] for k in order})
print("package modules:", [m["name"] for m in package_modules])
