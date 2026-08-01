"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");
var dom = require("./helpers/dom-shim");
var contracts = require("./helpers/contracts");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function readUtf8(filePath) {
  var text = fs.readFileSync(filePath, "utf8");
  return text.charCodeAt(0) === 0xFEFF ? text.slice(1) : text;
}

var root = path.resolve(__dirname, "..");
var windowObject = {};
var documentObject = {createElement: dom.createElement};
var context = vm.createContext({
  window: windowObject,
  document: documentObject,
  Math: Math,
  Uint8Array: Uint8Array
});
windowObject.window = windowObject;
windowObject.document = documentObject;
windowObject.Math = Math;
windowObject.Uint8Array = Uint8Array;

["icons.js", "response-package.js", "diagnosis-package.js", "diff.js", "screens.js", "state.js",
  "screens/workflow.js"].forEach(function (name) {
  vm.runInContext(readUtf8(path.join(root, "assets", "js", name)), context,
    {filename: name});
});

var api = windowObject.MacroStudioResponse;
var screens = windowObject.MacroStudioScreens;
var store = windowObject.MacroStudioState;
var workflow = windowObject.MacroStudioWorkflow;
var id = "3f1c9c7a-2b64-4a1e-9f52-0b5a4d2e77c1";
var diagnosisId = "11111111-1111-4111-8111-111111111111";
var modules = [{name: "Main", type: "standard", code: "old", lineCount: 1}];
var diagnosis = contracts.diagnosis(windowObject.MacroStudioDiagnosis, {
  requestId: diagnosisId,
  modules: modules,
  findings: [{
    number: "1",
    className: "DEFECT",
    confidence: "CONFIRMED",
    module: "Main",
    procedure: "Run",
    lines: "1",
    title: "保存方法を決められない",
    condition: "保存する",
    impact: "保存先が変わる",
    evidence: "候補が二つある"
  }]
});

function decisionBlock(number, finding, moduleName, question, options) {
  return [
    "'@MACROSTUDIO " + id + " DECISION BEGIN " + number,
    "'@MACROSTUDIO " + id + " META FINDING=" + finding +
      " MODULE=" + moduleName,
    "'@MACROSTUDIO " + id + " TEXT BEGIN QUESTION",
    question,
    "'@MACROSTUDIO " + id + " TEXT END QUESTION",
    "'@MACROSTUDIO " + id + " TEXT BEGIN OPTIONS",
    options,
    "'@MACROSTUDIO " + id + " TEXT END OPTIONS",
    "'@MACROSTUDIO " + id + " DECISION END " + number
  ];
}

function validLines() {
  return [
    "'@MACROSTUDIO " + id + " SUMMARY BEGIN",
    "保存先を一意に決められません。",
    "'@MACROSTUDIO " + id + " SUMMARY END"
  ].concat(
    decisionBlock("1", "1", "Main", "共有先と個人先のどちらですか。",
      "共有先なら全員が参照でき、個人先なら本人だけです。"),
    decisionBlock("2", "-", "-", "出力後に自動で開きますか。",
      "開く / 開かない"),
    [
      "'@MACROSTUDIO " + id + " NOCHANGE NEEDDECISION",
      "'@MACROSTUDIO " + id + " COMPLETE 0"
    ]);
}

function expectR3(lines, label, describe) {
  var parsed = api.parse(lines.join("\r\n"), id);
  var result = describe && parsed.ok
    ? api.describe(parsed, modules, diagnosis)
    : parsed;
  assert(result.ok === false && result.validationId === "R3",
    label + " must be rejected specifically by R3.");
}

var valid = validLines();
var parsed = api.parse(valid.join("\r\n"), id);
var described = api.describe(parsed, modules, diagnosis);
assert(parsed.ok && described.ok && described.noChange === "NEEDDECISION" &&
  described.decisions.length === 2,
"A canonical NEEDDECISION package must be accepted with normalized decisions.");

expectR3(valid.filter(function (line) {
  return line.indexOf(" DECISION ") < 0 && line.indexOf("META FINDING") < 0 &&
    line.indexOf("TEXT BEGIN") < 0 && line.indexOf("TEXT END") < 0 &&
    line.indexOf("どちらですか") < 0 && line.indexOf("全員が") < 0 &&
    line.indexOf("自動で") < 0 && line !== "開く / 開かない";
}), "NEEDDECISION without a decision");

