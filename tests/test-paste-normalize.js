"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(
      message +
      "\nExpected: " + JSON.stringify(expected) +
      "\nActual:   " + JSON.stringify(actual));
  }
}

const windowObject = {
  MacroStudioState: {
    loadDemoState: function () {}
  }
};
const sandbox = {
  window: windowObject,
  document: {
    addEventListener: function () {}
  },
  Promise: Promise
};

vm.createContext(sandbox);
["diff.js", "vba-highlight.js", "diff-view.js", "app.js"].forEach(
  function (name) {
    vm.runInContext(
      fs.readFileSync(
        path.join(__dirname, "..", "assets", "js", name),
        "utf8"),
      sandbox);
  });

const normalize = windowObject.MacroStudioApp.normalizePastedText;

assertEqual(
  normalize("  \nOption Explicit\rDim x As Long\r\n\n"),
  "Option Explicit\r\nDim x As Long\r\n",
  "Newlines and outer blank lines were not normalized.");

assertEqual(
  normalize(
    "```vba\nOption Explicit\n```\nPrivate Sub Run()\nEnd Sub"),
  "Option Explicit\r\nPrivate Sub Run()\r\nEnd Sub\r\n",
  "Code fence lines were not removed.");

assertEqual(
  normalize(
    "\n  Attribute VB_Name = \"Module1\"\n" +
    "\nattribute vb_description = \"sample\"\n" +
    "Option Explicit\n" +
    "Attribute VB_ProcData.VB_Invoke_Func = \"x\\n14\"\n"),
  "Option Explicit\r\n" +
    "Attribute VB_ProcData.VB_Invoke_Func = \"x\\n14\"\r\n",
  "Only the leading Attribute block must be removed.");

assertEqual(
  normalize("Attribute VB_Name = \"Module1\"\n\n```"),
  "",
  "Attribute-only and fence-only input must normalize to empty.");

// Trailing whitespace in an answer.
//
// A model drops or adds spaces at the end of a line as it formats. Left
// in, the line differs from the workbook, counts as changed, and the
// diff draws one dot per invisible space at the end of code nobody
// touched. Only the end of the line is trimmed.

assertEqual(
  normalize("Option Explicit    \nDim x As Long\t\t\n"),
  "Option Explicit\r\nDim x As Long\r\n",
  "Trailing spaces and tabs must be trimmed from every line.");

assertEqual(
  normalize("    Dim total As Long    \n"),
  "    Dim total As Long\r\n",
  "The indent must survive: only the end of the line is trimmed.");

assertEqual(
  normalize("    a = b   +   c   \n"),
  "    a = b   +   c\r\n",
  "Spacing inside the line is the code's own and must not change.");

assertEqual(
  normalize("Dim s As String\ns = \"keep me  \"  \n"),
  "Dim s As String\r\ns = \"keep me  \"\r\n",
  "Spaces inside a string literal must not be touched.");

// A full-width space is a character of the code, not formatting.
assertEqual(
  normalize("Dim x As Long　\n"),
  "Dim x As Long　\r\n",
  "A full-width space must be left alone.");

// A line that is only whitespace still becomes empty, and the blank
// lines inside a module keep their places.
assertEqual(
  normalize("Sub A()\n   \nEnd Sub\n"),
  "Sub A()\r\n\r\nEnd Sub\r\n",
  "A whitespace-only line becomes empty without moving.");

// ---- and the point of it: no phantom change, no dots ----

const Diff = windowObject.MacroStudioDiff;
const View = windowObject.MacroStudioDiffView;
const original =
  "Option Explicit\r\n" +
  "Public Sub Boot()\r\n" +
  "    Dim total As Long\r\n" +
  "End Sub\r\n";
// The same code, formatted with trailing spaces and a trailing tab.
const answered = normalize(
  "Option Explicit  \n" +
  "Public Sub Boot()\t\n" +
  "    Dim total As Long    \n" +
  "End Sub\n");
const rows = Diff.compare(original, answered);
const changed = rows.filter(function (row) {
  return row.type !== "equal";
});

assertEqual(
  changed.length,
  0,
  "Trailing whitespace alone must not become a change.");
assertEqual(
  Diff.countChangedLines(rows),
  0,
  "Trailing whitespace alone must not be counted.");
assertEqual(
  View.hasWhitespaceOnlyChange(rows),
  false,
  "There is no whitespace-only change left to report.");

// The dots are drawn only inside the marked stretch of a changed row.
// With no changed row there is nothing to mark, so nothing to draw.
assertEqual(
  rows.some(function (row) {
    return row.type === "changed";
  }),
  false,
  "No changed row is left, so no whitespace marks can be drawn.");

assertEqual(
  normalize("  ```vba\nOption Explicit\n"),
  "  ```vba\r\nOption Explicit\r\n",
  "A fence marker not at the start of the line must remain.");

assertEqual(
  normalize("Option Explicit\n\nPrivate Sub Run()\n\nEnd Sub"),
  "Option Explicit\r\n\r\nPrivate Sub Run()\r\n\r\nEnd Sub\r\n",
  "Internal blank lines must be preserved.");

console.log("test-paste-normalize: PASS");
