(function (global) {
  "use strict";

  // One answer, one code block. Every module inside it is wrapped in
  // sentinel lines that carry the request id this app issued, so a
  // stale or foreign answer can never be applied by accident.
  //
  //   '@MACROSTUDIO <request id> SUMMARY BEGIN
  //   ...what was changed, in plain words...
  //   '@MACROSTUDIO <request id> SUMMARY END
  //   '@MACROSTUDIO <request id> BEGIN <kind> <name>
  //   ...module code...
  //   '@MACROSTUDIO <request id> END <kind> <name>
  //   '@MACROSTUDIO <request id> COMPLETE <module count>
  //
  // The marker starts with an apostrophe so each sentinel is also a
  // valid VBA comment, and carries the random id so it cannot collide
  // with anything already in the workbook.
  var MARKER = "'@MACROSTUDIO";
  var KINDS = ["standard", "class", "form", "document"];
  var NAME_PATTERN = /^[A-Za-zÀ-￿][\wÀ-￿]{0,30}$/;

  var MESSAGES = {
    empty:
      "クリップボードが空でした。AIの返答のコードブロックをコピーして、" +
      "もう一度お試しください。",
    noSentinel:
      "取り込める形のコードが見つかりませんでした。AIの返答の" +
      "コードブロック全体をコピーして、もう一度お試しください。",
    otherRequest:
      "別の依頼への返答のようです。いまの依頼文をコピーし直して、" +
      "AIへもう一度送ってください。",
    truncated:
      "返答が途中で切れているようです。コードブロック全体を" +
      "コピーし直して、もう一度お試しください。",
    mismatch:
      "モジュールの区切りが揃っていません。コードブロック全体を" +
      "コピーし直して、もう一度お試しください。",
    duplicate:
      "同じモジュールが2回入っていました。AIへ、モジュールごとに" +
      "1つだけ返すよう伝えてください。",
    unknownKind:
      "知らない種類のモジュールが含まれていました。コードブロック全体を" +
      "コピーし直して、もう一度お試しください。",
    badName:
      "モジュール名として使えない名前が含まれていました。" +
      "AIの返答をコピーし直して、もう一度お試しください。",
    emptyModule:
      "中身のないモジュールが含まれていました。AIへ、変更したモジュールの" +
      "全文を返すよう伝えてください。"
  };

  function createRequestId() {
    var bytes;
    var index;
    var text = "";
    var crypto = global.crypto || global.msCrypto;

    if (crypto && typeof crypto.getRandomValues === "function") {
      bytes = new Uint8Array(16);
      crypto.getRandomValues(bytes);
    } else {
      bytes = [];
      for (index = 0; index < 16; index += 1) {
        bytes.push(Math.floor(Math.random() * 256));
      }
    }
    // RFC 4122 version 4 shape, so the id reads as an ordinary UUID.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    for (index = 0; index < 16; index += 1) {
      text += (bytes[index] + 0x100).toString(16).slice(1);
      if (index === 3 || index === 5 || index === 7 || index === 9) {
        text += "-";
      }
    }
    return text;
  }

  function isRequestId(value) {
    return typeof value === "string" &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
        .test(value);
  }

  function beginLine(requestId, kind, name) {
    return MARKER + " " + requestId + " BEGIN " + kind + " " + name;
  }

  function endLine(requestId, kind, name) {
    return MARKER + " " + requestId + " END " + kind + " " + name;
  }

  function summaryBeginLine(requestId) {
    return MARKER + " " + requestId + " SUMMARY BEGIN";
  }

  function summaryEndLine(requestId) {
    return MARKER + " " + requestId + " SUMMARY END";
  }

  function completeLine(requestId, count) {
    return MARKER + " " + requestId + " COMPLETE " + String(count);
  }

  function failure(reason) {
    return {
      ok: false,
      reason: reason,
      message: MESSAGES[reason] || MESSAGES.noSentinel,
      modules: []
    };
  }

  function splitLines(text) {
    return String(text)
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .split("\n");
  }

  // A sentinel is recognised on its own line only, so a marker-looking
  // string inside real code cannot end a module.
  function readSentinel(line) {
    var trimmed = String(line).replace(/^[\s　]+|[\s　]+$/g, "");
    var rest;
    var parts;

    if (trimmed.indexOf(MARKER) !== 0) {
      return null;
    }
    rest = trimmed.slice(MARKER.length).replace(/^\s+/, "");
    parts = rest.split(/\s+/);
    if (parts.length < 2) {
      return { requestId: parts[0] || "", directive: "", parts: parts };
    }
    return {
      requestId: parts[0],
      directive: parts[1].toUpperCase(),
      parts: parts
    };
  }

  function trimBlankEdges(lines) {
    var start = 0;
    var end = lines.length;

    while (start < end &&
        String(lines[start]).replace(/[\s\u3000]/g, "") === "") {
      start += 1;
    }
    while (end > start &&
        String(lines[end - 1]).replace(/[\s\u3000]/g, "") === "") {
      end -= 1;
    }
    return lines.slice(start, end);
  }

  function parse(text, requestId) {
    var lines;
    var modules = [];
    var seen = {};
    var open = null;
    var body = [];
    var completed = null;
    var sawMarker = false;
    var summary = [];
    var inSummary = false;
    var index;
    var sentinel;
    var kind;
    var name;

    if (!isRequestId(requestId)) {
      return failure("otherRequest");
    }
    if (typeof text !== "string" ||
        text.replace(/[\s　]/g, "").length === 0) {
      return failure("empty");
    }

    lines = splitLines(text);
    for (index = 0; index < lines.length; index += 1) {
      sentinel = readSentinel(lines[index]);
      if (sentinel === null) {
        // Fence lines outside a module are chrome; inside a module the
        // code is taken verbatim.
        if (open !== null) {
          body.push(lines[index]);
        } else if (inSummary) {
          summary.push(lines[index]);
        }
        continue;
      }
      sawMarker = true;
      if (sentinel.requestId !== requestId) {
        return failure("otherRequest");
      }
      // The summary is prose, not code: it is read for display only
      // and never reaches a module.
      if (sentinel.directive === "SUMMARY") {
        if (open !== null) {
          return failure("mismatch");
        }
        if (sentinel.parts.length !== 3) {
          return failure("mismatch");
        }
        if (sentinel.parts[2].toUpperCase() === "BEGIN") {
          if (inSummary) {
            return failure("mismatch");
          }
          inSummary = true;
          continue;
        }
        if (sentinel.parts[2].toUpperCase() === "END") {
          if (!inSummary) {
            return failure("mismatch");
          }
          inSummary = false;
          continue;
        }
        return failure("mismatch");
      }
      if (inSummary) {
        return failure("mismatch");
      }
      if (sentinel.directive === "BEGIN") {
        if (open !== null) {
          return failure("mismatch");
        }
        if (sentinel.parts.length !== 4) {
          return failure("mismatch");
        }
        kind = sentinel.parts[2].toLowerCase();
        name = sentinel.parts[3];
        if (KINDS.indexOf(kind) < 0) {
          return failure("unknownKind");
        }
        if (!NAME_PATTERN.test(name)) {
          return failure("badName");
        }
        if (Object.prototype.hasOwnProperty.call(
          seen,
          name.toLowerCase())) {
          return failure("duplicate");
        }
        open = { name: name, kind: kind };
        body = [];
        continue;
      }
      if (sentinel.directive === "END") {
        if (open === null || sentinel.parts.length !== 4) {
          return failure("mismatch");
        }
        if (sentinel.parts[2].toLowerCase() !== open.kind ||
            sentinel.parts[3] !== open.name) {
          return failure("mismatch");
        }
        if (body.join("").replace(/[\s　]/g, "").length === 0) {
          return failure("emptyModule");
        }
        seen[open.name.toLowerCase()] = true;
        modules.push({
          name: open.name,
          kind: open.kind,
          code: body.join("\r\n")
        });
        open = null;
        body = [];
        continue;
      }
      if (sentinel.directive === "COMPLETE") {
        if (open !== null) {
          return failure("truncated");
        }
        completed = sentinel.parts.length >= 3
          ? Number(sentinel.parts[2])
          : NaN;
        continue;
      }
      return failure("mismatch");
    }

    if (open !== null || inSummary) {
      return failure("truncated");
    }
    if (!sawMarker) {
      return failure("noSentinel");
    }
    if (modules.length === 0) {
      return failure("truncated");
    }
    if (completed === null) {
      return failure("truncated");
    }
    if (!isFinite(completed) || completed !== modules.length) {
      return failure("mismatch");
    }

    return {
      ok: true,
      reason: "",
      message: "",
      summary: trimBlankEdges(summary).join("\r\n"),
      modules: modules
    };
  }

  // What the parsed package means for this workbook: which modules it
  // replaces, and which ones it would add.
  //
  // For a module the workbook already has, the workbook decides the
  // kind. A kind the answer got wrong is corrected here and reported in
  // kindWarnings, so the user is told instead of the type changing
  // quietly underneath them.
  function describe(parsed, existingModules) {
    var known = {};
    var summary = {
      ok: true,
      reason: "",
      message: "",
      total: 0,
      existing: 0,
      added: 0,
      summary: "",
      modules: [],
      kindWarnings: []
    };

    if (!parsed || !parsed.ok) {
      return parsed || failure("noSentinel");
    }
    summary.summary = parsed.summary || "";
    (existingModules || []).forEach(function (module) {
      known[module.name.toLowerCase()] = module;
    });

    parsed.modules.forEach(function (item) {
      var match = known[item.name.toLowerCase()];
      var bookKind = match ? String(match.type || "") : "";
      var mismatch = Boolean(match) &&
        bookKind.length > 0 &&
        bookKind !== item.kind;

      summary.modules.push({
        name: match ? match.name : item.name,
        kind: match && bookKind.length > 0 ? bookKind : item.kind,
        answeredKind: item.kind,
        kindCorrected: mismatch,
        code: item.code,
        isNew: !match
      });
      if (mismatch) {
        summary.kindWarnings.push({
          name: match.name,
          answered: item.kind,
          actual: bookKind
        });
      }
      if (match) {
        summary.existing += 1;
      } else {
        summary.added += 1;
      }
    });
    summary.total = summary.modules.length;
    return summary;
  }

  // The one sentence the user sees when a kind was corrected.
  function describeKindWarning(kindWarnings) {
    var names;

    if (!kindWarnings || kindWarnings.length === 0) {
      return "";
    }
    names = kindWarnings.map(function (warning) {
      return warning.name;
    }).join("、");
    return names +
      " の種類はAIの返答と違っていたため、ブック側の種類のまま取り込みました。" +
      "変更内容を見て、意図どおりか確かめてください。";
  }

  global.MacroStudioResponse = {
    marker: MARKER,
    kinds: KINDS,
    messages: MESSAGES,
    createRequestId: createRequestId,
    isRequestId: isRequestId,
    beginLine: beginLine,
    endLine: endLine,
    completeLine: completeLine,
    summaryBeginLine: summaryBeginLine,
    summaryEndLine: summaryEndLine,
    parse: parse,
    describe: describe,
    describeKindWarning: describeKindWarning
  };
}(window));
