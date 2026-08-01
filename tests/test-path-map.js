"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");
var dom = require("./helpers/dom-shim");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function equal(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(
      message + "\nexpected: " + JSON.stringify(expected) +
      "\nactual: " + JSON.stringify(actual));
  }
}

function loadProduct() {
  var context = {window: {}};
  ["vba-lexer.js", "path-map.js"].forEach(function (name) {
    vm.runInNewContext(
      fs.readFileSync(
        path.join(__dirname, "..", "assets", "js", name),
        "utf8"),
      context,
      {filename: name});
  });
  return {
    lexer: context.window.MacroStudioVbaLexer,
    pathMap: context.window.MacroStudioPathMap
  };
}

function row(mapping, value) {
  var found = null;
  mapping.rows.some(function (item) {
    if (item.groupKey === value) {
      found = item;
      return true;
    }
    return false;
  });
  return found;
}

function update(api, mapping, value, patch) {
  var next = api.updateRow(mapping, value, patch);
  assert(next && next !== mapping, "The mapping row was not updated: " + value);
  return next;
}

var product = loadProduct();
var api = product.pathMap;
var classifierModule = {
  name: "Classifier",
  code:
    "Option Explicit\r\n" +
    "Public Sub Probe()\r\n" +
    "  a = \"C:\\Data\\report.xlsx\"\r\n" +
    "  b = \"\\\\server\\share\\report.xlsx\"\r\n" +
    "  c = \"https://example.test/report.csv\"\r\n" +
    "  d = \"%APPDATA%\\MacroStudio\\cache.dat\"\r\n" +
    "  e = \"..\\Users\\person\\Desktop\\report.xlsx\"\r\n" +
    "  f = \"folder/\" & _\r\n" +
    "      \"child/\"\r\n" +
    "  Workbooks.Open \"report.xlsx\"\r\n" +
    "  q = \"archive.tar\"\r\n" +
    "  r = \"folder/\"\r\n" +
    "  s = \"C:\\Data\\report.xlsx\"\r\n" +
    "  t = \"c:\\data\\report.xlsx\"\r\n" +
    "  Rem \"C:\\hidden\\rem.txt\"\r\n" +
    "  ' \"C:\\hidden\\apostrophe.txt\"\r\n" +
    "  Debug.Print [C:\\hidden\\bracket.txt]\r\n" +
    "End Sub\r\n"
};
var mapping = api.detect([classifierModule]);

assert(api.isProductResult(mapping), "Detection did not return a product result.");
assert(Object.isFrozen(mapping), "The product mapping must be immutable.");
[
  ["C:\\Data\\report.xlsx", "driveAbsolute", "P-DRIVE-01"],
  ["\\\\server\\share\\report.xlsx", "unc", "P-UNC-01"],
  ["https://example.test/report.csv", "url", "P-URL-01"],
  ["%APPDATA%\\MacroStudio\\cache.dat", "envVar", "P-ENV-01"],
  ["..\\Users\\person\\Desktop\\report.xlsx", "knownFolder", "P-KNOWN-01"],
  ["folder/", "fragment", "P-FRAG-01"],
  ["report.xlsx", "bareName", "P-BARE-01"],
  ["archive.tar", "ambiguous", "P-AMB-01"]
].forEach(function (expected) {
  var found = row(mapping, expected[0]);
  assert(found, "Missing class fixture " + expected[0]);
  equal(found["class"], expected[1], "Class mismatch for " + expected[0]);
  equal(found.ruleId, expected[2], "Rule mismatch for " + expected[0]);
});
equal(
  row(mapping, "folder/").occurrences.length,
  2,
  "Equal values must aggregate by value alone.");
assert(
  row(mapping, "folder/").occurrences.some(function (occurrence) {
    return occurrence["class"] === "ambiguous";
  }),
  "Each occurrence must retain its own lower-priority class.");
equal(
  row(mapping, "folder/")["class"],
  "fragment",
  "The group must retain the highest-priority occurrence class.");
assert(
  row(mapping, "C:\\Data\\report.xlsx") !==
    row(mapping, "c:\\data\\report.xlsx"),
  "Case-distinct values must remain separate rows.");
assert(
  mapping.rows.every(function (item) { return item.applied === false; }),
  "Every mapping row must begin unapplied.");
assert(
  !mapping.rows.some(function (item) {
    return item.from.indexOf("hidden") >= 0;
  }),
  "Comments and bracket identifiers must never become candidates.");

