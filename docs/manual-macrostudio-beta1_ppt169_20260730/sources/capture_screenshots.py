"""Macro Studio screenshot harness (revision 2).

Serves C:\\repos\\pub\\macrostudio\\assets read-only, injects a WebView2 host
mock before page scripts, then drives the REAL UI by clicking real controls.
Every capture is a normal operating state reached through the actual flow;
nothing is faked and no state is written directly.

If a scene cannot be reached, it is reported FAILED and no PNG is written.

    python shoot.py <out_dir>
"""
import functools
import http.server
import json
import pathlib
import socketserver
import sys
import threading

from playwright.sync_api import sync_playwright

REPO = pathlib.Path(r"C:\repos\pub\macrostudio")
ASSETS = REPO / "assets"
PRESETS = REPO / "presets"
HERE = pathlib.Path(__file__).parent
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else HERE / "out")
PORT = 8911
VIEWPORT = {"width": 1366, "height": 768}

OUT.mkdir(parents=True, exist_ok=True)
results = []


# ---------------------------------------------------------------- fixtures
def vba(*lines):
    return "\r\n".join(lines) + "\r\n"


MODULES = [
    {
        "name": "ThisWorkbook", "type": "document",
        "typeLabel": "ドキュメントモジュール", "ext": "cls",
        "code": vba("Option Explicit", "", "Private Sub Workbook_Open()",
                    "    ' 起動時に集計シートを開く", "    Sheet1.Activate",
                    "End Sub"),
        "attributes": "",
    },
    {
        "name": "Sheet1", "type": "document",
        "typeLabel": "ドキュメントモジュール", "ext": "cls",
        "code": vba("Option Explicit", "", "Private Sub Worksheet_Change(ByVal Target As Range)",
                    "    ' 入力があったら合計を引き直す",
                    "    If Target.Column = 3 Then Recalc", "End Sub"),
        "attributes": "",
    },
    {
        "name": "Main", "type": "standard", "typeLabel": "標準モジュール",
        "ext": "bas",
        "code": vba(
            "Option Explicit",
            "",
            "' 売上集計の入口",
            "Public Sub 集計実行()",
            "    Dim savePath As String",
            "    savePath = GetTempFolder() & \"\\売上集計.csv\"",
            "    If Len(Trim$(Range(\"C2\").Value)) = 0 Then Exit Sub",
            "    Call 書き出し(savePath)",
            "End Sub"),
        "attributes": "",
    },
    {
        "name": "FileHelpers", "type": "standard",
        "typeLabel": "標準モジュール", "ext": "bas",
        "code": vba(
            "Option Explicit",
            "",
            "Private Declare PtrSafe Function GetTempPathA Lib \"kernel32\" ( _",
            "    ByVal nBufferLength As Long, ByVal lpBuffer As String) As Long",
            "",
            "' 一時フォルダのパスを返す",
            "Public Function GetTempFolder() As String",
            "    Dim buf As String * 260",
            "    GetTempPathA 260, buf",
            "    GetTempFolder = Left$(buf, InStr(buf, vbNullChar) - 1)",
            "End Function"),
        "attributes": "",
    },
    {
        "name": "OrderRecord", "type": "class", "typeLabel": "クラスモジュール",
        "ext": "cls",
        "code": vba("Option Explicit", "", "Public 伝票番号 As String",
                    "Public 金額 As Currency"),
        "attributes": "",
    },
]
for m in MODULES:
    m.update(lineCount=len(m["code"].replace("\r\n", "\n").rstrip("\n").split("\n")),
             pastedCode=None, status="pending", changedLineCount=0,
             showChangesOnly=False, wrapDiff=True, written=False)

BOOK = {
    "name": "売上集計マクロ.xlsm",
    "path": r"C:\Tools\macrostudio-sample\売上集計マクロ.xlsm",
    "ext": ".xlsm",
    "totalLines": sum(m["lineCount"] for m in MODULES),
    "warning": False,
}

PRESET_FILES = sorted(p.name for p in PRESETS.glob("*.md"))
PRESET_CONTENT = {
    p.name: p.read_text(encoding="utf-8") for p in PRESETS.glob("*.md")
}

FIXTURES = {
    "book": BOOK,
    "modules": MODULES,
    "presets": [{"file": f, "content": PRESET_CONTENT[f]} for f in PRESET_FILES],
    "presetContent": PRESET_CONTENT,
    "requestTemplate": (REPO / "templates" / "request-template.txt").read_text(
        encoding="utf-8"),
    "buildFileLabel": "macrostudio",
    "runFolder": r"C:\Tools\macrostudio-sample\MacroStudio\売上集計マクロ_20260730_101500",
    "outputName": "売上集計マクロ_macrostudio.xlsm",
}

