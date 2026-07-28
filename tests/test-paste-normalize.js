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
  MacroDeskState: {
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
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "app.js"),
    "utf8"),
  sandbox);

const normalize = windowObject.MacroDeskApp.normalizePastedText;

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

assertEqual(
  normalize("  ```vba\nOption Explicit\n"),
  "  ```vba\r\nOption Explicit\r\n",
  "A fence marker not at the start of the line must remain.");

assertEqual(
  normalize("Option Explicit\n\nPrivate Sub Run()\n\nEnd Sub"),
  "Option Explicit\r\n\r\nPrivate Sub Run()\r\n\r\nEnd Sub\r\n",
  "Internal blank lines must be preserved.");

console.log("test-paste-normalize: PASS");
