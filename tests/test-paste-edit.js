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
  context,
  { filename: "state.js" });

var state = windowObject.MacroDeskState;

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
  state.navigate(2);
  state.navigate(3);
}

// Editing requires an imported module.
setup();
state.selectModule("Main");
assert(
  state.beginPasteEdit() === false,
  "A pending module must not enter manual edit.");
assert(
  state.getState().pasteEditing === false,
  "pasteEditing must stay false for pending modules.");

state.acceptModuleCode(
  "Main",
  "Option Explicit\r\nSub A(): Beep: End Sub\r\n",
  1);
assert(
  state.getState().pasteEditing === false,
  "Accepting a paste must not enter manual edit by itself.");
assert(
  state.beginPasteEdit() === true,
  "A changed module must enter manual edit.");
assert(
  state.getState().pasteEditing === true,
  "pasteEditing must be true after beginPasteEdit.");
assert(
  state.getGuideTarget().id === "apply-paste-edit",
  "The guide ring must move to the apply button while editing.");

// Applying (via acceptModuleCode) ends the edit session.
state.acceptModuleCode(
  "Main",
  "Option Explicit\r\nSub A(): Beep: Beep: End Sub\r\n",
  1);
assert(
  state.getState().pasteEditing === false,
  "acceptModuleCode must end the edit session.");

// Selecting another module ends the edit session.
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.selectModule("Helper");
assert(
  state.getState().pasteEditing === false,
  "Selecting another module must end the edit session.");

// Navigating away ends the edit session.
state.selectModule("Main");
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.navigate(2);
assert(
  state.getState().pasteEditing === false,
  "Navigation must end the edit session.");

// Cancelling the paste ends the edit session.
state.navigate(3);
state.selectModule("Main");
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.cancelModulePaste("Main");
assert(
  state.getState().pasteEditing === false,
  "Cancelling the paste must end the edit session.");
assert(
  state.findModule("Main").status === "pending",
  "Cancelling the paste must return the module to pending.");

// New-module intake ends the edit session, and editing is
// refused while the intake form is open.
state.acceptModuleCode(
  "Main",
  "Option Explicit\r\nSub A(): Beep: End Sub\r\n",
  1);
assert(state.beginPasteEdit() === true, "Re-entering edit failed.");
state.beginNewModuleIntake();
assert(
  state.getState().pasteEditing === false,
  "Starting new-module intake must end the edit session.");
assert(
  state.beginPasteEdit() === false,
  "Editing must be refused while the intake form is open.");
state.cancelNewModuleIntake();

// cancelPasteEdit is idempotent and only reports an active session.
assert(
  state.cancelPasteEdit() === false,
  "cancelPasteEdit must report no active session.");
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
state.beginNewModuleIntake();
var added = state.addNewModule(
  "WaitUtils",
  "Public Sub WaitMs()\r\nEnd Sub\r\n",
  2,
  2);
assert(added !== null, "Adding the new module failed.");
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

console.log("test-paste-edit: PASS");
console.log(
  "begin/apply/cancel, selection/navigation/intake resets, " +
  "new-module lineCount, prompt reset");
