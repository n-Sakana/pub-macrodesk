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
  "preset-document.js",
  "response-package.js",
  "screens.js",
  "state.js"
].forEach(function (name) {
  vm.runInContext(
    fs.readFileSync(
      path.join(root, "assets", "js", name),
      "utf8"),
    context,
    { filename: name });
});

var screens = windowObject.MacroStudioScreens;
var state = windowObject.MacroStudioState;

function currentScreen() {
  return state.getState().screen;
}

function attach() {
  state.reset();
  state.setBook(
    {
      name: "受注管理.xlsm",
      path: "C:\\work\\受注管理.xlsm",
      ext: ".xlsm",
      totalLines: 12
    },
    [
      {
        name: "Main",
        type: "standard",
        typeLabel: "標準モジュール",
        ext: "bas",
        lineCount: 8,
        code: "Option Explicit\r\nSub A(): End Sub\r\n",
        attributes: ""
      },
      {
        name: "OrderRecord",
        type: "class",
        typeLabel: "クラスモジュール",
        ext: "cls",
        lineCount: 4,
        code: "Option Explicit\r\n",
        attributes: "Attribute VB_Name = \"OrderRecord\"\r\n"
      }
    ]);
}

function choosePurpose(questions) {
  state.setPurpose(
    "01_refactor.md",
    "VBAリファクター",
    "3f1c9c7a-2b64-4a1e-9f52-0b5a4d2e77c1",
    questions || []);
  state.setRequestBase("動きを変えずに整理してください。");
  state.setRequestText("動きを変えずに整理してください。");
  state.setOutputRules({
    presetFile: "01_refactor.md",
    presetName: "VBAリファクター",
    title: "出力指示",
    body: "ひとつのコードブロックで返してください。"
  });
}

// ---- the table itself ----

assert(screens.count === 12, "The flow must have twelve screens.");
assert(
  screens.majors.length === 4,
  "The progress bar must have four steps.");
assert(
  screens.describe({ mode: "refactor" }, 0).major === 1 &&
    screens.describe({ mode: "refactor" }, 11).major === 4,
  "The first and last screens belong to the first and last steps.");
assert(
  screens.modeScreen === 2 &&
  screens.purposeScreen === 3 &&
  screens.questionScreen === 4 &&
  screens.requestScreen === 5 &&
  screens.handoffScreen === 6 &&
  screens.intakeScreen === 7 &&
  screens.reviewScreen === 8 &&
  screens.buildScreen === 10 &&
  screens.doneScreen === 11,
  "The named screens must match the table.");

// A refactoring run without questions walks straight through.
var index;
var plain = { mode: "refactor", questions: [] };
for (index = screens.purposeScreen; index < screens.doneScreen; index += 1) {
  assert(
    screens.nextIndex(plain, index) ===
      (index === screens.purposeScreen ? screens.requestScreen : index + 1),
    "Screen " + index + " leads to the wrong screen.");
}

// ---- nothing advances before its own condition is met ----

state.reset();
assert(
  !state.canGoNext(),
  "Without a workbook the flow must not advance.");
assert(
  !state.canGoBack(),
  "The first screen has nothing to go back to.");

attach();
assert(currentScreen() === 0, "Attaching keeps the first screen.");
assert(state.canGoNext(), "An attached workbook enables next.");
assert(state.goNext() && currentScreen() === 1, "0 must lead to 1.");
assert(state.canGoBack(), "Later screens can go back.");

assert(state.goNext() && currentScreen() === 2, "1 must lead to 2.");
assert(
  !state.canGoNext(),
  "What the run is for must be chosen before advancing.");

// ---- the three things this app can be used for ----

assert(state.setMode("diagnose"), "Diagnosis must be selectable.");
assert(
  screens.isDiagnose(state.getState()) &&
    screens.isChatOnly(state.getState()),
  "A diagnosis run never reaches the build.");
assert(
  screens.getMajors(state.getState()).length === 2,
  "A chat-only run shows two steps, not four.");
assert(state.setMode("refactor"), "Refactoring must be selectable.");
assert(
  screens.getMajors(state.getState()).length === 4,
  "A refactoring run shows all four steps.");