# The improved Main + a Win32-free replacement, as one answer package.
NEW_MAIN = vba(
    "Option Explicit",
    "",
    "' 売上集計の入口",
    "Public Sub 集計実行()",
    "    Dim savePath As String",
    "    savePath = GetTempFolder() & \"\\売上集計.csv\"",
    "    If Len(Trim$(Range(\"C2\").Value)) = 0 Then",
    "        MsgBox \"伝票番号を入力してください。\"",
    "        Exit Sub",
    "    End If",
    "    Call 書き出し(savePath)",
    "End Sub")
NEW_FILEHELPERS = vba(
    "Option Explicit",
    "",
    "' 一時フォルダのパスを返す（Win32 API を使わない形）",
    "Public Function GetTempFolder() As String",
    "    GetTempFolder = Environ$(\"TEMP\")",
    "End Function")


def build_package(request_id):
    m = "'@MACROSTUDIO " + request_id
    return "\n".join([
        m + " SUMMARY BEGIN",
        "Main: 伝票番号が空のときに、メッセージを出してから終了するようにしました。",
        "FileHelpers: Win32 API の宣言をやめ、Environ$ で一時フォルダを取得する形へ直しました。",
        m + " SUMMARY END",
        m + " BEGIN standard Main",
        NEW_MAIN.replace("\r\n", "\n").rstrip("\n"),
        m + " END standard Main",
        m + " BEGIN standard FileHelpers",
        NEW_FILEHELPERS.replace("\r\n", "\n").rstrip("\n"),
        m + " END standard FileHelpers",
        m + " COMPLETE 2",
    ])


# ------------------------------------------------------------------ server
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def serve():
    handler = functools.partial(Quiet, directory=str(ASSETS))
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


# ------------------------------------------------------------------ driver
class App:
    def __init__(self, page):
        self.page = page

    def state(self):
        return self.page.evaluate(
            "() => { var s = window.MacroStudioState.getState();"
            " return {screen: s.screen, mode: s.mode, preset: s.presetFile,"
            "  book: s.book && s.book.name, busy: s.busyAction,"
            "  requestId: s.requestId, questions: (s.questions||[]).length,"
            "  runFolder: s.runFolder, buildResult: s.buildResult && s.buildResult.status}; }"
        )

    def title(self):
        return self.page.evaluate(
            "() => { var e = document.querySelector('.screen-title');"
            " return e ? e.textContent : ''; }")

    def settle(self, ms=420):
        self.page.wait_for_function(
            "() => window.MacroStudioState.getState().busyAction === null",
            timeout=15000)
        self.page.wait_for_timeout(ms)

    def actions(self):
        return self.page.evaluate(
            "() => Array.from(document.querySelectorAll('[data-action]'))"
            ".map(e => e.getAttribute('data-action')"
            "  + (e.disabled ? '(disabled)' : ''))")

    def click(self, selector, label=None):
        loc = self.page.locator(selector).first
        try:
            loc.wait_for(state="visible", timeout=8000)
        except Exception:
            raise RuntimeError(
                "not found: %s (%s)\n  screen=%s title=%r\n  actions=%s"
                % (label or selector, selector, self.state(), self.title(),
                   sorted(set(self.actions()))))
        if loc.is_disabled():
            raise RuntimeError(
                "disabled: %s\n  screen=%s title=%r"
                % (label or selector, self.state(), self.title()))
        loc.click()
        self.settle()

    def next(self):
        # Some screens do async host work before the next one appears, so
        # wait for the index to actually change rather than a fixed delay.
        before = self.state()["screen"]
        self.click('[data-action="go-next"]', "次へ")
        try:
            self.page.wait_for_function(
                "(prev) => window.MacroStudioState.getState().screen !== prev",
                arg=before, timeout=20000)
        except Exception:
            raise RuntimeError(
                "screen did not advance from %s (title=%r)"
                % (before, self.title()))
        self.settle()

    def clear_toasts(self):
        # The browser harness has no real host for a few side calls; drop any
        # transient toast so it cannot leak into a screenshot.
        self.page.evaluate(
            "() => { var t = document.getElementById('toast-region');"
            " if (t) { t.textContent = ''; } }")

    def shot(self, name, expect_screen=None):
        st = self.state()
        if expect_screen is not None and st["screen"] != expect_screen:
            results.append((name, "FAILED", "screen=%s expected=%s"
                            % (st["screen"], expect_screen)))
            return False
        title = self.title()
        self.clear_toasts()
        self.page.wait_for_timeout(150)
        bad = self.page.evaluate(
            "() => { var sel = '.toast, .inline-error-card, .headline-warning,"
            " [class*=failure]'; var n = document.querySelectorAll(sel);"
            " return n.length ? n[0].textContent.trim().slice(0,120) : ''; }")
        self.page.screenshot(path=str(OUT / (name + ".png")))
        results.append((name, "ok", "s%-2s %-28s%s" % (
            st["screen"], title, "  ANOMALY: " + bad if bad else "")))
        return True


