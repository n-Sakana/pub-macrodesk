"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const windowObject = {};
const sandbox = {
  window: windowObject
};

vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "state.js"),
    "utf8"),
  sandbox);

const state = windowObject.MacroDeskState;
state.setBook(
  {
    name: "sample.xlsm",
    path: "C:\\sample.xlsm",
    ext: ".xlsm"
  },
  [
    {
      name: "Module1",
      type: "standard",
      lineCount: 2,
      code: "Option Explicit\r\nEnd\r\n"
    },
    {
      name: "Module2",
      type: "standard",
      lineCount: 1,
      code: "Option Explicit\r\n"
    }
  ]);

assert(state.navigate(3), "Could not navigate to Step 3.");
assert(state.selectModule("Module1"), "Could not select Module1.");
assert(
  state.acceptModuleCode(
    "Module1",
    "Option Explicit\r\nEnd\r\n",
    0).status === "unchanged",
  "Identical code must enter unchanged status.");
assert(
  state.getChangedModuleCount() === 0,
  "Unchanged code must not enable Step 4.");
assert(
  state.getTransitionRow()[4] === false,
  "Step 4 was enabled by unchanged code.");

assert(state.cancelModulePaste("Module1"), "Undo failed.");
assert(
  state.acceptModuleCode(
    "Module1",
    "Option Explicit\r\nDebug.Print 1\r\nEnd\r\n",
    2).status === "changed",
  "Changed code must enter changed status.");
assert(
  state.getChangedModuleCount() === 1,
  "Changed-module count mismatch.");
assert(
  state.getTransitionRow()[4] === true,
  "Changed code did not enable Step 4.");
assert(
  state.setModuleShowChangesOnly("Module1", true),
  "Changes-only state was not stored.");
assert(
  state.getState().modules[0].showChangesOnly === true,
  "Changes-only state mismatch.");
assert(
  state.toggleModuleExcluded("Module1") === false,
  "Confirmed module must be undone before exclusion.");

assert(state.navigate(2), "Could not return to Step 2.");
assert(state.navigate(3), "Could not return to Step 3.");
assert(
  state.getState().selectedModuleName === "Module1",
  "Step round trip lost module selection.");
assert(
  state.findModule("Module1").pastedCode.indexOf("Debug.Print") >= 0,
  "Step round trip lost pasted code.");

assert(state.cancelModulePaste("Module1"), "Second undo failed.");
assert(
  state.toggleModuleExcluded("Module1"),
  "Pending module could not be excluded.");
assert(
  state.acceptModuleCode("Module1", "changed\r\n", 1) === null,
  "Excluded module accepted pasted code.");
assert(
  state.toggleModuleExcluded("Module1"),
  "Excluded module could not be restored.");
assert(
  state.findModule("Module1").status === "pending",
  "Exclusion release did not restore pending status.");

console.log("test-p6-state: PASS");
