(function (global) {
  "use strict";

  var CRLF = "\r\n";

  function toText(value) {
    return value === undefined || value === null
      ? ""
      : String(value);
  }

  function escapeHtml(value) {
    return toText(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatTimestamp(value) {
    var text = toText(value);
    var match = /^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$/.exec(
      text);

    if (!match) {
      return text;
    }
    return match[1] + "-" + match[2] + "-" + match[3] +
      " " + match[4] + ":" + match[5] + ":" + match[6];
  }

  function getTypeLabel(module) {
    var labels = {
      document: "ドキュメントモジュール",
      form: "フォームモジュール",
      standard: "標準モジュール",
      "class": "クラスモジュール"
    };

    return module.typeLabel ||
      labels[module.type] ||
      "VBA モジュール";
  }

  function getChangedModules(modules) {
    return (modules || []).filter(function (module) {
      return module &&
        module.status === "changed" &&
        typeof module.pastedCode === "string";
    });
  }

  function getInlineDifference(leftText, rightText) {
    var left = toText(leftText);
    var right = toText(rightText);
    var start = 0;
    var leftEnd = left.length;
    var rightEnd = right.length;

    while (start < leftEnd &&
        start < rightEnd &&
        left.charAt(start) === right.charAt(start)) {
      start += 1;
    }
    while (leftEnd > start &&
        rightEnd > start &&
        left.charAt(leftEnd - 1) === right.charAt(rightEnd - 1)) {
      leftEnd -= 1;
      rightEnd -= 1;
    }
    return {
      leftStart: start,
      leftEnd: leftEnd,
      rightStart: start,
      rightEnd: rightEnd
    };
  }

  function buildTokenRange(tokens, start, end, showWhitespace) {
    var offset = 0;
    var parts = [];

    tokens.forEach(function (token) {
      var tokenStart = offset;
      var tokenEnd = offset + token.text.length;
      var from = Math.max(start, tokenStart);
      var to = Math.min(end, tokenEnd);
      var text;

      offset = tokenEnd;
      if (from >= to) {
        return;
      }
      text = token.text.substring(
        from - tokenStart,
        to - tokenStart);
      if (showWhitespace) {
        text = text.replace(/\t/g, "\u2192").replace(/ /g, "\u00B7");
      }
      text = escapeHtml(text);
      if (token.type === "plain") {
        parts.push(text);
      } else {
        parts.push(
          '<span class="vba-token vba-token--',
          token.type,
          '">',
          text,
          "</span>");
      }
    });
    return parts.join("");
  }

  function buildCodeCell(text, markStart, markEnd, markClass) {
    var value = toText(text);
    var tokens;

    if (!value) {
      return "&#160;";
    }
    tokens = global.MacroDeskVbaHighlight.tokenizeLine(value);
    if (markStart === undefined ||
        markEnd === undefined ||
        markStart >= markEnd) {
      return buildTokenRange(tokens, 0, value.length, false);
    }
    return [
      buildTokenRange(tokens, 0, markStart, false),
      '<mark class="diff-inline-mark ',
      markClass,
      '">',
      buildTokenRange(tokens, markStart, markEnd, true),
      "</mark>",
      buildTokenRange(tokens, markEnd, value.length, false)
    ].join("");
  }

  function buildDiffRow(row) {
    var type = /^(?:equal|changed|added|removed)$/.test(row.type)
      ? row.type
      : "changed";
    var leftNumber = row.lineA >= 0
      ? String(row.lineA + 1)
      : "";
    var rightNumber = row.lineB >= 0
      ? String(row.lineB + 1)
      : "";
    var inline = type === "changed"
      ? getInlineDifference(row.textA, row.textB)
      : null;

    return [
      '<tr class="diff-row diff-row--',
      type,
      '">',
      '<td class="line-number line-number--left" aria-hidden="true">',
      leftNumber,
      "</td>",
      '<td class="code-cell code-cell--left"><code>',
      buildCodeCell(
        row.textA,
        inline ? inline.leftStart : undefined,
        inline ? inline.leftEnd : undefined,
        "diff-inline-mark--removed"),
      "</code></td>",
      '<td class="separator" aria-hidden="true"></td>',
      '<td class="line-number line-number--right" aria-hidden="true">',
      rightNumber,
      "</td>",
      '<td class="code-cell code-cell--right"><code>',
      buildCodeCell(
        row.textB,
        inline ? inline.rightStart : undefined,
        inline ? inline.rightEnd : undefined,
        "diff-inline-mark--added"),
      "</code></td>",
      "</tr>"
    ].join("");
  }

  function buildModuleSection(module, index) {
    var rows = global.MacroDeskDiff.compare(
      module.code || "",
      module.pastedCode || "");
    var changedCount =
      global.MacroDeskDiff.countChangedLines(rows);
    var name = toText(module.name);
    var parts = [
      '<section class="module-report" data-module-index="',
      String(index),
      '">',
      '<header class="module-header">',
      "<div>",
      '<p class="module-kicker">変更モジュール</p>',
      "<h2>",
      escapeHtml(name),
      "</h2>",
      "</div>",
      '<p class="module-meta">',
      "<span>",
      escapeHtml(getTypeLabel(module)),
      "</span>",
      "<span>変更 ",
      String(changedCount),
      " 行</span>",
      "</p>",
      "</header>",
      '<div class="diff-scroll">',
      '<table class="diff-table">',
      "<caption>",
      escapeHtml(name),
      " の改修前後比較</caption>",
      "<colgroup>",
      '<col class="column-line">',
      '<col class="column-code">',
      '<col class="column-separator">',
      '<col class="column-line">',
      '<col class="column-code">',
      "</colgroup>",
      "<thead><tr>",
      '<th colspan="2" scope="colgroup">改修前</th>',
      '<th class="separator" aria-hidden="true"></th>',
      '<th colspan="2" scope="colgroup">改修後</th>',
      "</tr></thead>",
      "<tbody>"
    ];

    rows.forEach(function (row) {
      parts.push(buildDiffRow(row));
    });
    parts.push(
      "</tbody>",
      "</table>",
      "</div>",
      "</section>");
    return parts.join("");
  }

  function buildReport(options) {
    var input = options || {};
    var bookName = toText(input.bookName);
    var timestamp = formatTimestamp(input.buildTimestamp);
    var modules = getChangedModules(input.modules);
    var moduleSections = [];

    if (!global.MacroDeskDiff ||
        typeof global.MacroDeskDiff.compare !== "function") {
      throw new Error("The diff engine is unavailable.");
    }
    if (!global.MacroDeskVbaHighlight ||
        typeof global.MacroDeskVbaHighlight.tokenizeLine !== "function") {
      throw new Error("The VBA highlighter is unavailable.");
    }
    if (!bookName) {
      throw new Error("The report book name is missing.");
    }
    if (modules.length === 0) {
      throw new Error("The report has no changed modules.");
    }

    modules.forEach(function (module, index) {
      moduleSections.push(buildModuleSection(module, index));
    });

    return [
      "<!doctype html>",
      '<html lang="ja">',
      "<head>",
      '<meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      '<meta name="generator" content="MacroDesk">',
      "<title>",
      escapeHtml(bookName),
      " 改修差分</title>",
      "<style>",
      ":root{color-scheme:light;font-family:Noto Sans JP,Yu Gothic UI,",
      "Yu Gothic,Meiryo,sans-serif;background:#F4F6F8;color:#1F2A37}",
      "*{box-sizing:border-box}",
      "body{margin:0;background:#F4F6F8;color:#1F2A37}",
      "main{padding:32px}",
      ".report-header{margin:0 0 28px;padding:24px;border:1px solid ",
      "#CFD7DE;border-radius:10px;background:#FFFFFF}",
      ".report-kicker,.module-kicker{margin:0 0 6px;color:#5D6B7A;",
      "font-size:11px;font-weight:600;letter-spacing:.01em}",
      "h1,h2{margin:0;line-height:1.4}",
      "h1{font-size:22px}h2{font-size:17px}",
      ".report-summary{display:flex;flex-wrap:wrap;gap:10px 22px;",
      "margin:14px 0 0;color:#3C4B5C;font-size:13px}",
      ".module-report{margin:0 0 28px;border:1px solid #CFD7DE;",
      "border-radius:10px;background:#FFFFFF;overflow:visible}",
      ".module-header{display:flex;align-items:flex-end;",
      "justify-content:space-between;gap:20px;padding:18px 20px}",
      ".module-meta{display:flex;flex-wrap:wrap;justify-content:flex-end;",
      "gap:8px;margin:0;color:#3C4B5C;font-size:12px}",
      ".module-meta span{padding:4px 8px;border:1px solid #CFD7DE;",
      "border-radius:4px;background:#FAFBFC}",
      ".diff-scroll{width:100%;overflow-x:auto;",
      "border-top:1px solid #CFD7DE}",
      ".diff-table{width:max-content;min-width:100%;",
      "border-collapse:collapse;table-layout:auto;",
      "font-family:UDEV Gothic,Consolas,Cascadia Mono,monospace;",
      "font-size:13px;line-height:20px}",
      ".column-line{width:46px}.column-code{min-width:640px}",
      ".column-separator{width:1px}",
      "th{padding:8px 12px;background:#FAFBFC;color:#5D6B7A;",
      "font-family:Noto Sans JP,Yu Gothic UI,Yu Gothic,Meiryo,sans-serif;",
      "font-size:12px;font-weight:600;text-align:left}",
      "td{border-top:1px solid #E2E7EC;vertical-align:top}",
      ".line-number{width:46px;min-width:46px;padding:0 8px;",
      "background:#ECEFF2;color:#5D6B7A;text-align:right;",
      "user-select:none}",
      ".code-cell{min-width:640px;padding:0 12px;background:#FBFCFD}",
      ".code-cell code{display:block;white-space:pre}",
      ".separator{width:1px;min-width:1px;padding:0;background:#CFD7DE}",
      ".diff-row--changed .code-cell--left,",
      ".diff-row--removed .code-cell--left{background:#FBEDEE;",
      "box-shadow:inset 3px 0 0 #C25560}",
      ".diff-row--changed .line-number--left,",
      ".diff-row--removed .line-number--left{background:#FBEDEE}",
      ".diff-row--changed .code-cell--right,",
      ".diff-row--added .code-cell--right{background:#EAF5E7;",
      "box-shadow:inset 3px 0 0 #4C9155}",
      ".diff-row--changed .line-number--right,",
      ".diff-row--added .line-number--right{background:#EAF5E7}",
      ".diff-row--added .code-cell--left,",
      ".diff-row--added .line-number--left,",
      ".diff-row--removed .code-cell--right,",
      ".diff-row--removed .line-number--right{background:#ECEFF2}",
      ".diff-inline-mark{padding:0;color:inherit}",
      ".diff-inline-mark--removed{background:#F3CDD1}",
      ".diff-inline-mark--added{background:#C9E7C0}",
      ".vba-token--keyword{color:#2C5EA8}",
      ".vba-token--comment{color:#567545}",
      ".vba-token--string{color:#A0582C}",
      ".vba-token--number{color:#6E4FA5}",
      "@media(max-width:760px){main{padding:16px}",
      ".module-header{align-items:flex-start;flex-direction:column}",
      ".module-meta{justify-content:flex-start}}",
      "</style>",
      "</head>",
      "<body>",
      "<main>",
      '<header class="report-header">',
      '<p class="report-kicker">改修差分</p>',
      "<h1>",
      escapeHtml(bookName),
      "</h1>",
      '<p class="report-summary">',
      "<span>ビルド日時: ",
      escapeHtml(timestamp),
      "</span>",
      "<span>変更モジュール: ",
      String(modules.length),
      "</span>",
      "</p>",
      "</header>",
      moduleSections.join(""),
      "</main>",
      "</body>",
      "</html>",
      ""
    ].join(CRLF);
  }

  global.MacroDeskDiffReport = {
    escapeHtml: escapeHtml,
    formatTimestamp: formatTimestamp,
    getChangedModules: getChangedModules,
    getInlineDifference: getInlineDifference,
    buildReport: buildReport
  };
}(window));