expectR3(valid.filter(function (line) {
  return line.indexOf("NOCHANGE NEEDDECISION") < 0;
}), "A decision without NEEDDECISION");

expectR3(valid.map(function (line) {
  return line.replace("DECISION BEGIN 1", "DECISION BEGIN 01");
}), "A non-canonical decision number");

expectR3(valid.map(function (line) {
  return line.replace("META FINDING=1 MODULE=Main",
    "META MODULE=Main FINDING=1");
}), "META keys in the wrong order");

expectR3(valid.filter(function (line) {
  return line !== "共有先と個人先のどちらですか。";
}), "An empty QUESTION");

expectR3(valid.filter(function (line) {
  return line.indexOf("COMPLETE 0") < 0;
}), "A missing COMPLETE 0");

expectR3(valid.slice(0, -2).concat([
  "'@MACROSTUDIO " + id + " BEGIN standard Main",
  "changed",
  "'@MACROSTUDIO " + id + " END standard Main",
  "'@MACROSTUDIO " + id + " NOCHANGE NEEDDECISION",
  "'@MACROSTUDIO " + id + " COMPLETE 1"
]), "A decision mixed with a module");

expectR3(valid.map(function (line) {
  return line.replace("META FINDING=1 MODULE=Main",
    "META FINDING=99 MODULE=Main");
}), "An unknown finding", true);

expectR3(valid.map(function (line) {
  return line.replace("META FINDING=1 MODULE=Main",
    "META FINDING=1 MODULE=Unknown");
}), "An unknown module", true);

windowObject.MacroStudioApp = {
  showToast: function () {},
  handleHostError: function () {},
  isBlockingAttachError: function () { return false; },
  createAttachErrorCard: function () { return dom.createElement("div"); }
};
store.setBook({
  name: "book.xlsm", path: "C:\\books\\book.xlsm", ext: ".xlsm",
  totalLines: 1
}, modules);
store.setTargetEnvironment({displayName: "test", revision: "1"}, "ENV");
store.commitDiagnosisRequest({requestId: diagnosisId});
store.commitDiagnosis(diagnosis, "diagnosis.md");
store.setRepairPreset({
  file: "02_改修\\test.md", name: "test", content: "preset",
  parsed: {
    engine: "AI", questions: [], behaviorCandidates: [], preserveItems: [],
    output: {body: "rules"}, splitOutput: null
  }
});
store.setFindingSelected(1, true);
store.setDesiredBehaviour(1, "選択に従う");
store.commitRepairRequest({requestId: id, requestText: "request", prompt: "prompt"});
store.goTo(screens.repairIntakeScreen, false);

assert(workflow.applyRepairText(valid.join("\r\n")) === true,
  "The product intake path must accept the canonical decision package.");
var state = store.getState();
assert(state.needDecision && state.needDecision.decisions.length === 2 &&
  !screens.canAdvance(state, screens.repairIntakeScreen),
"Accepted decisions must remain on intake and must never open Next.");

var intake = workflow.createRepairIntakeScreen(state);
assert(dom.text(intake).indexOf("改修の入力へ戻る") >= 0 &&
  dom.text(intake).indexOf("共有先と個人先") >= 0,
"The intake screen must present the decision and the return action.");
workflow.handleAction("return-repair-input", dom.createElement("button"));
assert(store.getState().screen === screens.repairInputScreen,
  "The primary decision action must return to repair input.");

var input = workflow.createRepairInputScreen(store.getState());
var quotes = dom.collect(input, function (node) {
  return node.classList && node.classList.contains("decision-quote");
});
var extra = dom.collect(input, function (node) {
  return node.getAttribute &&
    node.getAttribute("data-workflow-input") === "extra-request";
})[0];
// The per-finding supplement box is gone; a question about a finding is
// quoted on that finding's row, and the answer goes in the one free-text
// box the screen still has.
assert(quotes.length === 2 && extra.value === "" &&
  dom.text(input).indexOf("共有先と個人先") >= 0 &&
  dom.text(input).indexOf("出力後に自動") >= 0,
"Each question must be quoted at its finding or extra-request destination " +
  "without writing an answer into either field.");

store.commitRepairRequest({requestId: "next-repair-id", prompt: "next"});
assert(store.getState().needDecision === null,
  "Committing a new repair request must clear the returned questions.");

console.log("test-need-decision: PASS");
console.log("R3 structure/context, no-forward state, return routing, quotation " +
  "placement and new-request invalidation behave as specified");
