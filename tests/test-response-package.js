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
  window: windowObject,
  Uint8Array: Uint8Array,
  Math: Math
});
windowObject.window = windowObject;

vm.runInContext(
  fs.readFileSync(
    path.join(root, "assets", "js", "response-package.js"),
    "utf8"),
  context,
  { filename: "response-package.js" });

var api = windowObject.MacroStudioResponse;
var identity = api.createRequestIdentity();
var id = identity.id;
var other = api.createRequestId();

function pack(requestId, modules, options) {
  var settings = options || {};
  var lines = [];

  if (settings.fenced) {
    lines.push("```vb");
  }
  modules.forEach(function (module) {
    lines.push(api.beginLine(requestId, module.kind, module.name));
    lines.push(module.code);
    if (!module.skipEnd) {
      lines.push(api.endLine(requestId, module.kind, module.name));
    }
  });
  if (!settings.skipComplete) {
    lines.push(api.completeLine(
      requestId,
      settings.count === undefined
        ? modules.length
        : settings.count));
  }
  if (settings.fenced) {
    lines.push("```");
  }
  return lines.join("\r\n");
}

var main = {
  name: "Main",
  kind: "standard",
  code: "Option Explicit\r\nPublic Sub Run()\r\n    Debug.Print 1\r\nEnd Sub"
};
var helper = {
  name: "Helper",
  kind: "class",
  code: "Option Explicit\r\nPrivate value As Long"
};
var addition = {
  name: "CompatHelpers",
  kind: "standard",
  code: "Option Explicit\r\nPublic Sub Wait(): End Sub"
};

// ---- the request id ----

assert(api.isRequestId(id), "A generated request id must be a UUID.");
assert(id !== other, "Each request must get its own id.");
assert(
  identity.secure === false,
  "A context without crypto must report the Math.random fallback.");
assert(
  !api.isRequestId("") && !api.isRequestId("not-an-id"),
  "Anything that is not a UUID must be refused.");

windowObject.crypto = {
  getRandomValues: function (bytes) {
    var index;

    for (index = 0; index < bytes.length; index += 1) {
      bytes[index] = index;
    }
    return bytes;
  }
};
var secureIdentity = api.createRequestIdentity();

assert(
  secureIdentity.secure === true && api.isRequestId(secureIdentity.id),
  "A working crypto provider must be reported as secure.");
windowObject.crypto = {
  getRandomValues: function () {
    throw new Error("crypto unavailable");
  }
};
var failedCryptoIdentity = api.createRequestIdentity();

assert(
  failedCryptoIdentity.secure === false &&
    api.isRequestId(failedCryptoIdentity.id),
  "A failing crypto provider must fall back without losing the UUID shape.");
delete windowObject.crypto;

// ---- the happy path ----

var parsed = api.parse(pack(id, [main, helper]), id);

assert(parsed.ok, "A well formed package must parse: " + parsed.message);
assert(parsed.modules.length === 2, "Both modules must come back.");
assert(
  parsed.modules[0].name === "Main" &&
    parsed.modules[0].kind === "standard" &&
    parsed.modules[0].code === main.code,
  "The first module was not read back as written.");
assert(
  parsed.modules[1].name === "Helper" &&
    parsed.modules[1].kind === "class",
  "The second module lost its name or kind.");

// Code fences around the block, and the block on its own, both work.
assert(
  api.parse(pack(id, [main], { fenced: true }), id).ok,
  "A fenced package must parse.");

// ---- what the package means for this workbook ----

var described = api.describe(
  api.parse(pack(id, [main, addition]), id),
  [{ name: "main", type: "standard" }]);

assert(
  described.total === 2 &&
    described.existing === 1 &&
    described.added === 1,
  "The package summary must separate existing and added modules.");
assert(
  described.modules[0].name === "main" &&
    described.modules[0].isNew === false,
  "An existing module must keep the name the workbook uses.");
assert(
  described.modules[1].isNew === true,
  "A module the workbook does not have must count as new.");

// ---- everything that must be refused ----

