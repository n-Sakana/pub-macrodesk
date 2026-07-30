(function (global) {
  "use strict";

  // The written report is the review screen, read-only.
  //
  // It carries the app's own diff engine, highlighter and diff view
  // inside itself and renders with them, so the rows, the context lines,
  // the change blocks and the "changes only" rule can never drift from
  // what the screen shows: there is one implementation, shipped twice.
  // What this file adds is the frame around that view - the module list,
  // the toolbar, the theme switch - and the data of the run.
  //
  // Everything is inline. No stylesheet, script, font or image is
  // fetched, so the file works from a folder with no network at all.
  // Nothing in it can change the workbook: there is no editing control
  // and no way back to the app.

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

  // The run's data travels in a JSON island. Escaping every "<" keeps
  // "</script" from ever appearing, whatever the VBA source holds.
  function escapeJson(value) {
    return JSON.stringify(value).replace(/</g, "\\u003c");
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

  // The bundled stylesheets declare the app's bundled fonts by relative
  // url(). A file sitting in an output folder cannot resolve those, and
  // embedding the fonts would add megabytes, so the declarations are
  // dropped and the token's own fallbacks take over. Nothing else in the
  // stylesheet is touched.
  function stripFontFaces(css) {
    return toText(css).replace(/@font-face\s*\{[^}]*\}\s*/g, "");
  }

  // The bundled files are stored with LF; the report is written with
  // CRLF throughout, so they are brought into line on the way in.
  function normalizeCrLf(value) {
    return toText(value)
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .replace(/\n/g, CRLF);
  }

  function requireBundle(bundle, label) {
    var items = bundle && bundle.length ? bundle : null;
    var index;

    if (!items) {
      throw new Error("The report " + label + " bundle is missing.");
    }
    for (index = 0; index < items.length; index += 1) {
      if (typeof items[index] !== "string" ||
          items[index].length === 0) {
        throw new Error(
          "The report " + label + " bundle has an empty entry.");
      }
    }
    return items;
  }

  // The frame the shared view is placed in. The app puts the diff in a
  // fixed-height pane because the flow owns the window; a written report
  // owns the whole page, so every box here grows with its content and
  // only long code lines scroll sideways.
  var REPORT_STYLES = [
    "*{box-sizing:border-box}",
    "html,body{margin:0}",
    "body{background:var(--surface-canvas);color:var(--text);",
    "font-family:var(--font-ui);font-size:var(--type-body-size);",
    "line-height:var(--type-body-line)}",
    "button{color:inherit;font:inherit;cursor:pointer}",
    "button:focus-visible{outline:2px solid var(--focus-color);",
    "outline-offset:2px}",
    ".report-shell{padding:var(--space-5);display:grid;",
    "gap:var(--space-4)}",
    ".report-header{display:grid;gap:var(--space-2);",
    "padding:var(--space-4);border:1px solid var(--border);",
    "border-radius:var(--radius-md);background:var(--surface)}",
    ".report-kicker{margin:0;color:var(--text-muted);",
    "font-size:var(--type-micro-size);",
    "font-weight:var(--weight-semibold)}",
    ".report-header h1{margin:0;font-size:var(--type-title-size);",
    "line-height:var(--type-title-line)}",
    ".report-summary{display:flex;flex-wrap:wrap;align-items:center;",
    "gap:var(--space-2) var(--space-4);margin:0;color:var(--text-sub);",
    "font-size:var(--type-meta-size)}",
    ".report-counts{display:inline-flex;gap:var(--space-2);",
    "font-family:var(--font-code);",
    "font-weight:var(--weight-semibold)}",
    ".report-count--add{color:var(--success-text)}",
    ".report-count--del{color:var(--danger-text)}",
    // Same mark as the app's own theme switch, which lives in the shell
    // stylesheet the report does not carry.
    ".theme-icon{width:var(--icon-sm);height:var(--icon-sm);fill:none;",
    "stroke:currentColor;stroke-linecap:round;stroke-linejoin:round;",
    "stroke-width:1.5}",
    ".report-noscript{margin:0;padding:var(--space-3);",
    "border:1px solid var(--caution);border-radius:var(--radius-sm);",
    "background:var(--caution-soft);color:var(--caution-text);",
    "font-size:var(--type-meta-size)}",
    ".report-layout{display:grid;align-items:start;gap:var(--space-4);",
    "grid-template-columns:minmax(200px,260px) minmax(0,1fr)}",
    // The list rides along instead of scrolling inside its own box.
    ".module-pane{position:sticky;top:var(--space-3);",
    "display:block;overflow:visible;border:1px solid var(--border);",
    "border-radius:var(--radius-md);background:var(--surface)}",
    ".module-list{overflow:visible}",
    ".module-item{width:100%;cursor:pointer}",
    // The diff grows to its full height: no inner vertical scroller.
    ".step-three-workspace,.step-three-workspace--diff{height:auto;",
    "display:block;overflow:visible}",
    // Walking the changes scrolls the page, so the bar that walks them
    // has to stay put.
    //
    // The column headings cannot follow: their nearest scrolling
    // ancestor is the sideways scroller around the table, not the page,
    // so their sticky positioning has nothing to hold on to here. They
    // scroll away with the rows, as they did before.
    ".diff-toolbar{position:sticky;top:0;z-index:3}",
    ".diff-table-host{display:block;overflow:visible}",
    ".diff-table-scroller{height:auto;overflow-x:auto;",
    "overflow-y:visible}",
    ".diff-review-column{min-width:0}",
    "@media(max-width:56.25em){",
    ".report-layout{grid-template-columns:minmax(0,1fr)}",
    ".module-pane{position:static}}",
    "@media print{.diff-actions .button{display:none}",
    ".diff-toolbar{position:static}",
    ".report-layout{grid-template-columns:minmax(0,1fr)}",
    ".module-pane{position:static}}"
  ];

  // The report's own behaviour: pick a module, draw it with the shared
  // view, and drive the toolbar. Every decision about what a row is, how
  // much context "changes only" keeps and which rows form a change block
  // stays inside MacroStudioDiff and MacroStudioDiffView.
  var REPORT_SCRIPT = [
    "(function () {",
    '  "use strict";',
    "",
    "  var GROUPS = [",
    '    { type: "standard", title: "標準モジュール" },',
    '    { type: "class", title: "クラスモジュール" },',
    '    { type: "form", title: "フォームモジュール" },',
    '    { type: "document", title: "ドキュメントモジュール" }',
    "  ];",
    "  var THEME_KEY = \"macrostudio.theme\";",
    // The report is read after the build, not while the pasted answer is
    // being reviewed, so the two sides are named for what they are by
    // then.
    "  var LABELS = {",
    '    caption: "元のコードと改修後のコードのインライン比較",',
    '    codeNote: "− 元のコード / ＋ 改修後のコード"',
    "  };",
    "  var THEME_ICONS =",
    "    '<svg class=\"theme-icon theme-icon--moon\" " +
      "viewBox=\"0 0 20 20\" aria-hidden=\"true\">' +",
    "    '<path d=\"M15.5 12.5A6.5 6.5 0 0 1 7.5 4.5a6 6 0 1 0 8 8Z\">" +
      "</path></svg>' +",
    "    '<svg class=\"theme-icon theme-icon--sun\" " +
      "viewBox=\"0 0 20 20\" aria-hidden=\"true\" hidden>' +",
    "    '<circle cx=\"10\" cy=\"10\" r=\"3.25\"></circle>' +",
    "    '<path d=\"M10 2v2M10 16v2M2 10h2M16 10h2M4.35 4.35l1.4 1.4" +
      "M14.25 14.25l1.4 1.4M15.65 4.35l-1.4 1.4M5.75 14.25l-1.4 1.4\">" +
      "</path></svg>';",
    "  var data = JSON.parse(",
    '    document.getElementById("report-data").textContent);',
    "  var modules = data.modules;",
    "  var selected = 0;",
    "  var listHost;",
    "  var diffHost;",
    "",
    "  function element(tag, className, text) {",
    "    var node = document.createElement(tag);",
    "    if (className) {",
    "      node.className = className;",
    "    }",
    "    if (text !== undefined) {",
    "      node.textContent = text;",
    "    }",
    "    return node;",
    "  }",
    "",
    "  // One compare per module, by the shared engine, kept for the",
    "  // list counts and every redraw of the same module.",
    "  function rowsOf(module) {",
    "    if (!module.rows) {",
    "      module.rows = MacroStudioDiff.compare(",
    "        module.before,",
    "        module.after);",
    "      module.counts = { added: 0, removed: 0 };",
    "      module.rows.forEach(function (row) {",
    '        if (row.type === "added" || row.type === "changed") {',
    "          module.counts.added += 1;",
    "        }",
    '        if (row.type === "removed" || row.type === "changed") {',
    "          module.counts.removed += 1;",
    "        }",
    "      });",
    "      module.changedLines = MacroStudioDiff.countChangedLines(",
    "        module.rows);",
    "      module.blocks = MacroStudioDiffView.assignChangeBlocks(",
    "        module.rows);",
    "      // Same starting point as the screen: a long module opens on",
    "      // its changes, a short one opens in full.",
    "      if (module.changesOnly === undefined) {",
    "        module.changesOnly = Math.max(",
    "          MacroStudioDiff.toLines(module.before).length,",
    "          MacroStudioDiff.toLines(module.after).length) > 200;",
    "        module.wrap = true;",
    "      }",
    "    }",
    "    return module.rows;",
    "  }",
    "",
    "  function counterText(module) {",
    "    return module.blocks > 0",
    '      ? "1/" + module.blocks',
    '      : "0/0";',
    "  }",
    "",
    "  function buildList() {",
    '    var pane = element("aside", "panel module-pane");',
    "",
    "    pane.appendChild(element(",
    '      "div",',
    '      "module-pane-title",',
    '      "モジュール（" + modules.length + "）"));',
    "    GROUPS.forEach(function (group) {",
    "      var list;",
    "",
    "      if (!modules.some(function (module) {",
    "        return module.type === group.type;",
    "      })) {",
    "        return;",
    "      }",
    "      pane.appendChild(element(",
    '        "div",',
    '        "module-group-title",',
    "        group.title));",
    '      list = element("ul", "module-list");',
    "      modules.forEach(function (module, index) {",
    "        var row;",
    "",
    "        if (module.type !== group.type) {",
    "          return;",
    "        }",
    '        row = element("li", "module-row");',
    "        row.appendChild(buildItem(module, index));",
    "        list.appendChild(row);",
    "      });",
    "      pane.appendChild(list);",
    "    });",
    "    listHost.textContent = \"\";",
    "    listHost.appendChild(pane);",
    "  }",
    "",
    "  function buildItem(module, index) {",
    '    var item = element("button", "module-item");',
    '    var counts = element("span", "module-counts");',
    "",
    '    item.type = "button";',
    '    item.setAttribute("data-module-index", String(index));',
    '    item.classList.toggle("is-active", index === selected);',
    '    item.setAttribute(',
    '      "aria-pressed",',
    '      index === selected ? "true" : "false");',
    "    rowsOf(module);",
    "    item.appendChild(element(",
    '      "span",',
    '      "module-dot " + (module.changed ? "changed" : ""),',
    '      ""));',
    '    item.appendChild(element("span", "module-name", module.name));',
    "    counts.appendChild(element(",
    '      "span",',
    '      "module-count--add",',
    '      "+" + module.counts.added));',
    "    counts.appendChild(element(",
    '      "span",',
    '      "module-count--del",',
    '      "\\u2212" + module.counts.removed));',
    "    item.appendChild(counts);",
    "    item.addEventListener(\"click\", function () {",
    "      selected = index;",
    "      buildList();",
    "      renderModule();",
    "    });",
    "    return item;",
    "  }",
    "",
    "  function toggleButton(label, pressed, title, onClick) {",
    "    var button = element(",
    '      "button",',
    '      "button button--compact diff-toggle");',
    "",
    '    button.type = "button";',
    '    button.setAttribute("aria-pressed", pressed ? "true" : "false");',
    "    if (title) {",
    "      button.title = title;",
    "    }",
    '    button.appendChild(element("span", "button-label", label));',
    '    button.addEventListener("click", onClick);',
    "    return button;",
    "  }",
    "",
    "  function actionButton(label, onClick, disabled) {",
    '    var button = element("button", "button button--compact");',
    "",
    '    button.type = "button";',
    "    button.disabled = disabled === true;",
    '    button.appendChild(element("span", "button-label", label));',
    '    button.addEventListener("click", onClick);',
    "    return button;",
    "  }",
    "",
    "  function renderModule() {",
    "    var module = modules[selected];",
    "    var rows = rowsOf(module);",
    "    var workspace = element(",
    '      "div",',
    '      "step-three-workspace step-three-workspace--diff");',
    '    var toolbar = element("div", "diff-toolbar");',
    '    var resultGroup = element("div", "diff-result-group");',
    '    var actions = element("div", "diff-actions");',
    '    var tableHost = element("div", "diff-table-host");',
    "    var result = element(",
    '      "span",',
    '      "diff-result diff-result--" +',
    '        (module.changed ? "changed" : "unchanged"),',
    "      module.changed",
    '        ? "変更 " + module.changedLines + " 行"',
    '        : "変更なし");',
    "    var counter = element(",
    '      "span",',
    '      "diff-change-counter",',
    "      counterText(module));",
    "    var placeholder;",
    "",
    '    result.setAttribute("role", "status");',
    '    result.title = "追加・削除・変更された行の合計です";',
    "    resultGroup.appendChild(result);",
    "    resultGroup.appendChild(element(",
    '      "span",',
    '      "diff-result-note",',
    "      module.typeLabel));",
    "    if (!module.changed) {",
    "      resultGroup.appendChild(element(",
    '        "span",',
    '        "diff-result-note",',
    '        "このモジュールは変更していません"));',
    "    } else if (MacroStudioDiffView.hasWhitespaceOnlyChange(rows)) {",
    "      resultGroup.appendChild(element(",
    '        "span",',
    '        "diff-result-note",',
    '        "空白のみの変更を含む"));',
    "    }",
    "",
    "    actions.appendChild(actionButton(",
    '      "\\u2191 前の変更",',
    "      function () {",
    "        MacroStudioDiffView.jumpToChange(tableHost, -1, counter);",
    "      },",
    "      module.blocks === 0));",
    "    actions.appendChild(actionButton(",
    '      "\\u2193 次の変更",',
    "      function () {",
    "        MacroStudioDiffView.jumpToChange(tableHost, 1, counter);",
    "      },",
    "      module.blocks === 0));",
    "    actions.appendChild(counter);",
    "    actions.appendChild(toggleButton(",
    '      "変更箇所のみ",',
    "      module.changesOnly === true,",
    '      "変更のない行を畳んで、変更箇所だけを表示します",',
    "      function () {",
    "        module.changesOnly = module.changesOnly !== true;",
    "        renderModule();",
    "      }));",
    "    actions.appendChild(toggleButton(",
    '      "折り返し",',
    "      module.wrap !== false,",
    '      "長い行を折り返して全文を表示します",',
    "      function () {",
    "        module.wrap = module.wrap === false;",
    "        renderModule();",
    "      }));",
    "    actions.appendChild(themeButton());",
    "",
    "    toolbar.appendChild(resultGroup);",
    "    toolbar.appendChild(actions);",
    "    workspace.appendChild(toolbar);",
    "    workspace.appendChild(tableHost);",
    "    MacroStudioDiffView.renderDiff(",
    "      tableHost,",
    "      rows,",
    "      module.changesOnly === true,",
    "      module.wrap !== false,",
    "      LABELS);",
    "    if (module.isNew) {",
    '      placeholder = element("div", "diff-new-placeholder");',
    "      placeholder.appendChild(element(",
    '        "span",',
    '        "diff-new-placeholder-icon",',
    '        "\\uFF0B"));',
    "      placeholder.appendChild(element(",
    '        "p",',
    '        "",',
    '        "新規モジュール — 元のコードはありません。" +',
    '          "全行が追加行になります。"));',
    "      tableHost.insertBefore(placeholder, tableHost.firstChild);",
    "    }",
    '    diffHost.textContent = "";',
    "    diffHost.appendChild(workspace);",
    "  }",
    "",
    "  function currentTheme() {",
    '    return document.documentElement.getAttribute("data-theme") ===',
    '      "dark" ? "dark" : "light";',
    "  }",
    "",
    // The switch carries the app's own two marks and no words: the moon
    // while the page is light, the sun while it is dark.
    "  function syncThemeButton(button, theme) {",
    "    var label = \"テーマを切り替える（現在: \" +",
    '      (theme === "dark" ? "ダーク" : "ライト") + "）";',
    "",
    "    if (!button) {",
    "      return;",
    "    }",
    '    button.querySelector(".theme-icon--moon").hidden =',
    '      theme === "dark";',
    '    button.querySelector(".theme-icon--sun").hidden =',
    '      theme !== "dark";',
    '    button.setAttribute("aria-label", label);',
    "    button.title = label;",
    "  }",
    "",
    "  function themeButton() {",
    "    var button = element(",
    '      "button",',
    '      "button button--compact button--icon report-theme");',
    "",
    '    button.type = "button";',
    '    button.id = "report-theme-toggle";',
    "    button.innerHTML = THEME_ICONS;",
    '    button.addEventListener("click", function () {',
    '      applyTheme(currentTheme() === "dark" ? "light" : "dark");',
    "    });",
    "    syncThemeButton(button, currentTheme());",
    "    return button;",
    "  }",
    "",
    "  function applyTheme(theme) {",
    '    document.documentElement.setAttribute("data-theme", theme);',
    "    syncThemeButton(",
    '      document.getElementById("report-theme-toggle"),',
    "      theme);",
    "    try {",
    "      localStorage.setItem(THEME_KEY, theme);",
    "    } catch (error) {",
    "      /* The choice still applies to this page. */",
    "    }",
    "  }",
    "",
    "  // The report opens on the first module that changed, the way the",
    "  // review screen opens on what came in.",
    "  function firstChangedIndex() {",
    "    var index;",
    "",
    "    for (index = 0; index < modules.length; index += 1) {",
    "      if (modules[index].changed) {",
    "        return index;",
    "      }",
    "    }",
    "    return 0;",
    "  }",
    "",
    "  function start() {",
    '    listHost = document.getElementById("report-modules");',
    '    diffHost = document.getElementById("report-diff");',
    "    modules.forEach(function (module) {",
    "      rowsOf(module);",
    "    });",
    "    selected = firstChangedIndex();",
    "    // The switch is part of the toolbar, so it is built with every",
    "    // redraw and binds its own click there.",
    "    applyTheme(currentTheme());",
    "    buildList();",
    "    renderModule();",
    "  }",
    "",
    '  if (document.readyState === "loading") {',
    '    document.addEventListener("DOMContentLoaded", start);',
    "  } else {",
    "    start();",
    "  }",
    "}());"
  ];

  function buildReport(options) {
    var input = options || {};
    var bookName = toText(input.bookName);
    var timestamp = formatTimestamp(input.buildTimestamp);
    var modules = getReportModules(input.modules);
    var changedCount = getChangedModules(input.modules).length;
    var assets = input.assets || {};
    var styleBundle;
    var scriptBundle;
    var data;

    if (!bookName) {
      throw new Error("The report book name is missing.");
    }
    if (changedCount === 0) {
      throw new Error("The report has no changed modules.");
    }
    // The report renders with the app's own code, so it cannot be built
    // without it. There is no cut-down copy to fall back on.
    styleBundle = requireBundle(assets.css, "style");
    scriptBundle = requireBundle(assets.js, "script");

    data = {
      bookName: bookName,
      buildTimestamp: timestamp,
      modules: modules.map(function (module) {
        return {
          name: toText(module.name),
          type: toText(module.type),
          typeLabel: getTypeLabel(module),
          isNew: module.isNew === true,
          changed: isChangedModule(module),
          before: toText(module.code),
          after: getModuleAfterText(module)
        };
      })
    };

    return [
      "<!doctype html>",
      '<html lang="ja" data-theme="light">',
      "<head>",
      '<meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      '<meta name="generator" content="MacroStudio">',
      "<title>",
      escapeHtml(bookName),
      " 改修差分</title>",
      "<style>",
      styleBundle.map(function (css) {
        return normalizeCrLf(stripFontFaces(css));
      }).join(CRLF),
      REPORT_STYLES.join(""),
      "</style>",
      "</head>",
      "<body>",
      '<div class="report-shell">',
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
      "</p>",
      "</header>",
      "<noscript>",
      '<p class="report-noscript">',
      "このレポートは、この 1 ファイルの中だけで差分を描画します。",
      "ブラウザのスクリプトを有効にしてから開いてください",
      "（外部との通信は行いません）。",
      "</p>",
      "</noscript>",
      '<div class="report-layout">',
      '<div id="report-modules"></div>',
      '<div id="report-diff" class="diff-review-column"></div>',
      "</div>",
      "</div>",
      '<script type="application/json" id="report-data">',
      escapeJson(data),
      "</script>",
      "<script>",
      scriptBundle.map(normalizeCrLf).join(CRLF),
      REPORT_SCRIPT.join(CRLF),
      "</script>",
      "</body>",
      "</html>",
      ""
    ].join(CRLF);
  }

  global.MacroStudioDiffReport = {
    escapeHtml: escapeHtml,
    escapeJson: escapeJson,
    formatTimestamp: formatTimestamp,
    getChangedModules: getChangedModules,
    getReportModules: getReportModules,
    stripFontFaces: stripFontFaces,
    reportStyles: REPORT_STYLES,
    reportScript: REPORT_SCRIPT,
    buildReport: buildReport
  };
}(window));
