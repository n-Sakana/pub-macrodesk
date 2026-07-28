"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function main() {
  const sourcePath = path.join(
    __dirname,
    "..",
    "assets",
    "js",
    "host-bridge.js"
  );
  const source = fs.readFileSync(sourcePath, "utf8");
  const posted = [];
  const timers = {};
  let nextTimer = 0;
  let timeoutDelay = 0;
  let messageHandler = null;

  const context = {
    window: {
      chrome: {
        webview: {
          addEventListener: function (name, handler) {
            assert(name === "message", "Unexpected host event name.");
            messageHandler = handler;
          },
          postMessage: function (message) {
            posted.push(message);
          }
        }
      },
      console: {
        error: function () {
        }
      },
      setTimeout: function (callback, delay) {
        nextTimer += 1;
        timers[nextTimer] = callback;
        timeoutDelay = delay;
        return nextTimer;
      },
      clearTimeout: function (id) {
        delete timers[id];
      },
      Promise: Promise,
      Error: Error
    }
  };
  context.window.window = context.window;

  vm.runInNewContext(source, context, {
    filename: sourcePath
  });

  const bridge = context.window.hostBridge;
  assert(bridge, "hostBridge was not exported.");
  assert(messageHandler, "Host message handler was not registered.");

  const infoPromise = bridge.request("getAppInfo");
  assert(posted.length === 1, "getAppInfo was not posted.");
  assert(posted[0].id === 1, "First request id mismatch.");
  assert(posted[0].action === "getAppInfo", "Action mismatch.");
  assert(timeoutDelay === 120000, "Timeout is not 120 seconds.");
  messageHandler({
    data: {
      id: 1,
      status: "ok",
      data: { version: "1.0" }
    }
  });
  const info = await infoPromise;
  assert(info.version === "1.0", "Success data mismatch.");

  const buildPromise = bridge.request("buildBook", {
    outputTimestamp: "20260728_010203",
    modules: []
  });
  assert(posted[1].id === 2, "Second request id mismatch.");
  messageHandler({
    data: {
      id: 2,
      status: "error",
      code: "E-BUILD-02",
      message: "Verification failed.",
      data: {
        outputPath: "",
        results: [{ name: "Module1", result: "verify_failed" }]
      }
    }
  });

  let buildError = null;
  try {
    await buildPromise;
  } catch (error) {
    buildError = error;
  }
  assert(buildError, "Build error did not reject.");
  assert(buildError.code === "E-BUILD-02", "Build error code mismatch.");
  assert(
    buildError.data.results[0].result === "verify_failed",
    "Build error data mismatch."
  );

  let droppedPath = "";
  const unsubscribe = bridge.on("bookDropped", function (data) {
    droppedPath = data.path;
  });
  messageHandler({
    data: {
      event: "bookDropped",
      data: { path: "C:\\work\\book.xlsm" }
    }
  });
  assert(
    droppedPath === "C:\\work\\book.xlsm",
    "bookDropped data mismatch."
  );
  unsubscribe();
  droppedPath = "";
  messageHandler({
    data: {
      event: "bookDropped",
      data: { path: "C:\\work\\other.xlsm" }
    }
  });
  assert(droppedPath === "", "Event unsubscribe failed.");

  const timeoutPromise = bridge.request("attachBook", {
    path: "C:\\work\\book.xlsm"
  });
  const timeoutId = nextTimer;
  assert(typeof timers[timeoutId] === "function", "Timeout was not armed.");
  timers[timeoutId]();

  let timeoutError = null;
  try {
    await timeoutPromise;
  } catch (error) {
    timeoutError = error;
  }
  assert(timeoutError, "Timeout did not reject.");
  assert(timeoutError.code === "E-SYS-02", "Timeout code mismatch.");
  assert(timeoutError.action === "attachBook", "Timeout action mismatch.");

  process.stdout.write("test-host-bridge: PASS\n");
}

main().catch(function (error) {
  process.stderr.write(error.stack + "\n");
  process.exitCode = 1;
});
