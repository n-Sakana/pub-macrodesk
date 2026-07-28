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

  function buildCodeCell(text) {
    var value = toText(text);

    return value.length > 0
      ? escapeHtml(value)
      : "&#160;";
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

    return [
      '<tr class="diff-row diff-row--',
      type,
      '">',
      '<td class="line-number line-number--left" aria-hidden="true">',
      leftNumber,
      "</td>",
      '<td class="code-cell code-cell--left"><code>',
      buildCodeCell(row.textA),
      "</code></td>",
      '<td class="separator" aria-hidden="true"></td>',
      '<td class="line-number line-number--right" aria-hidden="true">',
      rightNumber,
      "</td>",
      '<td class="code-cell code-cell--right"><code>',
      buildCodeCell(row.textB),
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
      '<p class="module-kicker">VBA MODULE</p>',
      "<h2>",
      escapeHtml(name),
      "</h2>",
      "</div>",
      '<p class="module-meta">',
      "<span>",
      escapeHtml(getTypeLabel(module)),
      "</span>",
      "<span>",
      String(changedCount),
      " 変更行</span>",
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
      ":root{color-scheme:dark;font-family:Segoe UI,Meiryo,sans-serif;",
      "background:#0d1117;color:#e6edf3}",
      "*{box-sizing:border-box}",
      "body{margin:0;background:#0d1117;color:#e6edf3}",
      "main{padding:32px}",
      ".report-header{margin:0 0 28px;padding:24px;",
      "border:1px solid #30363d;border-radius:10px;background:#161b22}",
      ".report-kicker,.module-kicker{margin:0 0 6px;color:#8b949e;",
      "font-size:12px;font-weight:700;letter-spacing:.12em}",
      "h1,h2{margin:0;line-height:1.35}",
      "h1{font-size:26px}",
      "h2{font-size:20px}",
      ".report-summary{display:flex;flex-wrap:wrap;gap:10px 22px;",
      "margin:14px 0 0;color:#b1bac4;font-size:14px}",
      ".module-report{margin:0 0 28px;border:1px solid #30363d;",
      "border-radius:10px;background:#161b22;overflow:visible}",
      ".module-header{display:flex;align-items:flex-end;",
      "justify-content:space-between;gap:20px;padding:18px 20px}",
      ".module-meta{display:flex;flex-wrap:wrap;justify-content:flex-end;",
      "gap:8px;margin:0;color:#b1bac4;font-size:13px}",
      ".module-meta span{padding:4px 8px;border:1px solid #30363d;",
      "border-radius:999px;background:#0d1117}",
      ".diff-scroll{width:100%;overflow-x:auto;",
      "border-top:1px solid #30363d}",
      ".diff-table{width:max-content;min-width:100%;",
      "border-collapse:collapse;table-layout:fixed;",
      "font-family:Consolas,Cascadia Mono,monospace;font-size:13px}",
      ".column-line{width:52px}",
      ".column-code{width:640px}",
      ".column-separator{width:1px}",
      "th{padding:10px 12px;background:#21262d;color:#b1bac4;",
      "font-family:Segoe UI,Meiryo,sans-serif;font-size:12px;",
      "font-weight:700;text-align:left}",
      "td{border-top:1px solid #21262d;vertical-align:top}",
      ".line-number{padding:3px 9px;background:#0d1117;",
      "color:#6e7681;text-align:right;user-select:none}",
      ".code-cell{min-width:640px;padding:3px 10px}",
      ".code-cell code{display:block;white-space:pre;line-height:1.55}",
      ".separator{width:1px;min-width:1px;padding:0;",
      "background:#30363d}",
      ".diff-row--equal .code-cell{color:#c9d1d9}",
      ".diff-row--changed .code-cell--left,",
      ".diff-row--removed .code-cell--left{background:#35171b;",
      "color:#ffdcd7}",
      ".diff-row--changed .code-cell--right,",
      ".diff-row--added .code-cell--right{background:#17351f;",
      "color:#aff5b4}",
      ".diff-row--added .code-cell--left,",
      ".diff-row--removed .code-cell--right{background:#11161d}",
      "@media(max-width:760px){main{padding:16px}",
      ".module-header{align-items:flex-start;flex-direction:column}",
      ".module-meta{justify-content:flex-start}}",
      "</style>",
      "</head>",
      "<body>",
      "<main>",
      '<header class="report-header">',
      '<p class="report-kicker">MACRODESK BUILD DIFF</p>',
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
    buildReport: buildReport
  };
}(window));
