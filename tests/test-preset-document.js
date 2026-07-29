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
    path.join(root, "assets", "js", "preset-document.js"),
    "utf8"),
  context,
  { filename: "preset-document.js" });

var presetApi = windowObject.MacroStudioPreset;

function lines(list) {
  return list.join("\n");
}

// ---- the shape a preset file must have ----

var complete = lines([
  "<!-- editor note before the title -->",
  "# 新端末移行",
  "",
  "<!--",
  "  複数行のコメント。",
  "  # これは見出しではない",
  "-->",
  "",
  "## 改修指示",
  "",
  "Win32 API を使わない形へ直してください。",
  "",
  "- 依存箇所をすべて見つける",
  "",
  "## 出力指示",
  "",
  "チャット本文のコードブロックで返してください。",
  "",
  "### 補足",
  "",
  "全文を返してください。",
  ""
]);

var parsed = presetApi.parse(complete);

assert(parsed.valid, "A complete preset must parse: " + parsed.message);
assert(
  parsed.name === "新端末移行",
  "The first H1 must become the preset name: " + parsed.name);
assert(
  parsed.instruction.title === "改修指示" &&
    parsed.output.title === "出力指示",
  "Both section titles must be reported.");
assert(
  parsed.instruction.body ===
    "Win32 API を使わない形へ直してください。\r\n\r\n" +
    "- 依存箇所をすべて見つける",
  "Instruction body mismatch: " +
    JSON.stringify(parsed.instruction.body));
assert(
  parsed.output.body ===
    "チャット本文のコードブロックで返してください。\r\n\r\n" +
    "### 補足\r\n\r\n全文を返してください。",
  "Output body mismatch: " + JSON.stringify(parsed.output.body));

// Comments are for the person editing the file, never for the chat.
assert(
  parsed.instruction.body.indexOf("editor note") < 0 &&
    parsed.output.body.indexOf("editor note") < 0 &&
    parsed.instruction.body.indexOf("複数行のコメント") < 0 &&
    parsed.output.body.indexOf("複数行のコメント") < 0 &&
    parsed.instruction.body.indexOf("<!--") < 0 &&
    parsed.output.body.indexOf("-->") < 0,
  "A comment leaked into a preset section.");
assert(
  parsed.name.indexOf("これは見出しではない") < 0,
  "A commented-out heading became the preset name.");

// Line endings: CRLF input parses to the same result as LF input.
assert(
  JSON.stringify(presetApi.parse(complete.replace(/\n/g, "\r\n"))) ===
    JSON.stringify(parsed),
  "CRLF input must parse like LF input.");

// ---- comments ----

var inlineComment = presetApi.parse(lines([
  "# 名前 <!-- 表示名の注意 -->",
  "## 改修指示",
  "本文 <!-- 行内コメント --> のつづき",
  "## 出力指示",
  "出力"
]));

assert(inlineComment.valid, "An inline comment must be accepted.");
assert(
  inlineComment.name === "名前",
  "An inline comment must be stripped from the name: " +
    inlineComment.name);
assert(
  inlineComment.instruction.body === "本文  のつづき",
  "An inline comment must be stripped from the body: " +
    JSON.stringify(inlineComment.instruction.body));

var strippedOnly = presetApi.stripComments(
  "a<!-- x -->b<!-- y -->c");
assert(
  strippedOnly.text === "abc" && !strippedOnly.unterminated,
  "stripComments must remove every comment.");

var unterminated = presetApi.parse(lines([
  "# 名前",
  "<!-- 閉じ忘れ",
  "## 改修指示",
  "本文",
  "## 出力指示",
  "出力"
]));
assert(
  !unterminated.valid &&
    unterminated.message === presetApi.messages.unterminatedComment,
  "An unterminated comment must be reported.");

// ---- fenced code blocks are body text, not headings ----

var fenced = presetApi.parse(lines([
  "# 名前",
  "## 改修指示",
  "```",
  "# これはコード内の行",
  "```",
  "## 出力指示",
  "出力"
]));
assert(
  fenced.valid && fenced.name === "名前",
  "A hash inside a fenced block must not be read as a heading.");
assert(
  fenced.instruction.body.indexOf("# これはコード内の行") >= 0,
  "Fenced content must stay in the body.");

