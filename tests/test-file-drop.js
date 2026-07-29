"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function createDragEvent(types, files, relatedTarget) {
  let prevented = false;

  return {
    dataTransfer: {
      types: types,
      files: files,
      dropEffect: ""
    },
    relatedTarget: relatedTarget || null,
    preventDefault: function () {
      prevented = true;
    },
    wasPrevented: function () {
      return prevented;
    }
  };
}

async function main() {
  const bodyClasses = {};
  const resolveCalls = [];
  const attachCalls = [];
  let resolveResult = ["C:\\work\\dropped.xlsm"];
  let resolveRejection = null;

  const windowObject = {
    MacroStudioState: {
      loadDemoState: function () {},
      getState: function () {
        return { busyAction: null, modules: [] };
      },
      hasImportedModules: function () {
        return false;
      },
      setBook: function () {},
      setBusyAction: function () {},
      setLastError: function () {}
    },
    hostBridge: {
      resolveDroppedFiles: function (files) {
        resolveCalls.push(files);
        if (resolveRejection) {
          return Promise.reject(resolveRejection);
        }
        return Promise.resolve(resolveResult);
      },
      request: function (action, params) {
        attachCalls.push({ action: action, params: params });
        if (action === "attachBook") {
          // The attach response needs the rendered document, which this
          // headless check does not build: stop at the host call.
          return new Promise(function () {});
        }
        return Promise.resolve(null);
      },
      on: function () {}
    }
  };
  const sandbox = {
    window: windowObject,
    document: {
      addEventListener: function () {},
      body: {
        classList: {
          toggle: function (name, active) {
            bodyClasses[name] = active;
          }
        }
      }
    },
    Promise: Promise
  };

  vm.createContext(sandbox);
  vm.runInContext(
    fs.readFileSync(
      path.join(__dirname, "..", "assets", "js", "app.js"),
      "utf8"),
    sandbox);

  const app = windowObject.MacroStudioApp;
  assert(app.onWindowDragOver, "Drag handlers were not exported.");

  // A file drag must be accepted, otherwise no drop event follows.
  const dragOver = createDragEvent(["Files"], null);
  app.onWindowDragOver(dragOver);
  assert(dragOver.wasPrevented(), "A file drag was not accepted.");
  assert(
    dragOver.dataTransfer.dropEffect === "copy",
    "The drop effect was not set to copy."
  );
  assert(
    bodyClasses["is-file-drag"] === true,
    "The drop target was not highlighted."
  );

  // A text drag inside the page must be left alone.
  const textDrag = createDragEvent(["text/plain"], null);
  app.onWindowDragOver(textDrag);
  assert(!textDrag.wasPrevented(), "A text drag was intercepted.");

  app.onWindowDragLeave({ relatedTarget: null });
  assert(
    bodyClasses["is-file-drag"] === false,
    "The drop highlight was not cleared."
  );

  const files = [{ name: "book.xlsm" }];
  const drop = createDragEvent(["Files"], files);
  app.onWindowDrop(drop);
  assert(drop.wasPrevented(), "The drop was not handled by the page.");
  assert(
    resolveCalls.length === 1 && resolveCalls[0] === files,
    "Dropped files were not sent to the host."
  );
  await Promise.resolve();
  await Promise.resolve();
  assert(
    attachCalls.length === 1 &&
      attachCalls[0].action === "attachBook" &&
      attachCalls[0].params.path === "C:\\work\\dropped.xlsm",
    "The resolved path was not attached."
  );

  // An empty resolve result must not start an attach.
  resolveResult = [];
  const emptyDrop = createDragEvent(["Files"], [{ name: "x.xlsm" }]);
  app.onWindowDrop(emptyDrop);
  await Promise.resolve();
  await Promise.resolve();
  assert(
    attachCalls.length === 1,
    "An empty resolve result started an attach."
  );

  // A host failure must clear the highlight and report the error.
  resolveRejection = { code: "E-SYS-02", message: "no host" };
  const failingDrop = createDragEvent(["Files"], [{ name: "x.xlsm" }]);
  app.onWindowDrop(failingDrop);
  await Promise.resolve();
  await Promise.resolve();
  assert(
    bodyClasses["is-file-drag"] === false,
    "The drop highlight survived a failed drop."
  );

  console.log("test-file-drop: PASS");
}

main().catch(function (error) {
  process.stderr.write(error.stack + "\n");
  process.exitCode = 1;
});
