"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var sandbox = {
  window: {},
  location: {
    search: ""
  }
};
var context = vm.createContext(sandbox);

[
  "diff.js",
  "vba-highlight.js",
  "diff-report.js"
].forEach(function (file) {
  vm.runInContext(
    fs.readFileSync(
      path.join(__dirname, "..", "assets", "js", file),
      "utf8"),
    context);
});

var report = sandbox.window.MacroStudioDiffReport;
var before =
  "Option Explicit\r\n" +
  "Public Sub Run()\r\n" +
  "    Debug.Print \"<old&>\"\r\n" +
  "End Sub\r\n";
var after =
  "Option Explicit\r\n" +
  "Public Sub Run()\r\n" +
  "    Debug.Print \"<new&>\"\r\n" +
  "End Sub\r\n";
var newCode =
  "Option Explicit\r\n" +
  "Public Sub SharedRun(): End Sub\r\n";
var html = report.buildReport({
  bookName: "Book<&>.xlsm",
  buildTimestamp: "20260728_123456",
  modules: [
    {
      name: "Module<&>",
      type: "standard",
      typeLabel: "標準モジュール",
      code: before,
      pastedCode: after,
      status: "changed"
    },
    {
      name: "UnchangedModule",
      type: "standard",
      typeLabel: "標準モジュール",
      code: "UNRELATED_MARKER\r\n",
      pastedCode: null,
      status: "pending"
    },
    {
      name: "CommonHelpers",
      type: "standard",
      typeLabel: "標準モジュール",
      code: "",
      pastedCode: newCode,
      status: "changed",
      isNew: true
    }
  ]
});

assert(
  html.indexOf("<!doctype html>") === 0,
  "Diff report doctype is missing.");
assert(
  html.indexOf("Book&lt;&amp;&gt;.xlsm") >= 0 &&
    html.indexOf("Module&lt;&amp;&gt;") >= 0,
  "Diff report metadata is not HTML-escaped.");
assert(
  html.indexOf("&lt;") >= 0 &&
    html.indexOf("old") >= 0 &&
    html.indexOf("new") >= 0 &&
    html.indexOf("&amp;&gt;") >= 0 &&
    html.indexOf("\"<old&>\"") < 0,
  "Diff report code is not HTML-escaped.");
assert(
  html.indexOf(
    'class="diff-inline-mark diff-inline-mark--removed"') >= 0 &&
    html.indexOf(
      'class="diff-inline-mark diff-inline-mark--added"') >= 0 &&
    html.indexOf('class="vba-token vba-token--string"') >= 0,
  "Diff report inline marks or syntax highlighting are missing.");
assert(
  html.indexOf("2026-07-28 12:34:56") >= 0,
  "Diff report timestamp format mismatch.");
// The report is a record of the whole workbook: an untouched module is
// there to be read, marked as unchanged.
assert(
  (html.match(/class="module-report"/g) || []).length === 3,
  "Diff report must cover every module of the workbook.");
assert(
  html.indexOf("UnchangedModule") >= 0 &&
    html.indexOf("UNRELATED_MARKER") >= 0,
  "Diff report must include the modules nobody changed.");
assert(
  html.indexOf('<p class="module-kicker">変更なし</p>') >= 0 &&
    html.indexOf('<p class="module-kicker">変更モジュール</p>') >= 0 &&
    html.indexOf('<p class="module-kicker">新規モジュール</p>') >= 0,
  "Every module must say which of the three states it is in.");
assert(
  html.indexOf("変更モジュール: 2 / 3") >= 0,
  "The summary must count the changed modules against the whole book.");

// ---- inline (unified) rows, the same shape as the screen diff ----

assert(
  html.indexOf('class="diff-row diff-row--changed"') < 0,
  "The report must not keep the two-column changed row.");
assert(
  (html.match(
    /<tr class="diff-row diff-row--removed">/g) || []).length === 1,
  "A changed line must produce exactly one removed row.");