var evidence = row(mapping, "C:\\Data\\report.xlsx").occurrences[0];
var evidenceLine = classifierModule.code.split("\r\n")[evidence.line - 1];
var evidenceToken = evidenceLine.slice(evidence.column, evidence.endColumn);
equal(
  product.lexer.decodeStringToken({
    kind: "string",
    text: evidenceToken
  }),
  "C:\\Data\\report.xlsx",
  "Evidence highlighting must use the product lexer span.");
assert(
  Array.isArray(evidence.logicalLines) &&
    evidence.logicalLines[0].line === evidence.line,
  "Evidence must carry the lexer's logical-line parts.");
equal(
  evidence.procedure,
  "Probe",
  "The occurrence must be attributed to its live procedure.");

var unsafe = api.detect([{
  name: "Unsafe",
  code:
    "#If VBA7 Then\r\n" +
    "x = \"C:\\unsafe\\one.txt\"\r\n"
}, {
  name: "Unterminated",
  code:
    "x = \"C:\\safe\\first.txt\" : [broken\r\n" +
    "y = \"C:\\unterminated\r\n"
}]);
assert(
  unsafe.rows.every(function (item) {
    return item["class"] === "ambiguous" && item.ruleId === "P-AMB-02";
  }),
  "Unbalanced conditionals and unterminated lines must lock every occurrence.");

[
  {
    input: {applied: true, "class": "fragment", to: ""},
    id: "M01"
  },
  {
    input: {applied: true, "class": "fragment", to: "x\tpath"},
    id: "M02"
  },
  {
    input: {
      applied: true,
      "class": "fragment",
      to: new Array(1026).join("x")
    },
    id: "M03"
  },
  {
    input: {
      applied: true,
      "class": "driveAbsolute",
      to: "hello",
      locationShapeConfirmed: false
    },
    id: "M04"
  }
].forEach(function (fixture) {
  var result = api.validateRow(fixture.input);
  assert(!result.ok, fixture.id + " failure was accepted.");
  equal(result.validationId, fixture.id, fixture.id + " ID mismatch.");
});
assert(
  api.validateRow({
    applied: false,
    "class": "driveAbsolute",
    to: "\t"
  }).ok,
  "An unapplied row must not be validated.");
assert(
  api.validateRow({
    applied: true,
    "class": "driveAbsolute",
    to: "D:\\new",
    locationShapeConfirmed: false
  }).ok,
  "Keeping an absolute location class must pass M04.");
assert(
  api.validateRow({
    applied: true,
    "class": "driveAbsolute",
    to: "https://example.test/new/",
    locationShapeConfirmed: false
  }).ok,
  "A drive-to-URL change must pass M04 without confirmation.");
var nonLocationValidation = api.validateRow({
  applied: true,
  "class": "driveAbsolute",
  to: "hello",
  locationShapeConfirmed: false
});
assert(
  !nonLocationValidation.ok &&
    nonLocationValidation.validationId === "M04" &&
    nonLocationValidation.requiresConfirmation === true,
  "A non-location target must require the M04 confirmation.");
assert(
  api.validateRow({
    applied: true,
    "class": "driveAbsolute",
    to: "hello",
    locationShapeConfirmed: true
  }).ok,
  "An explicitly confirmed non-location target must pass M04.");

var transitionMapping = api.detect([classifierModule]);
transitionMapping = update(
  api,
  transitionMapping,
  "C:\\Data\\report.xlsx",
  {to: "https://example.test/shared/report.xlsx"});
var transitionRow = row(transitionMapping, "C:\\Data\\report.xlsx");
assert(
  api.canApply(transitionMapping) &&
    transitionRow.valid &&
    !transitionRow.needsLocationShapeConfirmation,
  "An absolute-class transition must be non-blocking.");
equal(
  transitionRow.locationClassChangeMessage,
  "ドライブのパスから URL に変わります。",
  "An absolute-class transition must be shown as information.");

var nonLocationMapping = api.detect([classifierModule]);
nonLocationMapping = update(
  api,
  nonLocationMapping,
  "C:\\Data\\report.xlsx",
  {to: "hello"});
assert(
  !api.canApply(nonLocationMapping) &&
    row(nonLocationMapping, "C:\\Data\\report.xlsx")
      .needsLocationShapeConfirmation,
  "A non-location target must block deterministic apply.");
nonLocationMapping = update(
  api,
  nonLocationMapping,
  "C:\\Data\\report.xlsx",
  {locationShapeConfirmed: true});
assert(
  api.canApply(nonLocationMapping),
  "A confirmed non-location target must enable deterministic apply.");
