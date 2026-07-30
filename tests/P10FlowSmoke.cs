using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;

namespace MacroStudio.Tests
{
    // Walks the ten screens against the real host: one workbook in,
    // one run folder out.
    public static class P10FlowSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir,
            string lightScreenshot,
            string darkScreenshot)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                bookPath,
                cacheDir,
                lightScreenshot,
                darkScreenshot);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(120000))
            {
                throw new TimeoutException(
                    "The flow smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The flow smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string bookPath;
            private readonly string cacheDir;
            private readonly string lightScreenshot;
            private readonly string darkScreenshot;

            private Application application;
            private Window window;
            private WebView2 webView;
            private MessageRouter router;
            private DispatcherTimer timeoutTimer;
            private JavaScriptSerializer serializer;
            private IDataObject originalClipboard;
            private bool clipboardCaptured;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string bookPath,
                string cacheDir,
                string lightScreenshot,
                string darkScreenshot)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.bookPath = Path.GetFullPath(bookPath);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.lightScreenshot = Path.GetFullPath(lightScreenshot);
                this.darkScreenshot = Path.GetFullPath(darkScreenshot);
                serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = int.MaxValue;
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
                    timeoutTimer.Interval = TimeSpan.FromSeconds(100);
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

            private async void OnLoaded(
                object sender,
                RoutedEventArgs e)
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
                        "macrostudio.local",
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
                        "https://macrostudio.local/index.html");
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
                        "The flow test page navigation failed."));
                    return;
                }

                try
                {
                    Dictionary<string, object> result =
                        new Dictionary<string, object>();

                    await WaitFor(
                        "MacroStudioState.getState().appInfo !== null");
                    result.Add("start", await ReadShell());

                    // The work is the first decision, before any workbook.
                    // The whole screen's text is read as well: nothing on
                    // it may point at a workbook that has not been read.
                    result.Add("mode", await ReadJson(
                        "({" +
                        "screen:MacroStudioState.getState().screen," +
                        "title:document.querySelector(" +
                        "'.screen-title').textContent," +
                        "text:document.querySelector('#main-content')" +
                        ".textContent," +
                        "cards:Array.prototype.map.call(" +
                        "document.querySelectorAll('.choice-title')," +
                        "function(node){return node.textContent;})," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled," +
                        "backDisabled:document.querySelector(" +
                        "'[data-action=\"go-back\"]').disabled" +
                        "})"));
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"select-mode\"]" +
                        "[data-mode=\"refactor\"]').click();");
                    await WaitFor(
                        "MacroStudioState.getState().mode === 'refactor'");
                    result.Add("modeChosen", await ReadJson(
                        "({" +
                        "stillHere:MacroStudioState.getState().screen," +
                        "steps:document.querySelectorAll(" +
                        "'.progress-step').length," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));

                    await Next();
                    await WaitForScreen(1);
                    result.Add("dropScreen", await ReadJson(
                        "({" +
                        "screen:MacroStudioState.getState().screen," +
                        "title:document.querySelector(" +
                        "'.screen-title').textContent," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled," +
                        "backDisabled:document.querySelector(" +
                        "'[data-action=\"go-back\"]').disabled" +
                        "})"));

                    Dictionary<string, object> eventData =
                        new Dictionary<string, object>();
                    eventData.Add("path", bookPath);
                    router.PushEvent("bookDropped", eventData);
                    await WaitFor(
                        "MacroStudioState.getState().book !== null && " +
                        "MacroStudioState.getState().busyAction === null");
                    result.Add("attached", await ReadJson(
                        "({" +
                        "screen:MacroStudioState.getState().screen," +
                        "mode:MacroStudioState.getState().mode," +
                        "modules:MacroStudioState.getState()" +
                        ".modules.length," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled," +
                        "backDisabled:document.querySelector(" +
                        "'[data-action=\"go-back\"]').disabled" +
                        "})"));

                    await Next();
                    await WaitForScreen(2);
                    result.Add("book", await ReadJson(
                        "({" +
                        "screen:MacroStudioState.getState().screen," +
                        "stats:Array.prototype.map.call(" +
                        "document.querySelectorAll('.stat-value')," +
                        "function(node){return node.textContent;})," +
                        "chips:document.querySelectorAll(" +
                        "'.module-chip').length" +
                        "})"));

                    // Back from the read result returns to the workbook,
                    // and from there to the work choice.
                    await Back();
                    await WaitForScreen(1);
                    await Back();
                    await WaitForScreen(0);
                    result.Add("backToStart", await ReadJson(
                        "({" +
                        "screen:MacroStudioState.getState().screen," +
                        "mode:MacroStudioState.getState().mode," +
                        "book:MacroStudioState.getState().book !== null" +
                        "})"));

                    // The other route's purpose screen is rendered by the
                    // same card builder, so its declared lines are read
                    // here before the run goes on as a refactoring.
                    await Execute(
                        "document.querySelector('[data-action=\"select-mode\"]" +
                        "[data-mode=\"diagnose\"]').click();");
                    await WaitFor(
                        "MacroStudioState.getState().mode === 'diagnose'");
                    await Next();
                    await WaitForScreen(1);
                    await Next();
                    await WaitForScreen(2);
                    await Next();
                    await WaitForScreen(3);
                    result.Add("diagnosePurpose", await ReadJson(
                        "({" +
                        "cards:document.querySelectorAll(" +
                        "'[data-action=\"select-purpose\"]').length," +
                        "descriptions:Array.prototype.map.call(" +
                        "document.querySelectorAll('.choice-description')," +
                        "function(node){return node.textContent;})" +
                        "})"));
                    await Back();
                    await WaitForScreen(2);
                    await Back();
                    await WaitForScreen(1);
                    await Back();
                    await WaitForScreen(0);
                    await Execute(
                        "document.querySelector('[data-action=\"select-mode\"]" +
                        "[data-mode=\"refactor\"]').click();");
                    await WaitFor(
                        "MacroStudioState.getState().mode === 'refactor'");

                    await Next();
                    await WaitForScreen(1);
                    await Next();
                    await WaitForScreen(2);

                    await Next();
                    await WaitForScreen(3);
                    // The line under each name is read as rendered, to be
                    // compared with the description section of the preset
                    // file it came from.
                    result.Add("purpose", await ReadJson(
                        "({" +
                        "cards:document.querySelectorAll(" +
                        "'[data-action=\"select-purpose\"]').length," +
                        "descriptions:Array.prototype.map.call(" +
                        "document.querySelectorAll('.choice-description')," +
                        "function(node){return node.textContent;})," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"select-purpose\"]').click();");
                    await WaitFor(
                        "MacroStudioState.getState().presetFile !== null " +
                        "&& MacroStudioState.getState().requestId !== null " +
                        "&& MacroStudioState.getState()" +
                        ".busyAction === null");
                    result.Add("purposeChosen", await ReadJson(
                        "({" +
                        "stillHere:MacroStudioState.getState().screen," +
                        "selected:document.querySelectorAll(" +
                        "'.choice-card.is-selected').length," +
                        "requestChars:MacroStudioState.getState()" +
                        ".requestText.length," +
                        "outputRules:MacroStudioState.getState()" +
                        ".outputRules !== null," +
                        "placeholderLeft:MacroStudioState.getState()" +
                        ".outputRules.body.indexOf('{{') >= 0," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));

                    string requestId =
                        serializer.Deserialize<string>(
                            await ReadJson(
                                "MacroStudioState.getState().requestId"));
                    result.Add("requestId", requestId);

                    await Next();
                    await WaitForScreen(5);
                    // The request text is disclosed, not forced on screen.
                    result.Add("request", await ReadJson(
                        "({" +
                        "closed:document.querySelector(" +
                        "'[data-disclosure-box=\"request-editor\"]')" +
                        ".getAttribute('data-open')," +
                        "trigger:document.querySelector(" +
                        "'.disclosure-trigger').textContent," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"toggle-disclosure\"]').click();");
                    await WaitFor(
                        "document.querySelector(" +
                        "'[data-disclosure-box=\"request-editor\"]')" +
                        ".getAttribute('data-open') === 'true'");
                    result.Add("requestOpen", await ReadJson(
                        "({" +
                        "editor:document.getElementById(" +
                        "'request-text') !== null," +
                        "chars:document.getElementById(" +
                        "'request-text').value.length" +
                        "})"));

                    await Next();
                    await WaitFor(
                        "MacroStudioState.getState().screen === 6 && " +
                        "MacroStudioState.getState().runFolder !== null");
                    await Capture(lightScreenshot);
                    string runFolder =
                        serializer.Deserialize<string>(
                            await ReadJson(
                                "MacroStudioState.getState().runFolder"));
                    result.Add("runFolder", runFolder);
                    result.Add("handoff", await ReadJson(
                        "({" +
                        "cards:document.querySelectorAll(" +
                        "'.handoff-card').length," +
                        "chips:Array.prototype.map.call(" +
                        "document.querySelectorAll('.artifact-chip')," +
                        "function(node){return node.textContent;})," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));

                    CaptureClipboard();
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"copy-request-prompt\"]')" +
                        ".click();");
                    await WaitFor(
                        "MacroStudioState.getState().promptCopied === true");
                    string clipboardPrompt = Clipboard.GetText();
                    await Execute(
                        "MacroStudioState.setHandoffProgress(null,true);");
                    await WaitFor(
                        "MacroStudioState.getState()" +
                        ".codeFolderOpened === true");
                    result.Add("handoffReady", await ReadJson(
                        "({" +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled," +
                        "copyDone:document.querySelectorAll(" +
                        "'.handoff-card.is-done').length" +
                        "})"));
                    result.Add(
                        "clipboardIsPrompt",
                        clipboardPrompt ==
                            serializer.Deserialize<string>(
                                await ReadJson(
                                    "MacroStudioState.getState()" +
                                    ".requestPrompt")));
                    result.Add(
                        "promptCarriesRequestId",
                        clipboardPrompt != null &&
                            clipboardPrompt.IndexOf(
                                "'@MACROSTUDIO " + requestId,
                                StringComparison.Ordinal) >= 0);

                    // ---- one press takes the whole answer in --------
                    await Next();
                    await WaitForScreen(7);
                    result.Add("intakeScreen", await ReadJson(
                        "({" +
                        "actions:Array.prototype.map.call(" +
                        "document.querySelectorAll('main [data-action]')," +
                        "function(node){" +
                        "return node.getAttribute('data-action');})," +
                        "moduleLists:document.querySelectorAll(" +
                        "'.module-pane,.module-list').length," +
                        "textareas:document.querySelectorAll(" +
                        "'main textarea').length" +
                        "})"));

                    string firstModule =
                        serializer.Deserialize<string>(
                            await ReadJson(
                                "MacroStudioState.getState()" +
                                ".modules[0].name"));
                    string firstKind =
                        serializer.Deserialize<string>(
                            await ReadJson(
                                "MacroStudioState.getState()" +
                                ".modules[0].type"));

                    // A foreign answer must not be applied, and must not
                    // say anything the user cannot act on.
                    SetClipboard(
                        "Option Explicit\r\n" +
                        "Public Sub Stray()\r\nEnd Sub\r\n");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"import-response\"]').click();");
                    await WaitFor(
                        "MacroStudioState.getState().lastError !== null && " +
                        "MacroStudioState.getState().busyAction === null");
                    result.Add("refused", await ReadJson(
                        "({" +
                        "imported:MacroStudioScreens.countImported(" +
                        "MacroStudioState.getState())," +
                        "message:MacroStudioState.getState()" +
                        ".lastError.message," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));

                    SetClipboard(
                        "```vb\r\n" +
                        "'@MACROSTUDIO " + requestId + " SUMMARY BEGIN\r\n" +
                        "FlowSmoke: entry point rewritten.\r\n" +
                        "FlowSmokeHelpers: new helper module.\r\n" +
                        "'@MACROSTUDIO " + requestId + " SUMMARY END\r\n" +
                        "'@MACROSTUDIO " + requestId + " BEGIN " +
                        firstKind + " " + firstModule + "\r\n" +
                        "Option Explicit\r\n" +
                        "Public Sub FlowSmoke()\r\n" +
                        "    Debug.Print \"flow\"\r\n" +
                        "End Sub\r\n" +
                        "'@MACROSTUDIO " + requestId + " END " +
                        firstKind + " " + firstModule + "\r\n" +
                        "'@MACROSTUDIO " + requestId +
                        " BEGIN standard FlowSmokeHelpers\r\n" +
                        "Option Explicit\r\n" +
                        "Public Function FlowSmokeTag() As String\r\n" +
                        "    FlowSmokeTag = \"macrostudio\"\r\n" +
                        "End Function\r\n" +
                        "'@MACROSTUDIO " + requestId +
                        " END standard FlowSmokeHelpers\r\n" +
                        "'@MACROSTUDIO " + requestId + " COMPLETE 2\r\n" +
                        "```\r\n");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"import-response\"]').click();");
                    await WaitFor(
                        "MacroStudioState.getState().intakeResult !== null " +
                        "&& MacroStudioState.getState()" +
                        ".busyAction === null");
                    result.Add("intake", await ReadJson(
                        "({" +
                        "module:MacroStudioState.getState()" +
                        ".modules[0].name," +
                        "result:MacroStudioState.getState().intakeResult," +
                        "imported:MacroStudioScreens.countImported(" +
                        "MacroStudioState.getState())," +
                        "added:MacroStudioState.getState().modules.filter(" +
                        "function(m){return m.isNew === true;}).length," +
                        "summary:MacroStudioState.getState()" +
                        ".intakeResult.summary," +
                        "summaryClosed:document.querySelector(" +
                        "'[data-disclosure-box=\"intake-summary\"]')" +
                        ".getAttribute('data-open')," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));

                    // ---- the review screen shows a summary first ----
                    await Next();
                    await WaitForScreen(8);
                    result.Add("review", await ReadJson(
                        "({" +
                        "headline:document.querySelector(" +
                        "'.headline-text').textContent," +
                        "closed:document.querySelector(" +
                        "'[data-disclosure-box=\"change-detail\"]')" +
                        ".getAttribute('data-open')," +
                        "trigger:document.querySelector(" +
                        "'.disclosure-trigger').textContent," +
                        "decide:document.querySelectorAll(" +
                        "'[data-action=\"accept-package\"]," +
                        "[data-action=\"reject-package\"]').length," +
                        "accepted:MacroStudioScreens.countAccepted(" +
                        "MacroStudioState.getState())," +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled" +
                        "})"));

                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"toggle-disclosure\"]').click();");
                    await WaitFor(
                        "document.querySelector(" +
                        "'[data-disclosure-box=\"change-detail\"]')" +
                        ".getAttribute('data-open') === 'true'");
                    result.Add("diff", await ReadJson(
                        "({" +
                        "tree:document.querySelectorAll(" +
                        "'.module-pane [data-action=\"select-module\"]')" +
                        ".length," +
                        "groups:document.querySelectorAll(" +
                        "'.module-group-title').length," +
                        "columns:document.querySelectorAll(" +
                        "'.diff-table colgroup col').length," +
                        "markers:document.querySelectorAll(" +
                        "'.diff-marker').length," +
                        "removed:document.querySelectorAll(" +
                        "'.diff-row--removed').length," +
                        "added:document.querySelectorAll(" +
                        "'.diff-row--added').length," +
                        "twoColumn:document.querySelectorAll(" +
                        "'.diff-code--left,.diff-code--right').length," +
                        "toolbar:document.querySelectorAll(" +
                        "'.diff-toolbar [data-action]').length," +
                        "scrollsInside:(function(){" +
                        "var s=document.querySelector(" +
                        "'.diff-table-scroller');" +
                        "return s !== null && " +
                        "getComputedStyle(s).overflowY === 'auto';}())" +
                        "})"));

                    await Capture(darkScreenshot, true);
                    result.Add("accepted", await ReadJson(
                        "({" +
                        "nextReady:!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled," +
                        "accepted:MacroStudioState" +
                        ".getAcceptedModuleCount()" +
                        "})"));

                    await Next();
                    await WaitForScreen(9);
                    result.Add("summary", await ReadJson(
                        "({" +
                        "values:Array.prototype.map.call(" +
                        "document.querySelectorAll('.stat-value')," +
                        "function(node){return node.textContent;})," +
                        "files:Array.prototype.map.call(" +
                        "document.querySelectorAll('.artifact-chip')," +
                        "function(node){return node.textContent;})" +
                        "})"));
                    string outputName =
                        serializer.Deserialize<string>(
                            await ReadJson(
                                "document.getElementById(" +
                                "'output-name').value"));
                    await Execute(
                        "(function(){var f=document.getElementById(" +
                        "'output-name');f.value='broken.txt';" +
                        "f.dispatchEvent(new Event('input'," +
                        "{bubbles:true}));}());");
                    await WaitFor(
                        "document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled");
                    await Execute(
                        "(function(){var f=document.getElementById(" +
                        "'output-name');f.value=" +
                        serializer.Serialize(outputName) + ";" +
                        "f.dispatchEvent(new Event('input'," +
                        "{bubbles:true}));}());");
                    await WaitFor(
                        "!document.querySelector(" +
                        "'[data-action=\"go-next\"]').disabled");
                    result.Add("output", outputName);

                    await Next();
                    await WaitFor(
                        "MacroStudioState.getState().screen === 11 && " +
                        "MacroStudioState.getState().busyAction === null");
                    result.Add("done", await ReadJson(
                        "({" +
                        "outputPath:MacroStudioState.getState()" +
                        ".buildResult.outputPath," +
                        "diffPath:MacroStudioState.getState()" +
                        ".buildResult.diffPath," +
                        "resultPath:MacroStudioState.getState()" +
                        ".buildResult.resultPath," +
                        "rows:Array.prototype.map.call(" +
                        "document.querySelectorAll('.result-row code')," +
                        "function(node){return node.textContent;})," +
                        "openButtons:document.querySelectorAll(" +
                        "'[data-action=\"open-run-folder\"]').length," +
                        "copyButtons:document.querySelectorAll(" +
                        "'[data-action=\"copy-text\"]').length" +
                        "})"));
                    result.Add("finalShell", await ReadShell());
                    result.Add("finish", await ReadJson(
                        "({" +
                        "label:document.querySelector(" +
                        "'#footer-actions [data-action=\"finish\"]')" +
                        ".textContent," +
                        "nextButtons:document.querySelectorAll(" +
                        "'#footer-actions [data-action=\"go-next\"]')" +
                        ".length" +
                        "})"));

                    // The report the build wrote must open on its own.
                    string diffPath =
                        serializer.Deserialize<string>(
                            await ReadJson(
                                "MacroStudioState.getState()" +
                                ".buildResult.diffPath"));
                    await NavigateTo(diffPath);
                    // The report renders itself with the app's own diff
                    // code, so the rows appear only if that bundle ran.
                    await WaitFor(
                        "document.readyState === 'complete' && " +
                        "document.querySelectorAll(" +
                        "'.diff-row').length > 0");
                    result.Add("report", await ReadJson(
                        "({" +
                        "modules:document.querySelectorAll(" +
                        "'.module-item').length," +
                        "markers:document.querySelectorAll(" +
                        "'.diff-marker').length," +
                        "toolbar:document.querySelectorAll(" +
                        "'.diff-toolbar .button').length," +
                        "theme:document.documentElement.getAttribute(" +
                        "'data-theme')," +
                        "editable:document.querySelectorAll(" +
                        "'textarea,input,[contenteditable]').length," +
                        "external:document.querySelectorAll(" +
                        "'link[href],script[src],img[src]').length," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})"));

                    Result = serializer.Serialize(result);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            // Every screen keeps the footer visible and the page free
            // of scrollbars.
            private async Task<string> ReadShell()
            {
                return await ReadJson(
                    "(function(){" +
                    "var nav=document.querySelector('.nav-actions');" +
                    "var box=nav.getBoundingClientRect();" +
                    "return {" +
                    "documentScrollY:document.documentElement" +
                    ".scrollHeight>innerHeight," +
                    "documentScrollX:document.documentElement" +
                    ".scrollWidth>innerWidth," +
                    "footerVisible:box.bottom<=innerHeight+1&&" +
                    "box.top>=0," +
                    "buttons:nav.querySelectorAll('.button').length," +
                    "sameWidth:Math.abs(" +
                    "nav.children[0].getBoundingClientRect().width-" +
                    "nav.children[1].getBoundingClientRect().width)<1," +
                    "progress:document.querySelectorAll(" +
                    "'.progress-step').length," +
                    "progressSlots:document.querySelectorAll(" +
                    "'#progress-list > li').length" +
                    "};}())");
            }

            private async Task NavigateTo(string path)
            {
                TaskCompletionSource<bool> ready =
                    new TaskCompletionSource<bool>();
                EventHandler<CoreWebView2NavigationCompletedEventArgs>
                    handler = null;

                handler = delegate(
                    object sender,
                    CoreWebView2NavigationCompletedEventArgs args)
                {
                    webView.CoreWebView2.NavigationCompleted -= handler;
                    ready.TrySetResult(args.IsSuccess);
                };
                webView.CoreWebView2.NavigationCompleted += handler;
                webView.CoreWebView2.Navigate(
                    new Uri(path).AbsoluteUri);
                if (!await ready.Task)
                {
                    throw new InvalidOperationException(
                        "The report navigation failed: " + path);
                }
            }

            private async Task Next()
            {
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-next\"]').click();");
            }

            private async Task Back()
            {
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-back\"]').click();");
            }

            private async Task WaitForScreen(int index)
            {
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    index.ToString() + " && " +
                    "MacroStudioState.getState().busyAction === null");
            }

            private void CaptureClipboard()
            {
                if (clipboardCaptured)
                {
                    return;
                }
                try
                {
                    originalClipboard = Clipboard.GetDataObject();
                }
                catch
                {
                    originalClipboard = null;
                }
                clipboardCaptured = true;
            }

            private void SetClipboard(string text)
            {
                CaptureClipboard();
                Clipboard.SetText(text);
            }

            private void RestoreClipboard()
            {
                if (!clipboardCaptured)
                {
                    return;
                }
                try
                {
                    if (originalClipboard != null)
                    {
                        Clipboard.SetDataObject(originalClipboard, true);
                    }
                    else
                    {
                        Clipboard.Clear();
                    }
                }
                catch
                {
                }
                clipboardCaptured = false;
            }

            private async Task Capture(string path, bool dark)
            {
                if (dark)
                {
                    await Execute(
                        "document.getElementById('theme-toggle')" +
                        ".click();");
                    await Task.Delay(150);
                }
                using (FileStream stream = new FileStream(
                    path,
                    FileMode.Create,
                    FileAccess.Write,
                    FileShare.None))
                {
                    await webView.CoreWebView2.CapturePreviewAsync(
                        CoreWebView2CapturePreviewImageFormat.Png,
                        stream);
                }
                if (dark)
                {
                    await Execute(
                        "document.getElementById('theme-toggle')" +
                        ".click();");
                    await Task.Delay(150);
                }
            }

            private async Task Capture(string path)
            {
                await Capture(path, false);
            }

            private async Task Execute(string script)
            {
                await webView.CoreWebView2.ExecuteScriptAsync(script);
            }

            private async Task<string> ReadJson(string expression)
            {
                string raw =
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "JSON.stringify(" + expression + ")");
                return serializer.Deserialize<string>(raw);
            }

            private async Task WaitFor(string expression)
            {
                int attempt;
                for (attempt = 0; attempt < 400; attempt++)
                {
                    string raw =
                        await webView.CoreWebView2.ExecuteScriptAsync(
                            "Boolean(" + expression + ")");
                    if (raw == "true")
                    {
                        return;
                    }
                    await Task.Delay(50);
                }
                throw new TimeoutException(
                    "The flow condition timed out: " + expression);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The flow smoke test timed out."));
            }

            private void Fail(Exception error)
            {
                Error = error;
                Stop();
            }

            private void Stop()
            {
                RestoreClipboard();
                try
                {
                    if (timeoutTimer != null)
                    {
                        timeoutTimer.Stop();
                        timeoutTimer.Tick -= OnTimeout;
                        timeoutTimer = null;
                    }
                    if (webView != null)
                    {
                        if (webView.CoreWebView2 != null &&
                            router != null)
                        {
                            webView.CoreWebView2.WebMessageReceived -=
                                router.OnWebMessageReceived;
                        }
                        if (window != null)
                        {
                            window.Content = null;
                        }
                        webView.Dispose();
                        webView = null;
                        router = null;
                    }
                    if (window != null)
                    {
                        window.Close();
                        window = null;
                    }
                    if (application != null)
                    {
                        application.Shutdown();
                        application = null;
                    }
                }
                catch
                {
                }
            }
        }
    }
}