assert(state.canGoNext(), "A chosen mode enables next.");
assert(state.goNext() && currentScreen() === 3, "2 must lead to 3.");
assert(
  !state.canGoNext(),
  "A purpose must be chosen before advancing.");

choosePurpose();
assert(
  state.getState().requestId.length > 0,
  "Choosing a purpose must mint a request id.");
assert(state.canGoNext(), "A chosen purpose enables next.");
assert(
  state.goNext() && currentScreen() === screens.requestScreen,
  "A preset without questions skips the form.");
assert(state.canGoNext(), "A prepared request enables next.");

state.setRequestText("   ");
assert(
  !state.canGoNext(),
  "An emptied request must not advance.");
state.setRequestText("動きを変えずに整理してください。");

assert(
  state.goNext() && currentScreen() === screens.handoffScreen,
  "The request screen leads to the hand-off.");
assert(
  !state.canGoNext(),
  "The hand-off needs both the copy and the folder.");
state.setHandoffProgress(true, null);
assert(
  !state.canGoNext(),
  "Copying alone is not enough to advance.");
state.setHandoffProgress(null, true);
assert(
  state.canGoNext(),
  "Copying and opening the folder together enable next.");

// ---- bulk intake ----

assert(
  state.goNext() && currentScreen() === screens.intakeScreen,
  "The hand-off leads to the intake.");
assert(
  !state.canGoNext(),
  "Nothing is imported yet, so there is nothing to review.");

// One press applies every module in the answer, including a new one.
assert(
  state.importPackage([
    {
      name: "Main",
      code: "Option Explicit\r\nSub A(): Beep: End Sub\r\n",
      changedLineCount: 1,
      lineCount: 2
    },
    {
      name: "OrderRecord",
      code: "Option Explicit\r\n",
      changedLineCount: 0,
      lineCount: 1
    },
    {
      name: "CompatHelpers",
      code: "Option Explicit\r\nSub W(): End Sub\r\n",
      changedLineCount: 2,
      lineCount: 2
    }
  ]) === 3,
  "The whole package must be applied in one step.");
state.setIntakeResult({ total: 3, existing: 2, added: 1 });

assert(
  screens.countImported(state.getState()) === 3,
  "Every module in the package counts as imported.");
assert(
  screens.countChanged(state.getState()) === 2,
  "Only the modules whose code differs count as changed.");
assert(
  screens.countUnchangedImports(state.getState()) === 1,
  "A module that came back unchanged is reported as unchanged.");

// The workbook decides the kind: the class module stays a class and the
// new module is standard.
assert(
  state.findModule("OrderRecord").type === "class",
  "An imported existing module keeps the kind the workbook has.");
assert(
  state.findModule("CompatHelpers").type === "standard" &&
  state.findModule("CompatHelpers").isNew === true,
  "A new module is added as a standard module.");

assert(state.canGoNext(), "An imported package can be reviewed.");
assert(
  state.goNext() && currentScreen() === screens.reviewScreen,
  "The intake leads to the review.");
// Taking the answer in is the decision: reviewing does not ask again.
assert(
  screens.countAccepted(state.getState()) === 2,
  "Every changed module that came in is written back.");
assert(
  state.canGoNext(),
  "A reviewed package can go straight to the build.");

// ---- rejecting puts the workbook back the way it was ----

assert(
  state.discardImportedModules() === 3,
  "Discarding must revert every imported module.");
assert(
  screens.countImported(state.getState()) === 0 &&
  state.findModule("CompatHelpers") === null &&
  state.findModule("Main").status === "pending",
  "Discarding removes new modules and clears imported code.");

state.importPackage([
  {
    name: "Main",
    code: "Option Explicit\r\nSub A(): Beep: End Sub\r\n",
    changedLineCount: 1,
    lineCount: 2
  },
  {
    name: "CompatHelpers",
    code: "Option Explicit\r\nSub W(): End Sub\r\n",
    changedLineCount: 2,
    lineCount: 2
  }
]);
state.setIntakeResult({ total: 2, existing: 1, added: 1 });

// ---- what came in is what gets written ----

assert(
  screens.countAccepted(state.getState()) === 2,
  "Both changed modules are written back without a second decision.");
assert(
  screens.countAcceptedLines(state.getState()) === 3,
  "The written line count adds up the changed lines.");
