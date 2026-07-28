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

var view = windowObject.MacroDeskDiffView;
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
