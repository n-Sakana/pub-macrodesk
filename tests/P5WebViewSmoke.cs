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

namespace MacroDesk.Tests
{
    public static class P5WebViewSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir,
            string stepOneScreenshot,
            string stepTwoScreenshot)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                bookPath,
                cacheDir,
                stepOneScreenshot,
                stepTwoScreenshot);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(90000))
            {
                throw new TimeoutException(
                    "The P5 WebView smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The P5 WebView smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string bookPath;
            private readonly string cacheDir;
            private readonly string stepOneScreenshot;
            private readonly string stepTwoScreenshot;

            private Application application;
            private Window window;
            private WebView2 webView;
            private MessageRouter router;
            private DispatcherTimer timeoutTimer;
            private JavaScriptSerializer serializer;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string bookPath,
                string cacheDir,
                string stepOneScreenshot,
                string stepTwoScreenshot)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.bookPath = Path.GetFullPath(bookPath);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.stepOneScreenshot = Path.GetFullPath(
                    stepOneScreenshot);
                this.stepTwoScreenshot = Path.GetFullPath(
                    stepTwoScreenshot);
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
                    timeoutTimer.Interval = TimeSpan.FromSeconds(60);
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
                        "macrodesk.local",
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
                        "https://macrodesk.local/index.html");
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
                        "The P5 test page navigation failed."));
                    return;
                }

                try
                {
                    await WaitFor(
                        "MacroDeskState.getState().appInfo !== null");
                    await InstallLogCapture();
                    string initial = await ReadSnapshot();

                    Dictionary<string, object> eventData =
                        new Dictionary<string, object>();
                    eventData.Add("path", bookPath);
                    router.PushEvent("bookDropped", eventData);
                    await WaitFor(
                        "MacroDeskState.getState().book !== null && " +
                        "MacroDeskState.getState().busyAction === null");
                    string attached = await ReadSnapshot();
                    await Capture(stepOneScreenshot);

                    await RunMockAttachErrors();
                    string errors =
                        await ReadJson("window.__p5ErrorResults");

                    string bookJson = serializer.Serialize(bookPath);
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "window.__p5CancelDone=false;" +
                        "window.__p5ConfirmCount=0;" +
                        "MacroDeskState.getState().modules[2]" +
                        ".status='changed';" +
                        "window.confirm=function(){" +
                        "window.__p5ConfirmCount+=1;return false;};" +
                        "MacroDeskApp.attachPath(" + bookJson + ")" +
                        ".then(function(){window.__p5CancelDone=true;});");
                    await WaitFor("window.__p5CancelDone === true");
                    string cancelled = await ReadJson(
                        "({" +
                        "confirmCount:window.__p5ConfirmCount," +
                        "status:MacroDeskState.getState()" +
                        ".modules[2].status," +
                        "book:MacroDeskState.getState().book.name" +
                        "})");

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "window.__p5ResetDone=false;" +
                        "MacroDeskState.setLectureCollapsed(true);" +
                        "window.confirm=function(){return true;};" +
                        "MacroDeskApp.attachPath(" + bookJson + ")" +
                        ".then(function(){window.__p5ResetDone=true;});");
                    await WaitFor(
                        "window.__p5ResetDone === true && " +
                        "MacroDeskState.getState().busyAction === null");
                    string reset = await ReadJson(
                        "({" +
                        "step:MacroDeskState.getState().currentStep," +
                        "pending:MacroDeskState.getState().modules" +
                        ".filter(function(m){return m.status===" +
                        "'pending';}).length," +
                        "lectureCollapsed:MacroDeskState.getState()" +
                        ".lectureCollapsed," +
                        "requestText:MacroDeskState.getState()" +
                        ".requestText" +
                        "})");

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "document.querySelector(" +
                        "'[data-action=\"step1-next\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().currentStep === 2");

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "(function(){" +
                        "var t=document.getElementById('request-text');" +
                        "t.value='  \\n ';" +
                        "t.dispatchEvent(new Event('input'," +
                        "{bubbles:true}));" +
                        "document.querySelector(" +
                        "'[data-action=\"create-request\"]').click();" +
                        "}());");
                    await Task.Delay(100);
                    string empty = await ReadJson(
                        "({" +
                        "path:MacroDeskState.getState()" +
                        ".requestFilePath," +
                        "toast:document.getElementById(" +
                        "'toast-region').textContent," +
                        "invalid:document.getElementById(" +
                        "'request-text').getAttribute(" +
                        "'aria-invalid')" +
                        "})");
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "document.getElementById(" +
                        "'toast-region').textContent='';");

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "(function(){" +
                        "var t=document.getElementById('request-text');" +
                        "t.value='existing request';" +
                        "t.dispatchEvent(new Event('input'," +
                        "{bubbles:true}));" +
                        "document.querySelector(" +
                        "'[data-action=\"load-preset\"]').click();" +
                        "}());");
                    await WaitFor(
                        "MacroDeskState.getState().busyAction === null " +
                        "&& MacroDeskState.getState().requestText" +
                        ".indexOf('existing request') === 0 " +
                        "&& MacroDeskState.getState().requestText" +
                        ".length > 20");
                    string preset = await ReadJson(
                        "({" +
                        "requestText:MacroDeskState.getState()" +
                        ".requestText," +
                        "presetCount:document.querySelectorAll(" +
                        "'[data-action=\"load-preset\"]').length," +
                        "fixedOpen:document.querySelector(" +
                        "'.fixed-preview').open," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})");
                    await Capture(stepTwoScreenshot);

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "window.__p5ExpectedContent=" +
                        "MacroDeskPrompt.buildRequestFile({" +
                        "requestText:MacroDeskState.getState()" +
                        ".requestText," +
                        "book:MacroDeskState.getState().book," +
                        "modules:MacroDeskState.getState().modules});" +
                        "window.__p5CreateDone=false;" +
                        "MacroDeskApp.createRequestFile()" +
                        ".then(function(){window.__p5CreateDone=true;});");
                    await WaitFor(
                        "window.__p5CreateDone === true && " +
                        "MacroDeskState.getState().busyAction === null " +
                        "&& MacroDeskState.getState()" +
                        ".requestFilePath !== null");
                    string success = await ReadJson(
                        "({" +
                        "path:MacroDeskState.getState()" +
                        ".requestFilePath," +
                        "heading:document.querySelector(" +
                        "'.request-success h3').textContent," +
                        "next:document.querySelector(" +
                        "'[data-action=\"step2-next\"]')!==null," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch" +
                        "})");
                    string expectedContent = await ReadJson(
                        "window.__p5ExpectedContent");
                    expectedContent =
                        serializer.Deserialize<string>(
                            expectedContent);

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "document.querySelector(" +
                        "'[data-action=\"step2-next\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().currentStep === 3");
                    string preserved = await ReadJson(
                        "({" +
                        "step:MacroDeskState.getState().currentStep," +
                        "path:MacroDeskState.getState()" +
                        ".requestFilePath," +
                        "modules:MacroDeskState.getState()" +
                        ".modules.length" +
                        "})");

                    Dictionary<string, object> result =
                        new Dictionary<string, object>();
                    result.Add("initial", initial);
                    result.Add("attached", attached);
                    result.Add("errors", errors);
                    result.Add("cancelled", cancelled);
                    result.Add("reset", reset);
                    result.Add("empty", empty);
                    result.Add("preset", preset);
                    result.Add("success", success);
                    result.Add("expectedContent", expectedContent);
                    result.Add("preserved", preserved);
                    result.Add(
                        "logs",
                        await ReadJson("window.__p5Logs.slice()"));
                    Result = serializer.Serialize(result);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            private async Task InstallLogCapture()
            {
                await webView.CoreWebView2.ExecuteScriptAsync(
                    "window.__p5Logs=[];" +
                    "window.__p5RealRequest=hostBridge.request;" +
                    "hostBridge.request=function(action,params){" +
                    "if(action==='writeLog'){" +
                    "window.__p5Logs.push(params.message);" +
                    "}" +
                    "return window.__p5RealRequest(action,params);" +
                    "};");
            }

            private async Task RunMockAttachErrors()
            {
                string script =
                    "window.__p5ErrorResults=null;" +
                    "(async function(){" +
                    "var real=hostBridge.request;" +
                    "var codes=['E-ATTACH-01','E-ATTACH-02'," +
                    "'E-ATTACH-03','E-ATTACH-04'," +
                    "'E-ATTACH-05'];" +
                    "var results={};" +
                    "for(var i=0;i<codes.length;i+=1){" +
                    "var code=codes[i];" +
                    "hostBridge.request=(function(value){" +
                    "return function(){" +
                    "return Promise.reject({" +
                    "code:value,message:'mock attach error'});" +
                    "};}(code));" +
                    "await MacroDeskApp.attachPath(" +
                    "'C:\\\\attempt.xlsm');" +
                    "results[code]={" +
                    "state:MacroDeskState.getState()" +
                    ".lastError.code," +
                    "toast:document.getElementById(" +
                    "'toast-region').textContent," +
                    "card:document.querySelector(" +
                    "'.inline-error-card')!==null," +
                    "book:MacroDeskState.getState().book.name," +
                    "modules:MacroDeskState.getState()" +
                    ".modules.length};" +
                    "MacroDeskState.setLastError(null);" +
                    "document.getElementById(" +
                    "'toast-region').textContent='';" +
                    "}" +
                    "hostBridge.request=real;" +
                    "window.__p5ErrorResults=results;" +
                    "}());";
                await webView.CoreWebView2.ExecuteScriptAsync(script);
                await WaitFor(
                    "window.__p5ErrorResults !== null");
            }

            private async Task<string> ReadSnapshot()
            {
                return await ReadJson(
                    "({" +
                    "step:MacroDeskState.getState().currentStep," +
                    "book:MacroDeskState.getState().book," +
                    "modules:MacroDeskState.getState()" +
                    ".modules.length," +
                    "pending:document.querySelectorAll(" +
                    "'.module-badge--pending').length," +
                    "presets:MacroDeskState.getState().appInfo" +
                    ".presets.length," +
                    "drop:document.querySelector(" +
                    "'.book-drop-zone')!==null," +
                    "pick:document.querySelector(" +
                    "'[data-action=\"pick-book\"]')!==null," +
                    "bookCard:document.querySelector(" +
                    "'.book-card')!==null," +
                    "documentWidth:document.documentElement" +
                    ".scrollWidth," +
                    "viewportWidth:innerWidth" +
                    "})");
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
                    "The P5 browser condition timed out: " +
                    expression);
            }

            private async Task Capture(string path)
            {
                await Task.Delay(150);
                using (FileStream stream = new FileStream(
                    path,
                    FileMode.CreateNew,
                    FileAccess.Write,
                    FileShare.None))
                {
                    await webView.CoreWebView2.CapturePreviewAsync(
                        CoreWebView2CapturePreviewImageFormat.Png,
                        stream);
                }
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The P5 WebView smoke test timed out."));
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
