"""MacroStudio screenshot rig for the production manual (beta 1.0.0).

Serves C:\\repos\\pub\\macrostudio\\assets read-only, injects a WebView2
host mock before page scripts, then drives the REAL UI by clicking real
controls. Every capture is a normal operating state reached through the
actual flow; nothing is faked and no state is written directly.

Also saves the artifacts the app itself hands the host during the run:
request.md, source-code.md, the diff-report HTML and result.md.

    python shoot.py [<out_dir>]
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
HERE = pathlib.Path(__file__).parent
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else HERE / "out")
PORT = 8912
VIEWPORT = {"width": 1366, "height": 768}

FIXTURES = json.loads((HERE / "fixture.json").read_text(encoding="utf-8"))

OUT.mkdir(parents=True, exist_ok=True)
results = []


def build_package(request_id):
    m = "'@MACROSTUDIO " + request_id
    lines = [m + " SUMMARY BEGIN"]
    lines.extend(FIXTURES["summaryLines"])
    lines.append(m + " SUMMARY END")
    for module in FIXTURES["packageModules"]:
        lines.append(m + " BEGIN " + module["kind"] + " " + module["name"])
        lines.append(module["code"].replace("\r\n", "\n").rstrip("\n"))
        lines.append(m + " END " + module["kind"] + " " + module["name"])
    lines.append(m + " COMPLETE " + str(len(FIXTURES["packageModules"])))
    return "\n".join(lines)


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
            "  runFolder: s.runFolder,"
            "  buildResult: s.buildResult && s.buildResult.status}; }")

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

    def click(self, selector, label=None, settle=True):
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
        if settle:
            self.settle()

    def next(self):
        before = self.state()["screen"]
        self.click('[data-action="go-next"]', "次へ")
        try:
            self.page.wait_for_function(
                "(prev) => window.MacroStudioState.getState().screen"
                " !== prev",
                arg=before, timeout=20000)
        except Exception:
            raise RuntimeError(
                "screen did not advance from %s (title=%r)"
                % (before, self.title()))
        self.settle()

    def toggle_disclosure(self, key):
        self.click('[data-action="toggle-disclosure"]'
                   '[data-disclosure="%s"]' % key, "開閉: " + key)
        self.page.wait_for_timeout(350)

    def clear_toasts(self):
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
            "() => { var sel = '.toast, .inline-error-card,"
            " .headline-warning, [class*=failure]';"
            " var n = document.querySelectorAll(sel);"
            " return n.length ? n[0].textContent.trim().slice(0,120)"
            " : ''; }")
        self.page.screenshot(path=str(OUT / (name + ".png")))
        results.append((name, "ok", "s%-2s %-30s%s" % (
            st["screen"], title, "  ANOMALY: " + bad if bad else "")))
        return True


def make_page(ctx):
    page = ctx.new_page()
    page.goto("http://127.0.0.1:%d/index.html" % PORT)
    page.wait_for_selector(".screen", timeout=15000)
    app = App(page)
    app.settle()
    return page, app


def refactor_pass(ctx):
    page, app = make_page(ctx)

    # --- step 1: choose the work, read the workbook --------------------
    app.shot("01-mode", expect_screen=0)
    app.click('[data-action="select-mode"][data-mode="refactor"]',
              "AIで改修する")
    app.shot("02-mode-selected", expect_screen=0)
    app.next()
    app.shot("03-book-empty", expect_screen=1)
    app.click('[data-action="pick-book"]', "ファイルを選ぶ")
    app.shot("04-book-loaded", expect_screen=1)
    app.next()
    app.shot("05-read", expect_screen=2)
    app.toggle_disclosure("read-detail")
    app.shot("06-read-open", expect_screen=2)
    app.toggle_disclosure("read-detail")
    app.next()

    # --- step 2: purpose, request, hand-off -----------------------------
    app.shot("07-purpose", expect_screen=3)
    app.click('[data-action="select-purpose"]'
              '[data-preset-file="02_Win32 API を使わない形へ直す.md"]',
              "Win32 API を使わない形へ直す")
    app.shot("08-purpose-selected", expect_screen=3)
    app.next()
    app.shot("09-request", expect_screen=5)
    app.toggle_disclosure("request-editor")
    app.shot("10-request-open", expect_screen=5)
    app.toggle_disclosure("request-editor")
    app.next()
    app.shot("11-handoff", expect_screen=6)
    app.click('[data-action="copy-request-prompt"]', "依頼文をコピー")
    app.click('[data-action="open-run-folder"]', "ファイルの場所を開く")
    app.shot("12-handoff-done", expect_screen=6)
    app.next()

    # --- step 3: intake and review --------------------------------------
    app.shot("13-intake", expect_screen=7)
    request_id = app.state()["requestId"]
    page.evaluate("(t) => window.__msMock.setClipboard(t)",
                  build_package(request_id))
    app.click('[data-action="import-response"]', "取り込む")
    app.shot("14-intake-done", expect_screen=7)
    app.toggle_disclosure("intake-summary")
    app.shot("15-intake-summary", expect_screen=7)
    app.toggle_disclosure("intake-summary")
    app.next()
    app.shot("16-review", expect_screen=8)
    app.toggle_disclosure("change-detail")
    app.click('[data-action="select-module"]'
              '[data-module-name="TimerUtils"]', "TimerUtils")
    app.shot("17-review-diff-timerutils", expect_screen=8)
    app.click('[data-action="select-module"]'
              '[data-module-name="AppController"]', "AppController")
    app.shot("18-review-diff-appcontroller", expect_screen=8)
    app.toggle_disclosure("change-detail")
    app.next()

    # --- step 4: name, build, done --------------------------------------
    app.shot("19-output-name", expect_screen=9)
    page.evaluate("() => window.__msMock.setBuildDelay(1600)")
    before = app.state()["screen"]
    app.click('[data-action="go-next"]', "次へ", settle=False)
    page.wait_for_function(
        "(prev) => window.MacroStudioState.getState().screen !== prev",
        arg=before, timeout=20000)
    page.wait_for_timeout(400)
    app.shot("20-building", expect_screen=10)
    page.wait_for_function(
        "() => window.MacroStudioState.getState().screen === 11",
        timeout=30000)
    app.settle()
    app.shot("21-done", expect_screen=11)

    # dark theme example on a calm screen
    page.click("#theme-toggle")
    page.wait_for_timeout(400)
    app.shot("22-done-dark", expect_screen=11)
    page.click("#theme-toggle")
    page.wait_for_timeout(300)

    # --- save the artifacts the app handed the host ---------------------
    captured = page.evaluate("() => window.__msMock.captured()")
    (OUT / "request.md").write_text(
        captured.get("request", ""), encoding="utf-8", newline="")
    (OUT / "source-code.md").write_text(
        captured.get("code", ""), encoding="utf-8", newline="")
    build = captured.get("build") or {}
    (OUT / FIXTURES["book"]["name"].replace(".xlsm", "")
     .join(["", "-diff-report.html"])).write_text(
        build.get("diffHtml", ""), encoding="utf-8", newline="")
    (OUT / "result.md").write_text(
        build.get("resultMarkdown", ""), encoding="utf-8", newline="")
    meta = {
        "requestId": request_id,
        "outputName": build.get("outputName"),
        "diffName": build.get("diffName"),
        "outputTimestamp": build.get("outputTimestamp"),
        "modules": build.get("modules"),
        "copiedPromptEqualsRequest":
            captured.get("copiedPrompt") == captured.get("request"),
    }
    (OUT / "captured-meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    results.append(("artifacts", "ok",
                    "request/source-code/diff/result saved"))
    page.close()


def diagnose_pass(ctx):
    page, app = make_page(ctx)

    app.click('[data-action="select-mode"][data-mode="diagnose"]',
              "AIで相談する")
    app.shot("30-mode-diagnose", expect_screen=0)
    app.next()
    app.click('[data-action="pick-book"]', "ファイルを選ぶ")
    app.next()
    app.next()
    app.shot("31-purpose-diagnose", expect_screen=3)
    app.click('[data-action="select-purpose"]'
              '[data-preset-file='
              '"05_相談用の依頼文を作る（進め方を決めたいとき）.md"]',
              "相談用の依頼文を作る")
    app.next()
    app.shot("32-questions", expect_screen=4)
    app.click('[data-action="answer-choice"]', "選択肢")
    app.shot("33-questions-answered", expect_screen=4)
    app.next()
    app.shot("34-request-diagnose", expect_screen=5)
    app.toggle_disclosure("request-editor")
    app.shot("35-request-diagnose-open", expect_screen=5)
    app.toggle_disclosure("request-editor")
    app.next()
    app.shot("36-handoff-diagnose", expect_screen=6)
    app.click('[data-action="copy-request-prompt"]', "依頼文をコピー")
    app.click('[data-action="open-run-folder"]', "ファイルの場所を開く")
    app.shot("37-handoff-diagnose-done", expect_screen=6)
    page.close()


def report_pass(ctx):
    report_files = sorted(OUT.glob("*-diff-report.html"))
    if not report_files:
        results.append(("40-report-light", "FAILED", "no diff html saved"))
        return
    page = ctx.new_page()
    page.goto(report_files[0].as_uri())
    page.wait_for_timeout(900)
    page.screenshot(path=str(OUT / "40-report-light.png"))
    results.append(("40-report-light", "ok", "diff report, light"))
    # The report's theme switch is an icon-only button in the module
    # toolbar (id set by diff-report.js).
    toggle = page.locator("#report-theme-toggle").first
    toggle.click()
    page.wait_for_timeout(500)
    page.screenshot(path=str(OUT / "41-report-dark.png"))
    results.append(("41-report-dark", "ok", "diff report, dark"))
    page.close()


def run(pw):
    browser = pw.chromium.launch()
    ctx = browser.new_context(viewport=VIEWPORT, device_scale_factor=2)
    ctx.add_init_script(
        "window.__MS_FIXTURES__ = "
        + json.dumps(FIXTURES, ensure_ascii=False) + ";")
    ctx.add_init_script(path=str(HERE / "mock.js"))

    errors = []
    ctx.on("page", lambda p: p.on(
        "pageerror", lambda e: errors.append(str(e))))

    refactor_pass(ctx)
    diagnose_pass(ctx)
    report_pass(ctx)

    browser.close()
    if errors:
        results.append(("pageerror", "FAILED", "; ".join(errors)[:200]))


def report():
    print("--- scenes ---")
    for name, status, detail in results:
        print("%-28s %-7s %s" % (name, status, detail))
    failed = [r for r in results if r[1] != "ok"]
    print("--- %d scenes, %d failed ---" % (len(results), len(failed)))


def main():
    httpd = serve()
    try:
        with sync_playwright() as pw:
            run(pw)
    finally:
        httpd.shutdown()
        report()


main()
