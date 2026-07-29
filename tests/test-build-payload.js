"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(
      message +
      "\nExpected: " + JSON.stringify(expected) +
      "\nActual:   " + JSON.stringify(actual));
  }
}

var windowObject = {
  MacroStudioState: {
    loadDemoState: function () {}
  }
};
var context = vm.createContext({
  window: windowObject,
  document: {
    addEventListener: function () {}
  },
  Promise: Promise
});

vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "app.js"),
    "utf8"),
  context);

var app = windowObject.MacroStudioApp;
var attributes = "Attribute VB_Name = \"Module1\"\r\n";
var normalized =
  "Option Explicit\r\n" +
  "Public Sub Run(): End Sub\r\n";
var state = {
  modules: [
    {
      name: "Module1",
      status: "changed",
      accepted: true,
      attributes: attributes,
      pastedCode: normalized
    },
    {
      name: "ModulePending",
      status: "changed",
      accepted: false,
      attributes: "Attribute VB_Name = \"ModulePending\"\r\n",
      pastedCode: "Option Explicit\r\n"
    },
    {
      name: "Module2",
      status: "unchanged",
      attributes: "Attribute VB_Name = \"Module2\"\r\n",
      pastedCode: "Option Explicit\r\n"
    },
    {
      name: "Module3",
      status: "excluded",
      attributes: "Attribute VB_Name = \"Module3\"\r\n",
      pastedCode: null
    }
  ]
};

assertEqual(
  app.createOutputTimestamp(new Date(2026, 6, 8, 1, 2, 3)),
  "20260708_010203",
  "Output timestamp format mismatch.");
assertEqual(
  app.createBuildOutputName(
    {
      name: "sample.xlsm",
      ext: ".xlsm"
    },
    "20260708_010203",
    "改修済"),
  "sample_改修済_20260708_010203.xlsm",
  "Build output name mismatch.");
assertEqual(
  app.createBuildOutputName(
    {
      name: "SAMPLE.XLSM",
      ext: ".xlsm"
    },
    "20260708_010203",
    "改修済"),
  "SAMPLE_改修済_20260708_010203.xlsm",
  "Extension removal must be case-insensitive.");
assertEqual(
  app.createBuildOutputName(
    {
      name: "sample.xlsm",
      ext: ".xlsm"
    },
    "20260708_010203",
    "確認済"),
  "sample_確認済_20260708_010203.xlsm",
  "Build output name ignored the host-provided label.");
assertEqual(
  app.getHostErrorMessage({
    code: "E-SYS-02",
    data: {
      userMessage: "ひな形は UTF-8 で保存してください。"
    }
  }),
  "ひな形は UTF-8 で保存してください。",
  "Safe host-provided user message was not displayed.");

assertEqual(
  app.joinFinalCode(attributes, normalized),
  attributes + normalized,
  "CRLF-terminated attributes gained an extra blank line.");
assertEqual(
  app.joinFinalCode(
    "Attribute VB_Name = \"Module1\"",
    normalized),
  attributes + normalized,
  "Missing Attribute boundary CRLF was not supplied.");
assertEqual(
  app.joinFinalCode("", normalized),
  normalized,
  "Empty attributes added a leading line.");

var modules = app.createBuildModules(state);
assert(modules.length === 1, "Only accepted modules may be built.");
assertEqual(modules[0].name, "Module1", "Build module name mismatch.");
assertEqual(
  modules[0].code,
  attributes + normalized,
  "Build module final code mismatch.");
assertEqual(
  state.modules[0].attributes,
  attributes,
  "Build payload creation changed the retained attributes.");

var newModules = app.createBuildModules({
  modules: [
    {
      name: "CommonHelpers",
      status: "changed",
      accepted: true,
      attributes: "",
      pastedCode: normalized,
      isNew: true
    }
  ]
});
assert(newModules.length === 1, "New module build payload is missing.");
assertEqual(
  newModules[0].name,
  "CommonHelpers",
  "New module build name mismatch.");
assertEqual(
  newModules[0].code,
  normalized,
  "New module build payload must not synthesize Attributes in JS.");
assertEqual(
  newModules[0].isNew,
  true,
  "New module build payload is not explicitly marked.");

assertEqual(
  app.getNewModuleNameError(state, "共通処理"),
  "",
  "A valid Unicode VBA identifier was rejected.");
assert(
  app.getNewModuleNameError(state, "1Broken").length > 0,
  "An invalid VBA identifier was accepted.");
assert(
  app.getNewModuleNameError(state, "module1").length > 0,
  "A case-insensitive duplicate module name was accepted.");

var threw = false;
try {
  app.createBuildModules({
    modules: [
      {
        name: "Broken",
        status: "changed",
        accepted: true,
        pastedCode: null
      }
    ]
  });
} catch (error) {
  threw = true;
}
assert(threw, "Missing accepted code must produce an explicit error.");

console.log("test-build-payload: PASS");
