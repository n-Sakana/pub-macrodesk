"use strict";

// The written report is the review screen, read-only. It carries the
// app's diff engine, highlighter and diff view inside itself and renders
// with them, so what this test checks is the frame: the data that travels
// with the report, the escaping, the bundled code, and the absence of any
// external dependency or editing control.
//
// That the two views agree about rows and context lines is checked in
// tests\test-diff-report-toggle.js; that the controls really work is
// checked in tests\test-diff-report-webview.ps1.

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var root = path.resolve(__dirname, "..");
var sandbox = {
  window: {},
  location: { search: "" },
  JSON: JSON
};
var context = vm.createContext(sandbox);

[
  "diff.js",
  "vba-highlight.js",
  "diff-view.js",
  "diff-report.js"
].forEach(function (file) {
  vm.runInContext(
    fs.readFileSync(path.join(root, "assets", "js", file), "utf8"),
    context,
    { filename: file });
});

var report = sandbox.window.MacroStudioDiffReport;

// The same files the app hands over at build time.
var STYLE_FILES = [
  "css/variables.css",
  "css/flow.css",
  "css/module-list.css",
  "css/diff.css"
];
var SCRIPT_FILES = [
  "js/diff.js",
  "js/vba-highlight.js",
  "js/diff-view.js"
];

function readAsset(name) {
  return fs.readFileSync(
    path.join(root, "assets", name.replace("/", path.sep)),
    "utf8");
}

var assets = {
  css: STYLE_FILES.map(readAsset),
  js: SCRIPT_FILES.map(readAsset)
};

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
var modules = [
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
];

var html = report.buildReport({
  bookName: "Book<&>.xlsm",
  buildTimestamp: "20260728_123456",
  modules: modules,
  assets: assets
});

// ---- the document ----

assert(
  html.indexOf("<!doctype html>") === 0,
  "Diff report doctype is missing.");
assert(
  html.indexOf('data-theme="light"') >= 0,
  "The report must open in the light theme.");
assert(
  html.indexOf("Book&lt;&amp;&gt;.xlsm") >= 0,
  "Diff report metadata is not HTML-escaped.");
assert(
  html.indexOf("2026-07-28 12:34:56") >= 0,
  "Diff report timestamp format mismatch.");
assert(
  html.indexOf("変更モジュール: 2 / 3") >= 0,
  "The summary must count the changed modules against the whole book.");
assert(
  report.formatTimestamp("invalid") === "invalid",
  "Unexpected timestamps must not be silently replaced.");

// ---- the run travels as data, and cannot break out of the script ----

var dataMatch =
  /<script type="application\/json" id="report-data">\r\n([\s\S]*?)\r\n<\/script>/
    .exec(html);

assert(dataMatch !== null, "The report data island is missing.");
var data = JSON.parse(dataMatch[1]);

assert(
  data.modules.length === 3,
  "Every module of the workbook must travel with the report.");
assert(
  data.modules[0].name === "Module<&>" &&
    data.modules[0].before === before &&
    data.modules[0].after === after &&
    data.modules[0].changed === true,
  "A changed module must carry both sides of the comparison.");
assert(
  data.modules[1].name === "UnchangedModule" &&
    data.modules[1].changed === false &&
    data.modules[1].before === data.modules[1].after,
  "An untouched module travels with identical sides.");
assert(
  data.modules[2].isNew === true &&
    data.modules[2].before === "" &&
    data.modules[2].after === newCode,
  "A new module has no original side.");
assert(
  data.modules.every(function (module) {
    return module.typeLabel.length > 0 && module.type.length > 0;
  }),
  "Every module must carry its kind and its label.");
assert(
  dataMatch[1].indexOf("<") < 0,
  "The data island must not contain a raw '<': " +
    dataMatch[1].slice(0, 40));
assert(
  report.escapeJson("</script><b>").indexOf("</script") < 0,
  "escapeJson must neutralise a closing script tag.");

