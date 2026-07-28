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
    public static class P3WebViewSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                bookPath,
                cacheDir);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(60000))
            {
                throw new TimeoutException(
                    "The P3 WebView smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The P3 WebView smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string bookPath;
            private readonly string cacheDir;

            private Application application;
            private Window window;
            private WebView2 webView;
            private MessageRouter router;
            private DispatcherTimer timeoutTimer;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string bookPath,
                string cacheDir)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.bookPath = Path.GetFullPath(bookPath);
                this.cacheDir = Path.GetFullPath(cacheDir);
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
                    window.Width = 2;
                    window.Height = 2;
                    window.Left = -10000;
                    window.Top = -10000;
                    window.ShowInTaskbar = false;
                    window.ShowActivated = false;
                    window.WindowStyle = WindowStyle.None;

                    webView = new WebView2();
                    webView.AllowExternalDrop = false;
                    window.Content = webView;
                    window.Loaded += OnLoaded;

                    timeoutTimer = new DispatcherTimer();
                    timeoutTimer.Interval = TimeSpan.FromSeconds(30);
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
                        "The P3 test page navigation failed."));
                    return;
                }

                try
                {
                    JavaScriptSerializer serializer =
                        new JavaScriptSerializer();
                    serializer.MaxJsonLength = int.MaxValue;
                    string bookJson = serializer.Serialize(bookPath);
                    string script =
                        "window.__p3SmokeResult = null;" +
                        "(async function() {" +
                        "try {" +
                        "var info = await hostBridge.request(" +
                        "'getAppInfo');" +
                        "var attached = await hostBridge.request(" +
                        "'attachBook', {path:" + bookJson + "});" +
                        "var target = null;" +
                        "for (var i = 0; i < attached.modules.length; i++) {" +
                        "if (attached.modules[i].name === " +
                        "'AppController') {" +
                        "target = attached.modules[i];" +
                        "break;" +
                        "}" +
                        "}" +
                        "var built = await hostBridge.request(" +
                        "'buildBook', {" +
                        "outputTimestamp:" +
                        serializer.Serialize(
                            DateTime.Now.ToString(
                                "yyyyMMdd_HHmmss")) +
                        ",modules:[{" +
                        "name:target.name," +
                        "code:target.attributes + target.code" +
                        "}]});" +
                        "window.__p3DroppedPath = '';" +
                        "hostBridge.on('bookDropped', function(data) {" +
                        "window.__p3DroppedPath = data.path;" +
                        "});" +
                        "window.__p3SmokeResult = JSON.stringify({" +
                        "version:info.version," +
                        "modules:attached.modules.length," +
                        "ext:attached.book.ext," +
                        "outputPath:built.outputPath," +
                        "buildResult:built.results[0].result" +
                        "});" +
                        "} catch (error) {" +
                        "window.__p3SmokeResult = JSON.stringify({" +
                        "error:error.code || 'E-SYS-02'," +
                        "message:error.message" +
                        "});" +
                        "}" +
                        "}());";

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        script);
                    string json = null;
                    int attempt;
                    for (attempt = 0; attempt < 200; attempt++)
                    {
                        string raw = await webView.CoreWebView2
                            .ExecuteScriptAsync(
                                "window.__p3SmokeResult");
                        if (raw != "null" &&
                            raw != "undefined")
                        {
                            json = serializer.Deserialize<string>(
                                raw);
                            break;
                        }
                        await Task.Delay(50);
                    }
                    if (json == null)
                    {
                        throw new TimeoutException(
                            "The host request result was not returned.");
                    }

                    Dictionary<string, object> data =
                        serializer.Deserialize<
                            Dictionary<string, object>>(json);
                    if (data.ContainsKey("error"))
                    {
                        throw new InvalidOperationException(
                            data["error"].ToString() + ": " +
                            data["message"].ToString());
                    }

                    string outputPath = Path.GetFullPath(
                        data["outputPath"].ToString());
                    string sourceDirectory = Path.GetFullPath(
                        Path.GetDirectoryName(bookPath));
                    if (!string.Equals(
                        Path.GetDirectoryName(outputPath),
                        sourceDirectory,
                        StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException(
                            "The P3 build output is outside the " +
                            "source directory.");
                    }
                    if (!File.Exists(outputPath))
                    {
                        throw new InvalidOperationException(
                            "The P3 build output was not created.");
                    }
                    File.Delete(outputPath);

                    Dictionary<string, object> eventData =
                        new Dictionary<string, object>();
                    eventData.Add("path", bookPath);
                    router.PushEvent("bookDropped", eventData);
                    await Task.Delay(100);

                    string droppedRaw = await webView.CoreWebView2
                        .ExecuteScriptAsync(
                            "window.__p3DroppedPath");
                    string droppedPath =
                        serializer.Deserialize<string>(droppedRaw);

                    Result =
                        data["version"].ToString() + "|" +
                        data["modules"].ToString() + "|" +
                        data["ext"].ToString() + "|" +
                        droppedPath + "|" +
                        data["buildResult"].ToString();
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The P3 WebView request timed out."));
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
