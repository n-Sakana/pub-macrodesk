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
  window: windowObject
});
windowObject.window = windowObject;

[
  path.join(root, "assets", "js", "state.js"),
  path.join(root, "assets", "js", "lecture.js")
].forEach(function (filePath) {
  vm.runInContext(
    fs.readFileSync(filePath, "utf8"),
    context,
    { filename: filePath });
});

var stateApi = windowObject.MacroDeskState;
var lectureApi = windowObject.MacroDeskLecture;
var row = stateApi.getTransitionRow();

assert(row[1] === false, "Initial step 1 transition must be unavailable.");
assert(row[2] === false, "Step 2 must require an attached book.");
assert(row[3] === false, "Step 3 must require an attached book.");
assert(row[4] === false, "Step 4 must require a changed module.");
assert(
  lectureApi.getBranchKey(stateApi.getState()) === "L1-1",
  "Initial lecture branch mismatch.");

stateApi.setBook(
  { name: "sample.xlsm", path: "C:\\sample.xlsm", ext: ".xlsm" },
  [
    {
      name: "Module1",
      type: "standard",
      lineCount: 10,
      status: "pending",
      changedLineCount: 0,
      written: false
    }
  ]);

row = stateApi.getTransitionRow();
assert(row[2] === true, "Attached step 1 must allow step 2.");
assert(row[3] === true, "Attached step 1 must allow step 3.");
assert(row[4] === false, "Step 4 must still require a change.");

assert(stateApi.navigate(2), "Navigation to step 2 failed.");
stateApi.setRequestState("Please change it.", "C:\\request.txt");
assert(
  lectureApi.getBranchKey(stateApi.getState()) === "L2-3",
  "Created request lecture branch mismatch.");
assert(stateApi.navigate(3), "Navigation to step 3 failed.");
assert(stateApi.selectModule("Module1"), "Module selection failed.");
assert(
  lectureApi.getBranchKey(stateApi.getState()) === "L3-2",
  "Selected pending module lecture branch mismatch.");

assert(
  stateApi.acceptModuleCode("Module1", "changed\r\n", 3),
  "Accepting pasted module code failed.");
row = stateApi.getTransitionRow();
assert(row[1] === true, "Step 3 must allow returning to step 1.");
assert(row[2] === true, "Step 3 must allow returning to step 2.");
assert(row[3] === false, "The current step must be unavailable.");
assert(row[4] === true, "A changed module must enable step 4.");
assert(
  lectureApi.getBranchKey(stateApi.getState()) === "L3-3",
  "Changed module lecture branch mismatch.");
assert(
  stateApi.cancelModulePaste("Module1"),
  "Cancelling pasted module code failed.");
assert(
  stateApi.getState().modules[0].status === "pending",
  "Cancel must restore pending status.");
assert(
  stateApi.toggleModuleExcluded("Module1"),
  "Pending module could not be excluded.");
assert(
  stateApi.getState().modules[0].status === "excluded",
  "Excluded status mismatch.");
assert(
  stateApi.toggleModuleExcluded("Module1"),
  "Excluded module could not be restored.");
assert(
  stateApi.acceptModuleCode("Module1", "changed\r\n", 3),
  "Re-accepting pasted module code failed.");

assert(stateApi.navigate(2), "Return navigation to step 2 failed.");
assert(
  stateApi.getState().selectedModuleName === "Module1",
  "Step navigation must preserve module selection.");
assert(
  stateApi.getState().requestText === "Please change it.",
  "Step navigation must preserve request text.");
assert(
  stateApi.getState().returnedFromStep3 === true,
  "Returning from step 3 must be recorded.");
assert(
  lectureApi.getBranchKey(stateApi.getState()) === "L2-4",
  "Return-to-edit lecture branch mismatch.");

stateApi.setLastError({
  code: "E-TEST",
  message: "Test error"
});
assert(
  lectureApi.getBranchKey(stateApi.getState()) === "L-E*",
  "Error lecture branch mismatch.");

stateApi.reset();
stateApi.loadDemoState();
assert(
  stateApi.getState().currentStep === 3,
  "Demo state must open step 3.");
assert(
  stateApi.getChangedModuleCount() === 2,
  "Demo state changed-module count mismatch.");
assert(
  stateApi.getTransitionRow()[4] === true,
  "Demo state must enable step 4.");

console.log("test-p4-state: PASS");
console.log("transition table, state preservation, lecture branches: PASS");