assert(state.canGoNext(), "A reviewed package enables next.");

// An open manual fix holds the flow until it is applied or dropped.
state.selectModule("Main");
assert(state.beginPasteEdit(), "The manual fix must open.");
assert(
  !state.canGoNext(),
  "An open manual fix must hold the fixed next button.");
state.cancelPasteEdit();
assert(state.canGoNext(), "Leaving the manual fix releases next.");

// ---- output name and the build ----

assert(
  state.goNext() && currentScreen() === screens.outputScreen,
  "The review leads to the output name.");
assert(
  state.getState().outputName === "受注管理_macrostudio.xlsm",
  "The output name defaults to the book name plus _macrostudio.");
assert(state.canGoNext(), "A valid output name enables next.");

[
  "",
  "受注管理_macrostudio.txt",
  "..\\受注管理_macrostudio.xlsm",
  "sub/受注管理_macrostudio.xlsm"
].forEach(function (name) {
  state.setOutputName(name);
  assert(
    !state.canGoNext(),
    "This output name must be refused: " + name);
});
state.setOutputName("受注管理_macrostudio.xlsm");
assert(state.canGoNext(), "A repaired output name enables next again.");

assert(
  state.goNext() && currentScreen() === screens.buildScreen,
  "The output name leads to the build.");
assert(
  !state.canGoNext() && !state.canGoBack(),
  "The build screen has no manual way out.");

state.setBuildResult({ status: "success", success: true });
state.goTo(screens.doneScreen, false);
assert(
  !state.canGoNext(),
  "The last screen has nothing after it.");
assert(state.canGoBack(), "The last screen can still go back.");

// ---- back returns along the screens that were visited ----

attach();
choosePurpose();
state.goTo(screens.purposeScreen, true);
state.goNext();
assert(
  currentScreen() === screens.requestScreen,
  "Next moves to the request screen.");
state.goBack();
assert(
  currentScreen() === screens.purposeScreen,
  "Back must return to the screen the flow came from.");

// ---- a preset with questions asks them, then stops at the files ----

attach();
state.goTo(screens.modeScreen, true);
state.setMode("diagnose");
choosePurpose([
  { text: "何に困っていますか", choices: ["遅い", "壊れやすい"] },
  { text: "いつまでに直したいですか", choices: [] }
]);
state.goTo(screens.purposeScreen, true);
assert(
  screens.nextIndex(state.getState(), screens.purposeScreen) ===
    screens.questionScreen,
  "A preset with questions must open the form.");
assert(
  state.goNext() && currentScreen() === screens.questionScreen,
  "The purpose screen leads to the form.");
assert(
  !state.canGoNext(),
  "The form needs at least one answer.");
assert(state.setAnswer(0, "遅い"), "A choice must be storable.");
assert(
  screens.countAnswers(state.getState()) === 1,
  "The answered count must follow the form.");
assert(state.canGoNext(), "One answer is enough to move on.");
assert(
  state.goNext() && currentScreen() === screens.requestScreen,
  "The form leads to the request screen.");

// Handing the files over is the whole job, so that screen is the end.
state.goTo(screens.handoffScreen, true);
assert(
  screens.isTerminal(state.getState(), screens.handoffScreen),
  "A chat-only run ends on the hand-off screen.");
assert(
  !screens.canFinish(state.getState(), screens.handoffScreen),
  "Finishing waits for the copy and the folder, like next did.");
state.setHandoffProgress(true, true);
assert(
  screens.canFinish(state.getState(), screens.handoffScreen),
  "Copying and opening the folder allow the run to finish.");
assert(
  !state.canGoNext(),
  "A terminal screen never advances.");
assert(
  !screens.isTerminal(
    { mode: "refactor", questions: [] },
    screens.handoffScreen),
  "A refactoring run keeps going past the hand-off.");

// Busy work freezes both directions.
attach();
state.setBusyAction("attachBook");
assert(
  !state.canGoNext() && !state.canGoBack(),
  "A running host action must freeze the navigation.");
state.setBusyAction(null);

console.log("test-flow-state: PASS");
console.log(
  "twelve screens, both run modes, the question form, " +
  "one-press intake, discarding a package, output name and " +
  "back history behave as specified");