nonLocationMapping = update(
  api,
  nonLocationMapping,
  "C:\\Data\\report.xlsx",
  {to: "hello-again"});
assert(
  !api.canApply(nonLocationMapping) &&
    !row(nonLocationMapping, "C:\\Data\\report.xlsx")
      .locationShapeConfirmed,
  "Changing a confirmed non-location target must require fresh confirmation.");

var mergeMapping = api.detect([classifierModule]);
mergeMapping = update(
  api,
  mergeMapping,
  "C:\\Data\\report.xlsx",
  {to: "D:\\merged"});
mergeMapping = update(
  api,
  mergeMapping,
  "\\\\server\\share\\report.xlsx",
  {to: "D:\\merged"});
assert(
  api.canApply(mergeMapping),
  "Two source rows may intentionally converge on the same new value.");
assert(
  row(mergeMapping, "\\\\server\\share\\report.xlsx")
    .locationClassChangeMessage.length > 0,
  "A UNC-to-drive transition must remain visible but non-blocking.");
mergeMapping = update(
  api,
  mergeMapping,
  "\\\\server\\share\\report.xlsx",
  {to: "E:\\changed-again"});
assert(
  api.canApply(mergeMapping) &&
    row(mergeMapping, "\\\\server\\share\\report.xlsx").validationId ===
      null,
  "Changing between absolute location classes must not trigger M04.");
assert(
  JSON.stringify(api.validate(mergeMapping)).indexOf("M05") < 0,
  "M05 must not exist.");

var applyModule = {
  name: "ApplyModule",
  code:
    "Option Explicit\r\n" +
    "Public Sub Run()\r\n" +
    "  a = \"C:\\Data\\report.xlsx\": b = \"C:\\Data\\report.xlsx\"\r\n" +
    "  c = \"archive.tar\" ' C:\\Data\\report.xlsx stays text\r\n" +
    "End Sub\r\n"
};
var applyMapping = api.detect([applyModule]);
var newValue = "D:\\New\"Folder\\report.xlsx";
applyMapping = update(
  api,
  applyMapping,
  "C:\\Data\\report.xlsx",
  {to: newValue});
assert(api.canApply(applyMapping), "A valid drive mapping was not ready.");
var applied = api.apply(applyMapping, [applyModule]);
assert(
  api.isProductResult(applied) && applied.ok && applied.kind === "apply",
  "Apply did not return a branded success result.");
equal(applied.modules.length, 1, "The changed module count is wrong.");
equal(
  applied.modules[0].code,
  "Option Explicit\r\n" +
    "Public Sub Run()\r\n" +
    "  a = \"D:\\New\"\"Folder\\report.xlsx\": " +
      "b = \"D:\\New\"\"Folder\\report.xlsx\"\r\n" +
    "  c = \"archive.tar\" ' C:\\Data\\report.xlsx stays text\r\n" +
    "End Sub\r\n",
  "Only the two recorded string-token spans may change.");
assert(
  applied.modules[0].code.indexOf("\"archive.tar\"") >= 0,
  "An unapplied candidate changed.");
assert(
  JSON.stringify(applied.logSummary).indexOf("C:\\Data") < 0 &&
    JSON.stringify(applied.logSummary).indexOf("D:\\New") < 0,
  "The safe log summary leaked path values.");

var alteredModules = [{
  name: applyModule.name,
  code: applyModule.code.replace(
    "C:\\Data\\report.xlsx",
    "C:\\Other\\report.xlsx")
}];
var beforeModules = JSON.stringify(alteredModules);
var beforeMapping = JSON.stringify(applyMapping);
var refused = api.apply(applyMapping, alteredModules);
assert(
  api.isProductResult(refused) && !refused.ok &&
    refused.code === "E-MAP-02",
  "A stale token position must fail the whole preflight.");
equal(
  JSON.stringify(alteredModules),
  beforeModules,
  "E-MAP-02 mutated the input modules.");
equal(
  JSON.stringify(applyMapping),
  beforeMapping,
  "E-MAP-02 mutated staged mappings.");
assert(
  !api.isProductResult(JSON.parse(JSON.stringify(applyMapping))),
  "The private product brand must not survive cloning.");

assert(
  Object.keys(api).every(function (name) {
    return !/replace|replaceAll|fromTo/i.test(name);
  }),
  "An arbitrary string-replacement API must not be public.");

var workflowSource = fs.readFileSync(
  path.join(__dirname, "..", "assets", "js", "screens", "workflow.js"),
  "utf8");
