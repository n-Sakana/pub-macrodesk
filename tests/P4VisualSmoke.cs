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
    public static class P4VisualSmoke
    {
        public static string Run(
            string baseDir,
            string cacheDir,
            string screenshotPath)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                cacheDir,
                screenshotPath);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(60000))
            {
                throw new TimeoutException(
                    "The P4 visual smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The P4 visual smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string cacheDir;
            private readonly string screenshotPath;

            private Application application;
            private Window window;
            private WebView2 webView;
            private DispatcherTimer timeoutTimer;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string cacheDir,
                string screenshotPath)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.screenshotPath = Path.GetFullPath(
                    screenshotPath);
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
                    webView.ZoomFactor = 1.0;

                    webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                        "macrodesk.local",
                        Path.Combine(baseDir, "assets"),
                        CoreWebView2HostResourceAccessKind.Allow);
                    webView.CoreWebView2.NavigationCompleted +=
                        OnNavigationCompleted;
                    webView.CoreWebView2.Navigate(
                        "https://macrodesk.local/index.html?demo=1");
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
                        "The P4 test page navigation failed."));
                    return;
                }

                try
                {
                    await Task.Delay(500);
                    string initial = await ReadMetrics();

                    using (FileStream stream = new FileStream(
                        screenshotPath,
                        FileMode.CreateNew,
                        FileAccess.Write,
                        FileShare.None))
                    {
                        await webView.CoreWebView2.CapturePreviewAsync(
                            CoreWebView2CapturePreviewImageFormat.Png,
                            stream);
                    }

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "document.getElementById(" +
                        "'lecture-toggle').click();");
                    await Task.Delay(250);
                    string collapsed = await ReadMetrics();

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "MacroDeskState.setLastError({" +
                        "code:'E-TEST',message:'Test error'});");
                    await Task.Delay(250);
                    string error = await ReadMetrics();

                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "MacroDeskState.setLastError(null);" +
                        "MacroDeskState.navigate(2);" +
                        "MacroDeskState.navigate(3);");
                    await Task.Delay(100);
                    string preserved = await ReadMetrics();

                    JavaScriptSerializer serializer =
                        new JavaScriptSerializer();
                    Dictionary<string, object> result =
                        new Dictionary<string, object>();
                    result.Add("initial", initial);
                    result.Add("collapsed", collapsed);
                    result.Add("error", error);
                    result.Add("preserved", preserved);
                    Result = serializer.Serialize(result);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            private async Task<string> ReadMetrics()
            {
                string script =
                    "(function(){" +
                    "var q=function(s){return document.querySelector(s);};" +
                    "var r=function(s){var x=q(s).getBoundingClientRect();" +
                    "return {x:x.x,y:x.y,w:x.width,h:x.height};};" +
                    "var types=['pending','changed','unchanged'," +
                    "'excluded','written'];" +
                    "var badges={};" +
                    "types.forEach(function(t){" +
                    "badges[t]=document.querySelectorAll(" +
                    "'.module-badge--'+t).length;});" +
                    "return JSON.stringify({" +
                    "ready:document.readyState," +
                    "viewport:{w:innerWidth,h:innerHeight}," +
                    "documentSize:{w:document.documentElement.scrollWidth," +
                    "h:document.documentElement.scrollHeight}," +
                    "progress:r('.progress-region')," +
                    "modules:r('.module-region')," +
                    "work:r('.work-region')," +
                    "main:r('.main-region')," +
                    "lecture:r('.lecture-region')," +
                    "diff:r('.step-three-workspace--diff')," +
                    "diffColumns:document.querySelectorAll(" +
                    "'.diff-column-heading').length," +
                    "diffRows:document.querySelectorAll(" +
                    "'.diff-row').length," +
                    "badges:badges," +
                    "branch:q('.lecture-region').dataset.branch," +
                    "error:q('.lecture-region').classList" +
                    ".contains('is-error')," +
                    "collapsed:MacroDeskState.getState()" +
                    ".lectureCollapsed," +
                    "step:MacroDeskState.getState().currentStep," +
                    "selected:MacroDeskState.getState()" +
                    ".selectedModuleName," +
                    "step4:MacroDeskState.getTransitionRow()[4]" +
                    "});" +
                    "}())";
                string raw =
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        script);
                JavaScriptSerializer serializer =
                    new JavaScriptSerializer();
                return serializer.Deserialize<string>(raw);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The P4 visual smoke test timed out."));
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
