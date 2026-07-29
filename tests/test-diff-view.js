"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function equalRow(index) {
  return {
    type: "equal",
    lineA: index,
    lineB: index,
    textA: "Line " + index,
    textB: "Line " + index
  };
}

var root = path.resolve(__dirname, "..");
var windowObject = {};
var context = vm.createContext({
  window: windowObject
});
windowObject.window = windowObject;

vm.runInContext(
  fs.readFileSync(
    path.join(root, "assets", "js", "diff-view.js"),
    "utf8"),
  context,
  { filename: "diff-view.js" });

var view = windowObject.MacroStudioDiffView;
var inline = view.getInlineDifference(
  "abc old suffix",
  "abc new suffix");

assert(
  inline.leftStart === 4 &&
    inline.leftEnd === 7 &&
    inline.rightStart === 4 &&
    inline.rightEnd === 7,
  "Inline difference boundaries are incorrect.");

var blockRows = [
  equalRow(0),
  { type: "changed", textA: "a", textB: "b" },
  { type: "added", textA: "", textB: "c" },
  equalRow(3),
  { type: "removed", textA: "d", textB: "" }
];
assert(
  view.assignChangeBlocks(blockRows) === 2,
  "Continuous changes were not grouped into two blocks.");
assert(
  blockRows[1].changeBlock === 0 &&
    blockRows[2].changeBlock === 0 &&
    blockRows[4].changeBlock === 1,
  "Change block identifiers are incorrect.");

var rows = [];
var index;
for (index = 0; index < 50; index += 1) {
  rows.push(equalRow(index));
}
rows[25] = {
  type: "changed",
  lineA: 25,
  lineB: 25,
  textA: "old",
  textB: "new"
};
var visible = view.getVisibleRows(rows, true);
assert(
  visible.filter(function (row) {
    return row.type === "gap";
  }).length === 2,
  "Context view must retain two expandable gaps.");
assert(
  visible.filter(function (row) {
    return row.type !== "gap";
  }).length === 21,
  "Context view must retain ten lines around the change.");

// ---- inline (unified) rows ----

var expandedEqual = view.expandRow({
  type: "equal",
  lineA: 4,
  lineB: 6,
  textA: "Option Explicit",
  textB: "Option Explicit"
});
assert(
  expandedEqual.length === 1 &&
    expandedEqual[0].kind === "equal" &&
    expandedEqual[0].marker === "" &&
    expandedEqual[0].oldNumber === "5" &&
    expandedEqual[0].newNumber === "7" &&
    expandedEqual[0].text === "Option Explicit",
  "An unchanged line must become one row carrying both numbers.");

var expandedChanged = view.expandRow({
  type: "changed",
  lineA: 12,
  lineB: 12,
  textA: "    Sleep 100",
  textB: "    WaitMilliseconds 100"
});
assert(
  expandedChanged.length === 2,
  "A changed line must become a removed row and an added row.");
assert(
  expandedChanged[0].kind === "removed" &&
    expandedChanged[0].marker === "-" &&
    expandedChanged[0].oldNumber === "13" &&
    expandedChanged[0].newNumber === "" &&
    expandedChanged[0].text === "    Sleep 100" &&
    expandedChanged[0].markClass === "diff-inline-mark--removed",
  "The removed half of a changed line is wrong.");
assert(
  expandedChanged[1].kind === "added" &&
    expandedChanged[1].marker === "+" &&
    expandedChanged[1].oldNumber === "" &&
    expandedChanged[1].newNumber === "13" &&
    expandedChanged[1].text === "    WaitMilliseconds 100" &&
    expandedChanged[1].markClass === "diff-inline-mark--added",
  "The added half of a changed line is wrong.");
assert(
  expandedChanged[0].markStart === 4 &&
    expandedChanged[0].markEnd === 9 &&
    expandedChanged[1].markStart === 4 &&
    expandedChanged[1].markEnd === 20,
  "The within-line marks did not survive the inline split.");

assert(
  view.expandRow({
    type: "removed",
    lineA: 2,
    lineB: -1,
    textA: "Dim x",
    textB: ""
  })[0].newNumber === "" &&
    view.expandRow({
      type: "added",
      lineA: -1,
      lineB: 3,
      textA: "",
      textB: "Dim y"
    })[0].oldNumber === "",
  "A one-sided line must leave the other gutter empty.");

var expandedSequence = view.expandRows([
  equalRow(0),
  {
    type: "changed",
    lineA: 1,
    lineB: 1,
    textA: "a",
    textB: "b",
    changeBlock: 0
  },
  equalRow(2)
]);
assert(
  expandedSequence.length === 4 &&
    expandedSequence.map(function (row) {
      return row.marker;
    }).join("") === "-+",
  "Inline expansion changed the row order or markers.");
assert(
  expandedSequence[1].changeBlock === 0 &&
    expandedSequence[2].changeBlock === 0,
  "Both halves of a changed line must keep the change block.");

assert(
  view.hasWhitespaceOnlyChange([
    {
      type: "changed",
      textA: "    value",
      textB: "\tvalue"
    }
  ]),
  "Whitespace-only changes were not detected.");
assert(
  !view.hasWhitespaceOnlyChange([
    {
      type: "changed",
      textA: "old",
      textB: "new"
    }
  ]),
  "Content changes were mistaken for whitespace-only changes.");

console.log("test-diff-view: PASS");
console.log("inline marks, blocks, context gaps, whitespace: PASS");
