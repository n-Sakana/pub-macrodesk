/* Browser-side WebView2 host mock for the MacroStudio screenshot rig.
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
 *
 * On top of the prototype's mock this one also RECORDS what the app hands
 * the host (request.md / source-code.md / diff HTML / result.md), so the
 * rig can save the product's own artifacts to disk, and it answers
 * buildBook late so the building screen can be photographed.
 */
(function () {
  "use strict";

  var F = window.__MS_FIXTURES__;
  var listeners = {};
  var clipboardText = "";
  var calls = [];
  var captured = {};
  var buildDelayMs = 0;

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
      ok(id, { version: "1.0.0", presets: clone(F.presets) });
      return;

    case "pickBook":
      ok(id, { path: F.book.path });
      return;

    case "attachBook":
      // Fresh copy each time: the app writes status onto these objects.
      ok(id, {
        book: clone(F.book),
        modules: clone(F.modules),
        warning: F.warning === true,
        read: clone(F.read)
      });
      return;

    case "readPreset":
      var found = null;
      (F.presets || []).forEach(function (entry) {
        if (entry.file === params.file) {
          found = entry.content;
        }
      });
      if (found === null) {
        fail(id, "E-PRESET-01", "Mock has no preset: " + params.file);
        return;
      }
      ok(id, { content: found });
      return;

    case "readRequestTemplate":
      ok(id, { content: F.requestTemplate });
      return;

    case "writeRequestFiles":
      captured.request = params.request;
      captured.code = params.code;
      captured.outputTimestamp = params.outputTimestamp;
      ok(id, {
        folderPath: F.runFolder,
        requestPath: F.runFolder + "\\request.md",
        codePath: F.runFolder + "\\source-code.md"
      });
      return;

    case "writeClipboard":
      clipboardText = String(params.text || "");
      captured.copiedPrompt = clipboardText;
      ok(id, { copied: true });
      return;

    case "readClipboard":
      ok(id, { text: clipboardText });
      return;

    case "buildBook":
      captured.build = {
        outputTimestamp: params.outputTimestamp,
        outputName: params.outputName,
        diffName: params.diffName,
        diffHtml: params.diffHtml,
        resultMarkdown: params.resultMarkdown,
        modules: (params.modules || []).map(function (m) {
          return { name: m.name, isNew: m.isNew === true,
                   codeLength: (m.code || "").length };
        })
      };
      window.setTimeout(function () {
        ok(id, {
          outputPath: F.runFolder + "\\" + params.outputName,
          diffPath: F.runFolder + "\\" + params.diffName,
          resultPath: F.runFolder + "\\result.md",
          results: (params.modules || []).map(function (m) {
            return { name: m.name, result: "written", message: "" };
          })
        });
      }, buildDelayMs);
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

  // Rig-only control surface. The app never reads this.
  window.__msMock = {
    setClipboard: function (t) {
      clipboardText = String(t);
    },
    getClipboard: function () {
      return clipboardText;
    },
    setBuildDelay: function (ms) {
      buildDelayMs = Number(ms) || 0;
    },
    captured: function () {
      return captured;
    },
    calls: function () {
      return calls.slice();
    }
  };
}());
