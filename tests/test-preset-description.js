"use strict";

// The line under a preset's name on the purpose screen.
//
// It used to be scavenged from "## 改修指示", which is written for the chat
// AI: the card ended up showing a request addressed to somebody else, and
// it was cut wherever the file happened to wrap its prose. The line now has
// a section of its own, "## 説明", and the card shows nothing else.

var fs = require("fs");
var path = require("path");
var vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

var root = path.resolve(__dirname, "..");

// A document just real enough to build the purpose screen into, so the
// rule is checked where it is used and not only where it is written.
function createElementShim(tagName) {
  var element = {
    tagName: String(tagName).toUpperCase(),
    className: "",
    textContent: "",
    innerHTML: "",
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

function collectByClass(element, className, found) {
  var hits = found || [];

  if (element.classList && element.classList.contains(className)) {
    hits.push(element);
  }
  element.children.forEach(function (child) {
    collectByClass(child, className, hits);
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
var presetApi = windowObject.MacroStudioPreset;
var stateApi = windowObject.MacroStudioState;

function readUtf8(filePath) {
  var text = fs.readFileSync(filePath, "utf8");

  if (text.charCodeAt(0) === 0xFEFF) {
    text = text.slice(1);
  }
  return text;
}

function build(description) {
  return "# 名前\n\n" +
    (description === null ? "" : "## 説明\n\n" + description + "\n\n") +
    "## 改修指示\n\n直してください。\n\n" +
    "## 出力指示\n\n本文で返してください。\n";
}

// ---- the section, on its own ----

assert(
  presetApi.parse(build("画面に出る 1 行です。")).description ===
    "画面に出る 1 行です。",
  "The description section must become the card line.");
assert(
  presetApi.parse(build(null)).valid &&
    presetApi.parse(build(null)).description === "",
  "A preset without the section stays valid and has no card line.");
assert(
  presetApi.parse(build("今の動きを変えないまま、コードを\n読みやすく直します。"))
    .description === "今の動きを変えないまま、コードを読みやすく直します。",
  "A wrapped description must be joined without a space.");
assert(
  presetApi.parse(build("Win32\nAPI を使いません。")).description ===
    "Win32 API を使いません。",
  "A wrap between two Latin words must become a space.");
assert(
  presetApi.parse(build("Win32 API\nを使いません。")).description ===
    "Win32 APIを使いません。",
  "A wrap next to Japanese must not become a space.");

var empty = presetApi.parse(build("   "));

assert(
  !empty.valid &&
    empty.message === presetApi.messages.emptySection.replace(
      "{title}",
      "説明"),
  "An empty description must be rejected: " + empty.message);

var twoParagraphs = presetApi.parse(build("一段落です。\n\n二段落です。"));

assert(
  !twoParagraphs.valid &&
    twoParagraphs.message === presetApi.messages.manyDescriptions,
  "Two paragraphs must be rejected: " + twoParagraphs.message);

// The request is written for the chat AI, so it may no longer reach the
// card by any route.
assert(
  typeof app.getPresetSummary === "undefined",
  "The card line must not be derived from the request any more.");

// ---- every shipped preset ----

var presetDir = path.join(root, "presets");
var presets = fs.readdirSync(presetDir).filter(function (name) {
  return path.extname(name).toLowerCase() === ".md";
}).map(function (name) {
  return {
    file: name,
    content: readUtf8(path.join(presetDir, name))
  };
});
var entries = presetApi.describeAll(presets).filter(function (entry) {
  return entry.valid;
});

assert(
  entries.length >= 5,
  "The shipped presets must be readable for this check.");

entries.forEach(function (entry) {
  var text = entry.description;
  var firstLine = entry.instruction.body
    .replace(/\r\n/g, "\n")
    .split("\n")[0]
    .trim();

  assert(
    text.length > 0,
    "No 説明 in " + entry.file);
  assert(
    text.charAt(text.length - 1) === "。",
    "The card line of " + entry.file +
      " does not end on a full stop: " + text);
  ["、", "・", "，", ",", "「", "（"].forEach(function (mark) {
    assert(
      text.charAt(text.length - 1) !== mark,
      "The card line of " + entry.file + " ends on " + mark);
  });
  assert(
    text.indexOf("\n") < 0 && text.indexOf("\r") < 0,
    "The card line of " + entry.file + " carries a line break.");
  assert(
    text.indexOf("。") === text.length - 1,
    "The card line of " + entry.file + " is more than one sentence: " +
      text);
  // Whatever the request happens to say is the AI's business, so a card
  // line that repeats its opening is a sign of the old derivation.
  assert(
    text !== firstLine,
    "The card line of " + entry.file + " is the request's first line.");

  // The file name is not read by any code, which is how it drifted away
  // from the title in the first place. Keeping them equal is what makes
  // the next drift visible in the folder.
  assert(
    entry.file.replace(/^[0-9]+_/, "").replace(/\.md$/i, "") ===
      entry.name,
    "The file name of " + entry.file + " does not match its title: " +
      entry.name);
});

// The refactoring card, whose wording the owner fixed by hand.
var refactor = null;

entries.forEach(function (entry) {
  if (entry.instruction.body.indexOf("読みやすく") >= 0) {
    refactor = entry;
  }
});
assert(refactor !== null, "No shipped preset states the refactor request.");
assert(
  refactor.instruction.body.indexOf("読みやすく・壊れにくく") < 0,
  "The middle dot between the two adjectives must stay removed.");

// ---- the screen actually shows it ----
//
// Checking the parser alone is not enough: the card builder has to read
// the field. Both routes are built here and their lines read back.

["refactor", "diagnose"].forEach(function (mode) {
  var screen;
  var lines;
  var declared;

  stateApi.reset();
  stateApi.setAppInfo({ version: "test", presets: presets });
  stateApi.setMode(mode);
  screen = app.createPurposeScreen(stateApi.getState());
  lines = collectByClass(screen, "choice-description").map(
    function (node) {
      return node.textContent;
    });
  declared = entries.filter(function (entry) {
    return entry.mode === mode;
  }).map(function (entry) {
    return entry.description;
  });

  assert(
    declared.length >= 3,
    "The " + mode + " route must ship several presets.");
  assert(
    lines.length === declared.length,
    "The " + mode + " purpose screen showed " + lines.length +
      " lines for " + declared.length + " presets.");
  lines.forEach(function (text, index) {
    assert(
      text === declared[index],
      "The " + mode + " purpose screen shows " + text +
        " instead of the declared " + declared[index]);
  });
});

// A preset with no 説明 shows its name alone rather than borrowing a
// sentence from the request.
stateApi.reset();
stateApi.setAppInfo({
  version: "test",
  presets: [{ file: "plain.md", content: build(null) }]
});
stateApi.setMode("refactor");
assert(
  collectByClass(
    app.createPurposeScreen(stateApi.getState()),
    "choice-description").length === 0,
  "A preset without 説明 must show no line at all.");

console.log("test-preset-description: PASS");
console.log(
  "every shipped preset declares its own card line, the screen shows " +
  "that line and nothing else, and the file names match the titles");
