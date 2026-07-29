"use strict";

// The manual fix: a small correction to code that came in with the
// package, made on the review screen and applied to one module.

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

[
  "response-package.js",
  "screens.js",
  "state.js"
].forEach(function (name) {
  vm.runInContext(
    fs.readFileSync(
      path.join(__dirname, "..", "assets", "js", name),
      "utf8"),
    context,
    { filename: name });
});

var state = windowObject.MacroStudioState;
var screens = windowObject.MacroStudioScreens;
var reviewScreen = screens.reviewScreen;
var intakeScreen = screens.intakeScreen;

function setup() {
  state.reset();
  state.setBook(
    {
      name: "sample.xlsm",
      path: "sample.xlsm",
      ext: ".xlsm",
      totalLines: 3
    },
    [
      {
        name: "Main",
        type: "standard",
        typeLabel: "標準モジュール",
        ext: "bas",
        lineCount: 2,
        code: "Option Explicit\r\nSub A(): End Sub\r\n",
        attributes: ""
      },
      {
        name: "Helper",
        type: "standard",
        typeLabel: "標準モジュール",
        ext: "bas",
        lineCount: 1,
        code: "Option Explicit\r\n",
        attributes: ""
      }
    ]);
  state.goTo(intakeScreen, false);
  state.goTo(reviewScreen, false);
}

function importMain(code, changedLineCount, lineCount) {
  state.importPackage([
    {
      name: "Main",
      code: code,
      changedLineCount: changedLineCount,
      lineCount: lineCount
    }
  ]);
}

// Editing requires a module that came in with the package.
setup();
state.selectModule("Main");
assert(
  state.beginPasteEdit() === false,
  "A module with nothing imported must not enter manual edit.");
assert(
  state.getState().pasteEditing === false,
  "pasteEditing must stay false for untouched modules.");

importMain("Option Explicit\r\nSub A(): Beep: End Sub\r\n", 1, 2);
state.selectModule("Main");
assert(
  state.getState().pasteEditing === false,
  "Taking a package in must not enter manual edit by itself.");
assert(
  state.beginPasteEdit() === true,
  "A changed module must enter manual edit.");
assert(
  state.getState().pasteEditing === true,
  "pasteEditing must be true after beginPasteEdit.");
assert(
  state.canGoNext() === false,
  "The fixed next button must stay off while an edit is open.");

// Applying (via acceptModuleCode) ends the edit session.
state.acceptModuleCode(
  "Main",
  "Option Explicit\r\nSub A(): Beep: Beep: End Sub\r\n",
  1);
assert(
  state.getState().pasteEditing === false,
  "acceptModuleCode must end the edit session.");
assert(
  state.findModule("Main").accepted === true,
  "Code fixed by hand stays in the build.");

// Selecting another module ends the edit session.
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.selectModule("Helper");
assert(
  state.getState().pasteEditing === false,
  "Selecting another module must end the edit session.");

// Navigating away ends the edit session.
state.selectModule("Main");
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.goTo(intakeScreen, false);
assert(
  state.getState().pasteEditing === false,
  "Navigation must end the edit session.");

// Manual edit belongs to the review screen only.
assert(
  state.beginPasteEdit() === false,
  "The intake screen must not open the manual fix.");

// Discarding the package ends the edit session.
state.goTo(reviewScreen, false);
state.selectModule("Main");
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.discardImportedModules();
assert(
  state.getState().pasteEditing === false,
  "Discarding the package must end the edit session.");
assert(
  state.findModule("Main").status === "pending",
  "Discarding must return the module to its original code.");

// cancelPasteEdit is idempotent and only reports an active session.
assert(
  state.cancelPasteEdit() === false,
  "cancelPasteEdit must report no active session.");
importMain("Option Explicit\r\nSub A(): Beep: End Sub\r\n", 1, 2);
state.selectModule("Main");
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
assert(
  state.cancelPasteEdit() === true,
  "cancelPasteEdit must end an active session.");
assert(
  state.getState().pasteEditing === false,
  "cancelPasteEdit must clear pasteEditing.");

// New modules stay new through an edit, and their line count follows
// the accepted code.
state.importPackage([
  {
    name: "WaitUtils",
    code: "Public Sub WaitMs()\r\nEnd Sub\r\n",
    changedLineCount: 2,
    lineCount: 2
  }
]);
state.selectModule("WaitUtils");
assert(state.beginPasteEdit() === true, "Editing a new module failed.");
state.acceptModuleCode(
  "WaitUtils",
  "Public Sub WaitMs()\r\n    DoEvents\r\nEnd Sub\r\n",
  3);
var edited = state.findModule("WaitUtils");
assert(
  edited.isNew === true,
  "Editing must not clear the new-module marker.");
assert(
  edited.lineCount === 3,
  "A new module's line count must follow the accepted code.");
assert(
  edited.status === "changed",
  "The edited new module must stay changed.");

// setBook resets the editing state and the stored prompt.
state.setRequestPrompt("prompt text");
assert(
  state.getState().requestPrompt === "prompt text",
  "setRequestPrompt must store the prompt.");
state.selectModule("Main");
state.beginPasteEdit();
state.setBook(
  {
    name: "other.xlsm",
    path: "other.xlsm",
    ext: ".xlsm",
    totalLines: 0
  },
  []);
assert(
  state.getState().pasteEditing === false,
  "setBook must end the edit session.");
assert(
  state.getState().requestPrompt === null,
  "setBook must clear the stored request prompt.");
assert(
  state.getState().requestId === null,
  "setBook must clear the request id of the previous workbook.");

console.log("test-paste-edit: PASS");
