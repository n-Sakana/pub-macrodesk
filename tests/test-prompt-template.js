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
var defaultTemplate = fs.readFileSync(
  path.join(root, "templates", "request-template.txt"),
  "utf8");
var crlf = "\r\n";
var banner = new Array(81).join("=");
var indexLine = new Array(41).join("-");

var options = {
  template: defaultTemplate,
  requestText: "一行目\n二行目",
  codeFileName: "台帳_コード全文_20260729_120000.txt",
  book: {
    name: "台帳.xlsm",
    totalLines: 3
  },
  modules: [
    {
      name: "Module1",
      type: "standard",
      typeLabel: "標準モジュール",
      ext: "bas",
      lineCount: 3,
      code: "Option Explicit\nPublic Sub Run()\nEnd Sub\n",
      attributes: "Attribute VB_Name = \"Module1\"\r\n"
    },
    {
      name: "ThisWorkbook",
      type: "document",
      typeLabel: "ドキュメントモジュール",
      ext: "cls",
      lineCount: 0,
      code: "",
      attributes: "Attribute VB_Name = \"ThisWorkbook\"\r\n"
    }
  ]
};

// ---- the attached code file: fixed format, code only ----

var codeFile = promptApi.buildCodeFile({
  book: options.book,
  modules: options.modules,
  generatedAt: "2026-07-29 12:00:00"
});
var expectedCodeFile = [
  banner,
  " 台帳.xlsm - VBA Source Code",
  " Generated: 2026-07-29 12:00:00",
  banner,
  "",
  "MODULE INDEX",
  indexLine,
  "",
  "  Standard Modules:",
  "    Module1.bas (3 lines)",
  "",
  "  Document Modules:",
  "    ThisWorkbook.cls (0 lines)",
  "",
  "  Total: 3 lines across 2 modules",
  "",
  banner,
  " Module1.bas",
  banner,
  "",
  "Option Explicit",
  "Public Sub Run()",
  "End Sub",
  "",
  banner,
  " ThisWorkbook.cls",
  banner
].join(crlf) + crlf;

assert(
  codeFile === expectedCodeFile,
  "Generated code file mismatch.");
assert(
  codeFile.indexOf("【") < 0 &&
    codeFile.indexOf("■") < 0 &&
    codeFile.indexOf("現在空です") < 0 &&
    codeFile.indexOf("```") < 0,
  "The code file must contain no prose, notes, or fences.");
assert(
  codeFile.indexOf("Attribute VB_Name") < 0,
  "Attribute headers leaked into the code file.");
assert(
  codeFile.replace(/\r\n/g, "").indexOf("\n") < 0 &&
    codeFile.replace(/\r\n/g, "").indexOf("\r") < 0,
  "The code file contains a lone LF or CR.");
assert(
  codeFile.slice(-2) === crlf &&
    codeFile.slice(-4) !== crlf + crlf,
  "The code file must end with exactly one CRLF.");

var unknownTypeRejected = false;
try {
  promptApi.buildCodeFile({
    book: options.book,
    modules: [
      {
        name: "X",
        type: "mystery",
        ext: "bas",
        lineCount: 1,
        code: "A\n"
      }
    ],
    generatedAt: "2026-07-29 12:00:00"
  });
} catch (error) {
  unknownTypeRejected = true;
}
assert(
  unknownTypeRejected,
  "An unknown module type must raise an error.");

// ---- the chat prompt: external template, no source blocks ----

var expectedPrompt = [
  "添付ファイル 台帳_コード全文_20260729_120000.txt は、" +
    "Excel ブック 台帳.xlsm の VBA コード全文です",
  "（2 モジュール、合計 3 行。省略はありません）。",
  "ソースコードが欠落している・省略されていると判断せず、追加の資料を求めず、",
  "添付ファイルの内容だけを対象に、下の【依頼】に従って改修してください。",
  "",
  "【依頼】",
  "一行目",
  "二行目",
  "",
  "【対象モジュール】※ 0 行のモジュールは元から空です",
  "  - Module1 （標準モジュール, 3 行）",
  "  - ThisWorkbook （ドキュメントモジュール, 0 行）",
  "",
  "【出力形式の指定】",
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
  "- 改修に必要な行だけを変更する。それ以外の行は、空白・インデント・コメント・",
  "  変数宣言の並び・命名を含め、渡したものと一字一句同じにして返す。",
  "  整形、リファクタリング、コメントの追加や削除、命名の変更はしない。",
  "- コードは必ずモジュールの先頭から末尾までの全文を出力する。一部だけの",
  "  出力や「'（以下変更なし）」のような省略はしない。",
  "- 変更していないモジュールは出力しない。",
  "- コードブロックの中には VBA コード以外の文章（説明・注釈・見出し）を",
  "  入れない。",
  "- モジュール先頭に「Attribute VB_」で始まる行を付けない（渡したコードにも",
  "  付いていない。コードの途中に Attribute 行がある場合だけ、そのまま残す）。",
  "- 複数のモジュールに同じ処理を入れる場合は、新しい標準モジュールを 1 つ作って",
  "  そこに共通の処理を置き、既存モジュールからは呼び出すだけにしてください。",
  "  新しいモジュールは「■ <新しいモジュール名>（新規）」の見出しで出力してください。",
  "- モジュール名の変更と、モジュールの削除はしない。"
].join(crlf) + crlf;

