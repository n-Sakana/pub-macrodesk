"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var root = path.resolve(__dirname, "..");
var windowObject = {};
var context = vm.createContext({
  window: windowObject,
  document: {
    addEventListener: function () {},
    createElement: function () {
      return {};
    },
    getElementById: function () {
      return null;
    },
    querySelector: function () {
      return null;
    }
  },
  Promise: Promise,
  Uint8Array: Uint8Array,
  Math: Math,
  setTimeout: setTimeout,
  clearTimeout: clearTimeout
});
windowObject.window = windowObject;
windowObject.document = context.document;
windowObject.setTimeout = setTimeout;
windowObject.clearTimeout = clearTimeout;
windowObject.console = { error: function () {} };
windowObject.hostBridge = {
  request: function () {
    return Promise.resolve(null);
  },
  on: function () {
    return function () {};
  }
};

["handover.js",
  "diff.js",
  "diff-view.js",
  "vba-highlight.js",
  "preset-document.js",
  "response-package.js",
  "diagnosis-package.js",
  "prompt-template.js",
  "screens.js",
  "state.js",
  "app.js"
].forEach(function (name) {
  vm.runInContext(
    fs.readFileSync(path.join(root, "assets", "js", name), "utf8"),
    context,
    { filename: name });
});

var app = windowObject.MacroStudioApp;
var validContent = [
  "# 診断",
  "",
  "## 説明",
  "",
  "事実を監査します。",
  "",
  "## 改修指示",
  "",
  "事実を読んでください。",
  "",
  "## 出力指示",
  "",
  "契約で返してください。"
].join("\n");
var invalidContent = "見出しがありません。";

function info(diagnose) {
  return {
    version: "test",
    presets: {
      diagnose: diagnose,
      repair: []
    }
  };
}

function preset(file, content) {
  return { file: file, content: content };
}

var none = app.resolveDiagnosisPreset(info([]));
var one = app.resolveDiagnosisPreset(info([
  preset("01_診断\\one.md", validContent)
]));
var two = app.resolveDiagnosisPreset(info([
  preset("01_診断\\one.md", validContent),
  preset("01_診断\\two.md", validContent.replace("# 診断", "# 診断2"))
]));
var oneAndBroken = app.resolveDiagnosisPreset(info([
  preset("01_診断\\one.md", validContent),
  preset("01_診断\\broken.md", invalidContent)
]));

assert(
  !none.ok && none.code === "E-PRESET-02" && none.validCount === 0,
  "Zero valid diagnosis presets must stop with E-PRESET-02.");
assert(
  one.ok && one.code === "" && one.validCount === 1 &&
    one.entry.file === "01_診断\\one.md",
  "Exactly one valid diagnosis preset must be selected.");
assert(
  !two.ok && two.code === "E-PRESET-02" && two.validCount === 2,
  "Two valid diagnosis presets must stop with E-PRESET-02.");
assert(
  oneAndBroken.ok && oneAndBroken.validCount === 1 &&
    oneAndBroken.entries.length === 2 &&
    oneAndBroken.entries[1].valid === false,
  "Cardinality must count valid files while retaining invalid diagnostics.");

console.log("test-diagnosis-preset-cardinality: PASS");
console.log("0/1/2 valid files and invalid-file visibility: PASS");