assert(
  (html.match(
    /<tr class="diff-row diff-row--added">/g) || []).length === 3,
  "A changed line plus a two-line new module must add three rows.");
assert(
  html.indexOf('<td class="diff-marker" aria-hidden="true">-</td>') >= 0 &&
    html.indexOf('<td class="diff-marker" aria-hidden="true">+</td>') >= 0,
  "The report rows must carry the - and + markers.");
assert(
  html.indexOf('class="line-number line-number--old"') >= 0 &&
    html.indexOf('class="line-number line-number--new"') >= 0 &&
    html.indexOf("code-cell--left") < 0 &&
    html.indexOf("code-cell--right") < 0,
  "The report must use two gutters and one code column.");

// ---- the module tree on the left ----

assert(
  html.indexOf('class="module-tree"') >= 0 &&
    html.indexOf('class="tree-group-name">標準モジュール') >= 0,
  "The report is missing the module tree.");
assert(
  (html.match(/class="tree-link" href="#module-/g) || []).length === 3,
  "The tree must link to every module in the workbook.");
assert(
  html.indexOf('id="module-0"') >= 0 &&
    html.indexOf('id="module-1"') >= 0 &&
    html.indexOf('id="module-2"') >= 0,
  "Every module section needs the anchor its tree entry points at.");
assert(
  html.indexOf('<a class="tree-link" href="#module-2">' +
    '<span class="tree-name">CommonHelpers</span>') >= 0,
  "The tree entry must show the module name.");
// Three modules, counted in the tree and in their own header, plus the
// summary line at the top.
assert(
  (html.match(/class="count count--add">\+/g) || []).length === 7 &&
    (html.match(/class="count count--del">−/g) || []).length === 7,
  "Every module and the summary need an added and a removed count.");
assert(
  html.indexOf('class="count count--add">+3</span>') >= 0 &&
    html.indexOf('class="count count--del">−1</span>') >= 0,
  "The summary must total the per-module counts.");
assert(
  html.indexOf('class="count count--add">+2</span>') >= 0 &&
    html.indexOf('class="count count--del">−0</span>') >= 0,
  "A new module must count as two additions and no deletions.");

assert(
  html.indexOf("<link") < 0 &&
    html.indexOf("<script") < 0 &&
    html.indexOf("http://") < 0 &&
    html.indexOf("https://") < 0 &&
    html.indexOf("url(") < 0 &&
    html.indexOf(" src=") < 0,
  "Diff report has an external dependency.");
assert(
  (html.match(/ href="/g) || []).length ===
    (html.match(/ href="#/g) || []).length,
  "The report may only link to its own anchors.");
assert(
  html.indexOf("#F4F6F8") >= 0 &&
    html.indexOf("#1F2A37") >= 0 &&
    html.indexOf("#FBEDEE") >= 0 &&
    html.indexOf("#EAF5E7") >= 0 &&
    html.indexOf("#14171B") < 0 &&
    html.indexOf("data-theme") < 0,
  "Diff report must use the fixed light palette.");

var whitespaceHtml = report.buildReport({
  bookName: "Whitespace.xlsm",
  buildTimestamp: "20260728_123456",
  modules: [
    {
      name: "Whitespace",
      type: "standard",
      code: "    value\r\n",
      pastedCode: "\tvalue\r\n",
      status: "changed"
    }
  ]
});
assert(
  whitespaceHtml.indexOf("\u00B7") >= 0 &&
    whitespaceHtml.indexOf("\u2192") >= 0,
  "Diff report does not expose changed spaces and tabs.");

var withoutCrLf = html.replace(/\r\n/g, "");
assert(
  withoutCrLf.indexOf("\r") < 0 &&
    withoutCrLf.indexOf("\n") < 0,
  "Diff report line endings are mixed.");
assert(
  report.formatTimestamp("invalid") === "invalid",
  "Unexpected timestamps must not be silently replaced.");

console.log("test-diff-report: PASS");
