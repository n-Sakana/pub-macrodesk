(function (global) {
  "use strict";

  var CONTEXT_LINES = 10;

  function createElement(documentObject, tagName, className, text) {
    var element = documentObject.createElement(tagName);
    if (className) {
      element.className = className;
    }
    if (text !== undefined) {
      element.textContent = text;
    }
    return element;
  }

  function appendCode(cell, text, highlighted) {
    cell.setAttribute("title", text);
    if (highlighted) {
      global.MacroDeskVbaHighlight.appendHighlighted(cell, text);
    } else {
      cell.textContent = text.length > 0 ? text : " ";
    }
  }

  function createDiffRow(documentObject, row) {
    var tableRow = createElement(
      documentObject,
      "tr",
      "diff-row diff-row--" + row.type);
    var lineA = createElement(
      documentObject,
      "td",
      "diff-line-number diff-line-number--left",
      row.lineA >= 0 ? String(row.lineA + 1) : "");
    var codeA = createElement(
      documentObject,
      "td",
      "diff-code diff-code--left");
    var separator = createElement(
      documentObject,
      "td",
      "diff-separator");
    var lineB = createElement(
      documentObject,
      "td",
      "diff-line-number diff-line-number--right",
      row.lineB >= 0 ? String(row.lineB + 1) : "");
    var codeB = createElement(
      documentObject,
      "td",
      "diff-code diff-code--right");
    var highlighted = row.type === "equal";

    lineA.setAttribute("aria-hidden", "true");
    lineB.setAttribute("aria-hidden", "true");
    separator.setAttribute("aria-hidden", "true");
    appendCode(codeA, row.textA, highlighted);
    appendCode(codeB, row.textB, highlighted);
    tableRow.appendChild(lineA);
    tableRow.appendChild(codeA);
    tableRow.appendChild(separator);
    tableRow.appendChild(lineB);
    tableRow.appendChild(codeB);
    return tableRow;
  }

  function createGapRow(documentObject, count) {
    var row = createElement(documentObject, "tr", "diff-gap");
    var cell = createElement(
      documentObject,
      "td",
      "diff-gap-cell",
      count + " 行を省略");

    cell.colSpan = 5;
    row.appendChild(cell);
    return row;
  }

  function getVisibleRows(rows, contextOnly) {
    var visible = [];
    var include = [];
    var index;
    var start;
    var end;
    var pendingGap = 0;

    if (!contextOnly) {
      return rows.slice();
    }

    for (index = 0; index < rows.length; index += 1) {
      include[index] = false;
    }

    rows.forEach(function (row, rowIndex) {
      if (row.type !== "equal") {
        start = Math.max(0, rowIndex - CONTEXT_LINES);
        end = Math.min(rows.length - 1, rowIndex + CONTEXT_LINES);
        for (index = start; index <= end; index += 1) {
          include[index] = true;
        }
      }
    });

    for (index = 0; index < rows.length; index += 1) {
      if (include[index]) {
        if (pendingGap > 0) {
          visible.push({
            type: "gap",
            count: pendingGap
          });
          pendingGap = 0;
        }
        visible.push(rows[index]);
      } else {
        pendingGap += 1;
      }
    }

    if (pendingGap > 0) {
      visible.push({
        type: "gap",
        count: pendingGap
      });
    }

    return visible;
  }

  function renderDiff(container, rows, contextOnly) {
    var documentObject = container.ownerDocument || global.document;
    var scroller = createElement(
      documentObject,
      "div",
      "diff-table-scroller");
    var table = createElement(documentObject, "table", "diff-table");
    var caption = createElement(
      documentObject,
      "caption",
      "visually-hidden",
      "現在のコードと貼り付けたコードの行単位比較");
    var columns = documentObject.createElement("colgroup");
    var body = documentObject.createElement("tbody");

    [
      "diff-column--line",
      "diff-column--code",
      "diff-column--separator",
      "diff-column--line",
      "diff-column--code"
    ].forEach(function (className) {
      columns.appendChild(
        createElement(documentObject, "col", className));
    });

    getVisibleRows(rows, contextOnly).forEach(function (row) {
      body.appendChild(
        row.type === "gap"
          ? createGapRow(documentObject, row.count)
          : createDiffRow(documentObject, row));
    });

    table.appendChild(caption);
    table.appendChild(columns);
    table.appendChild(body);
    scroller.appendChild(table);
    container.textContent = "";
    container.appendChild(scroller);
    return table;
  }

  function createSourceView(documentObject, text) {
    var pane = createElement(
      documentObject,
      "section",
      "code-pane source-pane");
    var header = createElement(
      documentObject,
      "header",
      "code-pane-header");
    var tableScroller = createElement(
      documentObject,
      "div",
      "source-table-scroller");
    var table = createElement(documentObject, "table", "source-table");
    var caption = createElement(
      documentObject,
      "caption",
      "visually-hidden",
      "現在のコード");
    var body = documentObject.createElement("tbody");
    var lines = global.MacroDeskDiff.toLines(text);

    header.appendChild(
      createElement(documentObject, "span", "", "現在のコード"));
    header.appendChild(
      createElement(documentObject, "span", "code-pane-note", "ORIGINAL"));

    lines.forEach(function (line, index) {
      var row = documentObject.createElement("tr");
      var lineNumber = createElement(
        documentObject,
        "td",
        "source-line-number",
        String(index + 1));
      var code = createElement(documentObject, "td", "source-code");

      lineNumber.setAttribute("aria-hidden", "true");
      global.MacroDeskVbaHighlight.appendHighlighted(code, line);
      row.appendChild(lineNumber);
      row.appendChild(code);
      body.appendChild(row);
    });

    table.appendChild(caption);
    table.appendChild(body);
    tableScroller.appendChild(table);
    pane.appendChild(header);
    pane.appendChild(tableScroller);
    return pane;
  }

  global.MacroDeskDiffView = {
    contextLines: CONTEXT_LINES,
    getVisibleRows: getVisibleRows,
    renderDiff: renderDiff,
    createSourceView: createSourceView
  };
}(window));
