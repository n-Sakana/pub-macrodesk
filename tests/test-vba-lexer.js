"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function loadLexer() {
  var context = {window: {}};
  vm.runInNewContext(
    fs.readFileSync(
      path.join(__dirname, "..", "assets", "js", "vba-lexer.js"),
      "utf8"),
    context,
    {filename: "vba-lexer.js"});
  return context.window.MacroStudioVbaLexer;
}

function assertReversible(lexer, text, label) {
  var parsed = lexer.lex(text);

  assert(
    lexer.reconstruct(parsed) === text,
    label + " must reconstruct as the exact UTF-16 string.");
  parsed.lines.forEach(function (line) {
    assert(
      line.tokens.map(function (token) { return token.text; }).join("") ===
        line.text,
      label + " line " + line.number + " token text mismatch.");
  });
  return parsed;
}

function tokensOf(parsed, line, kind) {
  return parsed.lines[line - 1].tokens.filter(function (token) {
    return token.kind === kind;
  });
}

var lexer = loadLexer();
var interaction = assertReversible(
  lexer,
  "x = \"Don't C:\\data\\file.txt\" ' comment has \"quote\"\r\n" +
    "x = \"a\"\"b\" : y = \"\"\r\n",
  "string/comment interaction");

assert(
  tokensOf(interaction, 1, "string").length === 1 &&
    lexer.decodeStringToken(tokensOf(interaction, 1, "string")[0]) ===
      "Don't C:\\data\\file.txt",
  "An apostrophe inside a string must not start a comment.");
assert(
  tokensOf(interaction, 1, "comment").length === 1 &&
    tokensOf(interaction, 1, "comment")[0].text.indexOf("\"quote\"") >= 0,
  "Quotes inside a comment must not start strings.");
assert(
  lexer.decodeStringToken(tokensOf(interaction, 2, "string")[0]) === "a\"b" &&
    lexer.decodeStringToken(tokensOf(interaction, 2, "string")[1]) === "",
  "Escaped quotes and an empty VBA string must decode exactly.");

var rem = assertReversible(
  lexer,
  "Rem \"C:\\hidden-1\"\r\n" +
    "x = 1: REM \"C:\\hidden-2\"\r\n" +
    "Label1: rEm \"C:\\hidden-3\"\r\n" +
    "  100 Rem \"C:\\hidden-4\"\r\n" +
    "REMark = \"C:\\visible\"\r\n" +
    "REM\r\n",
  "REM comments");
assert(
  [1, 2, 3, 4, 6].every(function (line) {
    return tokensOf(rem, line, "comment").length === 1 &&
      tokensOf(rem, line, "string").length === 0;
  }),
  "REM must start a comment at every defined statement start.");
assert(
  tokensOf(rem, 5, "comment").length === 0 &&
    tokensOf(rem, 5, "string").length === 1,
  "REMark is an identifier, not a REM comment.");

var bracketDate = assertReversible(
  lexer,
  "[Don't \"split\"] = #2026-08-01#: x = \"C:\\real\"\r\n",
  "bracket/date");
assert(
  tokensOf(bracketDate, 1, "bracket").length === 1 &&
    tokensOf(bracketDate, 1, "string").length === 1 &&
    lexer.decodeStringToken(tokensOf(bracketDate, 1, "string")[0]) ===
      "C:\\real",
  "Brackets and date literals must not disturb the following string.");

var conditional = assertReversible(
  lexer,
  "#If VBA7 Then\r\n" +
    "  x = \"C:\\inside\"\r\n" +
    "  #If Win64 Then\r\n" +
    "    y = \"C:\\nested\"\r\n" +
    "  #Else\r\n" +
    "    z = \"C:\\other\"\r\n" +
    "  #End If\r\n" +
    "#End If\r\n" +
    "q = \"C:\\outside\"\r\n",
  "conditional compilation");
assert(conditional.conditionalBalanced, "Balanced directives were rejected.");
assert(
  [2, 4, 6].every(function (line) {
    return tokensOf(conditional, line, "string")[0].inConditional === true;
  }) &&
    tokensOf(conditional, 9, "string")[0].inConditional === false,
  "Conditional compilation depth must annotate only inner occurrences.");
