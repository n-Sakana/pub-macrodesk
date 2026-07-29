(function (global) {
  "use strict";

  var CRLF = "\r\n";
  var INSTRUCTION_TITLE = "改修指示";
  var OUTPUT_TITLE = "出力指示";
  var MODE_TITLE = "用途";
  var QUESTION_TITLE = "質問";
  var SECTION_TITLES = [INSTRUCTION_TITLE, OUTPUT_TITLE];
  var OPTIONAL_SECTION_TITLES = [MODE_TITLE, QUESTION_TITLE];
  // A preset either changes the workbook or only asks about it.
  // Diagnosing covers everything that ends in a conversation, whether
  // that is a check or a consultation. Files that say nothing keep the
  // original behaviour.
  var MODES = {
    "改修": "refactor",
    "診断": "diagnose"
  };
  var DEFAULT_MODE = "refactor";

  var MESSAGES = {
    empty: "ファイルが空です。",
    unterminatedComment:
      "コメントが閉じられていません。<!-- は --> で閉じてください。",
    missingName:
      "プリセット名の見出し（# ではじまる行）がありません。",
    emptyName:
      "プリセット名の見出し（#）に名前がありません。",
    multipleNames:
      "プリセット名の見出し（#）が 2 つ以上あります。" +
      "1 ファイルにつき 1 つにしてください。",
    textBeforeName:
      "プリセット名の見出し（#）より前に本文があります。" +
      "説明は <!-- --> のコメントにしてください。",
    textOutsideSection:
      "見出しの外に本文があります。本文は「## " +
      INSTRUCTION_TITLE + "」か「## " + OUTPUT_TITLE +
      "」の下に書いてください。",
    unknownSection:
      "知らない見出しがあります: ## {title}。使えるのは「## " +
      INSTRUCTION_TITLE + "」「## " + OUTPUT_TITLE + "」「## " +
      MODE_TITLE + "」「## " + QUESTION_TITLE + "」です。",
    unknownMode:
      "「## " + MODE_TITLE + "」には「改修」か「診断」と書いてください。",
    emptyQuestions:
      "「## " + QUESTION_TITLE +
      "」に質問がありません。「- 質問文」の形で書いてください。",
    duplicateSection: "「## {title}」が 2 つ以上あります。",
    missingSection: "「## {title}」がありません。",
    emptySection: "「## {title}」の本文が空です。",
    unreadable:
      "ファイルを読み取れませんでした。" +
      "UTF-8 で保存されているか確認してください。"
  };

  function format(message, title) {
    return message.replace("{title}", title);
  }

  function trimSpace(value) {
    return String(value).replace(
      /^[\s　]+|[\s　]+$/g,
      "");
  }

  // Editor notes never reach the chat request. The whole comment is
  // removed before anything else is read, so a commented-out heading
  // cannot become the preset name.
  function stripComments(text) {
    var stripped = String(text).replace(/<!--[\s\S]*?-->/g, "");

    return {
      text: stripped,
      unterminated: stripped.indexOf("<!--") >= 0
    };
  }

  function splitLines(text) {
    return String(text)
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .split("\n");
  }

  function hasText(lines) {
    return lines.some(function (line) {
      return trimSpace(line) !== "";
    });
  }

  function joinBody(lines) {
    var start = 0;
    var end = lines.length;

    while (start < end && trimSpace(lines[start]) === "") {
      start++;
    }
    while (end > start && trimSpace(lines[end - 1]) === "") {
      end--;
    }
    return lines.slice(start, end).join(CRLF);
  }

  function failure(message) {
    return {
      valid: false,
      name: "",
      mode: DEFAULT_MODE,
      questions: [],
      instruction: null,
      output: null,
      message: message
    };
  }

  // A question is one top-level "- " item. Items indented under it are
  // the choices offered for that question; without them the answer is
  // free text.
  function readQuestions(lines) {
    var questions = [];
    var index;
    var line;
    var match;

    for (index = 0; index < lines.length; index += 1) {
      line = lines[index];
      match = /^(\s*)[-*]\s+(.*)$/.exec(line);
      if (!match) {
        continue;
      }
      if (match[1].length === 0) {
        questions.push({
          text: trimSpace(match[2]),
          choices: []
        });
      } else if (questions.length > 0) {
        questions[questions.length - 1].choices.push(
          trimSpace(match[2]));
      }
    }
    return questions.filter(function (question) {
      return question.text !== "";
    });
  }

  function parse(content) {
    var stripped;
    var lines;
    var inFence = false;
    var name = null;
    var current = null;
    var sections = {};
    var beforeName = [];
    var outside = [];
    var index;
    var line;
    var match;
    var level;
    var title;
    var body;
    var result;

    if (typeof content !== "string" || trimSpace(content) === "") {
      return failure(MESSAGES.empty);
    }

    stripped = stripComments(content);
    if (stripped.unterminated) {
      return failure(MESSAGES.unterminatedComment);
    }
    lines = splitLines(stripped.text);

    for (index = 0; index < lines.length; index++) {
      line = lines[index];
      if (/^\s*(?:```|~~~)/.test(line)) {
        inFence = !inFence;
      }
      match = inFence
        ? null
        : /^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$/.exec(line);

      if (match) {
        level = match[1].length;
        title = trimSpace(match[2] === undefined ? "" : match[2]);

        if (level === 1) {
          if (name !== null) {
            return failure(MESSAGES.multipleNames);
          }
          if (title === "") {
            return failure(MESSAGES.emptyName);
          }
          name = title;
          current = null;
          continue;
        }
        if (level === 2) {
          if (name === null) {
            return failure(MESSAGES.missingName);
          }
          if (SECTION_TITLES.indexOf(title) < 0 &&
              OPTIONAL_SECTION_TITLES.indexOf(title) < 0) {
            return failure(format(
              MESSAGES.unknownSection,
              title === "" ? "（名前なし）" : title));
          }
          if (Object.prototype.hasOwnProperty.call(
            sections,
            title)) {
            return failure(format(
              MESSAGES.duplicateSection,
              title));
          }
          sections[title] = [];
          current = title;
          continue;
        }
        // Deeper headings (### and below) belong to the section body.
      }

      if (current !== null) {
        sections[current].push(line);
      } else if (name === null) {
        beforeName.push(line);
      } else {
        outside.push(line);
      }
    }

    if (name === null) {
      return failure(MESSAGES.missingName);
    }

    result = {
      valid: true,
      name: name,
      mode: DEFAULT_MODE,
      questions: [],
      instruction: null,
      output: null,
      message: ""
    };

    if (Object.prototype.hasOwnProperty.call(sections, QUESTION_TITLE)) {
      result.questions = readQuestions(sections[QUESTION_TITLE]);
      if (result.questions.length === 0) {
        return failure(MESSAGES.emptyQuestions);
      }
    }
    if (Object.prototype.hasOwnProperty.call(sections, MODE_TITLE)) {
      body = joinBody(sections[MODE_TITLE]);
      if (!Object.prototype.hasOwnProperty.call(MODES, body)) {
        return failure(MESSAGES.unknownMode);
      }
      result.mode = MODES[body];
    }

    for (index = 0; index < SECTION_TITLES.length; index++) {
      title = SECTION_TITLES[index];
      if (!Object.prototype.hasOwnProperty.call(sections, title)) {
        return failure(format(MESSAGES.missingSection, title));
      }
    }
    if (hasText(beforeName)) {
      return failure(MESSAGES.textBeforeName);
    }
    if (hasText(outside)) {
      return failure(MESSAGES.textOutsideSection);
    }

    for (index = 0; index < SECTION_TITLES.length; index++) {
      title = SECTION_TITLES[index];
      body = joinBody(sections[title]);
      if (body === "") {
        return failure(format(MESSAGES.emptySection, title));
      }
      if (title === INSTRUCTION_TITLE) {
        result.instruction = { title: title, body: body };
      } else {
        result.output = { title: title, body: body };
      }
    }

    return result;
  }

  // One list entry per file found in presets/. Invalid files stay in
  // the list with their reason so the mistake is visible, but they
  // never become a usable preset.
  function describe(preset) {
    var file = preset && preset.file ? String(preset.file) : "";
    var parsed;

    if (!preset || preset.error) {
      return {
        file: file,
        name: "",
        mode: DEFAULT_MODE,
        questions: [],
        valid: false,
        message: MESSAGES.unreadable,
        instruction: null,
        output: null
      };
    }

    parsed = parse(preset.content);
    return {
      file: file,
      name: parsed.name,
      mode: parsed.mode,
      questions: parsed.questions,
      valid: parsed.valid,
      message: parsed.message,
      instruction: parsed.instruction,
      output: parsed.output
    };
  }

  function describeAll(presets) {
    if (!presets || !presets.length) {
      return [];
    }
    return Array.prototype.map.call(presets, describe);
  }

  function countValid(presets) {
    var valid = 0;

    describeAll(presets).forEach(function (entry) {
      if (entry.valid) {
        valid++;
      }
    });
    return valid;
  }

  global.MacroStudioPreset = {
    instructionTitle: INSTRUCTION_TITLE,
    outputTitle: OUTPUT_TITLE,
    modeTitle: MODE_TITLE,
    questionTitle: QUESTION_TITLE,
    modes: MODES,
    defaultMode: DEFAULT_MODE,
    messages: MESSAGES,
    stripComments: stripComments,
    parse: parse,
    describe: describe,
    describeAll: describeAll,
    countValid: countValid
  };
}(window));
