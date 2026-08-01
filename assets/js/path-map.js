(function (global) {
  "use strict";

  var productResults = new WeakSet();
  var TEMPLATE_KEY = "fixed-path-replace";
  var ABSOLUTE_CLASSES = {
    driveAbsolute: true,
    unc: true,
    url: true
  };
  var OPEN_CLASSES = {
    driveAbsolute: true,
    unc: true,
    url: true,
    envVar: true
  };
  var CLASS_LABELS = {
    driveAbsolute: "ドライブから始まる場所",
    unc: "ネットワーク上の場所",
    url: "URL",
    envVar: "環境変数を含む場所",
    knownFolder: "既知のフォルダー名",
    fragment: "連結された場所の一部",
    bareName: "ファイル名",
    ambiguous: "確認が必要な候補"
  };
  var ABSOLUTE_CLASS_LABELS = {
    driveAbsolute: "ドライブのパス",
    unc: "ネットワークのパス",
    url: "URL"
  };
  var PRIORITY = {
    "P-AMB-02": 0,
    "P-DRIVE-01": 1,
    "P-UNC-01": 2,
    "P-URL-01": 3,
    "P-ENV-01": 4,
    "P-KNOWN-01": 5,
    "P-FRAG-01": 6,
    "P-BARE-01": 7,
    "P-AMB-01": 8
  };

  function deepFreeze(value) {
    if (!value || typeof value !== "object" || Object.isFrozen(value)) {
      return value;
    }
    Object.keys(value).forEach(function (key) {
      deepFreeze(value[key]);
    });
    return Object.freeze(value);
  }

  function brand(value) {
    productResults.add(value);
    return deepFreeze(value);
  }

  function isProductResult(value) {
    return Boolean(value) && typeof value === "object" &&
      productResults.has(value);
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function isPathish(value) {
    var text = String(value === undefined || value === null ? "" : value);

    return text.indexOf("\\") >= 0 ||
      text.indexOf("/") >= 0 ||
      /%[A-Za-z_][A-Za-z0-9_()]*%/.test(text) ||
      /\.[A-Za-z0-9]{1,8}$/.test(text);
  }

  function classifyAbsolute(value) {
    var text = String(value === undefined || value === null ? "" : value);

    if (/^[A-Za-z]:[\\/]/.test(text)) {
      return {className: "driveAbsolute", ruleId: "P-DRIVE-01"};
    }
    if (/^\\\\[^\\]/.test(text)) {
      return {className: "unc", ruleId: "P-UNC-01"};
    }
    if (/^(?:https?|ftp):\/\//i.test(text)) {
      return {className: "url", ruleId: "P-URL-01"};
    }
    return null;
  }

  function hasKnownFolder(value) {
    var text = String(value).toLowerCase();

    return text.indexOf("\\users\\") >= 0 ||
      text.indexOf("\\desktop") >= 0 ||
      text.indexOf("\\documents") >= 0 ||
      text.indexOf("\\appdata") >= 0 ||
      text.indexOf("\\program files") >= 0;
  }

  function hasBareNameContext(code) {
    return /\bWorkbooks[ \t]*\.[ \t]*Open\b/i.test(code) ||
      /\bDir[ \t]*(?:\(|$|[ \t])/i.test(code) ||
      /\bSaveAs\b/i.test(code) ||
      /\bOpen\b[\s\S]*\bFor\b/i.test(code) ||
      /\bFileSystemObject\b/i.test(code) ||
      /\bGetObject\b/i.test(code);
  }

  function classifyOccurrence(value, logicalCode, unsafe) {
    var absolute;

    if (unsafe) {
      return {className: "ambiguous", ruleId: "P-AMB-02"};
    }
    absolute = classifyAbsolute(value);
    if (absolute) {
      return absolute;
    }
    if (/%[A-Za-z_][A-Za-z0-9_()]*%/.test(value)) {
      return {className: "envVar", ruleId: "P-ENV-01"};
    }
    if (hasKnownFolder(value)) {
      return {className: "knownFolder", ruleId: "P-KNOWN-01"};
    }
    if ((value.indexOf("\\") >= 0 || value.indexOf("/") >= 0) &&
        logicalCode.indexOf("&") >= 0) {
      return {className: "fragment", ruleId: "P-FRAG-01"};
    }
    if (value.indexOf("\\") < 0 && value.indexOf("/") < 0 &&
        hasBareNameContext(logicalCode)) {
      return {className: "bareName", ruleId: "P-BARE-01"};
    }
    return {className: "ambiguous", ruleId: "P-AMB-01"};
  }

  function lineCount(value) {
    var text = String(value || "");
    var lines;

    if (!text) {
      return 0;
    }
    lines = text.split(/\r\n|\n|\r/);
    if (lines.length && lines[lines.length - 1] === "") {
      lines.pop();
    }
    return lines.length;
  }

  function decorateRow(row) {
    var result = validateRow(row);
    var targetClass = classifyAbsolute(row.to);
    var sourceIsAbsolute = ABSOLUTE_CLASSES[row["class"]] === true;

    row.valid = result.ok;
    row.validationId = result.validationId || null;
    row.validationMessage = result.message || "";
    row.needsLocationShapeConfirmation = row.applied === true &&
      sourceIsAbsolute && !targetClass;
    row.locationClassChangeMessage = row.applied === true &&
      sourceIsAbsolute && targetClass &&
      targetClass.className !== row["class"]
      ? ABSOLUTE_CLASS_LABELS[row["class"]] + "から " +
        ABSOLUTE_CLASS_LABELS[targetClass.className] + " に変わります。"
      : "";
    row.status = row.applied ? "applied" : "pending";
    return row;
  }

  function createContract(rows) {
    return brand({
      kind: "mapping",
      schemaVersion: 1,
      templateKey: TEMPLATE_KEY,
      rows: rows.map(decorateRow)
    });
  }

  function detect(modules) {
    var lexer = global.MacroStudioVbaLexer;
    var groups = Object.create(null);
    var order = [];

    if (!lexer || typeof lexer.lex !== "function") {
      return brand({
        kind: "failure",
        ok: false,
        code: "E-MAP-02",
        message: "固定パスの候補を安全に確認できませんでした。"
      });
    }
    (Array.isArray(modules) ? modules : []).forEach(function (module) {
      var moduleName = String(module && module.name || "");
      var parsed = lexer.lex(String(module && module.code || ""));

      parsed.lines.forEach(function (line) {
        var logical = parsed.logicalLines[line.logicalIndex];

        line.tokens.forEach(function (token) {
          var value;
          var classification;
          var occurrence;
          var row;
          var unsafe;

          if (token.kind !== "string") {
            return;
          }
          value = lexer.decodeStringToken(token);
          if (!isPathish(value)) {
            return;
          }
          unsafe = line.unterminatedString ||
            line.unterminatedBracket ||
            !parsed.conditionalBalanced;
          classification = classifyOccurrence(
            value,
            logical ? logical.code : "",
            unsafe);
          occurrence = {
            module: moduleName,
            procedure: token.procedure || "-",
            line: line.number,
            column: token.column,
            endColumn: token.endColumn,
            class: classification.className,
            ruleId: classification.ruleId,
            inConditional: line.inConditional === true,
            conditionalUnbalanced: !parsed.conditionalBalanced,
            logicalLine: logical ? logical.text : line.text,
            logicalLines: logical ? clone(logical.lines) : [{
              line: line.number,
              text: line.text
            }]
          };
          row = groups[value];
          if (!row) {
            row = {
              groupKey: value,
              "class": classification.className,
              ruleId: classification.ruleId,
              from: value,
              to: "",
              included: OPEN_CLASSES[classification.className] === true,
              applied: false,
              locationShapeConfirmed: false,
              occurrences: []
            };
            groups[value] = row;
            order.push(value);
          } else if (PRIORITY[classification.ruleId] <
              PRIORITY[row.ruleId]) {
            row["class"] = classification.className;
            row.ruleId = classification.ruleId;
            row.included = OPEN_CLASSES[classification.className] === true;
          }
          row.occurrences.push(occurrence);
        });
      });
    });
    return createContract(order.map(function (key) {
      return groups[key];
    }));
  }

  function validateRow(row) {
    var target;
    var targetClass;

    if (!row || row.applied !== true) {
      return {ok: true};
    }
    target = String(row.to === undefined || row.to === null ? "" : row.to);
    if (target.length === 0) {
      return {
        ok: false,
        validationId: "M01",
        message: "新しい場所を入力してください。"
      };
    }
    if (/[\u0000-\u001F\u007F]/.test(target)) {
      return {
        ok: false,
        validationId: "M02",
        message: "改行・タブなどの制御文字は入力できません。"
      };
    }
    if (target.length > 1024) {
      return {
        ok: false,
        validationId: "M03",
        message: "新しい場所は1024文字以内で入力してください。"
      };
    }
    if (ABSOLUTE_CLASSES[row["class"]]) {
      targetClass = classifyAbsolute(target);
      if (!targetClass && row.locationShapeConfirmed !== true) {
        return {
          ok: false,
          validationId: "M04",
          requiresConfirmation: true,
          message: "入力した値は場所の形になっていません。"
        };
      }
    }
    return {ok: true};
  }

  function validateInternal(mapping) {
    var applied;
    var results;

    if (!isProductResult(mapping) || mapping.kind !== "mapping" ||
        mapping.schemaVersion !== 1 ||
        mapping.templateKey !== TEMPLATE_KEY ||
        !Array.isArray(mapping.rows)) {
      return {
        ok: false,
        appliedCount: 0,
        rows: [],
        code: "E-MAP-01"
      };
    }
    applied = mapping.rows.filter(function (row) {
      return row && row.applied === true;
    });
    results = mapping.rows.map(function (row) {
      var validation = validateRow(row);
      return {
        groupKey: row.groupKey,
        ok: validation.ok,
        validationId: validation.validationId || null,
        message: validation.message || "",
        requiresConfirmation: validation.requiresConfirmation === true
      };
    });
    return {
      ok: applied.length > 0 && results.every(function (result) {
        return result.ok;
      }),
      appliedCount: applied.length,
      rows: results,
      code: "E-MAP-01"
    };
  }

  function validate(mapping) {
    var result = validateInternal(mapping);

    result.kind = "validation";
    return brand(result);
  }

  function canApply(mapping) {
    return validateInternal(mapping).ok;
  }

  function updateRow(mapping, groupKey, patch) {
    var rows;
    var found = false;

    if (!isProductResult(mapping) || mapping.kind !== "mapping") {
      return null;
    }
    rows = clone(mapping.rows);
    rows.forEach(function (row) {
      var next = patch || {};

      if (row.groupKey !== groupKey) {
        return;
      }
      found = true;
      if (Object.prototype.hasOwnProperty.call(next, "included") &&
          !OPEN_CLASSES[row["class"]]) {
        row.included = next.included === true;
      }
      if (Object.prototype.hasOwnProperty.call(next, "to")) {
        var target = String(next.to === undefined || next.to === null
          ? ""
          : next.to);
        if (target !== row.to) {
          row.locationShapeConfirmed = false;
        }
        row.to = target;
      }
      if (Object.prototype.hasOwnProperty.call(
          next,
          "locationShapeConfirmed")) {
        row.locationShapeConfirmed = next.locationShapeConfirmed === true;
      }
      row.applied = row.included === true && row.to.length > 0;
      if (!row.applied) {
        row.locationShapeConfirmed = false;
      }
    });
    return found ? createContract(rows) : mapping;
  }

  function findStringToken(parsed, occurrence) {
    var line = parsed.lines[Number(occurrence.line) - 1];
    var found = null;

    if (!line) {
      return null;
    }
    line.tokens.some(function (token) {
      if (token.kind === "string" &&
          token.column === Number(occurrence.column)) {
        found = token;
        return true;
      }
      return false;
    });
    return found;
  }

  function escapeLiteral(value) {
    return "\"" + String(value).replace(/"/g, "\"\"") + "\"";
  }

  function failure(code, message, validationId) {
    return brand({
      kind: "failure",
      ok: false,
      code: code,
      validationId: validationId || null,
      message: message
    });
  }

  function apply(mapping, modules) {
    var lexer = global.MacroStudioVbaLexer;
    var validation = validateInternal(mapping);
    var moduleList = Array.isArray(modules) ? modules : [];
    var moduleByName = Object.create(null);
    var parsedByName = Object.create(null);
    var replacements = Object.create(null);
    var output = [];
    var appliedRows;
    var preflightFailed = false;

    if (!validation.ok) {
      return failure(
        "E-MAP-01",
        "置き換える行の入力内容を確認してください。",
        validation.rows.filter(function (row) {
          return !row.ok;
        }).map(function (row) {
          return row.validationId;
        })[0] || null);
    }
    if (!lexer || typeof lexer.lex !== "function") {
      return failure(
        "E-MAP-02",
        "ブックを読み込み直して、もう一度やり直してください。");
    }
    moduleList.forEach(function (module) {
      var name = String(module && module.name || "");

      if (!name || moduleByName[name]) {
        preflightFailed = true;
        return;
      }
      moduleByName[name] = module;
      parsedByName[name] = lexer.lex(String(module.code || ""));
      replacements[name] = Object.create(null);
    });
    appliedRows = mapping.rows.filter(function (row) {
      return row.applied === true;
    });

    appliedRows.forEach(function (row) {
      row.occurrences.forEach(function (occurrence) {
        var parsed = parsedByName[occurrence.module];
        var token;
        var key;

        if (!parsed) {
          preflightFailed = true;
          return;
        }
        token = findStringToken(parsed, occurrence);
        if (!token || lexer.decodeStringToken(token) !== row.from) {
          preflightFailed = true;
          return;
        }
        key = String(occurrence.line) + ":" + String(occurrence.column);
        if (replacements[occurrence.module][key]) {
          preflightFailed = true;
          return;
        }
        replacements[occurrence.module][key] = {
          token: token,
          literal: escapeLiteral(row.to)
        };
      });
    });
    if (preflightFailed) {
      return failure(
        "E-MAP-02",
        "ブックを読み込み直して、もう一度やり直してください。");
    }

    moduleList.forEach(function (module) {
      var name = String(module.name || "");
      var parsed = parsedByName[name];
      var moduleReplacements = replacements[name];
      var keys = Object.keys(moduleReplacements);
      var code;

      if (keys.length === 0) {
        return;
      }
      code = parsed.lines.map(function (line) {
        return line.tokens.map(function (token) {
          var key = String(line.number) + ":" + String(token.column);
          return moduleReplacements[key]
            ? moduleReplacements[key].literal
            : token.text;
        }).join("") + line.eol;
      }).join("");
      output.push({
        name: name,
        code: code,
        lineCount: lineCount(code)
      });
    });

    return brand({
      kind: "apply",
      ok: true,
      schemaVersion: 1,
      templateKey: TEMPLATE_KEY,
      modules: output,
      mapping: {
        rows: appliedRows.map(function (row) {
          return {
            groupKey: row.groupKey,
            "class": row["class"],
            from: row.from,
            to: row.to,
            count: row.occurrences.length,
            occurrences: clone(row.occurrences)
          };
        })
      },
      logSummary: appliedRows.map(function (row) {
        var moduleCounts = Object.create(null);

        row.occurrences.forEach(function (occurrence) {
          moduleCounts[occurrence.module] =
            (moduleCounts[occurrence.module] || 0) + 1;
        });
        return {
          "class": row["class"],
          count: row.occurrences.length,
          modules: Object.keys(moduleCounts).map(function (name) {
            return {name: name, count: moduleCounts[name]};
          })
        };
      })
    });
  }

  function countOccurrences(mapping) {
    if (!isProductResult(mapping) || mapping.kind !== "mapping") {
      return 0;
    }
    return mapping.rows.reduce(function (count, row) {
      return count + row.occurrences.length;
    }, 0);
  }

  global.MacroStudioPathMap = {
    detect: detect,
    updateRow: updateRow,
    validate: validate,
    validateRow: validateRow,
    canApply: canApply,
    apply: apply,
    isProductResult: isProductResult,
    isPathish: isPathish,
    classifyAbsolute: classifyAbsolute,
    countOccurrences: countOccurrences,
    classLabels: clone(CLASS_LABELS),
    templateKey: TEMPLATE_KEY
  };
}(window));