// ---- the app's own code is what renders it ----

assert(
  html.indexOf("MacroStudioDiffView") >= 0 &&
    html.indexOf("MacroStudioVbaHighlight") >= 0 &&
    html.indexOf("global.MacroStudioDiff =") >= 0,
  "The report must carry the app's diff code, not a copy of it.");
assert(
  html.indexOf(".diff-row--added .diff-code") >= 0 &&
    html.indexOf(".module-item") >= 0,
  "The report must carry the app's own stylesheet rules.");
assert(
  html.indexOf("@font-face") < 0 && html.indexOf("url(") < 0,
  "The bundled font declarations must be dropped: a report in an " +
    "output folder cannot resolve them.");
assert(
  report.stripFontFaces(
    "@font-face { src: url(x.ttf) }\n.a{color:red}") === ".a{color:red}",
  "stripFontFaces must remove only the font declarations.");

// A report cannot be built without that code: there is no reduced copy
// to fall back on.
[
  { css: assets.css, js: null },
  { css: null, js: assets.js },
  { css: [], js: assets.js },
  { css: assets.css, js: [""] }
].forEach(function (broken) {
  var refused = false;

  try {
    report.buildReport({
      bookName: "Book.xlsm",
      buildTimestamp: "20260728_123456",
      modules: modules,
      assets: broken
    });
  } catch (error) {
    refused = error.message.indexOf("bundle") >= 0;
  }
  assert(
    refused,
    "A report without the app's code must be refused: " +
      JSON.stringify(Object.keys(broken)));
});

// ---- nothing outside the file, nothing to edit ----

assert(
  html.indexOf("<link") < 0 &&
    html.indexOf("http://") < 0 &&
    html.indexOf("https://") < 0 &&
    html.indexOf(" src=") < 0,
  "Diff report has an external dependency.");
assert(
  html.indexOf(" href=") < 0,
  "The report needs no links at all.");
assert(
  html.indexOf("<textarea") < 0 &&
    html.indexOf("contenteditable") < 0 &&
    html.indexOf('type="text"') < 0 &&
    html.indexOf("改修概要") < 0,
  "The report must offer nothing to edit and no summary panel.");
assert(
  html.indexOf("変更内容を見る") < 0,
  "The report shows the diff from the start, with no disclosure.");
assert(
  html.indexOf("手動修正") < 0,
  "The manual fix belongs to the app, never to the report.");
assert(
  (html.match(/<script/g) || []).length === 2 &&
    html.indexOf('<script type="application/json"') >= 0,
  "The report carries exactly its data island and its own script.");
assert(
  html.indexOf("<noscript>") >= 0,
  "A reader with scripting off must be told why the page is empty.");

// ---- the controls the report offers ----

[
  "report-theme-toggle",
  "前の変更",
  "次の変更",
  "変更箇所のみ",
  "折り返し",
  "diff-change-counter"
].forEach(function (marker) {
  assert(
    html.indexOf(marker) >= 0,
    "The report is missing this control: " + marker);
});

// ---- the file itself ----

var withoutCrLf = html.replace(/\r\n/g, "");
assert(
  withoutCrLf.indexOf("\r") < 0 &&
    withoutCrLf.indexOf("\n") < 0,
  "Diff report line endings are mixed.");

// A run with nothing changed is not a report.
var refusedEmpty = false;

try {
  report.buildReport({
    bookName: "Book.xlsm",
    buildTimestamp: "20260728_123456",
    modules: [modules[1]],
    assets: assets
  });
} catch (error) {
  refusedEmpty = error.message.indexOf("changed modules") >= 0;
}
assert(
  refusedEmpty,
  "A report with no changed module must be refused.");

console.log("test-diff-report: PASS");
console.log(
  "the report travels as data, carries the app's own diff code, and " +
  "holds nothing external and nothing editable");