assert(
  workflowSource.indexOf("path-evidence-mark") >= 0 &&
    workflowSource.indexOf("occurrence.column") >= 0 &&
    workflowSource.indexOf("occurrence.endColumn") >= 0,
  "The evidence UI must highlight the exact product-lexer span.");
assert(
  workflowSource.indexOf("MacroStudioVbaHighlight") < 0,
  "The mapping evidence UI must not use the display-only highlighter.");

var uiWindow = {};
var uiDocument = {createElement: dom.createElement};
var uiContext = vm.createContext({window: uiWindow, document: uiDocument});
uiWindow.window = uiWindow;
uiWindow.document = uiDocument;
["icons.js", "preset-document.js", "vba-lexer.js", "path-map.js", "screens.js",
  "screens/workflow.js"].forEach(function (name) {
  vm.runInContext(
    fs.readFileSync(path.join(__dirname, "..", "assets", "js", name), "utf8"),
    uiContext,
    {filename: name});
});
var uiMapping = uiWindow.MacroStudioPathMap.detect([classifierModule]);
var uiScreen = uiWindow.MacroStudioWorkflow.createRepairInputScreen({
  presetEngine: "固定パス置換",
  pathMap: uiMapping,
  busyAction: null
});
var uiRows = dom.collect(uiScreen, function (node) {
  return node.classList && node.classList.contains("path-map-row");
});
equal(uiRows.length, uiMapping.rows.length,
  "Screen 4 must render one row per exact-value group.");
var driveUiRow = uiRows.filter(function (node) {
  return dom.text(node).indexOf("C:\\Data\\report.xlsx") >= 0;
})[0];
var ambiguousUiRow = uiRows.filter(function (node) {
  return dom.text(node).indexOf("archive.tar") >= 0;
})[0];
assert(driveUiRow && driveUiRow.querySelector(".path-map-input"),
  "An absolute-path row must expose its input immediately.");
assert(ambiguousUiRow &&
  ambiguousUiRow.querySelector('[data-workflow-input="path-map-include"]') &&
  !ambiguousUiRow.querySelector(".path-map-input"),
  "An ambiguous row must stay locked until explicitly included.");
var evidenceMarks = dom.collect(uiScreen, function (node) {
  return node.classList && node.classList.contains("path-evidence-mark");
});
assert(evidenceMarks.length > 0 && dom.text(evidenceMarks[0]).charAt(0) === '"',
  "Evidence must visibly mark the full string token, including its quotes.");

var urlUiMapping = update(
  uiWindow.MacroStudioPathMap,
  uiMapping,
  "C:\\Data\\report.xlsx",
  {to: "https://example.test/shared/report.xlsx"});
var urlUiScreen = uiWindow.MacroStudioWorkflow.createRepairInputScreen({
  presetEngine: "固定パス置換",
  pathMap: urlUiMapping,
  busyAction: null
});
var urlUiRow = dom.collect(urlUiScreen, function (node) {
  return node.classList && node.classList.contains("path-map-row") &&
    dom.text(node).indexOf("C:\\Data\\report.xlsx") >= 0;
})[0];
assert(
  urlUiRow &&
    dom.text(urlUiRow).indexOf("ドライブのパスから URL に変わります。") >= 0 &&
    !urlUiRow.querySelector(
      '[data-workflow-input="path-map-location-shape-confirm"]'),
  "A drive-to-URL change must show information without a confirmation gate.");

var nonLocationUiMapping = update(
  uiWindow.MacroStudioPathMap,
  uiMapping,
  "C:\\Data\\report.xlsx",
  {to: "hello"});
var nonLocationUiScreen =
  uiWindow.MacroStudioWorkflow.createRepairInputScreen({
    presetEngine: "固定パス置換",
    pathMap: nonLocationUiMapping,
    busyAction: null
  });
var nonLocationUiRow = dom.collect(nonLocationUiScreen, function (node) {
  return node.classList && node.classList.contains("path-map-row") &&
    dom.text(node).indexOf("C:\\Data\\report.xlsx") >= 0;
})[0];
assert(
  nonLocationUiRow &&
    nonLocationUiRow.querySelector(
      '[data-workflow-input="path-map-location-shape-confirm"]') &&
    dom.text(nonLocationUiRow).indexOf(
      "入力した値が場所の形になっていないことを確認した") >= 0,
  "A non-location target must render the M04 confirmation gate.");

console.log("test-path-map: PASS");
console.log(
  "8 classes, value-only grouping, M01-M04, exact-span rebuild, quote " +
  "escaping, private brands and all-or-nothing E-MAP-02 are fixed");
