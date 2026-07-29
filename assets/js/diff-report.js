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

  function isChangedModule(module) {
    return Boolean(module) &&
      module.status === "changed" &&
      typeof module.pastedCode === "string";
  }

  function getChangedModules(modules) {
    return (modules || []).filter(isChangedModule);
  }

  // The report is a record of the whole workbook, not only of what
  // moved: a module nobody touched still has to be readable in it.
  function getReportModules(modules) {
    return (modules || []).filter(function (module) {
      return Boolean(module) &&
        (isChangedModule(module) ||
          typeof module.code === "string");
    });
  }

  function getModuleAfterText(module) {
    return isChangedModule(module)
      ? module.pastedCode
      : module.code || "";
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
    tokens = global.MacroStudioVbaHighlight.tokenizeLine(value);
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

  // One compared line becomes one inline row, except a changed line,
  // which becomes the removed row followed by the added row. Same
  // unified layout as the screen diff.
  function expandRow(row) {
    var inline;

    if (row.type === "removed") {
      return [{
        kind: "removed",
        marker: "-",
        oldNumber: row.lineA >= 0 ? String(row.lineA + 1) : "",
        newNumber: "",
        text: row.textA
      }];
    }
    if (row.type === "added") {
      return [{
        kind: "added",
        marker: "+",
        oldNumber: "",
        newNumber: row.lineB >= 0 ? String(row.lineB + 1) : "",
        text: row.textB
      }];
    }
    if (row.type === "changed") {
      inline = getInlineDifference(row.textA, row.textB);
      return [
        {
          kind: "removed",
          marker: "-",
          oldNumber: row.lineA >= 0 ? String(row.lineA + 1) : "",
          newNumber: "",
          text: row.textA,
          markStart: inline.leftStart,
          markEnd: inline.leftEnd,
          markClass: "diff-inline-mark--removed"
        },
        {
          kind: "added",
          marker: "+",
          oldNumber: "",
          newNumber: row.lineB >= 0 ? String(row.lineB + 1) : "",
          text: row.textB,
          markStart: inline.rightStart,
          markEnd: inline.rightEnd,
          markClass: "diff-inline-mark--added"
        }
      ];
    }
    return [{
      kind: "equal",
      marker: "",
      oldNumber: row.lineA >= 0 ? String(row.lineA + 1) : "",
      newNumber: row.lineB >= 0 ? String(row.lineB + 1) : "",
      text: row.textA
    }];
  }

  function countLineChanges(rows) {
    var counts = { added: 0, removed: 0 };

    (rows || []).forEach(function (row) {
      if (row.type === "added" || row.type === "changed") {
        counts.added += 1;
      }
      if (row.type === "removed" || row.type === "changed") {
        counts.removed += 1;
      }
    });
    return counts;
  }

  function buildInlineRow(inlineRow) {
    return [
      '<tr class="diff-row diff-row--',
      inlineRow.kind,
      '">',
      '<td class="line-number line-number--old" aria-hidden="true">',
      inlineRow.oldNumber,
      "</td>",
      '<td class="line-number line-number--new" aria-hidden="true">',
      inlineRow.newNumber,
      "</td>",
      '<td class="diff-marker" aria-hidden="true">',
      inlineRow.marker,
      "</td>",
      '<td class="code-cell"><code>',
      buildCodeCell(
        inlineRow.text,
        inlineRow.markStart,
        inlineRow.markEnd,
        inlineRow.markClass),
      "</code></td>",
      "</tr>"
    ].join("");
  }

  function buildCounts(counts) {
    return [
      '<span class="count count--add">+',
      String(counts.added),
      "</span>",
      '<span class="count count--del">−',
      String(counts.removed),
      "</span>"
    ].join("");
  }

  function buildModuleSection(entry) {
    var parts = [
      '<section class="module-report" id="',
      entry.id,
      '" data-module-index="',
      String(entry.index),
      '">',
      '<header class="module-header">',
      "<div>",
      '<p class="module-kicker">',
      entry.isNew
        ? "新規モジュール"
        : entry.changed ? "変更モジュール" : "変更なし",
      "</p>",
      "<h2>",
      escapeHtml(entry.name),
      "</h2>",
      "</div>",
      '<p class="module-meta">',
      "<span>",
      escapeHtml(entry.typeLabel),
      "</span>",
      buildCounts(entry.counts),
      "</p>",
      "</header>",
      '<div class="diff-scroll">',
      '<table class="diff-table">',
      "<caption>",
      escapeHtml(entry.name),
      " の改修前後インライン比較</caption>",
      "<colgroup>",
      '<col class="column-line">',
      '<col class="column-line">',
      '<col class="column-marker">',
      '<col class="column-code">',
      "</colgroup>",
      "<thead><tr>",
      '<th class="column-heading" scope="col">前</th>',
      '<th class="column-heading" scope="col">後</th>',
      '<th class="column-heading" scope="col"></th>',
      '<th class="column-heading column-heading--code" scope="col">',
      "コード（− 改修前 / + 改修後）</th>",
      "</tr></thead>",
      "<tbody>"
    ];

    entry.rows.forEach(function (row) {
      expandRow(row).forEach(function (inlineRow) {
        parts.push(buildInlineRow(inlineRow));
      });
    });
    parts.push(
      "</tbody>",
      "</table>",
      "</div>",
      "</section>");
    return parts.join("");
  }

  function buildModuleTree(entries) {
    var order = ["document", "form", "standard", "class", "other"];
    var groups = {};
    var parts = [
      '<nav class="module-tree" aria-label="モジュール一覧">',
      '<p class="tree-title">モジュール</p>'
    ];

    entries.forEach(function (entry) {
      var key = order.indexOf(entry.type) >= 0 ? entry.type : "other";

      if (!Object.prototype.hasOwnProperty.call(groups, key)) {
        groups[key] = [];
      }
      groups[key].push(entry);
    });

    order.forEach(function (key) {
      if (!Object.prototype.hasOwnProperty.call(groups, key)) {
        return;
      }
      parts.push(
        '<div class="tree-group">',
        '<p class="tree-group-name">',
        escapeHtml(groups[key][0].typeLabel),
        "</p>",
        '<ul class="tree-list">');
      groups[key].forEach(function (entry) {
        parts.push(
          '<li class="tree-item">',
          '<a class="tree-link" href="#',
          entry.id,
          '">',
          '<span class="tree-name">',
          escapeHtml(entry.name),
          "</span>",
          '<span class="tree-counts">',
          buildCounts(entry.counts),
          "</span>",
          "</a>",
          "</li>");
      });
      parts.push("</ul>", "</div>");
    });
    parts.push("</nav>");
    return parts.join("");
  }

  function buildReport(options) {
    var input = options || {};
    var bookName = toText(input.bookName);
    var timestamp = formatTimestamp(input.buildTimestamp);
    var modules = getReportModules(input.modules);
    var changedCount = getChangedModules(input.modules).length;
    var entries = [];
    var totals = { added: 0, removed: 0 };
    var moduleSections = [];

    if (!global.MacroStudioDiff ||
        typeof global.MacroStudioDiff.compare !== "function") {
      throw new Error("The diff engine is unavailable.");
    }
    if (!global.MacroStudioVbaHighlight ||
        typeof global.MacroStudioVbaHighlight.tokenizeLine !== "function") {
      throw new Error("The VBA highlighter is unavailable.");
    }
    if (!bookName) {
      throw new Error("The report book name is missing.");
    }
    if (changedCount === 0) {
      throw new Error("The report has no changed modules.");
    }

    modules.forEach(function (module, index) {
      var rows = global.MacroStudioDiff.compare(
        module.code || "",
        getModuleAfterText(module));
      var counts = countLineChanges(rows);

      totals.added += counts.added;
      totals.removed += counts.removed;
      entries.push({
        index: index,
        // The anchor is the index, never the module name: names can
        // hold characters that are not safe in a fragment.
        id: "module-" + String(index),
        name: toText(module.name),
        type: toText(module.type),
        typeLabel: getTypeLabel(module),
        isNew: module.isNew === true,
        changed: isChangedModule(module),
        rows: rows,
        counts: counts
      });
    });
    entries.forEach(function (entry) {
      moduleSections.push(buildModuleSection(entry));
    });

    return [
      "<!doctype html>",
      '<html lang="ja">',
      "<head>",
      '<meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      '<meta name="generator" content="MacroStudio">',
      "<title>",
      escapeHtml(bookName),
      " 改修差分</title>",
      "<style>",
      ":root{color-scheme:light;font-family:Noto Sans JP,Yu Gothic UI,",
      "Yu Gothic,Meiryo,sans-serif;background:#F4F6F8;color:#1F2A37}",
      "*{box-sizing:border-box}",
      "body{margin:0;background:#F4F6F8;color:#1F2A37}",
      ".report-page{padding:32px}",
      ".report-header{margin:0 0 24px;padding:24px;border:1px solid ",
      "#CFD7DE;border-radius:10px;background:#FFFFFF}",
      ".report-kicker,.module-kicker{margin:0 0 6px;color:#5D6B7A;",
      "font-size:11px;font-weight:600;letter-spacing:.01em}",
      "h1,h2{margin:0;line-height:1.4}",
      "h1{font-size:22px}h2{font-size:17px}",
      ".report-summary{display:flex;flex-wrap:wrap;align-items:center;",
      "gap:10px 22px;margin:14px 0 0;color:#3C4B5C;font-size:13px}",
      ".report-layout{display:grid;align-items:start;gap:24px;",
      "grid-template-columns:260px minmax(0,1fr)}",
      ".module-tree{position:sticky;top:24px;max-height:calc(100vh - 48px);",
      "padding:16px;border:1px solid #CFD7DE;border-radius:10px;",
      "background:#FFFFFF;overflow:auto}",
      ".tree-title{margin:0 0 10px;color:#5D6B7A;font-size:11px;",
      "font-weight:600;letter-spacing:.01em}",
      ".tree-group{margin:0 0 12px}",
      ".tree-group-name{margin:0 0 4px;color:#5D6B7A;font-size:12px;",
      "font-weight:600}",
      ".tree-list{margin:0;padding:0 0 0 10px;list-style:none;",
      "border-left:1px solid #E2E7EC}",
      ".tree-item{margin:0}",
      ".tree-link{display:flex;align-items:baseline;",
      "justify-content:space-between;gap:8px;padding:4px 6px;",
      "border-radius:4px;color:#1F2A37;font-size:13px;",
      "text-decoration:none}",
      ".tree-link:hover{background:#ECEFF2;text-decoration:underline}",
      ".tree-name{font-family:UDEV Gothic,Consolas,Cascadia Mono,",
      "monospace;overflow-wrap:anywhere}",
      ".tree-counts{display:flex;flex:0 0 auto;gap:6px}",
      ".count{font-family:UDEV Gothic,Consolas,Cascadia Mono,monospace;",
      "font-size:12px;font-weight:600}",
      ".count--add{color:#2F6B39}.count--del{color:#9E3843}",
      ".module-report{margin:0 0 24px;border:1px solid #CFD7DE;",
      "border-radius:10px;background:#FFFFFF;overflow:hidden;",
      "scroll-margin-top:24px}",
      ".module-header{display:flex;align-items:flex-end;",
      "justify-content:space-between;gap:20px;padding:18px 20px}",
      ".module-meta{display:flex;flex-wrap:wrap;align-items:center;",
      "justify-content:flex-end;gap:8px;margin:0;color:#3C4B5C;",
      "font-size:12px}",
      ".module-meta>span{padding:4px 8px;border:1px solid #CFD7DE;",
      "border-radius:4px;background:#FAFBFC}",
      ".diff-scroll{width:100%;overflow-x:auto;",
      "border-top:1px solid #CFD7DE}",
      ".diff-table{width:max-content;min-width:100%;",
      "border-collapse:collapse;table-layout:auto;",
      "font-family:UDEV Gothic,Consolas,Cascadia Mono,monospace;",
      "font-size:13px;line-height:20px}",
      // The module header already names the module on screen, so the
      // caption is left for assistive technology only.
      "caption{position:absolute;width:1px;height:1px;margin:-1px;",
      "padding:0;border:0;clip:rect(0 0 0 0);overflow:hidden;",
      "white-space:nowrap}",
      ".column-line{width:46px}.column-marker{width:20px}",
      ".column-code{min-width:640px}",
      "th{padding:8px 12px;background:#FAFBFC;color:#5D6B7A;",
      "font-family:Noto Sans JP,Yu Gothic UI,Yu Gothic,Meiryo,sans-serif;",
      "font-size:12px;font-weight:600;text-align:center}",
      ".column-heading--code{border-left:1px solid #CFD7DE;",
      "text-align:left}",
      "td{border-top:1px solid #E2E7EC;vertical-align:top}",
      ".line-number{width:46px;min-width:46px;padding:0 8px;",
      "background:#ECEFF2;color:#5D6B7A;text-align:right;",
      "user-select:none}",
      ".line-number--new{border-right:1px solid #E2E7EC}",
      ".diff-marker{width:20px;min-width:20px;padding:0;",
      "background:#FBFCFD;color:#5D6B7A;text-align:center;",
      "user-select:none}",
      ".code-cell{min-width:640px;padding:0 12px;background:#FBFCFD}",
      ".code-cell code{display:block;white-space:pre}",
      ".diff-row--removed .code-cell,",
      ".diff-row--removed .line-number{background:#FBEDEE}",
      ".diff-row--removed .diff-marker{background:#FBEDEE;",
      "box-shadow:inset 3px 0 0 #C25560;color:#9E3843}",
      ".diff-row--added .code-cell,",
      ".diff-row--added .line-number{background:#EAF5E7}",
      ".diff-row--added .diff-marker{background:#EAF5E7;",
      "box-shadow:inset 3px 0 0 #4C9155;color:#2F6B39}",
      ".diff-inline-mark{padding:0;color:inherit}",
      ".diff-inline-mark--removed{background:#F3CDD1}",
      ".diff-inline-mark--added{background:#C9E7C0}",
      ".vba-token--keyword{color:#2C5EA8}",
      ".vba-token--comment{color:#567545}",
      ".vba-token--string{color:#A0582C}",
      ".vba-token--number{color:#6E4FA5}",
      "@media(max-width:760px){.report-page{padding:16px}",
      ".report-layout{grid-template-columns:minmax(0,1fr)}",
      ".module-tree{position:static;max-height:none}",
      ".module-header{align-items:flex-start;flex-direction:column}",
      ".module-meta{justify-content:flex-start}}",
      "@media print{.module-tree{position:static;max-height:none}",
      ".report-layout{grid-template-columns:minmax(0,1fr)}}",
      "</style>",
      "</head>",
      "<body>",
      '<div class="report-page">',
      '<header class="report-header">',
      '<p class="report-kicker">改修差分</p>',
      "<h1>",
      escapeHtml(bookName),
      "</h1>",
      '<p class="report-summary">',
      "<span>ビルド日時: ",
      escapeHtml(timestamp),
      "</span>",
      "<span>変更モジュール: " + String(changedCount) +
        " / " + String(modules.length) + "</span>",
      buildCounts(totals),
      "</p>",
      "</header>",
      '<div class="report-layout">',
      buildModuleTree(entries),
      '<main class="report-main">',
      moduleSections.join(""),
      "</main>",
      "</div>",
      "</div>",
      "</body>",
      "</html>",
      ""
    ].join(CRLF);
  }

  global.MacroStudioDiffReport = {
    escapeHtml: escapeHtml,
    formatTimestamp: formatTimestamp,
    getChangedModules: getChangedModules,
    getReportModules: getReportModules,
    getInlineDifference: getInlineDifference,
    countLineChanges: countLineChanges,
    expandRow: expandRow,
    buildReport: buildReport
  };
}(window));
