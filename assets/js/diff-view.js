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

  function appendTokenText(documentObject, container, type, text) {
    var node;

    if (!text) {
      return;
    }
    if (type === "plain") {
      node = documentObject.createTextNode(text);
    } else {
      node = createElement(
        documentObject,
        "span",
        "vba-token vba-token--" + type,
        text);
    }
    container.appendChild(node);
  }

  function appendTokenRange(
    documentObject,
    container,
    tokens,
    start,
    end,
    showWhitespace
  ) {
    var offset = 0;

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
      appendTokenText(
        documentObject,
        container,
        token.type,
        text);
    });
  }

  function appendCode(cell, text, markStart, markEnd, markClass) {
    var documentObject = cell.ownerDocument || global.document;
    var value = String(text || "");
    var tokens = global.MacroDeskVbaHighlight.tokenizeLine(value);
    var mark;

    cell.setAttribute("title", value);
    if (value.length === 0) {
      cell.appendChild(documentObject.createTextNode(" "));
      return;
    }
    if (markStart === undefined ||
        markEnd === undefined ||
        markStart >= markEnd) {
      appendTokenRange(
        documentObject,
        cell,
        tokens,
        0,
        value.length,
        false);
      return;
    }

    appendTokenRange(
      documentObject,
      cell,
      tokens,
      0,
      markStart,
      false);
    mark = createElement(
      documentObject,
      "mark",
      "diff-inline-mark " + markClass);
    appendTokenRange(
      documentObject,
      mark,
      tokens,
      markStart,
      markEnd,
      true);
    cell.appendChild(mark);
    appendTokenRange(
      documentObject,
      cell,
      tokens,
      markEnd,
      value.length,
      false);
  }

  function getInlineDifference(leftText, rightText) {
    var left = String(leftText || "");
    var right = String(rightText || "");
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
    var inline = row.type === "changed"
      ? getInlineDifference(row.textA, row.textB)
      : null;

    lineA.setAttribute("aria-hidden", "true");
    lineB.setAttribute("aria-hidden", "true");
    separator.setAttribute("aria-hidden", "true");
    if (row.changeBlock !== undefined && row.changeBlock !== null) {
      tableRow.setAttribute(
        "data-change-block",
        String(row.changeBlock));
    }
    appendCode(
      codeA,
      row.textA,
      inline ? inline.leftStart : undefined,
      inline ? inline.leftEnd : undefined,
      "diff-inline-mark--removed");
    appendCode(
      codeB,
      row.textB,
      inline ? inline.rightStart : undefined,
      inline ? inline.rightEnd : undefined,
      "diff-inline-mark--added");
    tableRow.appendChild(lineA);
    tableRow.appendChild(codeA);
    tableRow.appendChild(separator);
    tableRow.appendChild(lineB);
    tableRow.appendChild(codeB);
    return tableRow;
  }

  function createGapRow(documentObject, hiddenRows) {
    var row = createElement(documentObject, "tr", "diff-gap");
    var cell = createElement(documentObject, "td", "diff-gap-cell");
    var button = createElement(
      documentObject,
      "button",
      "diff-gap-button",
      "\u2026" + hiddenRows.length + " 行を表示");

    button.type = "button";
    button.addEventListener("click", function () {
      var fragment = documentObject.createDocumentFragment();

      hiddenRows.forEach(function (hiddenRow) {
        fragment.appendChild(
          createDiffRow(documentObject, hiddenRow));
      });
      row.parentNode.replaceChild(fragment, row);
    });
    cell.colSpan = 5;
    cell.appendChild(button);
    row.appendChild(cell);
    return row;
  }

  function assignChangeBlocks(rows) {
    var block = -1;
    var inChange = false;

    (rows || []).forEach(function (row) {
      if (row.type === "equal") {
        inChange = false;
        row.changeBlock = null;
        return;
      }
      if (!inChange) {
        block += 1;
        inChange = true;
      }
      row.changeBlock = block;
    });
    return block + 1;
  }

  function getVisibleRows(rows, contextOnly) {
    var visible = [];
    var include = [];
    var index;
    var start;
    var end;
    var gapRows = [];

    assignChangeBlocks(rows);
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
        if (gapRows.length > 0) {
          visible.push({
            type: "gap",
            count: gapRows.length,
            rows: gapRows
          });
          gapRows = [];
        }
        visible.push(rows[index]);
      } else {
        gapRows.push(rows[index]);
      }
    }

    if (gapRows.length > 0) {
      visible.push({
        type: "gap",
        count: gapRows.length,
        rows: gapRows
      });
    }

    return visible;
  }

  function hasWhitespaceOnlyChange(rows) {
    return (rows || []).some(function (row) {
      return row.type === "changed" &&
        row.textA !== row.textB &&
        row.textA.replace(/\s/g, "") ===
          row.textB.replace(/\s/g, "");
    });
  }

  function createHeaderCell(documentObject, title, note) {
    var cell = createElement(documentObject, "th", "diff-column-heading");
    var label = createElement(documentObject, "span", "", title);

    cell.colSpan = 2;
    cell.scope = "colgroup";
    cell.appendChild(label);
    cell.appendChild(
      createElement(documentObject, "span", "code-pane-note", note));
    return cell;
  }

  function createHeader(documentObject) {
    var head = documentObject.createElement("thead");
    var row = documentObject.createElement("tr");
    var separator = createElement(
      documentObject,
      "th",
      "diff-separator diff-separator--heading");

    separator.setAttribute("aria-hidden", "true");
    row.appendChild(
      createHeaderCell(documentObject, "現在のコード", "ORIGINAL"));
    row.appendChild(separator);
    row.appendChild(
      createHeaderCell(documentObject, "貼り付けたコード", "COPILOT"));
    head.appendChild(row);
    return head;
  }

  function renderDiff(container, rows, contextOnly, wrapLines) {
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
          ? createGapRow(documentObject, row.rows)
          : createDiffRow(documentObject, row));
    });

    table.appendChild(caption);
    table.appendChild(columns);
    // The column headings live inside the table so they always line up
    // with the columns they name and stay visible while scrolling.
    table.appendChild(createHeader(documentObject));
    table.appendChild(body);
    scroller.appendChild(table);
    scroller.classList.toggle("is-wrapped", wrapLines === true);
    container.textContent = "";
    container.appendChild(scroller);
    container.setAttribute(
      "data-change-block-count",
      String(assignChangeBlocks(rows)));
    container.setAttribute("data-current-change-block", "0");
    return table;
  }

  function jumpToChange(container, direction, counter) {
    var rows = container.querySelectorAll(
      ".diff-row[data-change-block]");
    var blockCount = Number(
      container.getAttribute("data-change-block-count")) || 0;
    var current = Number(
      container.getAttribute("data-current-change-block")) || 0;
    var target;
    var targetRows;

    if (blockCount === 0 || rows.length === 0) {
      return false;
    }
    target = Math.max(
      0,
      Math.min(blockCount - 1, current + direction));
    container.setAttribute(
      "data-current-change-block",
      String(target));
    targetRows = container.querySelectorAll(
      '.diff-row[data-change-block="' + target + '"]');
    Array.prototype.forEach.call(rows, function (row) {
      row.classList.remove("is-jump-target");
    });
    Array.prototype.forEach.call(targetRows, function (row) {
      row.classList.add("is-jump-target");
    });
    if (targetRows.length > 0) {
      targetRows[0].scrollIntoView({
        block: "center",
        inline: "nearest"
      });
    }
    if (counter) {
      counter.textContent = (target + 1) + "/" + blockCount;
    }
    global.setTimeout(function () {
      Array.prototype.forEach.call(targetRows, function (row) {
        row.classList.remove("is-jump-target");
      });
    }, 1000);
    return true;
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
    assignChangeBlocks: assignChangeBlocks,
    getVisibleRows: getVisibleRows,
    getInlineDifference: getInlineDifference,
    hasWhitespaceOnlyChange: hasWhitespaceOnlyChange,
    renderDiff: renderDiff,
    jumpToChange: jumpToChange,
    createSourceView: createSourceView
  };
}(window));