// ---- editing mistakes must be refused, never silently accepted ----

var invalidCases = [
  {
    label: "no H1 (the old plain-body format)",
    text: lines([
      "Win32 API を使わない形へ直してください。",
      "- 依存箇所をすべて見つける"
    ]),
    message: presetApi.messages.missingName
  },
  {
    label: "two H1",
    text: lines([
      "# 名前",
      "## 改修指示",
      "本文",
      "## 出力指示",
      "出力",
      "# もう一つ"
    ]),
    message: presetApi.messages.multipleNames
  },
  {
    label: "H1 without a name",
    text: lines(["#", "## 改修指示", "本文", "## 出力指示", "出力"]),
    message: presetApi.messages.emptyName
  },
  {
    label: "missing instruction section",
    text: lines(["# 名前", "## 出力指示", "出力"]),
    message: "「## 改修指示」がありません。"
  },
  {
    label: "missing output section",
    text: lines(["# 名前", "## 改修指示", "本文"]),
    message: "「## 出力指示」がありません。"
  },
  {
    label: "duplicate section",
    text: lines([
      "# 名前",
      "## 改修指示",
      "本文",
      "## 改修指示",
      "本文2",
      "## 出力指示",
      "出力"
    ]),
    message: "「## 改修指示」が 2 つ以上あります。"
  },
  {
    label: "unknown section",
    text: lines([
      "# 名前",
      "## 改修指示",
      "本文",
      "## メモ",
      "個人用",
      "## 出力指示",
      "出力"
    ]),
    message:
      "知らない見出しがあります: ## メモ。" +
      "使えるのは「## 改修指示」「## 出力指示」「## 用途」「## 質問」です。"
  },
  {
    label: "empty section body",
    text: lines([
      "# 名前",
      "## 改修指示",
      "",
      "## 出力指示",
      "出力"
    ]),
    message: "「## 改修指示」の本文が空です。"
  },
  {
    label: "text before the title",
    text: lines([
      "前置き",
      "# 名前",
      "## 改修指示",
      "本文",
      "## 出力指示",
      "出力"
    ]),
    message: presetApi.messages.textBeforeName
  },
  {
    label: "text outside a section",
    text: lines([
      "# 名前",
      "見出しの外の本文",
      "## 改修指示",
      "本文",
      "## 出力指示",
      "出力"
    ]),
    message: presetApi.messages.textOutsideSection
  },
  {
    label: "empty file",
    text: "   \n\n",
    message: presetApi.messages.empty
  }
];

invalidCases.forEach(function (item) {
  var result = presetApi.parse(item.text);

  assert(
    !result.valid,
    "This preset must be refused: " + item.label);
  assert(
    result.message === item.message,
    "Wrong reason for " + item.label + ": " + result.message);
  assert(
    result.instruction === null && result.output === null,
    "A refused preset must not expose sections: " + item.label);
});

assert(
  !presetApi.parse(null).valid &&
    !presetApi.parse(undefined).valid,
  "Missing content must be refused.");

// ---- the list the UI renders ----

var entries = presetApi.describeAll([
  { file: "a.md", content: complete },
  { file: "b.md", content: "# 名前だけ" },
  { file: "c.md", content: "", error: "read" }
]);

assert(entries.length === 3, "Every file must stay in the list.");
assert(
  entries[0].valid && entries[0].name === "新端末移行",
  "A valid file must carry its H1 name.");
assert(
  !entries[1].valid && entries[1].name === "" &&
    entries[1].message === "「## 改修指示」がありません。",
  "An invalid file must carry its reason instead of a name.");
assert(
  !entries[2].valid &&
    entries[2].message === presetApi.messages.unreadable,
  "A file the host could not read must be reported as unreadable.");
assert(
  presetApi.countValid([
    { file: "a.md", content: complete },
    { file: "b.md", content: "# 名前だけ" }
  ]) === 1,
  "Only parsable files count as usable presets.");
assert(
  presetApi.countValid([]) === 0 &&
    presetApi.describeAll(null).length === 0,
  "An empty presets folder must yield no usable presets.");

console.log("test-preset-document: PASS");
console.log(
  "H1 name, both sections, comment removal and every refused " +
  "editing mistake behave as specified");
