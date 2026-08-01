"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

var root = path.resolve(__dirname, "..");
var windowObject = {};
var context = vm.createContext({
  window: windowObject,
  JSON: JSON,
  Object: Object,
  Array: Array,
  Error: Error
});
windowObject.window = windowObject;

vm.runInContext(
  fs.readFileSync(
    path.join(root, "assets", "js", "target-environment.js"),
    "utf8"),
  context,
  { filename: "target-environment.js" });

var api = windowObject.MacroStudioTargetEnvironment;
var valid = {
  schemaVersion: 1,
  profileId: "test-terminal",
  displayName: "試験端末",
  revision: "2026-08-01",
  summary: "1行目\n2行目",
  sources: [
    {
      id: "source-one",
      origin: "fixture",
      path: "fixture.json",
      readAt: "2026-08-01"
    }
  ],
  constraints: [
    {
      key: "Z_STORAGE",
      axis: "storage",
      effect: "changed",
      title: "保存場所が変わる",
      detail: "固定の場所は使えない。",
      basis: "inferred",
      sourceIds: ["source-one"]
    },
    {
      key: "A_EXECUTION",
      axis: "execution",
      effect: "blocked",
      title: "実行できない",
      detail: "外部の処理は止められる。",
      basis: "declared",
      sourceIds: ["source-one"],
      examples: ["Alpha", "Beta"]
    }
  ]
};

function expectFailure(value, validationId, label) {
  var actualCode = "";
  var actualValidationId = "";

  try {
    api.parse(typeof value === "string" ? value : JSON.stringify(value));
  } catch (error) {
    actualCode = error && error.code;
    actualValidationId = error && error.validationId;
  }
  assert(
    actualCode === "E-ENV-01" && actualValidationId === validationId,
    label + " must fail with E-ENV-01/" + validationId +
      ", got " + actualCode + "/" + actualValidationId + ".");
}

assert(
  api.parse(JSON.stringify(valid)).profileId === "test-terminal",
  "A valid target environment must parse.");

expectFailure("", "ENV-READ", "A missing or empty file");
expectFailure(
  "\uFFFD" + JSON.stringify(valid),
  "ENV-JSON",
  "Malformed text reaching the JSON boundary");
expectFailure("{not json", "ENV-JSON", "Invalid JSON");

var changed = clone(valid);
changed.schemaVersion = 2;
expectFailure(changed, "ENV-SCHEMA", "An unknown schema version");

changed = clone(valid);
delete changed.displayName;
expectFailure(changed, "ENV-FIELD", "A missing required field");

changed = clone(valid);
changed.revision = 1;
expectFailure(
  changed,
  "ENV-FIELD",
  "A required field with the wrong type");

changed = clone(valid);
changed.constraints[0].axis = "network";
expectFailure(changed, "ENV-ENUM", "An unknown enum value");

changed = clone(valid);
changed.constraints[1].key = changed.constraints[0].key;
expectFailure(changed, "ENV-KEYDUP", "A duplicated constraint key");

changed = clone(valid);
changed.constraints[0].key = "bad-key";
expectFailure(changed, "ENV-KEY", "A malformed constraint key");

changed = clone(valid);
changed.constraints[0].sourceIds = ["missing-source"];
expectFailure(changed, "ENV-SOURCE", "An unknown source id");

changed = clone(valid);
changed.constraints[0].sourceIds = [];
expectFailure(changed, "ENV-SOURCE", "An empty source id list");

changed = clone(valid);
changed.constraints = [];
expectFailure(changed, "ENV-EMPTY", "An empty constraint list");

changed = clone(valid);
changed.sources.push(clone(changed.sources[0]));
expectFailure(changed, "ENV-SOURCEDUP", "A duplicated source id");

changed = clone(valid);
changed.profileId = "UPPER_CASE";
expectFailure(changed, "ENV-FIELD", "A malformed profile id");

changed = clone(valid);
changed.summary = "1\n2\n3\n4";
expectFailure(
  changed,
  "ENV-FIELD",
  "A summary longer than three lines");

changed = clone(valid);
changed.constraints[0].title = "line 1\nline 2";
expectFailure(changed, "ENV-FIELD", "A multi-line title");

