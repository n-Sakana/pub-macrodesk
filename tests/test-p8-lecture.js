"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertContent(content, label) {
  var lines;

  assert(content, label + " content is missing.");
  assert(
    typeof content.title === "string" &&
      content.title.trim().length > 0,
    label + " title is empty.");
  assert(
    typeof content.body === "string",
    label + " body is not text.");
  lines = content.body.split("\n");
  assert(
    lines.length >= 2 && lines.length <= 4,
    label + " body must have two to four lines.");
  lines.forEach(function (line) {
    assert(line.trim().length > 0, label + " has an empty line.");
  });
  assert(
    content.body.indexOf("P8") < 0 &&
      content.body.indexOf("整備します") < 0,
    label + " still contains placeholder copy.");
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

var lecture = windowObject.MacroDeskLecture;
var branchKeys = [
  "L1-1",
  "L1-2",
  "L2-1",
  "L2-2",
  "L2-3",
  "L2-4",
  "L3-1",
  "L3-2",
  "L3-3",
  "L3-4",
  "L3-5",
  "L3-6",
  "L4-1",
  "L4-2",
  "L-E*"
];
var errorCodes = [
  "E-ATTACH-01",
  "E-ATTACH-02",
  "E-ATTACH-03",
  "E-ATTACH-04",
  "E-ATTACH-05",
  "E-GEN-01",
  "E-PASTE-01",
  "E-BUILD-01",
  "E-BUILD-02",
  "E-BUILD-03",
  "E-SYS-01",
  "E-SYS-02"
];

branchKeys.forEach(function (key) {
  assertContent(lecture.contentByKey[key], key);
});
errorCodes.forEach(function (code) {
  assertContent(lecture.errorContentByCode[code], code);
});

assert(
  lecture.contentByKey["L1-1"].body.indexOf(".xlsm") >= 0 &&
    lecture.contentByKey["L1-1"].body.indexOf("Excel") >= 0,
  "L1-1 must describe formats and the open-Excel restriction.");
assert(
  lecture.contentByKey["L2-3"].body.indexOf("Copilot Chat") >= 0 &&
    lecture.contentByKey["L2-3"].body.indexOf("添付ファイルの依頼") >= 0,
  "L2-3 must include the Copilot handoff.");
assert(
  lecture.contentByKey["L3-3"].body.indexOf("赤") >= 0 &&
    lecture.contentByKey["L3-3"].body.indexOf("緑") >= 0,
  "L3-3 must explain diff colors in text.");
assert(
  lecture.contentByKey["L4-1"].body.indexOf("元のブック") >= 0 &&
    lecture.contentByKey["L4-1"].body.indexOf("変更しません") >= 0,
  "L4-1 must explain that the source is unchanged.");
assert(
  lecture.errorContentByCode["E-SYS-02"].body.indexOf(
    "%LOCALAPPDATA%\\MacroDesk\\logs\\") >= 0,
  "E-SYS-02 must include the log location.");

var noChangeState = {
  currentStep: 3,
  modules: [
    { name: "A", status: "unchanged" },
    { name: "B", status: "excluded" }
  ],
  selectedModuleName: null,
  lastError: null,
  buildResult: null
};
var changedState = {
  currentStep: 3,
  modules: [
    { name: "A", status: "changed" },
    { name: "B", status: "excluded" }
  ],
  selectedModuleName: null,
  lastError: null,
  buildResult: null
};

assert(
  lecture.getBranchKey(noChangeState) === "L3-6",
  "No-change completed state must remain in L3-6.");
assert(
  lecture.getContent(noChangeState, "L3-6").title ===
    "書き戻す変更はありません",
  "No-change L3-6 guidance mismatch.");
assert(
  lecture.getContent(changedState, "L3-6").title ===
    lecture.contentByKey["L3-6"].title,
  "Changed L3-6 guidance mismatch.");
assert(
  lecture.getContent({
    lastError: { code: "E-UNKNOWN" },
    modules: []
  }, "L-E*") === lecture.errorContentByCode["E-SYS-02"],
  "Unknown errors must use E-SYS-02 guidance.");

console.log("test-p8-lecture: PASS");
console.log("branches=15, errors=12, body-lines=2-4, L3-6=dynamic");
