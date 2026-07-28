(function (global) {
  "use strict";

  var keywordList = [
    "sub", "function", "end", "exit", "property", "get", "let", "set",
    "public", "private", "friend", "static", "dim", "redim", "preserve",
    "const", "as", "new", "nothing", "me", "mybase", "myclass",
    "byval", "byref", "optional", "paramarray",
    "if", "then", "else", "elseif", "select", "case",
    "for", "to", "step", "next", "each", "in",
    "do", "loop", "while", "wend", "until", "with",
    "goto", "gosub", "return", "on", "error", "resume",
    "call", "debug", "print", "stop", "type", "enum",
    "declare", "ptrsafe", "lib", "alias", "option", "explicit",
    "compare", "base", "implements", "event", "raiseevent", "withevents",
    "and", "or", "not", "xor", "mod", "like", "is",
    "true", "false", "null", "empty", "attribute",
    "open", "close", "input", "output", "append", "binary", "random",
    "write", "read", "seek", "lock", "unlock", "kill", "name",
    "mkdir", "rmdir", "chdir", "chdrive", "curdir", "dir",
    "filecopy", "filelen", "filedatetime", "freefile", "lof", "eof",
    "erase", "lbound", "ubound", "doevents", "beep", "appactivate",
    "shell", "sendkeys", "msgbox", "inputbox", "environ",
    "createobject", "getobject",
    "string", "long", "integer", "double", "single", "boolean", "date",
    "variant", "object", "byte", "currency", "longptr", "longlong",
    "decimal", "any", "collection", "dictionary",
    "abs", "array", "asc", "atn", "cbool", "cbyte", "ccur", "cdate",
    "cdbl", "cdec", "chr", "cint", "clng", "clnglng", "clngptr",
    "cos", "csng", "cstr", "cvar", "cverr", "dateadd", "datediff",
    "datepart", "dateserial", "datevalue", "day", "exp", "fix",
    "format", "hex", "hour", "iif", "instr", "instrrev", "int",
    "isarray", "isdate", "isempty", "iserror", "ismissing", "isnull",
    "isnumeric", "isobject", "join", "lcase", "left", "len", "log",
    "ltrim", "mid", "minute", "month", "monthname", "now", "oct",
    "replace", "right", "rnd", "round", "rtrim", "second", "sgn",
    "sin", "space", "split", "sqr", "str", "strcomp", "strconv",
    "strreverse", "tan", "time", "timer", "timeserial", "timevalue",
    "trim", "typename", "ucase", "val", "vartype",
    "weekday", "weekdayname", "year"
  ];
  var keywords = {};

  keywordList.forEach(function (keyword) {
    keywords[keyword] = true;
  });

  function appendToken(tokens, type, text) {
    var last;

    if (text.length === 0) {
      return;
    }
    last = tokens.length > 0 ? tokens[tokens.length - 1] : null;
    if (last && last.type === type) {
      last.text += text;
    } else {
      tokens.push({
        type: type,
        text: text
      });
    }
  }

  function readString(line, start) {
    var index = start + 1;

    while (index < line.length) {
      if (line.charAt(index) === "\"") {
        if (index + 1 < line.length &&
            line.charAt(index + 1) === "\"") {
          index += 2;
          continue;
        }
        index += 1;
        break;
      }
      index += 1;
    }
    return index;
  }

  function tokenizeLine(value) {
    var line = String(value === undefined || value === null ? "" : value);
    var tokens = [];
    var index = 0;
    var rest;
    var match;
    var end;
    var word;

    while (index < line.length) {
      if (line.charAt(index) === "'") {
        appendToken(tokens, "comment", line.substring(index));
        break;
      }

      if (line.charAt(index) === "\"") {
        end = readString(line, index);
        appendToken(tokens, "string", line.substring(index, end));
        index = end;
        continue;
      }

      rest = line.substring(index);
      match = /^(?:&[hH][0-9a-fA-F]+&?|&[oO][0-7]+&?|\d+\.\d*(?:[eE][\-+]?\d+)?|\d+[eE][\-+]?\d+|\d+)/.exec(rest);
      if (match) {
        appendToken(tokens, "number", match[0]);
        index += match[0].length;
        continue;
      }

      match = /^[A-Za-z_][A-Za-z0-9_]*[$%&!#@]?/.exec(rest);
      if (match) {
        word = match[0].replace(/[$%&!#@]$/, "");
        if (word.toLowerCase() === "rem") {
          appendToken(tokens, "comment", line.substring(index));
          break;
        }
        appendToken(
          tokens,
          keywords[word.toLowerCase()] ? "keyword" : "plain",
          match[0]);
        index += match[0].length;
        continue;
      }

      appendToken(tokens, "plain", line.charAt(index));
      index += 1;
    }

    return tokens;
  }

  function appendHighlighted(container, text) {
    var documentObject = container.ownerDocument || global.document;

    tokenizeLine(text).forEach(function (token) {
      var span;

      if (token.type === "plain") {
        container.appendChild(documentObject.createTextNode(token.text));
      } else {
        span = documentObject.createElement("span");
        span.className = "vba-token vba-token--" + token.type;
        span.textContent = token.text;
        container.appendChild(span);
      }
    });
  }

  global.MacroDeskVbaHighlight = {
    tokenizeLine: tokenizeLine,
    appendHighlighted: appendHighlighted
  };
}(window));
