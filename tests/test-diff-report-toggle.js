"use strict";

// The report and the review screen must never disagree about a diff.
//
// The report carries the app's own diff engine and diff view, so this
// test loads the bundle the report ships exactly as a browser would -
// from the report's own <script> - and checks that the code inside it is
// the same code the app runs, with the same context-line count, the same
// rows and the same change blocks.

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var root = path.resolve(__dirname, "..");

function readAsset(name) {
  return fs.readFileSync(
    path.join(root, "assets", name.replace("/", path.sep)),
    "utf8");
}

// ---- the app's own view ----

var appSandbox = { window: {} };
var appContext = vm.createContext(appSandbox);

["diff.js", "vba-highlight.js", "diff-view.js", "diff-report.js"].forEach(
  function (file) {
    vm.runInContext(
      readAsset("js/" + file),
      appContext,
      { filename: file });
  });

var appDiff = appSandbox.window.MacroStudioDiff;
var appView = appSandbox.window.MacroStudioDiffView;
var report = appSandbox.window.MacroStudioDiffReport;

function buildLines(count, prefix) {
  var lines = [];
  var index;

  for (index = 0; index < count; index += 1) {
    lines.push("    " + prefix + " " + index);
  }
  return lines.join("\r\n") + "\r\n";
}

var before = "Option Explicit\r\n" + buildLines(80, "Debug.Print");
var after = before.replace(
  "    Debug.Print 40",
  "    Debug.Print 40: Beep");
var modules = [
  {
    name: "Main",
    type: "standard",
    typeLabel: "標準モジュール",
    ext: "bas",
    lineCount: 81,
    code: before,
    pastedCode: after,
    status: "changed"
  },
  {
    name: "Untouched",
    type: "class",
    typeLabel: "クラスモジュール",
    ext: "cls",
    lineCount: 81,
    code: before,
    pastedCode: null,
    status: "pending"
  }
];

var html = report.buildReport({
  bookName: "book.xlsm",
  buildTimestamp: "20260730_010203",
  modules: modules,
  assets: {
    css: [
      "css/variables.css",
      "css/flow.css",
      "css/module-list.css",
      "css/diff.css"
    ].map(readAsset),
    js: ["js/diff.js", "js/vba-highlight.js", "js/diff-view.js"]
      .map(readAsset)
  }
});

// ---- the bundle inside the report, run on its own ----

var bundle = /<script>\r\n([\s\S]*)\r\n<\/script>/.exec(html);

assert(bundle !== null, "The report script bundle is missing.");

var reportSandbox = { window: {}, JSON: JSON };
var reportContext = vm.createContext(reportSandbox);

// The bundle ends with the report's own bootstrap, which waits for a
// document. Only the shared modules are needed here, so the bootstrap is
// dropped at the line where it starts.
var bootstrapAt = bundle[1].indexOf('(function () {\r\n  "use strict";');
var sharedSource = bootstrapAt > 0
  ? bundle[1].slice(0, bootstrapAt)
  : bundle[1];

assert(
  bootstrapAt > 0,
  "The report bundle must end with the report's own bootstrap.");
vm.runInContext(sharedSource, reportContext, { filename: "bundle.js" });

var bundledDiff = reportSandbox.window.MacroStudioDiff;
var bundledView = reportSandbox.window.MacroStudioDiffView;

assert(
  bundledDiff && typeof bundledDiff.compare === "function",
  "The report bundle must carry the diff engine.");
assert(
  bundledView && typeof bundledView.renderDiff === "function",
  "The report bundle must carry the diff view.");
assert(
  bundledView.contextLines === appView.contextLines,
  "The report keeps a different amount of context than the screen: " +
    bundledView.contextLines + " vs " + appView.contextLines);

// ---- the same rows, from the same inputs ----

var appRows = appDiff.compare(before, after);
var bundledRows = bundledDiff.compare(before, after);

assert(
  bundledRows.length === appRows.length,
  "The report produces a different number of rows: " +
    bundledRows.length + " vs " + appRows.length);
bundledRows.forEach(function (row, index) {
  var expected = appRows[index];

  assert(
    row.type === expected.type &&
      row.textA === expected.textA &&
      row.textB === expected.textB &&
      row.lineA === expected.lineA &&
      row.lineB === expected.lineB,
    "Row " + index + " differs between the report and the screen.");
});

assert(
  bundledView.assignChangeBlocks(bundledRows) ===
    appView.assignChangeBlocks(appRows),
  "The two views count change blocks differently.");
assert(
  bundledDiff.countChangedLines(bundledRows) ===
    appDiff.countChangedLines(appRows),
  "The two views count changed lines differently.");

// "Changes only" keeps exactly the same rows on both sides.
var appVisible = appView.getVisibleRows(appRows, true);
var bundledVisible = bundledView.getVisibleRows(bundledRows, true);

assert(
  appVisible.length === bundledVisible.length,
  "The changes-only view keeps a different number of entries.");
appVisible.forEach(function (entry, index) {
  var other = bundledVisible[index];

  assert(
    entry.type === other.type,
    "The changes-only view differs at entry " + index);
  if (entry.type === "gap") {
    assert(
      entry.count === other.count,
      "A collapsed stretch has a different size at " + index);
  }
});
assert(
  appVisible.some(function (entry) {
    return entry.type === "gap";
  }),
  "This module must be long enough to collapse something.");
assert(
  appVisible.filter(function (entry) {
    return entry.type !== "gap";
  }).length < appRows.length,
  "The changes-only view must actually leave rows out.");

// ---- the report holds no second implementation ----

var reportSource = readAsset("js/diff-report.js");

[
  "function expandRow",
  "function buildInlineRow",
  "function buildCodeCell",
  "function planRows",
  "CONTEXT_LINES"
].forEach(function (marker) {
  assert(
    reportSource.indexOf(marker) < 0,
    "diff-report.js must not re-implement the diff view: " + marker);
});
assert(
  reportSource.indexOf("MacroStudioDiffView.renderDiff") >= 0,
  "The report must render with the shared view.");

console.log("test-diff-report-toggle: PASS");
console.log(
  "the code the report ships is the code the app runs: same context, " +
  "same rows, same change blocks, no second implementation");
