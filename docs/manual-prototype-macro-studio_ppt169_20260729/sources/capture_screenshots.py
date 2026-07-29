"""Capture the current MacroDesk UI from its own ?demo=1 fixture.

Nothing in the repository is modified: the assets folder is served read-only
over http://127.0.0.1:8899 and the browser only calls the app's own public
state API (MacroDeskState / MacroDeskApp) to move between the 12 screens.
"""
import io
import pathlib
import sys

from playwright.sync_api import sync_playwright

REPO = pathlib.Path(r"C:\repos\pub\pub-macrodesk")
OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

PRESET = (REPO / "presets" / "サンプル_新端末移行.md").read_text(encoding="utf-8")
TEMPLATE = (REPO / "templates" / "request-template.txt").read_text(encoding="utf-8")

# Build the prompt exactly the way prompt-template.js does, from the demo book.
SETUP = """
(function (preset) {
  "use strict";
  var S = window.MacroDeskState;
  var st = S.getState();
  var parsed = window.MacroDeskPreset.parse(preset);

  st.appInfo = {
    version: "1.0",
    buildFileLabel: "macrodesk",
    presets: [{ file: "サンプル_新端末移行.md", content: preset }]
  };
  st.method = "preset";
  st.presetFile = "サンプル_新端末移行.md";
  st.requestText = parsed.instruction.body;
  st.outputRules = {
    presetFile: "サンプル_新端末移行.md",
    presetName: parsed.name,
    title: parsed.output.title,
    body: parsed.output.body
  };
  st.requestFilePath =
    "samples\\\\MacroDesk\\\\受注管理_20260729_101500\\\\source-code.md";
  return parsed.name;
})
"""

SHOTS = [
    # (file stem, js run before the shot, screen index)
    ("s02-book-loaded", None, 1),
    ("s03-method", None, 2),
    ("s04-preset-list", None, 3),
    ("s05-request-editor", None, 4),
    ("s06-handoff", None, 5),
    (
        "s07-intake",
        """
        var S = window.MacroDeskState, st = S.getState();
        st.selectedModuleName = "Main";
        st.modules.forEach(function (m) {
          if (m.name === "Main") { m.status = "pending"; m.pastedCode = null; }
        });
        """,
        6,
    ),
    (
        "s08-intake-done",
        """
        var S = window.MacroDeskState, st = S.getState();
        st.modules.forEach(function (m) {
          if (m.name === "Main") {
            m.status = "changed"; m.changedLineCount = 4; m.accepted = false;
            m.pastedCode = 'Option Explicit\\r\\n\\r\\nPrivate Sub SaveRecord()' +
              '\\r\\n    If Len(Trim$(Range("A2").Value)) = 0 Then\\r\\n' +
              '        MsgBox "\\u4f1d\\u7968\\u756a\\u53f7\\u3092\\u5165\\u529b' +
              '\\u3057\\u3066\\u304f\\u3060\\u3055\\u3044\\u3002"\\r\\n' +
              '        Exit Sub\\r\\n    End If\\r\\n' +
              '    Range("D2").Value = Now\\r\\nEnd Sub\\r\\n';
          }
        });
        """,
        6,
    ),
    ("s09-diff", None, 7),
    (
        "s10-diff-accepted",
        """window.MacroDeskState.acceptModuleChange("Main");""",
        7,
    ),
    ("s11-accepted-summary", None, 8),
    ("s12-output-name", None, 9),
    ("s13-building", """window.MacroDeskState.setBusyAction("buildBook");""", 10),
    (
        "s14-done",
        """
        // Order matters: keep busyAction set until we have left screen 10,
        // otherwise render() re-enters buildBook() on every notify.
        var S = window.MacroDeskState;
        S.setBuildResult({
          status: "success", success: true,
          outputPath: "samples\\\\MacroDesk\\\\\\u53d7\\u6ce8\\u7ba1\\u7406" +
            "_20260729_101500\\\\\\u53d7\\u6ce8\\u7ba1\\u7406_macrodesk.xlsm",
          diffPath: "samples\\\\MacroDesk\\\\\\u53d7\\u6ce8\\u7ba1\\u7406" +
            "_20260729_101500\\\\diff-report.html",
          results: [], diffError: ""
        });
        S.goTo(11, false);
        S.setBusyAction(null);
        """,
        11,
    ),
    # Captured last: reset() clears the demo book, so nothing may follow it.
    ("s01-book-drop", "window.MacroDeskState.reset();", 0),
]


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(
            viewport={"width": 1366, "height": 768},
            device_scale_factor=2,
        )
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.goto("http://127.0.0.1:8899/index.html?demo=1")
        page.wait_for_selector(".screen", timeout=15000)
        name = page.evaluate(SETUP, PRESET)
        print("preset parsed as:", name)

        for stem, js, screen in SHOTS:
            if js:
                page.evaluate("(function(){%s}())" % js)
            page.evaluate(
                "(function(n){ var S=window.MacroDeskState;"
                "  if (S.getState().screen !== n) { S.goTo(n, false); }"
                "  else { window.MacroDeskApp.render(S.getState()); } }(%d))"
                % screen
            )
            # The browser harness has no WebView2 host, so loadAppInfo()
            # leaves an "unavailable host" toast that the real app never
            # shows at this point. Drop it before the shot.
            page.evaluate(
                "document.getElementById('toast-region').textContent = '';"
            )
            page.wait_for_timeout(450)
            path = OUT / (stem + ".png")
            page.screenshot(path=str(path))
            print("wrote", path.name, path.stat().st_size, "bytes")

        browser.close()
        if errors:
            print("PAGE ERRORS:", *errors, sep="\n  ")


main()
