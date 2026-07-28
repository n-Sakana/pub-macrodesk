"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function joinWithBlankLine(parts) {
  var result = "";

  parts.forEach(function (part) {
    var trailing;
    var leading;
    var breaks;

    if (!result) {
      result = part;
      return;
    }
    trailing = result.match(/(?:(?:\r\n|\r|\n))+$/);
    leading = part.match(/^(?:(?:\r\n|\r|\n))+/);
    breaks = 0;
    if (trailing) {
      breaks += trailing[0].match(/\r\n|\r|\n/g).length;
    }
    if (leading) {
      breaks += leading[0].match(/\r\n|\r|\n/g).length;
    }
    result += new Array(Math.max(0, 2 - breaks) + 1)
      .join("\r\n") + part;
  });
  return result;
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
var crlf = "\r\n";
var sectionLine =
  "==================================================";
var moduleLine =
  "--------------------------------------------------";
var expectedFixed = [
  sectionLine,
  "【出力形式の指定】※ここから下はツールが自動で付けた指定です",
  sectionLine,
  "回答は、必ず次の形式・順序で出力してください。",
  "",
  "1. 最初に「■ 改修サマリー」という見出しを置き、改修したモジュール名と",
  "   変更内容の要点を箇条書きで書いてください。",
  "   これは、読んだ人がこのあと取り込み作業をするための指示書を兼ねます。",
  "",
  "2. 続けて、改修したモジュールごとに、モジュール名だけの見出し",
  "   （例: ■ Module1）を置き、その直後にそのモジュールの改修後コードの",
  "   全文を 1 つのコードブロックで出力してください。",
  "",
  "守ってください:",
  "- コードは必ずモジュールの先頭から末尾までの全文を出力する。一部だけの",
  "  出力や「'（以下変更なし）」のような省略はしない。",
  "- 変更していないモジュールは出力しない。",
  "- 「このモジュールは現在空です」という注記は VBA コードへ含めない。空の",
  "  モジュールも、改修対象なら改修後コードの全文を出し、未変更なら出力しない。",
  "- コードブロックの中には VBA コード以外の文章（説明・注釈・見出し）を",
  "  入れない。",
  "- モジュール先頭に「Attribute VB_」で始まる行を付けない（渡したコードにも",
  "  付いていない。コードの途中に Attribute 行がある場合だけ、そのまま残す）。",
  "- モジュール名の変更、モジュールの新規追加・削除はしない。既存モジュール",
  "  の中身の変更だけで対応する。"
].join(crlf);

assert(
  promptApi.fixedInstructions === expectedFixed,
  "Fixed output instructions do not match SPEC 6.3.");

var options = {
  requestText: "一行目\n二行目",
  book: {
    name: "台帳.xlsm",
    totalLines: 3
  },
  modules: [
    {
      name: "Module1",
      typeLabel: "標準モジュール",
      lineCount: 3,
      code: "Option Explicit\nPublic Sub Run()\nEnd Sub\n",
      attributes: "Attribute VB_Name = \"Module1\"\r\n"
    },
    {
      name: "ThisWorkbook",
      typeLabel: "ドキュメントモジュール",
      lineCount: 0,
      code: "",
      attributes: "Attribute VB_Name = \"ThisWorkbook\"\r\n"
    }
  ]
};

var expectedSource = [
  sectionLine,
  "【ソースコード】",
  sectionLine,
  "",
  joinWithBlankLine([
    [
      "■ Module1（標準モジュール）",
      moduleLine,
      "Option Explicit",
      "Public Sub Run()",
      "End Sub",
      ""
    ].join(crlf),
    [
      "■ ThisWorkbook（ドキュメントモジュール）",
      moduleLine,
      "（このモジュールは現在空です。コードの省略ではありません）"
    ].join(crlf)
  ])
].join(crlf);

var expected = joinWithBlankLine([
  [
    "このファイルは Excel マクロ改修支援ツール「MacroDesk」が生成した、Excel マクロの改修依頼です。",
    "下の【依頼】に従って、【ソースコード】にある VBA コードを改修してください。"
  ].join(crlf),
  [
    sectionLine,
    "【依頼】",
    sectionLine,
    "一行目",
    "二行目"
  ].join(crlf),
  [
    sectionLine,
    "【対象ブック】",
    sectionLine,
    "ファイル名: 台帳.xlsm",
    "モジュール数: 2（合計 3 行）※以下に全モジュールの全文を掲載しています。省略はありません。",
    "",
    "  - Module1 （標準モジュール, 3 行）",
    "  - ThisWorkbook （ドキュメントモジュール, 0 行）"
  ].join(crlf),
  expectedSource,
  expectedFixed
]) + crlf;

var actual = promptApi.buildRequestFile(options);
assert(actual === expected, "Generated request template mismatch.");
assert(
  actual.indexOf("Attribute VB_Name") < 0,
  "Attribute header leaked into the request file.");
assert(
  actual.indexOf(
    "■ ThisWorkbook（ドキュメントモジュール）\r\n" +
    moduleLine + "\r\n" +
    "（このモジュールは現在空です。コードの省略ではありません）") >= 0,
  "An empty module must be identified as complete, not omitted.");
assert(
  actual.indexOf(
    "End Sub\r\n\r\n■ ThisWorkbook") >= 0,
  "Module blocks must have exactly one blank line.");
assert(
  actual.replace(/\r\n/g, "").indexOf("\n") < 0,
  "Generated request contains a lone LF.");
assert(
  actual.replace(/\r\n/g, "").indexOf("\r") < 0,
  "Generated request contains a lone CR.");

assert(
  promptApi.appendPreset("", "preset") === "preset",
  "Preset append to an empty request must preserve the preset.");
assert(
  promptApi.appendPreset("request", "preset") ===
    "request\r\n\r\npreset",
  "Preset append must insert one blank line.");
assert(
  promptApi.appendPreset("request\r\n", "preset") ===
    "request\r\n\r\npreset",
  "Preset append must supplement one missing line break.");
assert(
  promptApi.appendPreset("request\r\n\r\n", "preset") ===
    "request\r\n\r\npreset",
  "Preset append must not add a second blank line.");
assert(
  promptApi.appendPreset("request", "\r\npreset") ===
    "request\r\n\r\npreset",
  "Preset leading break must count toward the blank line.");

var rejected = false;
try {
  promptApi.buildRequestFile({});
} catch (error) {
  rejected = true;
}
assert(rejected, "Missing prompt data must raise an error.");

console.log("test-prompt-template: PASS");
console.log("SPEC 6.2/6.3 exact text, CRLF, all modules, append 2A: PASS");
