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
  "diff-report.js"
].forEach(function (file) {
  vm.runInContext(
    fs.readFileSync(
      path.join(__dirname, "..", "assets", "js", file),
      "utf8"),
    context);
});

var report = sandbox.window.MacroDeskDiffReport;
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
  html.indexOf("&lt;old&amp;&gt;") >= 0 &&
    html.indexOf("&lt;new&amp;&gt;") >= 0 &&
    html.indexOf("\"<old&>\"") < 0,
  "Diff report code is not HTML-escaped.");
assert(
  html.indexOf("2026-07-28 12:34:56") >= 0,
  "Diff report timestamp format mismatch.");
assert(
  (html.match(/class="module-report"/g) || []).length === 2,
  "Diff report did not include exactly the changed modules.");
assert(
  html.indexOf("UnchangedModule") < 0 &&
    html.indexOf("UNRELATED_MARKER") < 0,
  "Diff report included an unchanged module.");
assert(
  (html.match(
    /<tr class="diff-row diff-row--changed">/g) || []).length === 1,
  "Existing-module report does not use the screen diff result.");
assert(
  (html.match(
    /<tr class="diff-row diff-row--added">/g) || []).length === 2,
  "New-module report must compare against an empty source.");
assert(
  html.indexOf("<link") < 0 &&
    html.indexOf("<script") < 0 &&
    html.indexOf("http://") < 0 &&
    html.indexOf("https://") < 0 &&
    html.indexOf("url(") < 0 &&
    html.indexOf(" src=") < 0 &&
    html.indexOf(" href=") < 0,
  "Diff report has an external dependency.");

var withoutCrLf = html.replace(/\r\n/g, "");
assert(
  withoutCrLf.indexOf("\r") < 0 &&
    withoutCrLf.indexOf("\n") < 0,
  "Diff report line endings are mixed.");
assert(
  report.formatTimestamp("invalid") === "invalid",
  "Unexpected timestamps must not be silently replaced.");

console.log("test-diff-report: PASS");
