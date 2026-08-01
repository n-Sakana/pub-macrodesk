"use strict";

var fs = require("fs");
var path = require("path");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function listFiles(directory) {
  var result = [];

  fs.readdirSync(directory, { withFileTypes: true }).forEach(function (entry) {
    var fullPath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      result = result.concat(listFiles(fullPath));
    } else if (entry.isFile()) {
      result.push(fullPath);
    }
  });
  return result;
}

function findLiteral(files, value) {
  return files.filter(function (file) {
    return fs.readFileSync(file, "utf8").indexOf(value) >= 0;
  });
}

var root = path.resolve(__dirname, "..");
var profile = JSON.parse(fs.readFileSync(
  path.join(root, "environment", "target-environment.json"),
  "utf8"));
var implementationFiles = listFiles(path.join(root, "src"))
  .filter(function (file) {
    return path.extname(file).toLowerCase() === ".cs";
  })
  .concat(listFiles(path.join(root, "assets", "js")).filter(function (file) {
    return path.extname(file).toLowerCase() === ".js";
  }));
var proseFiles = listFiles(path.join(root, "src"))
  .concat(listFiles(path.join(root, "assets")))
  .concat(listFiles(path.join(root, "templates")));

profile.constraints.forEach(function (constraint) {
  var embeddedKey = findLiteral(implementationFiles, constraint.key);
  var embeddedTitle = findLiteral(proseFiles, constraint.title);
  var embeddedDetail = findLiteral(proseFiles, constraint.detail);

  assert(
    embeddedKey.length === 0,
    "Environment key is embedded in product code: " +
      constraint.key + " in " + embeddedKey.join(", "));
  assert(
    embeddedTitle.length === 0,
    "Environment title is duplicated outside its data file: " +
      embeddedTitle.join(", "));
  assert(
    embeddedDetail.length === 0,
    "Environment detail is duplicated outside its data file: " +
      embeddedDetail.join(", "));
});

console.log("test-environment-not-embedded: PASS");
console.log("all environment keys and prose remain data-only");
