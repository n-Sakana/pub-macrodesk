"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const sandbox = {
  window: {
    location: {
      search: ""
    }
  }
};

vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "diff.js"),
    "utf8"),
  sandbox);
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "diff-view.js"),
    "utf8"),
  sandbox);

const diff = sandbox.window.MacroStudioDiff;
assert(diff.lookahead === 100, "Lookahead must be 100.");
assert(diff.runSelfTest(), "Built-in diff self-test failed.");

let rows = diff.compare(
  "A\r\nsame\r\nold\r\nlast\r\n",
  "A\r\nsame\r\nnew\r\ninserted\r\nlast\r\n");
assert(
  rows.map((row) => row.type).join(",") ===
    "equal,equal,changed,added,equal",
  "Mixed diff shape mismatch.");
assert(
  diff.countChangedLines(rows) === 2,
  "Changed-line count mismatch.");
assert(
  rows[2].lineA === 2 && rows[2].lineB === 2,
  "Changed row line numbers mismatch.");
assert(
  rows[3].lineA === -1 && rows[3].lineB === 3,
  "Added row line numbers mismatch.");

rows = diff.compare("", "one\r\n");
assert(rows.length === 1 && rows[0].type === "added", "Empty-left diff failed.");

rows = diff.compare("one\r\n", "");
assert(
  rows.length === 1 && rows[0].type === "removed",
  "Empty-right diff failed.");

rows = [];
for (let index = 0; index < 40; index += 1) {
  rows.push({
    type: index === 20 ? "changed" : "equal"
  });
}
const visible = sandbox.window.MacroStudioDiffView.getVisibleRows(rows, true);
assert(
  visible.length === 23,
  "Context-only diff must include two gaps and 21 context rows.");
assert(
  visible[0].type === "gap" && visible[0].count === 10,
  "Leading context gap mismatch.");
assert(
  visible[visible.length - 1].type === "gap" &&
    visible[visible.length - 1].count === 9,
  "Trailing context gap mismatch.");

console.log("test-diff: PASS");
