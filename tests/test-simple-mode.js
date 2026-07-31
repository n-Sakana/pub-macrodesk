"use strict";

// The short way through the flow.
//
// It is the same run as the detailed one: the same request id, the same
// answer checks, the same rebuild. What differs is which screens are
// visited and what they show. So this checks two things - that the short
// path really is shorter, and that the detailed path is untouched by it.

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var root = path.resolve(__dirname, "..");

function createElementShim(tagName) {
  var element = {
    tagName: String(tagName).toUpperCase(),
    className: "",
    textContent: "",
    innerHTML: "",
    value: "",
    id: "",
    rows: 0,
    checked: false,
    spellcheck: true,
    children: [],
    attributes: {},
    disabled: false,
    type: ""
  };

  function names() {
    return element.className.split(/\s+/).filter(function (name) {
      return name.length > 0;
    });
  }

  element.appendChild = function (child) {
    element.children.push(child);
    return child;
  };
  element.setAttribute = function (name, value) {
    element.attributes[name] = String(value);
  };
  element.getAttribute = function (name) {
    return Object.prototype.hasOwnProperty.call(element.attributes, name)
      ? element.attributes[name]
      : null;
  };
  element.querySelector = function () {
    return null;
  };
  element.classList = {
    add: function (name) {
      if (names().indexOf(name) < 0) {
        element.className = names().concat([name]).join(" ");
      }
    },
    remove: function (name) {
      element.className = names().filter(function (item) {
        return item !== name;
      }).join(" ");
    },
    contains: function (name) {
      return names().indexOf(name) >= 0;
    },
    toggle: function (name, on) {
      if (on) {
        element.classList.add(name);
      } else {
        element.classList.remove(name);
      }
    }
  };
  return element;
}

function collect(element, className, found) {
  var hits = found || [];

  if (element.classList && element.classList.contains(className)) {
    hits.push(element);
  }
  element.children.forEach(function (child) {
    collect(child, className, hits);
  });
  return hits;
}

function readText(element) {
  var text = element.textContent || "";

  element.children.forEach(function (child) {
    text += readText(child);
  });
  return text;
}

function findByAction(element, action, found) {
  var hits = found || [];

  if (element.getAttribute &&
      element.getAttribute("data-action") === action) {
    hits.push(element);
  }
  element.children.forEach(function (child) {
    findByAction(child, action, hits);
  });
  return hits;
}

var windowObject = {};
var context = vm.createContext({
  window: windowObject,
  document: {
    createElement: createElementShim,
    addEventListener: function () {
    },
    getElementById: function () {
      return null;
    },
    querySelector: function () {
      return null;
    }
  },
  Promise: Promise,
  Uint8Array: Uint8Array,
  Math: Math,
  setTimeout: setTimeout,
  clearTimeout: clearTimeout
});

windowObject.window = windowObject;
windowObject.document = context.document;
windowObject.setTimeout = setTimeout;
windowObject.clearTimeout = clearTimeout;
windowObject.console = { error: function () {} };
windowObject.hostBridge = {
  request: function () {
    return Promise.resolve(null);
  },
  on: function () {
    return function () {
    };
  }
};

[
  "diff.js",
  "diff-view.js",
  "vba-highlight.js",
  "preset-document.js",
  "response-package.js",
  "screens.js",
  "state.js",
  "app.js"
].forEach(function (name) {
  vm.runInContext(
    fs.readFileSync(path.join(root, "assets", "js", name), "utf8"),
    context,
    { filename: name });
});

var app = windowObject.MacroStudioApp;
var screens = windowObject.MacroStudioScreens;
var stateApi = windowObject.MacroStudioState;

function readUtf8(filePath) {
  var text = fs.readFileSync(filePath, "utf8");

  if (text.charCodeAt(0) === 0xFEFF) {
    text = text.slice(1);
  }
  return text;
}

var presetDir = path.join(root, "presets");
var presets = fs.readdirSync(presetDir).filter(function (name) {
  return path.extname(name).toLowerCase() === ".md";
}).map(function (name) {
  return {
    file: name,
    content: readUtf8(path.join(presetDir, name))
  };
});

var BOOK = {
  path: "C:\\books\\SalesTool.xlsm",
  name: "SalesTool.xlsm",
  ext: ".xlsm",
  totalLines: 40
};
var MODULES = [{
  name: "Main",
  type: "standard",
  typeLabel: "標準モジュール",
  ext: ".bas",
  lineCount: 3,
  code: "Sub A()\r\nEnd Sub",
  attributes: ""
}];

function start(simple) {
  stateApi.reset();
  stateApi.setAppInfo({ version: "test", presets: presets });
  if (simple) {
    stateApi.startSimple();
  } else {
    stateApi.setMode("refactor");
  }
  return stateApi.getState();
}

// ---- the opening screen offers the short way, quietly ----