var cases = [
  {
    label: "an answer to another request",
    text: pack(other, [main]),
    reason: "otherRequest"
  },
  {
    label: "no sentinels at all",
    text: "Option Explicit\r\nPublic Sub Run(): End Sub\r\n",
    reason: "noSentinel"
  },
  {
    label: "empty clipboard",
    text: "   \r\n  ",
    reason: "empty"
  },
  {
    label: "a module that never ends",
    text: pack(id, [{
      name: "Main",
      kind: "standard",
      code: main.code,
      skipEnd: true
    }]),
    reason: "truncated"
  },
  {
    label: "a package without its end line",
    text: pack(id, [main], { skipComplete: true }),
    reason: "truncated"
  },
  {
    label: "a count that does not match",
    text: pack(id, [main, helper], { count: 3 }),
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "a decimal count",
    text: pack(id, [main], { count: "1.0" }),
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "a leading-zero count",
    text: pack(id, [main], { count: "01" }),
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "a hexadecimal count",
    text: pack(id, [main, helper], { count: "0x2" }),
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "an exponent count",
    text: pack(id, [main], { count: "1e0" }),
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "an extra COMPLETE token",
    text: pack(id, [main]) + " extra",
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "two COMPLETE lines",
    text: pack(id, [main]) + "\r\n" + api.completeLine(id, 1),
    reason: "mismatch",
    validationId: "R1"
  },
  {
    label: "the same module twice",
    text: pack(id, [main, main]),
    reason: "duplicate"
  },
  {
    label: "an unknown module kind",
    text: [
      api.beginLine(id, "spreadsheet", "Main"),
      main.code,
      api.endLine(id, "spreadsheet", "Main"),
      api.completeLine(id, 1)
    ].join("\r\n"),
    reason: "unknownKind"
  },
  {
    label: "a name that is not an identifier",
    text: [
      api.beginLine(id, "standard", "1Broken"),
      main.code,
      api.endLine(id, "standard", "1Broken"),
      api.completeLine(id, 1)
    ].join("\r\n"),
    reason: "badName"
  },
  {
    label: "an end line for another module",
    text: [
      api.beginLine(id, "standard", "Main"),
      main.code,
      api.endLine(id, "standard", "Other"),
      api.completeLine(id, 1)
    ].join("\r\n"),
    reason: "mismatch"
  },
  {
    label: "a module with no code",
    text: [
      api.beginLine(id, "standard", "Main"),
      "   ",
      api.endLine(id, "standard", "Main"),
      api.completeLine(id, 1)
    ].join("\r\n"),
    reason: "emptyModule"
  },
  {
    label: "a begin inside a module",
    text: [
      api.beginLine(id, "standard", "Main"),
      main.code,
      api.beginLine(id, "standard", "Helper"),
      helper.code,
      api.endLine(id, "standard", "Helper"),
      api.completeLine(id, 1)
    ].join("\r\n"),
    reason: "mismatch"
  },
  {
    label: "an unknown directive",
    text: [
      "'@MACROSTUDIO " + id + " RESTART now",
      api.completeLine(id, 0)
    ].join("\r\n"),
    reason: "mismatch"
  }
];

cases.forEach(function (item) {
  var result = api.parse(item.text, id);

  assert(!result.ok, "This must be refused: " + item.label);
  assert(
    result.reason === item.reason,
    "Wrong reason for " + item.label + ": " + result.reason);
  if (item.validationId) {
    assert(
      result.validationId === item.validationId,
      "Wrong validation id for " + item.label + ": " +
        result.validationId);
  }
  assert(
    result.message.length > 0 &&
      result.message.indexOf("undefined") < 0,
    "A refusal must carry a readable message: " + item.label);
  assert(
    result.modules.length === 0,
    "A refused package must not hand over modules: " + item.label);
});

// A marker-looking line that belongs to the pasted code stays code:
// only a whole line with this request's id counts as a sentinel.
var trap = {
  name: "Main",
  kind: "standard",
  code: [
    "Option Explicit",
    "' @MACROSTUDIO looks like a marker but is not",
    "Debug.Print \"'@MACROSTUDIO inside a string\"",
    "Public Sub Run(): End Sub"
  ].join("\r\n")
};
var trapped = api.parse(pack(id, [trap]), id);

assert(trapped.ok, "Marker-like code must not break the package.");
assert(
  trapped.modules[0].code === trap.code,
  "Marker-like lines must survive as code.");

