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

vm.runInContext(
  fs.readFileSync(
    path.join(root, "assets", "js", "prompt-template.js"),
    "utf8"),
  context,
  { filename: "prompt-template.js" });

var promptApi = windowObject.MacroDeskPrompt;

function readUtf8(filePath) {
  var text = fs.readFileSync(filePath, "utf8");
  if (text.charCodeAt(0) === 0xFEFF) {
    text = text.slice(1);
  }
  return text;
}

var preset = readUtf8(
  path.join(root, "presets", "サンプル_新端末移行.md"));
var template = readUtf8(
  path.join(root, "templates", "request-template.txt"));

// The requirements the shipped migration preset must state. These are
// the canonical wording of the initial request the user sees after
// pressing the preset button.
var requiredPhrases = [
  "Win32 API を利用できない端末",
  "同じ機能・結果",
  "Win32 API 依存箇所",
  "すべて見つける",
  "特定の API だけに限定しない",
  "VBA 標準機能",
  "代替関数",
  "既存の処理モジュールへ混在させず",
  "新しい標準モジュール",
  "差し替える箇所だけを変更",
  "変更は最小限",
  "行を省略せず全文を返す",
  "依存そのものをなくす"
];

// Legacy wording that must not come back: goals that narrow the work
// to one API or convert it into declaration maintenance.
var bannedTokens = [
  "64 bit",
  "64bit",
  "64 ビット",
  "64ビット",
  "PtrSafe",
  "Sleep",
  "API 宣言を確認",
  "宣言を確認する"
];

requiredPhrases.forEach(function (phrase) {
  assert(
    preset.indexOf(phrase) >= 0,
    "The preset is missing the requirement: " + phrase);
});
bannedTokens.forEach(function (token) {
  assert(
    preset.indexOf(token) < 0,
    "The preset still contains legacy wording: " + token);
});

// The same statements must reach the clipboard prompt unchanged when
// the preset body is used as the request text.
var prompt = promptApi.buildRequestPrompt({
  template: template,
  requestText: preset,
  codeFileName: "book_code_20260729_120000.txt",
  book: {
    name: "book.xlsm",
    totalLines: 12
  },
  modules: [
    {
      name: "Main",
      type: "standard",
      typeLabel: "標準モジュール",
      ext: "bas",
      lineCount: 12,
      code: "Option Explicit\n"
    }
  ]
});

requiredPhrases.forEach(function (phrase) {
  assert(
    prompt.indexOf(phrase) >= 0,
    "The generated prompt is missing the requirement: " + phrase);
});
bannedTokens.forEach(function (token) {
  assert(
    prompt.indexOf(token) < 0,
    "The generated prompt still contains legacy wording: " + token);
});
assert(
  prompt.indexOf("一字一句") >= 0 &&
    prompt.indexOf("省略はありません") >= 0,
  "The template rules must accompany the preset request.");

console.log("test-preset-migration: PASS");
console.log(
  "preset and generated prompt state the Win32-API-removal " +
  "requirements without legacy wording");
