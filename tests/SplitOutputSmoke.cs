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
    // Drives the module-by-module option through the real WebView2
    // runtime: the checkbox on the request screen, the rules that reach
    // the written request, taking the parts in one by one, and the way
    // back to another answer on the intake screen.
    //
    // The clipboard is not used anywhere here. The hand-off screen needs
    // a copy and an explorer window to release its [next], which is what
    // tests\test-flow-webview.ps1 covers; this run marks that step done
    // through the state so the intake screen can be reached without
    // touching the clipboard.
    public static class SplitOutputSmoke
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

            if (!thread.Join(60000))
            {
                throw new TimeoutException(
                    "The split output smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The split output smoke test failed.",
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
                    timeoutTimer.Interval = TimeSpan.FromSeconds(50);
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
                        "The split output test page navigation failed."));
                    return;
                }

                try
                {
                    Dictionary<string, object> report =
                        new Dictionary<string, object>();

                    await OpenRequestScreen(report);
                    await TurnTheOptionOn(report);
                    await PrepareTheRequest(report);
                    await TakeThePartsIn(report);
                    await TakeAWholeAnswerInstead(report);

                    Result = serializer.Serialize(report);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            // Read the workbook, choose refactoring, and press the first
            // preset that carries the module-by-module rules.
            private async Task OpenRequestScreen(
                Dictionary<string, object> report)
            {
                await WaitFor(
                    "MacroStudioState.getState().appInfo !== null");
                Dictionary<string, object> eventData =
                    new Dictionary<string, object>();
                eventData.Add("path", bookPath);
                router.PushEvent("bookDropped", eventData);
                await WaitFor(
                    "MacroStudioState.getState().book !== null && " +
                    "MacroStudioState.getState().busyAction === null");
                await ClickNext(1);
                await ClickNext(2);
                await Execute(
                    "document.querySelector('[data-action=\"select-mode\"]" +
                    "[data-mode=\"refactor\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().mode === 'refactor'");
                await ClickNext(3);

                string presetFile = await ReadJson(
                    "(function(){" +
                    "var entries = MacroStudioPreset.describeAll(" +
                    "MacroStudioState.getState().appInfo.presets);" +
                    "var found = '';" +
                    "entries.forEach(function(entry){" +
                    "if (!found && entry.valid && " +
                    "entry.mode === 'refactor' && entry.splitOutput) {" +
                    "found = entry.file;}});" +
                    "return found;}())");
                if (string.IsNullOrEmpty(presetFile))
                {
                    throw new InvalidOperationException(
                        "No shipped preset carries the split rules.");
                }
                report.Add("presetFile", presetFile);
                await Execute(
                    "document.querySelector('[data-action=" +
                    "\"select-purpose\"][data-preset-file=" +
                    serializer.Serialize(presetFile) + "]').click();");
                await WaitFor(
                    "MacroStudioState.getState().splitOutputRules " +
                    "!== null && " +
                    "MacroStudioState.getState().busyAction === null");
                await ClickNext(-1);
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.requestScreen");
            }

            private async Task TurnTheOptionOn(
                Dictionary<string, object> report)
            {
                report.Add(
                    "optionOnScreen",
                    await ReadBool(
                        "document.getElementById('split-output') !== null"));
                report.Add(
                    "optionOffByDefault",
                    await ReadBool(
                        "MacroStudioState.getState().splitOutput " +
                        "=== false && " +
                        "document.getElementById('split-output')" +
                        ".checked === false"));
                await Execute(
                    "document.getElementById('split-output').click();");
                await WaitFor(
                    "MacroStudioState.getState().splitOutput === true");
                report.Add(
                    "optionChecked",
                    await ReadBool(
                        "document.getElementById('split-output')" +
                        ".checked === true"));
            }

            // Leaving the request screen writes the run folder and its
            // two files, so this is where the rules that were chosen
            // actually reach the request the user pastes into the chat.
            private async Task PrepareTheRequest(
                Dictionary<string, object> report)
            {
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-next\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.handoffScreen && " +
                    "MacroStudioState.getState().busyAction === null");
                report.Add(
                    "runFolder",
                    await ReadJson(
                        "MacroStudioState.getState().runFolder"));
                report.Add(
                    "promptHasPartSentinel",
                    await ReadBool(
                        "MacroStudioState.getState().requestPrompt" +
                        ".indexOf(MacroStudioResponse.marker + ' ' + " +
                        "MacroStudioState.getState().requestId + " +
                        "' PART ') >= 0"));
                report.Add(
                    "promptHasOneBlockRule",
                    await ReadBool(
                        "MacroStudioState.getState().requestPrompt" +
                        ".indexOf(MacroStudioResponse.marker + ' ' + " +
                        "MacroStudioState.getState().requestId + " +
                        "' COMPLETE 1') >= 0"));

                // The copy and the explorer window are the hand-off
                // screen's own conditions and need the clipboard, so they
                // are marked done here instead of being pressed.
                await Execute(
                    "MacroStudioState.setHandoffProgress(true, true);");
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-next\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.intakeScreen");
            }

            private async Task TakeThePartsIn(
                Dictionary<string, object> report)
            {
                await Execute(BuildPart(
                    0,
                    2,
                    "standard",
                    "AppController",
                    "Public Sub Boot(): Beep: End Sub",
                    true));
                await WaitFor(
                    "MacroStudioScreens.countIntakeParts(" +
                    "MacroStudioState.getState()) === 1");
                report.Add(
                    "afterFirstPart",
                    await ReadJson(
                        "JSON.stringify({" +
                        "parts: MacroStudioScreens.countIntakeParts(" +
                        "MacroStudioState.getState())," +
                        "total: MacroStudioScreens.getIntakePartTotal(" +
                        "MacroStudioState.getState())," +
                        "imported: MacroStudioScreens.countImported(" +
                        "MacroStudioState.getState())," +
                        "canGoNext: MacroStudioState.canGoNext()," +
                        "rows: document.querySelectorAll(" +
                        "'.intake-part-row').length," +
                        "missingShown: document.querySelector(" +
                        "'.intake-part-missing') !== null" +
                        "})"));

                // A second module under a number that is already in, with
                // other content, is a contradiction and must be refused.
                report.Add(
                    "conflictRefused",
                    await ReadBool(
                        "(function(){" +
                        "var before = MacroStudioScreens" +
                        ".countIntakeParts(" +
                        "MacroStudioState.getState());" +
                        BuildPartExpression(
                            0,
                            2,
                            "standard",
                            "SystemInfo",
                            "Public Sub Other(): End Sub",
                            false) +
                        "return taken === false && " +
                        "MacroStudioScreens.countIntakeParts(" +
                        "MacroStudioState.getState()) === before;}())"));

                await Execute(BuildPart(
                    1,
                    2,
                    "standard",
                    "CompatHelpers",
                    "Public Sub Wait(): End Sub",
                    false));
                await WaitFor(
                    "MacroStudioScreens.countImported(" +
                    "MacroStudioState.getState()) === 2");
                report.Add(
                    "afterLastPart",
                    await ReadJson(
                        "JSON.stringify({" +
                        "imported: MacroStudioScreens.countImported(" +
                        "MacroStudioState.getState())," +
                        "changed: MacroStudioScreens.countChanged(" +
                        "MacroStudioState.getState())," +
                        "canGoNext: MacroStudioState.canGoNext()," +
                        "buildModules: MacroStudioApp" +
                        ".createBuildModules(" +
                        "MacroStudioState.getState()).length," +
                        "restartOnScreen: document.querySelector(" +
                        "'[data-action=\"restart-intake\"]') !== null," +
                        "summary: MacroStudioState.getState()" +
                        ".intakeResult.summary" +
                        "})"));
            }

            // Audit P2-1: after a package has come in, the way to take a
            // corrected answer instead has to be on the screen.
            private async Task TakeAWholeAnswerInstead(
                Dictionary<string, object> report)
            {
                await Execute("MacroStudioState.setSplitOutput(false);");
                await WaitFor(
                    "MacroStudioState.getState().splitOutput === false && " +
                    "MacroStudioScreens.countImported(" +
                    "MacroStudioState.getState()) === 0");
                await Execute(
                    "(function(){" +
                    "var id = MacroStudioState.getState().requestId;" +
                    "var api = MacroStudioResponse;" +
                    "MacroStudioApp.applyResponsePackage([" +
                    "api.beginLine(id, 'standard', 'AppController')," +
                    "'Option Explicit'," +
                    "'Public Sub Boot(): Beep: End Sub'," +
                    "api.endLine(id, 'standard', 'AppController')," +
                    "api.beginLine(id, 'standard', 'TimerUtils')," +
                    "'Option Explicit'," +
                    "'Public Sub Tick(): Beep: End Sub'," +
                    "api.endLine(id, 'standard', 'TimerUtils')," +
                    "api.completeLine(id, 2)" +
                    "].join('\\r\\n'));}());");
                await WaitFor(
                    "MacroStudioScreens.countImported(" +
                    "MacroStudioState.getState()) === 2");
                report.Add(
                    "afterWholeAnswer",
                    await ReadJson(
                        "JSON.stringify({" +
                        "imported: MacroStudioScreens.countImported(" +
                        "MacroStudioState.getState())," +
                        "canGoNext: MacroStudioState.canGoNext()," +
                        "reimportOnScreen: document.querySelector(" +
                        "'[data-action=\"import-response\"]') !== null," +
                        "addedModuleGone: MacroStudioState.findModule(" +
                        "'CompatHelpers') === null," +
                        "horizontal: document.documentElement" +
                        ".scrollWidth > innerWidth" +
                        "})"));
            }

            private string BuildPartExpression(
                int index,
                int total,
                string kind,
                string name,
                string body,
                bool withSummary)
            {
                string summary = withSummary
                    ? "api.summaryBeginLine(id), 'two modules changed', " +
                      "api.summaryEndLine(id), "
                    : string.Empty;

                return "var id = MacroStudioState.getState().requestId;" +
                    "var api = MacroStudioResponse;" +
                    "var taken = MacroStudioApp.applyResponsePackage([" +
                    summary +
                    "api.partLine(id, " + index.ToString() + ", " +
                    total.ToString() + ")," +
                    "api.beginLine(id, '" + kind + "', '" + name + "')," +
                    "'Option Explicit'," +
                    "'" + body + "'," +
                    "api.endLine(id, '" + kind + "', '" + name + "')," +
                    "api.completeLine(id, 1)" +
                    "].join('\\r\\n'));";
            }

            private string BuildPart(
                int index,
                int total,
                string kind,
                string name,
                string body,
                bool withSummary)
            {
                return "(function(){" +
                    BuildPartExpression(
                        index,
                        total,
                        kind,
                        name,
                        body,
                        withSummary) +
                    "return taken;}());";
            }

            private async Task ClickNext(int expectedScreen)
            {
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-next\"]').click();");
                if (expectedScreen >= 0)
                {
                    await WaitFor(
                        "MacroStudioState.getState().screen === " +
                        expectedScreen.ToString());
                }
            }

            private async Task Execute(string script)
            {
                await webView.CoreWebView2.ExecuteScriptAsync(script);
            }

            private async Task<string> ReadJson(string expression)
            {
                string raw =
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "String(" + expression + ")");
                return serializer.Deserialize<string>(raw);
            }

            private async Task<bool> ReadBool(string expression)
            {
                string raw =
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "Boolean(" + expression + ")");
                return raw == "true";
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
                    "The split output condition timed out: " +
                    expression);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The split output smoke test timed out."));
            }

            private void Fail(Exception error)
            {
                Error = error;
                Stop();
            }

            private void Stop()
            {
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
