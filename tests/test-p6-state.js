"use strict";

// Module-level state after a package comes in: statuses, per-module
// view flags, the manual fix, and what a discard leaves behind.
// Screen order and next-enabled conditions live in test-flow-state.js.

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
["response-package.js", "screens.js", "state.js"].forEach(function (name) {
  vm.runInContext(
    fs.readFileSync(
      path.join(__dirname, "..", "assets", "js", name),
      "utf8"),
    sandbox,
    { filename: name });
});

const state = windowObject.MacroStudioState;
const screens = windowObject.MacroStudioScreens;
const reviewScreen = screens.reviewScreen;

function attach() {
  state.reset();
  state.setBook(
    {
      name: "sample.xlsm",
      path: "sample.xlsm",
      ext: ".xlsm"
    },
    [
      {
        name: "Module1",
        type: "standard",
        typeLabel: "標準モジュール",
        ext: "bas",
        lineCount: 2,
        code: "Option Explicit\r\nEnd\r\n",
        attributes: ""
      },
      {
        name: "Module2",
        type: "standard",
        typeLabel: "標準モジュール",
        ext: "bas",
        lineCount: 1,
        code: "Option Explicit\r\n",
        attributes: ""
      },
      {
        name: "OrderRecord",
        type: "class",
        typeLabel: "クラスモジュール",
        ext: "cls",
        lineCount: 1,
        code: "Option Explicit\r\n",
        attributes: "Attribute VB_Name = \"OrderRecord\"\r\n"
      }
    ]);
}

// ---- an answer that changes nothing is still an answer ----

attach();
state.importPackage([
  {
    name: "Module1",
    code: "Option Explicit\r\nEnd\r\n",
    changedLineCount: 0,
    lineCount: 2
  }
]);
assert(
  state.findModule("Module1").status === "unchanged",
  "Identical code must enter unchanged status.");
assert(
  state.getChangedModuleCount() === 0,
  "Unchanged code must not count as a change.");
assert(
  state.getAcceptedModuleCount() === 0,
  "Unchanged code must not become a written change.");

// ---- a package that changes code, adds a module and keeps a class ----

attach();
assert(
  state.importPackage([
    {
      name: "Module1",
      code: "Option Explicit\r\nDebug.Print 1\r\nEnd\r\n",
      changedLineCount: 2,
      lineCount: 3
    },
    {
      name: "OrderRecord",
      code: "Option Explicit\r\nPrivate mId As String\r\n",
      changedLineCount: 1,
      lineCount: 2
    },
    {
      name: "CommonHelpers",
      code: "Option Explicit\r\nPublic Sub Run(): End Sub\r\n",
      changedLineCount: 2,
      lineCount: 2
    }
  ]) === 3,
  "The package must apply every module at once.");

assert(
  state.getChangedModuleCount() === 3,
  "Changed-module count mismatch.");
assert(
  state.findModule("OrderRecord").type === "class" &&
    state.findModule("OrderRecord").ext === "cls",
  "An existing class module must keep its kind and extension.");
assert(
  state.findModule("OrderRecord").attributes.length > 0,
  "An existing class module must keep its attribute header.");

const added = state.findModule("CommonHelpers");
assert(added !== null, "The new module was not added.");
assert(
  added.isNew === true &&
    added.type === "standard" &&
    added.ext === "bas" &&
    added.status === "changed",
  "A module the answer adds must be a standard module.");

assert(
  state.getAcceptedModuleCount() === 3,
  "Everything the package changed is written back.");

// ---- per-module view flags ----

assert(
  state.setModuleShowChangesOnly("Module1", true),
  "Changes-only state was not stored.");
assert(
  state.findModule("Module1").showChangesOnly === true,
  "Changes-only state mismatch.");
assert(
  state.setModuleWrapDiff("Module1", false),
  "Wrap state was not stored.");
assert(
  state.findModule("Module1").wrapDiff === false,
  "Wrap state mismatch.");
assert(
  state.setModuleShowChangesOnly("Module2", true) === false,
  "A module that took nothing in has no diff to filter.");

// ---- moving between screens keeps what came in ----

assert(state.goTo(reviewScreen, false), "Could not open the review screen.");
assert(state.selectModule("Module1"), "Could not select Module1.");
assert(
  state.goTo(screens.intakeScreen, false) &&
    state.goTo(reviewScreen, false),
  "Could not move between intake and review.");
assert(
  state.getState().selectedModuleName === "Module1",
  "The screen round trip lost the module selection.");
assert(
  state.findModule("Module1").pastedCode.indexOf("Debug.Print") >= 0,
  "The screen round trip lost the imported code.");

// ---- the manual fix belongs to the review screen ----

assert(state.beginPasteEdit(), "A changed module must enter manual edit.");
assert(
  state.getState().pasteEditing === true,
  "Manual edit state was not stored.");
assert(
  state.acceptModuleCode(
    "Module1",
    "Option Explicit\r\nDebug.Print 2\r\nEnd\r\n",
    2).status === "changed",
  "The manual fix must be taken as changed code.");
assert(
  state.getState().pasteEditing === false,
  "Applying the manual fix must leave edit mode.");
assert(
  state.findModule("Module1").accepted === true,
  "A module fixed by hand stays in the build.");

// ---- discarding takes the whole answer back out ----

assert(
  state.discardImportedModules() === 3,
  "Discarding must cover every imported module.");
assert(
  state.findModule("CommonHelpers") === null,
  "Discarding must remove the modules the answer added.");
assert(
  state.findModule("Module1").status === "pending" &&
    state.findModule("Module1").pastedCode === null,
  "Discarding must return an existing module to its original code.");
assert(
  state.findModule("OrderRecord").type === "class",
  "Discarding must not disturb the kinds the workbook has.");
assert(
  state.getState().intakeResult === null,
  "Discarding must clear the intake summary.");

console.log("test-p6-state: PASS");