// Leading spaces around a sentinel are tolerated; the content is not.
var indented = [
  "   " + api.beginLine(id, "standard", "Main"),
  main.code,
  "\t" + api.endLine(id, "standard", "Main"),
  "  " + api.completeLine(id, 1)
].join("\r\n");

assert(
  api.parse(indented, id).ok,
  "An indented sentinel must still be recognised.");

// A long module survives untouched.
var longLines = [];
var index;
for (index = 0; index < 4000; index += 1) {
  longLines.push("    Debug.Print " + index);
}
var longModule = {
  name: "Bulk",
  kind: "standard",
  code: "Option Explicit\r\n" + longLines.join("\r\n")
};
var longParsed = api.parse(pack(id, [longModule]), id);

assert(
  longParsed.ok &&
    longParsed.modules[0].code === longModule.code,
  "A long module must survive the round trip.");

// Several modules, including a new one, in one block.
var many = api.parse(
  pack(id, [
    main,
    helper,
    { name: "Sheet1", kind: "document", code: "Option Explicit" },
    { name: "CompatHelpers", kind: "standard", code: "Public Sub W(): End Sub" }
  ]),
  id);

assert(
  many.ok && many.modules.length === 4,
  "Four modules in one block must all be read.");
assert(
  many.modules.map(function (item) {
    return item.kind;
  }).join(",") === "standard,class,document,standard",
  "Each module must keep its own kind.");

// ---- the workbook decides the kind of a module it already has ----

var wrongKind = api.describe(
  api.parse(
    pack(id, [
      { name: "OrderRecord", kind: "standard", code: "Option Explicit" },
      { name: "Sheet1", kind: "class", code: "Option Explicit" },
      { name: "Main", kind: "standard", code: "Option Explicit" }
    ]),
    id),
  [
    { name: "OrderRecord", type: "class" },
    { name: "Sheet1", type: "document" },
    { name: "Main", type: "standard" }
  ]);

assert(
  wrongKind.modules[0].kind === "class" &&
    wrongKind.modules[1].kind === "document",
  "An existing module must keep the kind the workbook has.");
assert(
  wrongKind.modules[0].answeredKind === "standard" &&
    wrongKind.modules[0].kindCorrected === true,
  "The kind the answer gave must stay visible as a correction.");
assert(
  wrongKind.modules[2].kindCorrected === false,
  "A matching kind is not a correction.");
assert(
  wrongKind.warnings.length === 2 &&
    wrongKind.warnings[0].name === "OrderRecord" &&
    wrongKind.warnings[0].answered === "standard" &&
    wrongKind.warnings[0].actual === "class",
  "Every corrected kind must be reported.");

var warningText = api.describeKindWarning(wrongKind.warnings);
assert(
  warningText.indexOf("OrderRecord") >= 0 &&
    warningText.indexOf("Sheet1") >= 0,
  "The warning must name the modules whose kind was corrected.");
assert(
  api.describeKindWarning([]) === "" &&
    api.describeKindWarning(null) === "",
  "With nothing corrected there is no warning to show.");

// The contract layer, not the app, refuses every non-standard new module.
var newStandard = api.describe(
  api.parse(
    pack(id, [
      { name: "NewThing", kind: "standard", code: "Option Explicit" }
    ]),
    id),
  [{ name: "Main", type: "standard" }]);

assert(
  newStandard.ok &&
    newStandard.modules[0].isNew === true &&
    newStandard.modules[0].kind === "standard" &&
    newStandard.warnings.length === 0,
  "A new standard module must pass R2.");

["class", "form", "document"].forEach(function (kind) {
  var refused = api.describe(
    api.parse(
      pack(id, [
        { name: "NewThing", kind: kind, code: "Option Explicit" }
      ]),
      id),
    [{ name: "Main", type: "standard" }]);

  assert(
    !refused.ok &&
      refused.validationId === "R2" &&
      refused.reason === "newModuleKind" &&
      refused.modules.length === 0,
    "A new " + kind + " module must be refused by R2 without output.");
});

console.log("test-response-package: PASS");
console.log(
  "request ids, one-block packaging, and every refusal case " +
  "behave as specified");