var opening = app.createModeScreen(start(false));
var starters = findByAction(opening, "start-simple");

assert(
  starters.length === 1,
  "The opening screen must offer the short way exactly once.");
assert(
  readText(starters[0]).indexOf("簡易モード") >= 0,
  "The short way must say what it is: " + readText(starters[0]));
assert(
  !starters[0].classList.contains("button--primary"),
  "The short way must not be a primary button.");
assert(
  findByAction(opening, "select-mode").length === 2,
  "The two main choices must still be there.");

// ---- the short way skips the screens that ask for decisions ----

var state = start(true);

assert(state.simple === true, "The short way must be on.");
assert(
  state.mode === "refactor",
  "The short way is a refactoring run.");
assert(
  state.screen === screens.bookScreen,
  "The short way opens on the workbook screen: " + state.screen);
assert(
  screens.getMajors(state).length === 4,
  "The short way still has four steps.");

stateApi.setBook(BOOK, MODULES);
state = stateApi.getState();
assert(
  screens.nextIndex(state, screens.bookScreen) === screens.requestScreen,
  "The short way goes from the workbook straight to what to change.");
assert(
  screens.nextIndex(state, screens.reviewScreen) === screens.buildScreen,
  "The short way builds straight from the review screen.");

// The detailed path keeps every one of its screens.
var detailed = start(false);

stateApi.setBook(BOOK, MODULES);
detailed = stateApi.getState();
assert(
  screens.nextIndex(detailed, screens.bookScreen) === screens.readScreen,
  "The detailed path must still show what was read.");
assert(
  screens.nextIndex(detailed, screens.reviewScreen) ===
    screens.outputScreen,
  "The detailed path must still ask for the output name.");

// ---- what to change: one box, one option, no jargon ----

state = start(true);
stateApi.setBook(BOOK, MODULES);
stateApi.setPurpose("x.md", "ignored", "id-1", []);
stateApi.setSplitOutputRules({
  presetFile: "x.md",
  presetName: "ignored",
  title: "出力指示（モジュール単位）",
  body: "one module per reply"
});
stateApi.setRequestText("");
state = stateApi.getState();

var requestScreen = app.createRequestScreen(state);
var requestText = readText(requestScreen);

assert(
  collect(requestScreen, "form-textarea").length === 1,
  "The short way asks for the change in one box.");
assert(
  collect(requestScreen, "option-checkbox").length === 1,
  "There is exactly one option on this screen.");
assert(
  requestText.indexOf("コードが長い場合は、モジュールごとに受け取る") >= 0,
  "The long-code option must be worded plainly: " + requestText);
assert(
  collect(requestScreen, "disclosure").length === 0,
  "The short way shows no request editor.");
[
  "ひな形",
  "プリセット",
  "出力指示",
  "依頼ID",
  "モジュール単位出力",
  "ignored"
].forEach(function (word) {
  assert(
    requestText.indexOf(word) < 0,
    "The short way must not show " + word + ": " + requestText);
});
assert(
  screens.get(screens.requestScreen).title(state) ===
    "どのように直しますか",
  "The screen asks what to change.");
assert(
  screens.get(screens.requestScreen).ready(state) === false,
  "An empty box cannot go on.");
stateApi.setRequestText("速くしてください。");
assert(
  screens.get(screens.requestScreen).ready(stateApi.getState()) === true,
  "Written text lets the run go on.");

// ---- the review screen shows the summary and nothing else ----

// Taking a package in clears whatever the previous answer left behind,
// so the account of the change is recorded after it, the way the app
// does it.
stateApi.importPackage([{
  name: "Main",
  code: "Sub A()\r\n'x\r\nEnd Sub",
  changedLineCount: 1,
  lineCount: 3
}]);
stateApi.setIntakeResult({
  summary: "Main の繰り返しを配列にまとめました。",
  modules: [],
  kindWarning: ""
});
state = stateApi.getState();

var review = app.createReviewScreen(state);
var reviewText = readText(review);

assert(
  reviewText.indexOf("Main の繰り返しを配列にまとめました。") >= 0,
  "The review screen must show what the AI said it changed.");
assert(
  collect(review, "module-list").length === 0 &&
    collect(review, "module-item").length === 0,
  "The short way shows no module list.");
assert(
  collect(review, "diff-table").length === 0 &&
    collect(review, "diff-toolbar").length === 0,
  "The short way shows no diff.");
assert(
  findByAction(review, "edit-paste").length === 0,
  "The short way offers no manual fix.");
assert(
  collect(review, "disclosure").length === 0,
  "The short way hides nothing behind a disclosure.");
assert(
  screens.get(screens.reviewScreen).context(state)
    .indexOf("マクロを改修") >= 0,
  "The review screen names the button that builds.");

console.log("test-simple-mode: PASS");
console.log(
  "the short way skips the deciding screens, shows one box and the " +
  "summary, and leaves the detailed path as it was");
