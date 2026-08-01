(function (global) {
  "use strict";

  function splitPhysicalLines(value) {
    var text = String(value === undefined || value === null ? "" : value);
    var lines = [];
    var pattern = /\r\n|\n|\r/g;
    var start = 0;
    var match;

    while ((match = pattern.exec(text)) !== null) {
      lines.push({
        number: lines.length + 1,
        text: text.slice(start, match.index),
        eol: match[0]
      });
      start = match.index + match[0].length;
    }
    if (start < text.length || lines.length === 0) {
      lines.push({
        number: lines.length + 1,
        text: text.slice(start),
        eol: ""
      });
    }
    return lines;
  }

  function addToken(tokens, kind, text, line, start, end) {
    if (end <= start) {
      return;
    }
    tokens.push({
      kind: kind,
      text: text.slice(start, end),
      line: line,
      column: start,
      endColumn: end
    });
  }

  function isSpace(character) {
    return character === " " || character === "\t";
  }

  function isRemStart(text, index) {
    return text.slice(index, index + 3).toLowerCase() === "rem" &&
      (index + 3 === text.length || isSpace(text.charAt(index + 3)));
  }

  function scanPhysicalLine(record) {
    var text = record.text;
    var tokens = [];
    var numericLabel = /^[ \t]*\d+[ \t]+/.exec(text);
    var numericLabelEnd = numericLabel ? numericLabel[0].length : 0;
    var statementStart = true;
    var codeStart = 0;
    var i = 0;
    var j;
    var closed;

    record.unterminatedString = false;
    record.unterminatedBracket = false;

    while (i < text.length) {
      if (i < numericLabelEnd) {
        i += 1;
        if (i === numericLabelEnd) {
          statementStart = true;
        }
        continue;
      }
      if (statementStart && isSpace(text.charAt(i))) {
        i += 1;
        continue;
      }
      if (statementStart && isRemStart(text, i)) {
        addToken(tokens, "code", text, record.number, codeStart, i);
        addToken(tokens, "comment", text, record.number, i, text.length);
        i = text.length;
        codeStart = i;
        break;
      }
      if (text.charAt(i) === "\"") {
        addToken(tokens, "code", text, record.number, codeStart, i);
        j = i + 1;
        closed = false;
        while (j < text.length) {
          if (text.charAt(j) === "\"") {
            if (j + 1 < text.length && text.charAt(j + 1) === "\"") {
              j += 2;
              continue;
            }
            j += 1;
            closed = true;
            break;
          }
          j += 1;
        }
        if (!closed) {
          record.unterminatedString = true;
        }
        addToken(tokens, "string", text, record.number, i, j);
        i = j;
        codeStart = i;
        statementStart = false;
        continue;
      }
      if (text.charAt(i) === "'") {
        addToken(tokens, "code", text, record.number, codeStart, i);
        addToken(tokens, "comment", text, record.number, i, text.length);
        i = text.length;
        codeStart = i;
        break;
      }
      if (text.charAt(i) === "[") {
        addToken(tokens, "code", text, record.number, codeStart, i);
        j = i + 1;
        while (j < text.length && text.charAt(j) !== "]") {
          j += 1;
        }
        if (j < text.length) {
          j += 1;
        } else {
          record.unterminatedBracket = true;
        }
        addToken(tokens, "bracket", text, record.number, i, j);
        i = j;
        codeStart = i;
        statementStart = false;
        continue;
      }
      if (text.charAt(i) === ":") {
        statementStart = true;
        i += 1;
        continue;
      }
      if (!isSpace(text.charAt(i))) {
        statementStart = false;
      }
      i += 1;
    }
    addToken(tokens, "code", text, record.number, codeStart, text.length);
    record.tokens = tokens;
    record.continues = isContinuation(record);
    return record;
  }

  function tokenAtColumn(line, column) {
    var found = null;

    line.tokens.some(function (token) {
      if (token.column <= column && token.endColumn > column) {
        found = token;
        return true;
      }
      return false;
    });
    return found;
  }

  function isContinuation(line) {
    var match = /[ \t]+_$/.exec(line.text);
    var token;

    if (!match) {
      return false;
    }
    token = tokenAtColumn(line, line.text.length - 1);
    return Boolean(token && token.kind === "code");
  }

  function codeOnly(line) {
    var parts = [];

    line.tokens.forEach(function (token) {
      if (token.kind === "code") {
        parts.push(token.text);
      } else {
        parts.push(new Array(token.text.length + 1).join(" "));
      }
    });
    return parts.join("");
  }

  function annotateConditionals(lines) {
    var depth = 0;
    var balanced = true;

    lines.forEach(function (line) {
      var source = codeOnly(line).replace(/^[ \t]+/, "");
      var opens = /^#\s*If\b[\s\S]*\bThen\b/i.test(source) &&
        !/^#\s*ElseIf\b/i.test(source);
      var closes = /^#\s*End[ \t]+If\b/i.test(source);

      line.inConditional = depth > 0;
      line.tokens.forEach(function (token) {
        token.inConditional = line.inConditional;
      });
      if (closes) {
        if (depth === 0) {
          balanced = false;
        } else {
          depth -= 1;
        }
      }
      if (opens) {
        depth += 1;
      }
    });
    if (depth !== 0) {
      balanced = false;
    }
    return balanced;
  }

  function buildLogicalLines(lines) {
    var logical = [];
    var start = 0;
    var index;

    while (start < lines.length) {
      var end = start;
      var text = "";
      var code = "";
      var parts = [];

      while (end < lines.length) {
        if (end > start) {
          text += lines[end - 1].eol || "\r\n";
          code += lines[end - 1].eol || "\r\n";
        }
        text += lines[end].text;
        code += codeOnly(lines[end]);
        parts.push({
          line: lines[end].number,
          text: lines[end].text
        });
        if (!lines[end].continues) {
          break;
        }
        end += 1;
      }
      if (end >= lines.length) {
        end = lines.length - 1;
      }
      index = logical.length;
      logical.push({
        index: index,
        startLine: lines[start].number,
        endLine: lines[end].number,
        text: text,
        code: code,
        lines: parts
      });
      while (start <= end) {
        lines[start].logicalIndex = index;
        lines[start].logicalStartLine = logical[index].startLine;
        lines[start].logicalEndLine = logical[index].endLine;
        start += 1;
      }
    }
    return logical;
  }

  function procedureEvents(source) {
    var events = [];
    var startPattern =
      /(^|:)[ \t]*(?:(?:Public|Private|Friend|Static)[ \t]+)?(Sub|Function|Property[ \t]+(?:Get|Let|Set))[ \t]+([A-Za-z_][A-Za-z0-9_]*)\b/ig;
    var endPattern = /(^|:)[ \t]*End[ \t]+(Sub|Function|Property)\b/ig;
    var match;

    while ((match = startPattern.exec(source)) !== null) {
      events.push({
        column: match.index + (match[1] === ":" ? 1 : 0),
        action: "start",
        kind: match[2].toLowerCase().split(/[ \t]+/)[0],
        name: match[3]
      });
      if (match[0].length === 0) {
        startPattern.lastIndex += 1;
      }
    }
    while ((match = endPattern.exec(source)) !== null) {
      events.push({
        column: match.index + (match[1] === ":" ? 1 : 0),
        action: "end",
        kind: match[2].toLowerCase()
      });
      if (match[0].length === 0) {
        endPattern.lastIndex += 1;
      }
    }
    events.sort(function (left, right) {
      if (left.column !== right.column) {
        return left.column - right.column;
      }
      return left.action === "end" ? -1 : 1;
    });
    return events;
  }

  function applyProcedureEvent(current, event) {
    if (event.action === "start") {
      return {name: event.name, kind: event.kind};
    }
    if (current && current.kind === event.kind) {
      return null;
    }
    return current;
  }

  function annotateProcedures(lines) {
    var current = null;

    lines.forEach(function (line) {
      var events = procedureEvents(codeOnly(line));
      var eventIndex = 0;
      var stringTokens = line.tokens.filter(function (token) {
        return token.kind === "string";
      });

      stringTokens.forEach(function (token) {
        while (eventIndex < events.length &&
            events[eventIndex].column <= token.column) {
          current = applyProcedureEvent(current, events[eventIndex]);
          eventIndex += 1;
        }
        token.procedure = current ? current.name : "-";
      });
      while (eventIndex < events.length) {
        current = applyProcedureEvent(current, events[eventIndex]);
        eventIndex += 1;
      }
    });
  }

  function decodeStringToken(token) {
    var raw = token && token.kind === "string" ? token.text : "";
    var closed = raw.length >= 2 &&
      raw.charAt(0) === "\"" &&
      raw.charAt(raw.length - 1) === "\"";
    var body = raw.charAt(0) === "\"" ? raw.slice(1) : raw;

    if (closed) {
      body = body.slice(0, -1);
    }
    return body.replace(/""/g, "\"");
  }

  function lex(value) {
    var text = String(value === undefined || value === null ? "" : value);
    var lines = splitPhysicalLines(text).map(scanPhysicalLine);
    var balanced = annotateConditionals(lines);
    var logicalLines = buildLogicalLines(lines);

    annotateProcedures(lines);
    return {
      text: text,
      lines: lines,
      logicalLines: logicalLines,
      conditionalBalanced: balanced
    };
  }

  function reconstruct(result) {
    if (!result || !Array.isArray(result.lines)) {
      return "";
    }
    return result.lines.map(function (line) {
      return line.tokens.map(function (token) {
        return token.text;
      }).join("") + line.eol;
    }).join("");
  }

  global.MacroStudioVbaLexer = {
    lex: lex,
    reconstruct: reconstruct,
    decodeStringToken: decodeStringToken,
    codeOnly: codeOnly
  };
}(window));
