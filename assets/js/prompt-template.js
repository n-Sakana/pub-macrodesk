(function (global) {
  "use strict";

  var CRLF = "\r\n";
  var MODULE_LINE =
    "--------------------------------------------------";
  var EMPTY_MODULE_NOTE =
    "（このモジュールは現在空です。コードの省略ではありません）";
  var PLACEHOLDER_NAMES = [
    "REQUEST_TEXT",
    "BOOK_NAME",
    "MODULE_COUNT",
    "TOTAL_LINE_COUNT",
    "MODULE_LIST",
    "MODULE_SOURCE_BLOCKS"
  ];
  var REQUIRED_PLACEHOLDER_NAMES = [
    "REQUEST_TEXT",
    "MODULE_SOURCE_BLOCKS"
  ];
  var KNOWN_PLACEHOLDERS = {};

  PLACEHOLDER_NAMES.forEach(function (name) {
    KNOWN_PLACEHOLDERS[name] = true;
  });

  function normalizeCrLf(value) {
    return value
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .replace(/\n/g, CRLF);
  }

  function countLineBreaks(value, fromStart) {
    var expression = fromStart
      ? /^(?:(?:\r\n|\r|\n))+/
      : /(?:(?:\r\n|\r|\n))+$/;
    var match = value.match(expression);
    var breaks;

    if (!match) {
      return 0;
    }

    breaks = match[0].match(/\r\n|\r|\n/g);
    return breaks ? breaks.length : 0;
  }

  function appendPreset(existingText, presetText) {
    var existing = existingText === null ||
      existingText === undefined
      ? ""
      : String(existingText);
    var preset = presetText === null ||
      presetText === undefined
      ? ""
      : String(presetText);
    var boundaryBreaks;
    var needed;

    if (!existing) {
      return preset;
    }
    if (!preset) {
      return existing;
    }

    boundaryBreaks =
      countLineBreaks(existing, false) +
      countLineBreaks(preset, true);
    needed = Math.max(0, 2 - boundaryBreaks);
    return existing +
      new Array(needed + 1).join(CRLF) +
      preset;
  }

  function joinWithBlankLine(parts) {
    var result = "";

    parts.forEach(function (part) {
      result = appendPreset(result, part);
    });
    return result;
  }

  function requireString(value, label) {
    if (typeof value !== "string") {
      throw new Error(label + " is missing.");
    }
    return value;
  }

  function buildModuleList(modules) {
    var lines = [];

    modules.forEach(function (module) {
      lines.push(
        "  - " +
        requireString(module.name, "Module name") +
        " （" +
        requireString(module.typeLabel, "Module type label") +
        ", " +
        module.lineCount +
        " 行）");
    });

    return lines.join(CRLF);
  }

  function buildSourceBlocks(modules) {
    var blocks = [];

    modules.forEach(function (module) {
      var code = normalizeCrLf(
        requireString(module.code, "Module code"));

      blocks.push([
        "■ " +
          requireString(module.name, "Module name") +
          "（" +
          requireString(module.typeLabel, "Module type label") +
          "）",
        MODULE_LINE,
        code || EMPTY_MODULE_NOTE
      ].join(CRLF));
    });

    return joinWithBlankLine(blocks);
  }

  function validateTemplate(template) {
    var placeholderPattern = /\{\{([^{}\r\n]*)\}\}/g;
    var seen = {};
    var match;
    var withoutPlaceholders;

    while ((match = placeholderPattern.exec(template)) !== null) {
      if (!Object.prototype.hasOwnProperty.call(
        KNOWN_PLACEHOLDERS,
        match[1])) {
        throw new Error(
          "Unknown request template placeholder: " + match[0]);
      }
      seen[match[1]] = true;
    }

    withoutPlaceholders = template.replace(
      /\{\{([^{}\r\n]*)\}\}/g,
      "");
    if (withoutPlaceholders.indexOf("{{") >= 0 ||
        withoutPlaceholders.indexOf("}}") >= 0) {
      throw new Error("The request template has a malformed placeholder.");
    }

    REQUIRED_PLACEHOLDER_NAMES.forEach(function (name) {
      if (!seen[name]) {
        throw new Error(
          "The request template is missing {{" + name + "}}.");
      }
    });
  }

  function renderTemplate(template, variables) {
    var text = normalizeCrLf(template);
    var placeholderPattern = /\{\{([^{}\r\n]*)\}\}/g;
    var result = "";
    var searchIndex = 0;
    var match;
    var value;
    var afterToken;
    var followingBreaks;
    var trailingBreaks;
    var overlap;

    while ((match = placeholderPattern.exec(text)) !== null) {
      value = normalizeCrLf(variables[match[1]]);
      trailingBreaks = countLineBreaks(value, false);
      afterToken = match.index + match[0].length;
      followingBreaks = 0;
      while (text.substr(
        afterToken + (followingBreaks * CRLF.length),
        CRLF.length) === CRLF) {
        followingBreaks++;
      }
      overlap = Math.min(trailingBreaks, followingBreaks);
      result += text.slice(searchIndex, match.index) +
        value +
        new Array(followingBreaks - overlap + 1).join(CRLF);
      searchIndex =
        afterToken + (followingBreaks * CRLF.length);
      placeholderPattern.lastIndex = searchIndex;
    }
    result += text.slice(searchIndex);
    return result.replace(/(?:(?:\r\n))+$/, "") + CRLF;
  }

  function buildRequestFile(options) {
    var template;
    var requestText;
    var book;
    var modules;
    var variables;

    if (!options || !options.book ||
        !Array.isArray(options.modules)) {
      throw new Error("Prompt source data is missing.");
    }

    template = requireString(
      options.template,
      "Request template");
    validateTemplate(template);
    requestText = normalizeCrLf(
      requireString(options.requestText, "Request text"));
    book = options.book;
    modules = options.modules;
    variables = {
      REQUEST_TEXT: requestText,
      BOOK_NAME: requireString(book.name, "Book name"),
      MODULE_COUNT: String(modules.length),
      TOTAL_LINE_COUNT: String(book.totalLines),
      MODULE_LIST: buildModuleList(modules),
      MODULE_SOURCE_BLOCKS: buildSourceBlocks(modules)
    };

    return renderTemplate(template, variables);
  }

  global.MacroDeskPrompt = {
    appendPreset: appendPreset,
    buildRequestFile: buildRequestFile
  };
}(window));
