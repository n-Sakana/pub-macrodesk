/* Browser-side WebView2 host mock for Macro Studio.
 *
 * Injected before any page script, because assets/js/host-bridge.js grabs
 * window.chrome.webview at load time.
 *
 * Implements the contract src/03_MessageRouter.cs speaks:
 *   page -> host : chrome.webview.postMessage({id, action, params})
 *   host -> page : {id, status:"ok", data} | {id, status:"error", ...}
 *                | {event:"<name>", data}
 *
 * Deliberately not clever: an unknown action returns an error, exactly as
 * the real host would, so an unreachable screen fails visibly instead of
 * being faked. Fixture data is fictional - no real paths, names or orgs.
 */
(function () {
  "use strict";

  var F = window.__MS_FIXTURES__;
  var listeners = {};
  var clipboardText = "";
  var calls = [];

  function emit(payload) {
    (listeners.message || []).slice().forEach(function (h) {
      h({ data: payload });
    });
  }

  function clone(v) {
    return JSON.parse(JSON.stringify(v));
  }

  function ok(id, data) {
    emit({ id: id, status: "ok", data: data === undefined ? null : data });
  }

  function fail(id, code, message) {
    emit({ id: id, status: "error", code: code, message: message, data: null });
  }

  function handle(message) {
    var id = message.id;
    var action = message.action;
    var params = message.params || {};

    calls.push(action);

    switch (action) {
    case "getAppInfo":
      ok(id, {
        version: "1.0",
        presets: clone(F.presets),
        buildFileLabel: F.buildFileLabel
      });
      return;

    case "pickBook":
      ok(id, { path: F.book.path });
      return;

    case "attachBook":
      // Fresh copy each time: the app writes status onto these objects.
      ok(id, { book: clone(F.book), modules: clone(F.modules) });
      return;

    case "readPreset":
      ok(id, { content: F.presetContent[params.file] || "" });
      return;

    case "readRequestTemplate":
      ok(id, { content: F.requestTemplate });
      return;

    case "writeRequestFiles":
      ok(id, {
        folderPath: F.runFolder,
        requestPath: F.runFolder + "\\request.md",
        codePath: F.runFolder + "\\source-code.md"
      });
      return;

    case "writeClipboard":
      clipboardText = String(params.text || "");
      ok(id, null);
      return;

    case "readClipboard":
      ok(id, { text: clipboardText });
      return;

    case "buildBook":
      ok(id, {
        outputPath: F.runFolder + "\\" + (params.outputName || F.outputName),
        diffPath: F.runFolder + "\\diff-report.html",
        diffError: "",
        results: (params.modules || []).map(function (m) {
          return { name: m.name, result: "written", message: "" };
        })
      });
      return;

    case "revealPath":
      ok(id, null);
      return;

    case "writeLog":
      ok(id, null);
      return;

    default:
      fail(id, "E-SYS-02", "Mock host has no action: " + action);
      return;
    }
  }

  window.chrome = window.chrome || {};
  window.chrome.webview = {
    addEventListener: function (name, handler) {
      if (!listeners[name]) {
        listeners[name] = [];
      }
      listeners[name].push(handler);
    },
    removeEventListener: function (name, handler) {
      var hs = listeners[name];
      if (!hs) {
        return;
      }
      var i = hs.indexOf(handler);
      if (i >= 0) {
        hs.splice(i, 1);
      }
    },
    postMessage: function (message) {
      // The real host answers asynchronously; keep that shape so busy
      // states are exercised rather than skipped.
      window.setTimeout(function () {
        handle(message);
      }, 0);
    }
  };

  // Harness-only control surface. The app never reads this.
  window.__msMock = {
    setClipboard: function (t) {
      clipboardText = String(t);
    },
    getClipboard: function () {
      return clipboardText;
    },
    calls: function () {
      return calls.slice();
    }
  };
}());
