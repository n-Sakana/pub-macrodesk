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
    // Drives the short way through the real WebView2 runtime, twice: once
    // with the answer arriving in one piece, once module by module. Both
    // runs go all the way to a rebuilt workbook, because the point of the
    // short way is that it still finishes the same job.
    //
    // The clipboard is not used. The hand-off screen needs a copy and an
    // explorer window before its [next] frees up, which the flow test
    // covers; here that step is marked done through the state.
    public static class SimpleModeSmoke
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

            if (!thread.Join(180000))
            {
                throw new TimeoutException(
                    "The simple mode smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The simple mode smoke test failed.",
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
                    timeoutTimer.Interval = TimeSpan.FromSeconds(170);
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
                        "The simple mode test page navigation failed."));
                    return;
                }

                try
                {
                    Dictionary<string, object> report =
                        new Dictionary<string, object>();

                    await WaitFor(
                        "MacroStudioState.getState().appInfo !== null");
                    report.Add("opening", await ReadJson(OpeningShape()));
                    report.Add("whole", await RunOnce(false));
                    report.Add("split", await RunOnce(true));

                    Result = serializer.Serialize(report);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            // The short way is offered on the opening screen without
            // taking the place of either main choice.
            private static string OpeningShape()
            {
                return "(function(){" +
                    "var start=document.querySelector(" +
                    "'[data-action=\"start-simple\"]');" +
                    "return JSON.stringify({" +
                    "starters:document.querySelectorAll(" +
                    "'[data-action=\"start-simple\"]').length," +
                    "modes:document.querySelectorAll(" +
                    "'[data-action=\"select-mode\"]').length," +
                    "primary:start?start.classList.contains(" +
                    "'button--primary'):true," +
                    "label:start?start.textContent.trim():''" +
                    "});}())";
            }

            private async Task<string> RunOnce(bool perModule)
            {
                Dictionary<string, object> phase =
                    new Dictionary<string, object>();

                // Starting over the way [完了] does: the state is cleared
                // and the list of presets is read again.
                await Execute("MacroStudioState.reset();");
                await Execute(
                    "window.hostBridge.request('getAppInfo').then(" +
                    "function(info){MacroStudioState.setAppInfo(info);});");
                await WaitFor(
                    "MacroStudioState.getState().appInfo !== null && " +
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.modeScreen");
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"start-simple\"]').click();");
                await WaitFor(
                    "MacroStudioState.getState().simple === true && " +
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.bookScreen");
                phase.Add("startedOnBook", true);

                Dictionary<string, object> eventData =
                    new Dictionary<string, object>();
                eventData.Add("path", bookPath);
                router.PushEvent("bookDropped", eventData);
                await WaitFor(
                    "MacroStudioState.getState().book !== null && " +
                    "MacroStudioState.getState().busyAction === null");

                // Straight from the workbook to what to change: no screen
                // for what was read, no purpose, no questions.
                await ClickNext();
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.requestScreen && " +
                    "MacroStudioState.getState().requestId !== null && " +
                    "MacroStudioState.getState().busyAction === null");
                phase.Add("requestScreen", await ReadJson(
                    "(function(){" +
                    "var main=document.getElementById('main-content');" +
                    "return JSON.stringify({" +
                    "boxes:document.querySelectorAll(" +
                    "'#simple-request-input').length," +
                    "options:document.querySelectorAll(" +
                    "'.option-checkbox').length," +
                    "disclosures:document.querySelectorAll(" +
                    "'.disclosure').length," +
                    "presetCards:document.querySelectorAll(" +
                    "'[data-action=\"select-purpose\"]').length," +
                    "text:main?main.textContent:''" +
                    "});}())"));

                await Execute(
                    "(function(){var box=document.getElementById(" +
                    "'simple-request-input');" +
                    "box.value='\\u9045\\u3044\\u306e\\u3067\\u901f\\u304f" +
                    "\\u3057\\u3066\\u304f\\u3060\\u3055\\u3044\\u3002';" +
                    "box.dispatchEvent(new Event('input',{bubbles:true}));" +
                    "}());");
                await WaitFor(
                    "MacroStudioState.getState().requestText.length > 0");
                if (perModule)
                {
                    await Execute(
                        "document.getElementById('split-output').click();");
                    await WaitFor(
                        "MacroStudioState.getState().splitOutput === true");
                }
                phase.Add("splitChosen", await ReadBool(
                    "MacroStudioState.getState().splitOutput === " +
                    (perModule ? "true" : "false")));

                await ClickNext();
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.handoffScreen && " +
                    "MacroStudioState.getState().busyAction === null");
                phase.Add("request", await ReadJson(
                    "JSON.stringify({" +
                    "runFolder:MacroStudioState.getState().runFolder," +
                    "carriesWhatWasWritten:MacroStudioState.getState()" +
                    ".requestPrompt.indexOf(MacroStudioState.getState()" +
                    ".requestText) >= 0," +
                    "carriesTheId:MacroStudioState.getState()" +
                    ".requestPrompt.indexOf(MacroStudioResponse.marker + " +
                    "' ' + MacroStudioState.getState().requestId) >= 0," +
                    "carriesPartRule:MacroStudioState.getState()" +
                    ".requestPrompt.indexOf(MacroStudioResponse.marker + " +
                    "' ' + MacroStudioState.getState().requestId + " +
                    "' PART ') >= 0" +
                    "})"));

                await Execute(
                    "MacroStudioState.setHandoffProgress(true, true);");
                await ClickNext();
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.intakeScreen");

                if (perModule)
                {
                    await Execute(Part(0, 2, "AppController", true));
                    await WaitFor(
                        "MacroStudioScreens.countIntakeParts(" +
                        "MacroStudioState.getState()) === 1");
                    await Execute(Part(1, 2, "TimerUtils", false));
                }
                else
                {
                    await Execute(WholeAnswer());
                }
                await WaitFor(
                    "MacroStudioScreens.countImported(" +
                    "MacroStudioState.getState()) === 2");

                await ClickNext();
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.reviewScreen");
                phase.Add("review", await ReadJson(
                    "(function(){" +
                    "var main=document.getElementById('main-content');" +
                    "return JSON.stringify({" +
                    "diffTables:document.querySelectorAll(" +
                    "'.diff-table').length," +
                    "moduleItems:document.querySelectorAll(" +
                    "'.module-item').length," +
                    "disclosures:document.querySelectorAll(" +
                    "'.disclosure').length," +
                    "editButtons:document.querySelectorAll(" +
                    "'[data-action=\"edit-paste\"]').length," +
                    "forwardLabel:document.querySelector(" +
                    "'[data-action=\"go-next\"] .button-label')" +
                    ".textContent," +
                    "text:main?main.textContent:''" +
                    "});}())"));

                // The one button on that screen starts the same build the
                // detailed way runs.
                await ClickNext();
                await WaitFor(
                    "MacroStudioState.getState().screen === " +
                    "MacroStudioScreens.doneScreen && " +
                    "MacroStudioState.getState().buildResult !== null");
                phase.Add("built", await ReadJson(
                    "JSON.stringify({" +
                    "success:MacroStudioState.getState().buildResult" +
                    ".status !== 'error'," +
                    "outputPath:MacroStudioState.getState().buildResult" +
                    ".outputPath || ''," +
                    "written:MacroStudioState.getState().buildResult" +
                    ".results ? MacroStudioState.getState().buildResult" +
                    ".results.length : 0" +
                    "})"));
                return serializer.Serialize(phase);
            }

            // A whole answer: two modules in one paste.
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

            // One module per reply, the way the option asks the AI to
            // answer.
            private static string Part(
                int index,
                int total,
                string name,
                bool withSummary)
            {
                string summary = withSummary
                    ? "api.summaryBeginLine(id), " +
                      "'\\u7e70\\u308a\\u8fd4\\u3057\\u3092\\u76f4\\u3057" +
                      "\\u307e\\u3057\\u305f', api.summaryEndLine(id), "
                    : string.Empty;

                return "(function(){" +
                    "var id = MacroStudioState.getState().requestId;" +
                    "var api = MacroStudioResponse;" +
                    "MacroStudioApp.applyResponsePackage([" +
                    summary +
                    "api.partLine(id, " + index.ToString() + ", " +
                    total.ToString() + ")," +
                    "api.beginLine(id, 'standard', '" + name + "')," +
                    "'Option Explicit'," +
                    "'Public Sub Run" + index.ToString() +
                    "(): Beep: End Sub'," +
                    "api.endLine(id, 'standard', '" + name + "')," +
                    "api.completeLine(id, 1)" +
                    "].join('\\r\\n'));}());";
            }

            private async Task ClickNext()
            {
                await Execute(
                    "document.querySelector(" +
                    "'[data-action=\"go-next\"]').click();");
                await Task.Delay(120);
            }

            private async Task Execute(string script)
            {
                await webView.CoreWebView2.ExecuteScriptAsync(script);
            }

            private async Task<string> ReadJson(string expression)
            {
                string raw =
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        expression);
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
                for (attempt = 0; attempt < 600; attempt++)
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
                    "The simple mode condition timed out: " + expression);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The simple mode smoke test timed out."));
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
                        if (webView.CoreWebView2 != null && router != null)
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