changed = clone(valid);
changed.constraints[0].examples = [1];
expectFailure(changed, "ENV-FIELD", "A non-string example");

var banner = new Array(81).join("=");
var divider = new Array(81).join("-");
var expectedPrompt = [
  banner,
  " TARGET ENVIRONMENT: 試験端末 (test-terminal / rev 2026-08-01)",
  banner,
  "1行目",
  "2行目",
  "",
  "[A_EXECUTION] execution / blocked / declared",
  "  実行できない",
  "  外部の処理は止められる。",
  "  例: Alpha, Beta",
  "",
  "[Z_STORAGE] storage / changed / inferred",
  "  保存場所が変わる",
  "  固定の場所は使えない。",
  "",
  divider,
  " basis: observed=実測 / declared=前提として宣言 / inferred=設計上の推定",
  banner
].join("\r\n");

assert(
  api.renderForPrompt(valid) === expectedPrompt,
  "Prompt rendering must be byte-fixed, axis/key sorted, and omit " +
    "the examples line when examples are absent.");

var actualPath = path.join(
  root,
  "environment",
  "target-environment.json");
var actualText = fs.readFileSync(actualPath, "utf8");
var actual = api.parse(actualText);
var keys = Object.create(null);
var exampleCount = 0;

assert(actual.constraints.length === 24, "The bundled profile must have 24 constraints.");
actual.constraints.forEach(function (constraint) {
  assert(
    /^[A-Z][A-Z0-9_]{2,39}$/.test(constraint.key),
    "Every bundled key must follow the naming rule.");
  assert(!keys[constraint.key], "Every bundled key must be unique.");
  keys[constraint.key] = true;
  assert(
    constraint.basis === "declared" || constraint.basis === "inferred",
    "The initial profile must not claim an unperformed observation.");
  if (Object.prototype.hasOwnProperty.call(constraint, "examples")) {
    exampleCount += 1;
  }
});
assert(exampleCount === 6, "Exactly six initial constraints must carry examples.");
assert(
  actual.constraints.filter(function (constraint) {
    return constraint.axis === "office" || constraint.axis === "platform";
  }).length === 0,
  "Office and platform must stay empty until target-terminal observations exist.");

var hostSource = fs.readFileSync(
  path.join(root, "src", "04_HostServices.cs"),
  "utf8");
var methodStart = hostSource.indexOf("GetTargetEnvironment()");
var methodEnd = hostSource.indexOf("// Every run gets one folder", methodStart);
var hostMethod = hostSource.slice(methodStart, methodEnd);
assert(
  methodStart >= 0 &&
    hostMethod.indexOf("new UTF8Encoding(false, true)") >= 0,
  "The host transport must reject invalid UTF-8 instead of replacing bytes.");

var indexSource = fs.readFileSync(
  path.join(root, "assets", "index.html"),
  "utf8");
var appSource = fs.readFileSync(
  path.join(root, "assets", "js", "app.js"),
  "utf8");
var loadStart = appSource.indexOf("function loadTargetEnvironment()");
var loadEnd = appSource.indexOf("function goToScreen", loadStart);
var loadSource = appSource.slice(loadStart, loadEnd);
assert(
  indexSource.indexOf('src="js/target-environment.js"') >= 0 &&
    indexSource.indexOf('src="js/target-environment.js"') <
      indexSource.indexOf('src="js/app.js"'),
  "The environment validator must load before the app.");
assert(
  loadSource.indexOf('request("getTargetEnvironment")') >= 0 &&
    loadSource.indexOf("MacroStudioTargetEnvironment.parse") >= 0,
  "The app must load and validate the real environment file.");
assert(
  loadSource.indexOf("handleHostError") < 0 &&
    appSource.indexOf("createTargetEnvironmentErrorCard") >= 0 &&
    appSource.indexOf("environment\\\\target-environment.json") >= 0,
  "E-ENV-01 must remain a blocking in-screen card, not a toast.");

console.log("test-target-environment: PASS");
console.log("schema failures, bundled data, ordering and byte-fixed prompt rendering verified");
