"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var windowObject = {};
var context = vm.createContext({
  window: windowObject
});
windowObject.window = windowObject;

vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "state.js"),
    "utf8"),
  context);

var state = windowObject.MacroDeskState;

state.setBook(
  {
    name: "sample.xlsm",
    path: "sample.xlsm",
    ext: ".xlsm"
  },
  [
    {
      name: "Module1",
      code: "Option Explicit\r\n",
      attributes: "Attribute VB_Name = \"Module1\"\r\n"
    },
    {
      name: "Module2",
      code: "Option Explicit\r\n"
    }
  ]);

assert(state.navigate(3), "Could not enter Step 3.");
assert(
  state.acceptModuleCode(
    "Module1",
    "Option Explicit\r\nDebug.Print 1\r\n",
    1),
  "Could not accept changed code.");

state.setLastError({
  code: "E-OLD",
  message: "Old error"
});
state.setBuildResult({
  status: "error"
});
state.setBuildConfirmation("20260728_010203");

assert(
  state.getState().buildTimestamp === "20260728_010203",
  "Build timestamp was not stored.");
assert(
  state.getState().buildResult === null,
  "New confirmation did not clear the prior build result.");
assert(
  state.getState().lastError === null,
  "New confirmation did not clear the prior error.");
assert(state.navigate(4), "Could not enter Step 4.");

state.setBuildResult({
  status: "success",
  outputPath: "sample_20260728_010203.xlsm",
  results: [
    {
      name: "Module1",
      result: "written",
      message: ""
    }
  ]
});
state.markModulesWritten(state.getState().buildResult.results);

assert(
  state.findModule("Module1").written === true,
  "Written result did not mark its module.");
assert(
  state.findModule("Module2").written === false,
  "Unreported module was marked written.");

assert(state.navigate(3), "Could not return to Step 3.");
assert(
  state.findModule("Module1").pastedCode.indexOf("Debug.Print") >= 0,
  "Step 4 round trip lost pasted code.");
assert(
  state.findModule("Module1").written === true,
  "Step 4 round trip lost the written badge.");

state.setBuildConfirmation("20260728_010204");
assert(
  state.getState().buildTimestamp === "20260728_010204",
  "Re-entry did not replace the build timestamp.");
assert(
  state.getState().buildResult === null,
  "Re-entry did not return to confirmation state.");

console.log("test-p7-state: PASS");