var actualPrompt = promptApi.buildRequestPrompt(options);
assert(
  actualPrompt === expectedPrompt,
  "Generated request prompt mismatch.");
assert(
  actualPrompt.indexOf("Option Explicit") < 0 &&
    actualPrompt.indexOf("End Sub") < 0,
  "Module source leaked into the request prompt.");
assert(
  actualPrompt.indexOf("一字一句") >= 0 &&
    actualPrompt.indexOf("省略はありません") >= 0 &&
    actualPrompt.indexOf("欠落") >= 0,
  "The default prompt must state completeness and minimal-change rules.");
assert(
  actualPrompt.replace(/\r\n/g, "").indexOf("\n") < 0 &&
    actualPrompt.replace(/\r\n/g, "").indexOf("\r") < 0,
  "Generated prompt contains a lone LF or CR.");
assert(
  !Object.prototype.hasOwnProperty.call(
    promptApi,
    "buildRequestFile"),
  "The single-file request builder must be removed.");

var boundaryPrompt = promptApi.buildRequestPrompt({
  template: defaultTemplate,
  requestText: "末尾改行あり\n",
  codeFileName: options.codeFileName,
  book: options.book,
  modules: options.modules
});
assert(
  boundaryPrompt.indexOf(
    "末尾改行あり\r\n\r\n【対象モジュール】") >= 0,
  "A request trailing newline changed the section boundary.");

// ---- preset append (unchanged behaviour) ----

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

// ---- template validation ----

var rejected = false;
try {
  promptApi.buildRequestPrompt({});
} catch (error) {
  rejected = true;
}
assert(rejected, "Missing prompt data must raise an error.");

function buildWithTemplate(template, requestText) {
  return promptApi.buildRequestPrompt({
    template: template,
    requestText: requestText === undefined
      ? options.requestText
      : requestText,
    codeFileName: options.codeFileName,
    book: options.book,
    modules: options.modules
  });
}

var minimal = buildWithTemplate("{{REQUEST_TEXT}}\n");
assert(
  minimal.indexOf("一行目\r\n二行目\r\n") === 0,
  "A template may omit optional placeholders.");
assert(
  minimal.slice(-2) === crlf &&
    minimal.slice(-4) !== crlf + crlf,
  "Rendered prompts must end with exactly one CRLF.");

var repeated = buildWithTemplate(
  "{{CODE_FILE_NAME}}|{{CODE_FILE_NAME}}\n{{REQUEST_TEXT}}");
assert(
  repeated.indexOf(
    options.codeFileName + "|" + options.codeFileName + "\r\n") === 0,
  "Known placeholders may be repeated.");

var dollarText = buildWithTemplate(
  "{{REQUEST_TEXT}}",
  "$&\n$1");
assert(
  dollarText.indexOf("$&\r\n$1\r\n") === 0,
  "Placeholder values must not use replacement-string semantics.");

var literalPlaceholderText = buildWithTemplate(
  "{{REQUEST_TEXT}}",
  "{{BOOK_NAME}}\n{{MODULE_COUNT}}");
assert(
  literalPlaceholderText.indexOf(
    "{{BOOK_NAME}}\r\n{{MODULE_COUNT}}\r\n") === 0,
  "Placeholder-like text inside a value must remain literal.");

var sourceBlocksError = "";
try {
  buildWithTemplate(
    "{{REQUEST_TEXT}}\n{{MODULE_SOURCE_BLOCKS}}");
} catch (error) {
  sourceBlocksError = error.message;
}
assert(
  sourceBlocksError.indexOf("MODULE_SOURCE_BLOCKS") >= 0,
  "A retired MODULE_SOURCE_BLOCKS placeholder must be " +
    "rejected with a clear message.");

[
  {
    template: "{{MODULE_LIST}}",
    label: "REQUEST_TEXT"
  },
  {
    template: "{{REQUEST_TEXT}}\n{{BOOK_NAM}}",
    label: "unknown"
  },
  {
    template: "{{REQUEST_TEXT}}\n{{BOOK_NAME}",
    label: "malformed"
  }
].forEach(function (testCase) {
  var didReject = false;

  try {
    buildWithTemplate(testCase.template);
  } catch (error) {
    didReject = true;
  }
  assert(
    didReject,
    "The " + testCase.label + " template error was accepted.");
});

console.log("test-prompt-template: PASS");
console.log(
  "code file format, exact default prompt, variables, CRLF, append: PASS");
