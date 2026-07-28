(function (global) {
  "use strict";

  var CRLF = "\r\n";
  var SECTION_LINE =
    "==================================================";
  var MODULE_LINE =
    "--------------------------------------------------";
  var EMPTY_MODULE_NOTE =
    "（このモジュールは現在空です。コードの省略ではありません）";

  var FIXED_INSTRUCTIONS = [
    SECTION_LINE,
    "【出力形式の指定】※ここから下はツールが自動で付けた指定です",
    SECTION_LINE,
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
    "- コードは必ずモジュールの先頭から末尾までの全文を出力する。一部だけの",
    "  出力や「'（以下変更なし）」のような省略はしない。",
    "- 変更していないモジュールは出力しない。",
    "- 「このモジュールは現在空です」という注記は VBA コードへ含めない。空の",
    "  モジュールも、改修対象なら改修後コードの全文を出し、未変更なら出力しない。",
    "- コードブロックの中には VBA コード以外の文章（説明・注釈・見出し）を",
    "  入れない。",
    "- モジュール先頭に「Attribute VB_」で始まる行を付けない（渡したコードにも",
    "  付いていない。コードの途中に Attribute 行がある場合だけ、そのまま残す）。",
    "- 複数のモジュールに同じ処理を入れる場合は、新しい標準モジュールを 1 つ作って",
    "  そこに共通の処理を置き、既存モジュールからは呼び出すだけにしてください。",
    "  新しいモジュールは「■ <新しいモジュール名>（新規）」の見出しで出力してください。",
    "- モジュール名の変更と、モジュールの削除はしない。"
  ].join(CRLF);

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

  function buildTargetSection(book, modules) {
    var lines = [
      SECTION_LINE,
      "【対象ブック】",
      SECTION_LINE,
      "ファイル名: " + requireString(book.name, "Book name"),
      "モジュール数: " + modules.length +
        "（合計 " + book.totalLines + " 行）" +
        "※以下に全モジュールの全文を掲載しています。省略はありません。",
      ""
    ];

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

  function buildSourceSection(modules) {
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

    return [
      SECTION_LINE,
      "【ソースコード】",
      SECTION_LINE,
      "",
      joinWithBlankLine(blocks)
    ].join(CRLF);
  }

  function buildRequestFile(options) {
    var requestText;
    var book;
    var modules;
    var intro;
    var requestSection;

    if (!options || !options.book ||
        !Array.isArray(options.modules)) {
      throw new Error("Prompt source data is missing.");
    }

    requestText = normalizeCrLf(
      requireString(options.requestText, "Request text"));
    book = options.book;
    modules = options.modules;
    intro = [
      "このファイルは Excel マクロ改修支援ツール「MacroDesk」が生成した、Excel マクロの改修依頼です。",
      "下の【依頼】に従って、【ソースコード】にある VBA コードを改修してください。"
    ].join(CRLF);
    requestSection = [
      SECTION_LINE,
      "【依頼】",
      SECTION_LINE,
      requestText
    ].join(CRLF);

    return joinWithBlankLine([
      intro,
      requestSection,
      buildTargetSection(book, modules),
      buildSourceSection(modules),
      FIXED_INSTRUCTIONS
    ]) + CRLF;
  }

  global.MacroDeskPrompt = {
    fixedInstructions: FIXED_INSTRUCTIONS,
    appendPreset: appendPreset,
    buildRequestFile: buildRequestFile
  };
}(window));