assert(
  lexer.lex("#End If\r\nx = \"C:\\x\"\r\n").conditionalBalanced === false &&
    lexer.lex("#If VBA7 Then\r\nx = \"C:\\x\"\r\n")
      .conditionalBalanced === false,
  "Both extra and missing conditional delimiters must be unsafe.");

var continuation = assertReversible(
  lexer,
  "x = \"C:\\folder\\\" & _\r\n" +
    "    \"file.txt\"\r\n" +
    "a = \"inside _\"\r\n" +
    "b = 1 ' comment _\r\n" +
    "[external _]\r\n",
  "logical continuation");
assert(
  continuation.lines[0].continues === true &&
    continuation.lines[1].logicalIndex === continuation.lines[0].logicalIndex,
  "A code-space-underscore ending must join the next physical line.");
assert(
  continuation.lines.slice(2).every(function (line) {
    return line.continues === false;
  }),
  "String, comment and bracket underscores must not continue a line.");

var unsafe = assertReversible(
  lexer,
  "x = \"C:\\unterminated\r\n" +
    "y = \"C:\\safe\" : [unterminated\r\n",
  "unterminated syntax");
assert(
  unsafe.lines[0].unterminatedString === true &&
    unsafe.lines[1].unterminatedBracket === true,
  "Unterminated string and bracket lines must be marked.");

var procedures = lexer.lex(
  "Private Sub First()\r\n" +
  "x = \"C:\\one\"\r\n" +
  "End Sub\r\n" +
  "q = \"C:\\module\"\r\n" +
  "Property Get Value() As String\r\n" +
  "Value = \"C:\\two\"\r\n" +
  "End Property\r\n");
assert(
  tokensOf(procedures, 2, "string")[0].procedure === "First" &&
    tokensOf(procedures, 4, "string")[0].procedure === "-" &&
    tokensOf(procedures, 6, "string")[0].procedure === "Value",
  "Procedure ownership must end at End Sub/Function/Property.");

[
  "alpha\r\n日本語 😀 \"C:\\x\"\r\n",
  "alpha\n日本語 😀 \"C:\\x\"\n",
  "末尾改行なし 😀 \"C:\\x\""
].forEach(function (text, index) {
  var parsed = assertReversible(lexer, text, "synthetic form " + index);
  var lastLine = parsed.lines[parsed.lines.length - 1];
  var string = lastLine.tokens.filter(function (token) {
    return token.kind === "string";
  })[0];
  if (string) {
    assert(
      string.column === lastLine.text.indexOf("\""),
      "Columns must use UTF-16 code-unit offsets.");
  }
});

fs.readdirSync(path.join(__dirname, "fixtures", "monthly-report"))
  .filter(function (name) { return /\.bas$/i.test(name); })
  .forEach(function (name) {
    assertReversible(
      lexer,
      fs.readFileSync(
        path.join(__dirname, "fixtures", "monthly-report", name),
        "utf8"),
      "monthly-report/" + name);
  });

fs.readdirSync(path.join(__dirname, "fixtures", "lexer"))
  .filter(function (name) { return /\.bas$/i.test(name); })
  .forEach(function (name) {
    assertReversible(
      lexer,
      fs.readFileSync(path.join(__dirname, "fixtures", "lexer", name), "utf8"),
      "lexer/" + name);
  });

var realFixture = JSON.parse(fs.readFileSync(
  path.join(__dirname, "fixtures", "lexer", "test-large-modules.json"),
  "utf8"));
realFixture.modules.forEach(function (module) {
  assertReversible(
    lexer,
    Buffer.from(module.codeBase64, "base64").toString("utf8"),
    "test_large.xlsm/" + module.name);
});

console.log("test-vba-lexer: PASS");
console.log(
  "REM/brackets/dates/conditionals/continuations/unterminated syntax, " +
  "UTF-16 reversibility and real-book fixtures are fixed");
