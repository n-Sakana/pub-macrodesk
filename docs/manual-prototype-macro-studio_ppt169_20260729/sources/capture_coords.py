"""Dump real element coordinates from each MacroDesk demo screen.

Reuses shoot.py's state setup, then reports CSS-pixel boxes (viewport
1366x768) for the elements the manual annotates, so the SVG callouts land
on the actual controls instead of estimated positions.
"""
import json
import pathlib
import sys

import shoot  # noqa: F401  (only for its constants)
from playwright.sync_api import sync_playwright

# page key -> list of (label, selector, nth)
TARGETS = {
    "s01": [("dropzone", ".drop-zone", 0), ("next", "[data-action='go-next']", 0)],
    "s02": [
        ("filecard", ".file-card", 0),
        ("stat1", ".stat-card", 0),
        ("stat3", ".stat-card", 2),
        ("strip", ".module-strip", 0),
    ],
    "s03": [("c1", ".choice-card", 0), ("c2", ".choice-card", 1)],
    "s04": [("p1", ".preset", 0), ("list", ".preset-list", 0)],
    "s05": [
        ("editor", ".request-editor", 0),
        ("meta", ".editor-meta", 0),
        ("rules", ".output-rules-details", 0),
    ],
    "s06": [
        ("card1", ".handoff-card", 0),
        ("card2", ".handoff-card", 1),
        ("folder", ".folder-contract", 0),
    ],
    "s07": [("pane", ".module-pane", 0), ("target", ".paste-target", 0)],
    "s08": [("target", ".paste-target", 0)],
    "s09": [
        ("gutter", ".diff-line-numbers, .diff-gutter", 0),
        ("toolbar", ".diff-toolbar, .panel-header", 0),
        ("row", ".diff-row, .diff-line", 3),
    ],
    "s10": [("pane", ".module-pane", 0), ("decision", ".review-decision", 0)],
    "s11": [("grid", ".summary-grid", 0), ("table", ".build-panel, .accepted-table", 0)],
    "s12": [("input", "#output-name", 0), ("folder", ".folder-contract", 0)],
    "s14": [
        ("path", ".folder-path", 0),
        ("open", "[data-action='open-run-folder']", 0),
        ("list", ".result-list", 0),
    ],
}

OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("coords.json")


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1366, "height": 768})
        page.goto("http://127.0.0.1:8899/index.html?demo=1")
        page.wait_for_selector(".screen", timeout=15000)
        page.evaluate(shoot.SETUP, shoot.PRESET)

        result = {}
        for stem, js, screen in shoot.SHOTS:
            key = stem.split("-")[0]
            if js:
                page.evaluate("(function(){%s}())" % js)
            page.evaluate(
                "(function(n){ var S=window.MacroDeskState;"
                "  if (S.getState().screen !== n) { S.goTo(n, false); }"
                "  else { window.MacroDeskApp.render(S.getState()); } }(%d))" % screen
            )
            page.wait_for_timeout(350)
            if key not in TARGETS:
                continue
            boxes = {}
            for label, selector, nth in TARGETS[key]:
                try:
                    el = page.locator(selector).nth(nth)
                    box = el.bounding_box(timeout=1500)
                except Exception as exc:
                    box = None
                    print("  !", key, label, type(exc).__name__)
                if box:
                    boxes[label] = {k: round(v, 1) for k, v in box.items()}
            result[key] = boxes
            print(key, json.dumps(boxes, ensure_ascii=False))
        browser.close()
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", OUT)


main()
