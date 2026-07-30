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
  const delays = {};
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
        delays[nextTimer] = delay;
        timeoutDelay = delay;
        return nextTimer;
      },
      clearTimeout: function (id) {
        delete timers[id];
        delete delays[id];
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
      data: { path: "work\\book.xlsm" }
    }
  });
  assert(
    droppedPath === "work\\book.xlsm",
    "bookDropped data mismatch."
  );
  unsubscribe();
  droppedPath = "";
  messageHandler({
    data: {
      event: "bookDropped",
      data: { path: "work\\other.xlsm" }
    }
  });
  assert(droppedPath === "", "Event unsubscribe failed.");

  const timeoutPromise = bridge.request("attachBook", {
    path: "work\\book.xlsm"
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

  // Audit P2-3. Rebuilding a large workbook can take longer than the
  // client is willing to wait, and the host keeps working past that
  // point. Such a request is sent without a reject timer: the wait is
  // reported, nothing is decided by the clock, and the answer that
  // arrives late still resolves against the same request id.
  const slowCalls = [];
  const longPromise = bridge.request(
    "buildBook",
    { outputTimestamp: "20260730_010203", modules: [] },
    {
      timeoutMilliseconds: 0,
      onSlow: function (action) {
        slowCalls.push(action);
      }
    }
  );
  const longId = posted[posted.length - 1].id;
  const armed = Object.keys(timers).map(function (key) {
    return delays[key];
  });

  assert(
    armed.indexOf(120000) >= 0,
    "The slow notice must still be armed at the client wait.");
  assert(
    armed.every(function (delay) {
      return delay === 120000;
    }),
    "A long running request must arm no other timer than the notice.");

  const slowTimerId = Object.keys(timers).filter(function (key) {
    return delays[key] === 120000;
  })[0];
  timers[slowTimerId]();
  assert(
    slowCalls.length === 1 && slowCalls[0] === "buildBook",
    "The slow notice must fire once, naming the action.");

  let settled = false;
  longPromise.then(
    function () {
      settled = true;
    },
    function () {
      settled = true;
    });
  await Promise.resolve();
  assert(
    !settled,
    "Passing the client wait must not settle a long running request.");

  messageHandler({
    data: {
      id: longId,
      status: "ok",
      data: { outputPath: "work\\out.xlsm", results: [] }
    }
  });
  const longResult = await longPromise;
  assert(
    longResult.outputPath === "work\\out.xlsm",
    "The late answer must resolve the request that is still waiting.");

  process.stdout.write("test-host-bridge: PASS\n");
}

main().catch(function (error) {
  process.stderr.write(error.stack + "\n");
  process.exitCode = 1;
});
