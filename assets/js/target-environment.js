(function (global) {
  "use strict";

  var CRLF = "\r\n";
  var BANNER = new Array(81).join("=");
  var DIVIDER = new Array(81).join("-");
  var AXES = [
    "execution",
    "storage",
    "host",
    "components",
    "office",
    "platform"
  ];
  var EFFECTS = ["blocked", "changed", "uncertain"];
  var BASES = ["observed", "declared", "inferred"];
  var PROFILE_ID = /^[a-z][a-z0-9-]{2,63}$/;
  var CONSTRAINT_KEY = /^[A-Z][A-Z0-9_]{2,39}$/;

  function EnvironmentError(message, validationId) {
    this.name = "EnvironmentError";
    this.code = "E-ENV-01";
    this.validationId = validationId;
    this.message = message;
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, EnvironmentError);
    }
  }
  EnvironmentError.prototype = Object.create(Error.prototype);
  EnvironmentError.prototype.constructor = EnvironmentError;

  function fail(message, validationId) {
    throw new EnvironmentError(message, validationId || "ENV-FIELD");
  }

  function isRecord(value) {
    return value !== null &&
      typeof value === "object" &&
      !Array.isArray(value);
  }

  function requireRecord(value, path) {
    if (!isRecord(value)) {
      fail(path + " must be an object.", "ENV-FIELD");
    }
    return value;
  }

  function requireArray(value, path, allowEmpty, emptyValidationId) {
    if (!Array.isArray(value)) {
      fail(path + " must be an array.", "ENV-FIELD");
    }
    if (!allowEmpty && value.length === 0) {
      fail(
        path + " must be a non-empty array.",
        emptyValidationId || "ENV-FIELD");
    }
    return value;
  }

  function requireString(value, path) {
    if (typeof value !== "string" || value.trim() === "") {
      fail(path + " must be a non-empty string.", "ENV-FIELD");
    }
    return value;
  }

  function requireOneLine(value, path) {
    var text = requireString(value, path);

    if (/\r|\n/.test(text)) {
      fail(path + " must be one line.", "ENV-FIELD");
    }
    return text;
  }

  function requireEnum(value, allowed, path) {
    if (typeof value !== "string" || allowed.indexOf(value) < 0) {
      fail(path + " has an unknown value.", "ENV-ENUM");
    }
    return value;
  }

  function validateSource(source, index, sourceIds) {
    var path = "sources[" + index + "]";
    var id;

    requireRecord(source, path);
    id = requireString(source.id, path + ".id");
    if (sourceIds[id]) {
      fail(path + ".id is duplicated.", "ENV-SOURCEDUP");
    }
    sourceIds[id] = true;
    requireString(source.origin, path + ".origin");
    requireString(source.path, path + ".path");
    requireString(source.readAt, path + ".readAt");
  }

  function validateStringArray(
    values,
    path,
    allowEmpty,
    emptyValidationId
  ) {
    requireArray(values, path, allowEmpty, emptyValidationId);
    values.forEach(function (value, index) {
      requireString(value, path + "[" + index + "]");
    });
  }

  function validateConstraint(
    constraint,
    index,
    sourceIds,
    constraintKeys
  ) {
    var path = "constraints[" + index + "]";
    var key;

    requireRecord(constraint, path);
    key = requireString(constraint.key, path + ".key");
    if (!CONSTRAINT_KEY.test(key)) {
      fail(path + ".key has an invalid name.", "ENV-KEY");
    }
    if (constraintKeys[key]) {
      fail(path + ".key is duplicated.", "ENV-KEYDUP");
    }
    constraintKeys[key] = true;

    requireEnum(constraint.axis, AXES, path + ".axis");
    requireEnum(constraint.effect, EFFECTS, path + ".effect");
    requireOneLine(constraint.title, path + ".title");
    requireString(constraint.detail, path + ".detail");
    requireEnum(constraint.basis, BASES, path + ".basis");
    validateStringArray(
      constraint.sourceIds,
      path + ".sourceIds",
      false,
      "ENV-SOURCE");
    constraint.sourceIds.forEach(function (sourceId) {
      if (!sourceIds[sourceId]) {
        fail(
          path + ".sourceIds contains an unknown id.",
          "ENV-SOURCE");
      }
    });
    if (Object.prototype.hasOwnProperty.call(constraint, "examples")) {
      validateStringArray(constraint.examples, path + ".examples", true);
    }
  }

  function validate(profile) {
    var summary;
    var sourceIds = Object.create(null);
    var constraintKeys = Object.create(null);

    requireRecord(profile, "target environment");
    if (profile.schemaVersion !== 1) {
      fail("schemaVersion is unknown.", "ENV-SCHEMA");
    }
    if (typeof profile.profileId !== "string" ||
        !PROFILE_ID.test(profile.profileId)) {
      fail("profileId has an invalid value.", "ENV-FIELD");
    }
    requireString(profile.displayName, "displayName");
    requireString(profile.revision, "revision");
    summary = requireString(profile.summary, "summary")
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n");
    if (summary.split("\n").length > 3) {
      fail("summary must contain one to three lines.", "ENV-FIELD");
    }

    requireArray(profile.sources, "sources", false);
    profile.sources.forEach(function (source, index) {
      validateSource(source, index, sourceIds);
    });
    requireArray(profile.constraints, "constraints", false, "ENV-EMPTY");
    profile.constraints.forEach(function (constraint, index) {
      validateConstraint(
        constraint,
        index,
        sourceIds,
        constraintKeys);
    });
    return profile;
  }

  function parse(content) {
    var profile;

    if (typeof content !== "string" || content.trim() === "") {
      fail("The target environment file is empty.", "ENV-READ");
    }
    try {
      profile = JSON.parse(content);
    } catch (error) {
      fail("The target environment JSON is invalid.", "ENV-JSON");
    }
    return validate(profile);
  }

  function compareConstraints(left, right) {
    var axisDifference =
      AXES.indexOf(left.axis) - AXES.indexOf(right.axis);

    if (axisDifference !== 0) {
      return axisDifference;
    }
    if (left.key < right.key) {
      return -1;
    }
    return left.key > right.key ? 1 : 0;
  }

  function appendTextLines(lines, text, prefix) {
    text.replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .split("\n")
      .forEach(function (line) {
        lines.push(prefix + line);
      });
  }

  function renderForPrompt(profile) {
    var lines = [];
    var ordered;

    validate(profile);
    ordered = profile.constraints.slice().sort(compareConstraints);
    lines.push(BANNER);
    lines.push(
      " TARGET ENVIRONMENT: " + profile.displayName +
      " (" + profile.profileId + " / rev " + profile.revision + ")");
    lines.push(BANNER);
    appendTextLines(lines, profile.summary, "");
    lines.push("");
    ordered.forEach(function (constraint) {
      lines.push(
        "[" + constraint.key + "] " +
        constraint.axis + " / " +
        constraint.effect + " / " +
        constraint.basis);
      appendTextLines(lines, constraint.title, "  ");
      appendTextLines(lines, constraint.detail, "  ");
      if (Array.isArray(constraint.examples) &&
          constraint.examples.length > 0) {
        lines.push("  例: " + constraint.examples.join(", "));
      }
      lines.push("");
    });
    lines.push(DIVIDER);
    lines.push(
      " basis: observed=実測 / declared=前提として宣言 / " +
      "inferred=設計上の推定");
    lines.push(BANNER);
    return lines.join(CRLF);
  }

  global.MacroStudioTargetEnvironment = {
    parse: parse,
    validate: validate,
    renderForPrompt: renderForPrompt
  };
}(window));
