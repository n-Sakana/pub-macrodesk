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
  window: {}
};

vm.createContext(sandbox);
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "..", "assets", "js", "vba-highlight.js"),
    "utf8"),
  sandbox);

const highlight = sandbox.window.MacroStudioVbaHighlight;
let tokens = highlight.tokenizeLine(
  "If value = 42 Then MsgBox \"a\"\"b\" ' note");
assert(
  tokens.some((token) => token.type === "keyword" && token.text === "If"),
  "If keyword was not highlighted.");
assert(
  tokens.some((token) => token.type === "number" && token.text === "42"),
  "Number was not highlighted.");
assert(
  tokens.some(
    (token) => token.type === "string" && token.text === "\"a\"\"b\""),
  "Escaped VBA string was not highlighted.");
assert(
  tokens.some(
    (token) => token.type === "comment" && token.text === "' note"),
  "Apostrophe comment was not highlighted.");

tokens = highlight.tokenizeLine("x = 1: Rem explanation");
assert(
  tokens[tokens.length - 1].type === "comment" &&
    tokens[tokens.length - 1].text === "Rem explanation",
  "Rem comment was not highlighted.");

tokens = highlight.tokenizeLine("value = &HFF& + &O17&");
assert(
  tokens.filter((token) => token.type === "number").length === 2,
  "Hexadecimal and octal numbers were not highlighted.");

console.log("test-vba-highlight: PASS");