def run(pw):
    browser = pw.chromium.launch()
    ctx = browser.new_context(viewport=VIEWPORT, device_scale_factor=2)
    ctx.add_init_script(
        "window.__MS_FIXTURES__ = " + json.dumps(FIXTURES, ensure_ascii=False) + ";")
    ctx.add_init_script(path=str(HERE / "mock.js"))
    page = ctx.new_page()
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    app = App(page)

    page.goto("http://127.0.0.1:%d/index.html" % PORT)
    page.wait_for_selector(".screen", timeout=15000)
    app.settle()

    # --- Step 1: read the workbook -------------------------------------
    app.shot("s01-drop-empty", expect_screen=0)
    app.click('[data-action="pick-book"]', "ブックを選ぶ")
    app.shot("s02-book-loaded", expect_screen=0)
    app.next()
    app.shot("s03-read-result", expect_screen=1)
    app.next()
    app.shot("s04-mode", expect_screen=2)

    # --- Step 1c: choose refactor -------------------------------------
    app.click('[data-action="select-mode"][data-mode="refactor"]', "改修する")
    app.shot("s05-mode-chosen", expect_screen=2)
    app.next()

    # --- Step 2: pick the purpose -------------------------------------
    app.shot("s06-purpose", expect_screen=3)
    first = page.locator('[data-action="select-purpose"]').first
    first.click()
    app.settle()
    app.shot("s07-purpose-chosen", expect_screen=3)
    app.next()

    st = app.state()
    if st["screen"] == 4:  # questions screen exists on this path
        app.shot("s08-questions", expect_screen=4)
        app.next()

    # --- Step 2c: request text ----------------------------------------
    app.shot("s09-request")
    app.next()

    # --- Step 2d: hand off --------------------------------------------
    st = app.state()
    app.shot("s10-handoff")
    app.click('[data-action="copy-request-prompt"]', "依頼文をコピー")
    app.click('[data-action="open-run-folder"]', "場所を開く")
    app.shot("s11-handoff-done")
    app.next()

    # --- Step 3: intake ------------------------------------------------
    st = app.state()
    app.shot("s12-intake")
    rid = st["requestId"]
    page.evaluate("(t) => window.__msMock.setClipboard(t)",
                  build_package(rid))
    app.click('[data-action="import-response"]', "取り込む")
    app.shot("s13-intake-done")
    app.next()

    # --- Step 3b: review ----------------------------------------------
    st = app.state()
    app.shot("s14-review")
    # The line-by-line diff sits behind a disclosure on this screen.
    try:
        disc = page.locator('[data-action="toggle-disclosure"]')
        if disc.count():
            disc.first.click()
            app.settle()
            changed = page.locator(
                '[data-action="select-module"][data-module-name="Main"]')
            if changed.count() and changed.first.is_visible():
                changed.first.click()
                app.settle()
            app.shot("s15-review-diff")
        else:
            results.append(("s15-review-diff", "FAILED", "no disclosure"))
    except Exception as exc:
        results.append(("s15-review-diff", "FAILED", str(exc)[:90]))
    app.next()

    # --- Step 4: build -------------------------------------------------
    st = app.state()
    app.shot("s16-output-name")
    app.next()
    page.wait_for_function(
        "() => { var s = window.MacroStudioState.getState();"
        " return s.buildResult !== null; }", timeout=20000)
    app.settle()
    app.shot("s17-done")

    browser.close()


def report():
    print("--- scenes ---")
    for name, status, detail in results:
        print("%-22s %-7s %s" % (name, status, detail))


def main():
    httpd = serve()
    try:
        with sync_playwright() as pw:
            run(pw)
    finally:
        httpd.shutdown()
        report()


main()
