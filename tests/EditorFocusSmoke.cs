using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;

namespace MacroStudio.Tests
{
    // Types into every box the flow offers, in the real runtime, and
    // watches the box itself rather than the value.
    //
    // The value was never the problem: a screen rebuilt from the state
    // shows the right characters. What a rebuild destroys is the box the
    // characters were going into - the node, and with it the caret, the
    // selection and any composition in progress. So each keystroke here
    // asks one question: is the element still the same object, and is it
    // still the focused one? A run where every answer is yes is a run
    // where a person could actually have typed the sentence.
    public static class EditorFocusSmoke
    {
        public static string Run(
            string baseDir,
            string cacheDir,
            string bookPath)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                cacheDir,
                bookPath);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(240000))
            {
                throw new TimeoutException(
                    "The editor focus smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The editor focus smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string cacheDir;
            private readonly string bookPath;
            private readonly JavaScriptSerializer serializer;

            private Application application;
            private Window window;
            private WebView2 webView;
            private MessageRouter router;
            private DispatcherTimer timeoutTimer;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string cacheDir,
                string bookPath)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.bookPath = Path.GetFullPath(bookPath);
                serializer = new JavaScriptSerializer();
                Result = string.Empty;
            }

            public void Run()
            {
                try
                {
                    application = new Application();
                    application.ShutdownMode =
                        ShutdownMode.OnExplicitShutdown;

                    window = new Window();
                    window.Width = 1366;
                    window.Height = 768;
                    window.Left = -10000;
                    window.Top = -10000;
                    window.ShowInTaskbar = false;
                    window.ShowActivated = false;
                    window.WindowStyle = WindowStyle.None;
                    window.ResizeMode = ResizeMode.NoResize;

                    webView = new WebView2();
                    webView.AllowExternalDrop = false;
                    window.Content = webView;
                    window.Loaded += OnLoaded;

                    timeoutTimer = new DispatcherTimer();
                    timeoutTimer.Interval = TimeSpan.FromSeconds(230);
                    timeoutTimer.Tick += OnTimeout;
                    timeoutTimer.Start();

                    application.Run(window);
                }
                catch (Exception ex)
                {
                    Error = ex;
                    Stop();
                }
            }

            private async void OnLoaded(object sender, RoutedEventArgs e)
            {
                try
                {
                    Directory.CreateDirectory(cacheDir);
                    CoreWebView2Environment environment =
                        await CoreWebView2Environment.CreateAsync(
                            null,
                            cacheDir,
                            null);
                    await webView.EnsureCoreWebView2Async(environment);
                    webView.ZoomFactor = 1.0;
                    webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                        WebViewSecurity.TrustedHost,
                        Path.Combine(baseDir, "assets"),
                        CoreWebView2HostResourceAccessKind.Allow);

                    HostServices services = new HostServices(
                        window,
                        baseDir);
                    router = new MessageRouter(webView, services);
                    webView.CoreWebView2.WebMessageReceived +=
                        router.OnWebMessageReceived;
                    webView.CoreWebView2.NavigationCompleted +=
                        OnNavigationCompleted;
                    webView.CoreWebView2.Navigate(
                        WebViewSecurity.StartPage);
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            private async void OnNavigationCompleted(
                object sender,
                CoreWebView2NavigationCompletedEventArgs e)
            {
                webView.CoreWebView2.NavigationCompleted -=
                    OnNavigationCompleted;
                if (!e.IsSuccess)
                {
                    Fail(new InvalidOperationException(
                        "The editor focus test page navigation failed."));
                    return;
                }

                try
                {
                    Dictionary<string, object> report =
                        new Dictionary<string, object>();

                    await WaitFor(
                        "MacroStudioState.getState().appInfo !== null");
                    await Execute(ProbeScript());

                    report.Add("detailed", await RunDetailed());
                    report.Add("questions", await RunQuestions());
                    report.Add("simple", await RunSimple());

                    Result = serializer.Serialize(report);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            // ---- the detailed way: the request box and the option ----

            private async Task<string> RunDetailed()
            {
                Dictionary<string, object> phase =
                    new Dictionary<string, object>();

                await StartOver();
                await Execute(
                    "document.querySelector('[data-action=\"select-mode\"]" +
                    "[data-mode=\"refactor\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().mode === 'refactor'");
                await AttachBook();
                await ClickNext();
                await WaitForScreen("readScreen");
                await ClickNext();
                await WaitForScreen("purposeScreen");
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"select-purpose\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().presetFile !== null && " +
                    "MacroStudioState.getState().requestId !== null && " +
                    "MacroStudioState.getState().busyAction === null");
                await ClickNext();
                await WaitForScreen("requestScreen");

                // The request text lives behind a disclosure, the way a
                // person would open it before editing. A box that is
                // still folded away cannot be focused at all, so the
                // wait is for it to be on screen, not merely present.
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"toggle-disclosure\"]').click();");
                await WaitFor(
                    "document.getElementById('request-text') !== null && " +
                    "getComputedStyle(document.getElementById(" +
                    "'request-text')).visibility === 'visible'");

                phase.Add("requestText", await Probe("request-text"));

                // Keeping the box alive is only half of it: what was
                // typed still has to reach the state, and the parts of
                // the screen worked out from the state - the preview
                // line and the character count - still have to follow.
                phase.Add("derived", await ReadJson(
                    "JSON.stringify({" +
                    "stateText:MacroStudioState.getState().requestText," +
                    "boxText:document.getElementById(" +
                    "'request-text').value," +
                    "note:document.querySelector(" +
                    "'.disclosure-note').textContent," +
                    "preview:document.querySelector(" +
                    "'.headline-preview').textContent" +
                    "})"));

                phase.Add("splitOption", await ProbeToggle("split-output"));

                // ...and on to the box that names the file, which is the
                // last thing typed in a run.
                await ClickNext();
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.handoffScreen && " +
                    "MacroStudioState.getState().runFolder !== null");
                phase.Add(
                    "runFolder",
                    await ReadJson(
                        "MacroStudioState.getState().runFolder"));
                await Execute(
                    "MacroStudioState.setHandoffProgress(true, true);");
                await ClickNext();
                await WaitForScreen("intakeScreen");
                await Execute(WholeAnswer());
                await WaitFor(
                    "MacroStudioScreens.countImported(" +
                    "MacroStudioState.getState()) === 2");
                await ClickNext();
                await WaitForScreen("reviewScreen");
                await AcceptEverything();
                await ClickNext();
                await WaitForScreen("outputScreen");
                phase.Add("outputName", await Probe("output-name"));
                phase.Add("outputNameState", await ReadJson(
                    "MacroStudioState.getState().outputName"));
                return serializer.Serialize(phase);
            }

            // ---- the questions a preset asks ----

            private async Task<string> RunQuestions()
            {
                Dictionary<string, object> phase =
                    new Dictionary<string, object>();

                await StartOver();
                await Execute(
                    "document.querySelector('[data-action=\"select-mode\"]" +
                    "[data-mode=\"diagnose\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().mode === 'diagnose'");
                await AttachBook();
                await ClickNext();
                await WaitForScreen("readScreen");
                await ClickNext();
                await WaitForScreen("purposeScreen");

                // Only some presets ask anything, and which ones is the
                // preset folder's business, not this test's. So each is
                // tried in turn until one brings up the form.
                int cards = serializer.Deserialize<int>(await ReadRaw(
                    "document.querySelectorAll(" +
                    "'[data-action=\"select-purpose\"]').length"));
                int asked = 0;
                int index;

                for (index = 0; index < cards; index += 1)
                {
                    await Execute(
                        "document.querySelectorAll(" +
                        "'[data-action=\"select-purpose\"]')[" +
                        index.ToString() + "].click();");
                    await WaitFor(
                        "MacroStudioState.getState().busyAction === null " +
                        "&& MacroStudioState.getState()" +
                        ".presetFile !== null");
                    asked = serializer.Deserialize<int>(await ReadRaw(
                        "MacroStudioState.getState().questions.length"));
                    if (asked > 0)
                    {
                        break;
                    }
                }
                if (asked == 0)
                {
                    throw new InvalidOperationException(
                        "No preset on the purpose screen asks questions, " +
                        "so the answer box could not be reached.");
                }
                phase.Add("questionCount", asked);
                await ClickNext();
                await WaitForScreen("questionScreen");

                // A question with choices is answered by pressing one of
                // them; only a question without any offers a box. The
                // form is walked forward until that box appears.
                string answerId = string.Empty;

                for (index = 0; index < asked; index += 1)
                {
                    answerId = await ReadJson(
                        "(function(){var box=document.querySelector(" +
                        "'textarea[id^=\"answer-\"]');" +
                        "return box ? box.id : '';}())");
                    if (answerId.Length > 0)
                    {
                        break;
                    }
                    await Execute(
                        "document.querySelector(" +
                        "'.question-arrow--next').click();");
                    await Task.Delay(120);
                }
                if (answerId.Length == 0)
                {
                    throw new InvalidOperationException(
                        "No question offered a box to write in, so the " +
                        "free answer could not be reached.");
                }
                phase.Add("answerId", answerId);
                phase.Add("answer", await Probe(answerId));
                phase.Add("answerState", await ReadJson(
                    "MacroStudioState.getState().answers[" +
                    "String(MacroStudioState.getState().questionIndex)]"));
                return serializer.Serialize(phase);
            }

            // ---- the short way: one box, one option ----

            private async Task<string> RunSimple()
            {
                Dictionary<string, object> phase =
                    new Dictionary<string, object>();

                await StartOver();
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"start-simple\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().simple === true && " +
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.bookScreen");
                await AttachBook();
                await ClickNext();
                await WaitForScreen("requestScreen");
                await WaitFor(
                    "document.getElementById(" +
                    "'simple-request-input') !== null");
                phase.Add(
                    "requestText",
                    await Probe("simple-request-input"));
                phase.Add("requestState", await ReadJson(
                    "MacroStudioState.getState().requestText"));
                phase.Add("splitOption", await ProbeToggle("split-output"));
                return serializer.Serialize(phase);
            }

            // ---- shared steps ----

            private async Task StartOver()
            {
                await Execute("MacroStudioState.reset();");
                await Execute(
                    "window.hostBridge.request('getAppInfo').then(" +
                    "function(info){MacroStudioState.setAppInfo(info);});");
                await WaitFor(
                    "MacroStudioState.getState().appInfo !== null && " +
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.modeScreen");
            }

            private async Task AttachBook()
            {
                await ClickNext();
                await WaitForScreen("bookScreen");
                Dictionary<string, object> eventData =
                    new Dictionary<string, object>();
                eventData.Add("path", bookPath);
                router.PushEvent("bookDropped", eventData);
                await WaitFor(
                    "MacroStudioState.getState().book !== null && " +
                    "MacroStudioState.getState().busyAction === null");
            }

            private async Task AcceptEverything()
            {
                await Execute(
                    "(function(){var all=document.querySelectorAll(" +
                    "'[data-action=\"accept-package\"]');" +
                    "var index;for(index=0;index<all.length;index+=1){" +
                    "all[index].click();}}());");
                await WaitFor(
                    "!document.querySelector(" +
                    "'[data-action=\"go-next\"]').disabled");
            }

            private static string WholeAnswer()
            {
                return "(function(){" +
                    "var id = MacroStudioState.getState().requestId;" +
                    "var api = MacroStudioResponse;" +
                    "MacroStudioApp.applyResponsePackage([" +
                    "api.summaryBeginLine(id)," +
                    "'\\u7e70\\u308a\\u8fd4\\u3057\\u3092\\u76f4\\u3057" +
                    "\\u307e\\u3057\\u305f'," +
                    "api.summaryEndLine(id)," +
                    "api.beginLine(id, 'standard', 'AppController')," +
                    "'Option Explicit'," +
                    "'Public Sub Boot(): Beep: End Sub'," +
                    "api.endLine(id, 'standard', 'AppController')," +
                    "api.beginLine(id, 'standard', 'TimerUtils')," +
                    "'Option Explicit'," +
                    "'Public Sub Tick(): Beep: End Sub'," +
                    "api.endLine(id, 'standard', 'TimerUtils')," +
                    "api.completeLine(id, 2)" +
                    "].join('\\r\\n'));}());";
            }

            // ---- the probe itself ----

            // One run of everything a person does to a box: typing
            // character by character, an IME sentence, a paste, and a
            // replacement over a selection. Every step reports whether
            // the element survived it.
            private async Task<string> Probe(string id)
            {
                return await ReadJson(
                    "JSON.stringify(window.__focusProbe.run(" +
                    serializer.Serialize(id) + "))");
            }

            private async Task<string> ProbeToggle(string id)
            {
                return await ReadJson(
                    "JSON.stringify(window.__focusProbe.toggle(" +
                    serializer.Serialize(id) + "))");
            }

            private async Task ClickNext()
            {
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-next\"]').click();");
                await Task.Delay(120);
            }

            private async Task WaitForScreen(string name)
            {
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens." + name + " && " +
                    "MacroStudioState.getState().busyAction === null");
            }

            private async Task Execute(string script)
            {
                await webView.CoreWebView2.ExecuteScriptAsync(script);
            }

            private async Task<string> ReadJson(string expression)
            {
                return serializer.Deserialize<string>(
                    await ReadRaw(expression));
            }

            // What the page returned, still JSON: numbers and booleans
            // are not strings and must not be read as one.
            private async Task<string> ReadRaw(string expression)
            {
                return await webView.CoreWebView2.ExecuteScriptAsync(
                    expression);
            }

            private async Task WaitFor(string expression)
            {
                int attempt;

                for (attempt = 0; attempt < 400; attempt += 1)
                {
                    string raw =
                        await webView.CoreWebView2.ExecuteScriptAsync(
                            "(" + expression + ") === true");
                    if (raw == "true")
                    {
                        return;
                    }
                    await Task.Delay(50);
                }
                throw new TimeoutException(
                    "The page never satisfied: " + expression);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The editor focus smoke test ran out of time."));
            }

            private void Fail(Exception ex)
            {
                if (Error == null)
                {
                    Error = ex;
                }
                Stop();
            }

            private void Stop()
            {
                if (timeoutTimer != null)
                {
                    timeoutTimer.Stop();
                }
                if (application != null)
                {
                    application.Dispatcher.BeginInvoke(
                        new Action(delegate ()
                        {
                            if (window != null)
                            {
                                window.Close();
                            }
                            application.Shutdown();
                        }));
                }
            }

            // The script that does the typing. It is injected once and
            // reads only what the DOM already knows, so nothing here can
            // hide a rebuild from the report.
            private static string ProbeScript()
            {
                return @"
window.__focusProbe = (function () {
  function live(id) { return document.getElementById(id); }
  function activeName() {
    var node = document.activeElement;
    if (!node) { return ''; }
    return node.id ? node.id : node.tagName;
  }
  function caret(node) {
    if (!node) { return -1; }
    try {
      return node.selectionStart === null ||
        node.selectionStart === undefined ? -1 : node.selectionStart;
    } catch (error) { return -1; }
  }
  function snap(id, origin, label) {
    var node = live(id);
    return {
      step: label,
      survived: node === origin,
      focused: document.activeElement === origin,
      active: activeName(),
      caret: caret(node),
      value: node ? String(node.value) : null
    };
  }
  function place(node, start, end) {
    try { node.setSelectionRange(start, end); } catch (error) { }
  }
  function fire(node, name, data, inputType, composing) {
    var event;
    if (name === 'input') {
      event = new InputEvent('input', {
        bubbles: true,
        data: data,
        inputType: inputType,
        isComposing: composing === true
      });
    } else {
      event = new CompositionEvent(name, { bubbles: true, data: data });
    }
    node.dispatchEvent(event);
  }
  function typeOne(id, character, steps, label) {
    var origin = live(id);
    var start = caret(origin);
    var end = origin.selectionEnd;
    if (start < 0) { start = origin.value.length; }
    if (end === null || end === undefined) { end = start; }
    origin.value = origin.value.slice(0, start) + character +
      origin.value.slice(end);
    place(origin, start + character.length, start + character.length);
    fire(origin, 'input', character, 'insertText', false);
    steps.push(snap(id, origin, label));
  }
  return {
    run: function (id) {
      var report = { id: id, typed: [], composed: [], pasted: [],
        replaced: [], focusTaken: false, finalValue: '' };
      var node = live(id);
      var text = '\u3042\u3044\u3046abc';
      var chunks = ['\u304b', '\u304b\u3093', '\u304b\u3093\u3058'];
      var settled = '\u6f22\u5b57';
      var pasted = '\u8cbc\u4ed8';
      var base;
      var index;
      var origin;
      var start;

      if (!node) { report.missing = true; return report; }
      node.value = '';
      node.focus();
      place(node, 0, 0);
      report.focusTaken = document.activeElement === node;
      report.why = {
        active: activeName(),
        pageHasFocus: document.hasFocus(),
        disabled: node.disabled === true,
        visibility: getComputedStyle(node).visibility,
        display: getComputedStyle(node).display,
        height: node.offsetHeight,
        inDocument: document.body.contains(node)
      };

      // one character at a time, the way a sentence is written
      for (index = 0; index < text.length; index += 1) {
        typeOne(id, text.charAt(index), report.typed, 'type:' + index);
      }

      // a Japanese word: composing, then settled
      origin = live(id);
      base = origin.value;
      fire(origin, 'compositionstart', '', null, true);
      report.composed.push(snap(id, origin, 'compositionstart'));
      for (index = 0; index < chunks.length; index += 1) {
        origin = live(id);
        origin.value = base + chunks[index];
        place(origin, origin.value.length, origin.value.length);
        fire(origin, 'compositionupdate', chunks[index], null, true);
        fire(origin, 'input', chunks[index], 'insertCompositionText', true);
        report.composed.push(snap(id, origin, 'compose:' + index));
      }
      origin = live(id);
      origin.value = base + settled;
      place(origin, origin.value.length, origin.value.length);
      fire(origin, 'compositionend', settled, null, false);
      fire(origin, 'input', settled, 'insertCompositionText', false);
      report.composed.push(snap(id, origin, 'compositionend'));

      // a paste
      origin = live(id);
      start = caret(origin);
      origin.value = origin.value.slice(0, start) + pasted +
        origin.value.slice(start);
      place(origin, start + pasted.length, start + pasted.length);
      fire(origin, 'input', pasted, 'insertFromPaste', false);
      report.pasted.push(snap(id, origin, 'paste'));

      // typing over a selection replaces it
      origin = live(id);
      origin.focus();
      place(origin, 0, 3);
      report.replaced.push(snap(id, origin, 'select'));
      typeOne(id, 'X', report.replaced, 'replace');

      node = live(id);
      report.finalValue = node ? String(node.value) : null;
      return report;
    },
    toggle: function (id) {
      var node = live(id);
      var report = { id: id, steps: [] };

      if (!node) { report.missing = true; return report; }
      node.focus();
      report.focusTaken = document.activeElement === node;
      node.click();
      report.steps.push(snap(id, node, 'on'));
      node = live(id);
      node.click();
      report.steps.push(snap(id, node, 'off'));
      return report;
    }
  };
}());
";
            }
        }
    }
}
