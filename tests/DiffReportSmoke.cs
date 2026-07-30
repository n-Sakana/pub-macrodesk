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
    // Builds a real diff report with the product code, writes it out the
    // way a build does, opens the written file in the browser engine and
    // works its controls by clicking them: change navigation, changes
    // only, wrap, the theme switch and the module list.
    //
    // The report renders with the app's own diff code, carried inside the
    // file, so the rows appear at all only if that bundle ran.
    public static class DiffReportSmoke
    {
        public static string Run(
            string baseDir,
            string cacheDir,
            string reportDir)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                cacheDir,
                reportDir);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(60000))
            {
                throw new TimeoutException(
                    "The diff report smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The diff report smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string cacheDir;
            private readonly string reportDir;
            private readonly JavaScriptSerializer serializer;

            private Application application;
            private Window window;
            private WebView2 webView;
            private DispatcherTimer timeoutTimer;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string cacheDir,
                string reportDir)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.reportDir = Path.GetFullPath(reportDir);
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
                    Directory.CreateDirectory(reportDir);
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
                    webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                        "report.local",
                        reportDir,
                        CoreWebView2HostResourceAccessKind.Allow);
                    await Navigate("https://macrostudio.local/index.html");
                    await BuildAndCheck();
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            private async Task BuildAndCheck()
            {
                await WaitFor(
                    "Boolean(window.MacroStudioDiffReport) && " +
                    "Boolean(window.MacroStudioDiffView)");

                // The product code builds the report, exactly as a build
                // does, including reading the assets it embeds; nothing
                // about the file is written by this test.
                await Execute(
                    "window.reportHtml = null;" +
                    "MacroStudioApp.loadReportAssets().then(" +
                    "function (assets) {" +
                    "var lines = [];var index;" +
                    "for (index = 0; index < 80; index += 1) {" +
                    "lines.push('    Debug.Print ' + index);}" +
                    "var before = 'Option Explicit\\r\\n' + " +
                    "lines.join('\\r\\n') + '\\r\\n';" +
                    "var after = before.replace(" +
                    "'    Debug.Print 40', " +
                    "'    Debug.Print 40: a very long trailing comment " +
                    "that has to wrap somewhere on the screen');" +
                    "window.reportHtml = " +
                    "MacroStudioDiffReport.buildReport({" +
                    "bookName: 'book.xlsm'," +
                    "buildTimestamp: '20260730_010203'," +
                    "modules: [{name: 'Main', type: 'standard'," +
                    "typeLabel: '\\u6a19\\u6e96\\u30e2\\u30b8\\u30e5" +
                    "\\u30fc\\u30eb', ext: 'bas', lineCount: 81," +
                    "code: before, pastedCode: after, " +
                    "status: 'changed'}," +
                    // A document module: the longest type label there
                    // is, which is what makes the toolbar of an
                    // unchanged module run out of room.
                    "{name: 'ThisWorkbook', type: 'document'," +
                    "typeLabel: '\\u30c9\\u30ad\\u30e5\\u30e1\\u30f3" +
                    "\\u30c8\\u30e2\\u30b8\\u30e5\\u30fc\\u30eb'," +
                    "ext: 'cls', lineCount: 81," +
                    "code: before, pastedCode: null, " +
                    "status: 'pending'}]," +
                    "assets: assets});});");
                await WaitFor("typeof window.reportHtml === 'string'");

                string html = await ReadString("window.reportHtml");

                string reportPath = Path.Combine(
                    reportDir,
                    "book-Diff-Report-20260730.html");
                using (FileStream output = new FileStream(
                    reportPath,
                    FileMode.Create,
                    FileAccess.Write,
                    FileShare.None))
                using (StreamWriter writer = new StreamWriter(
                    output,
                    new UTF8Encoding(true)))
                {
                    writer.Write(html);
                }

                await Navigate(
                    "https://report.local/book-Diff-Report-20260730.html");
                await WaitFor(
                    "document.querySelectorAll('.diff-row').length > 0");

                Dictionary<string, object> report =
                    new Dictionary<string, object>();
                report.Add("bytes", new FileInfo(reportPath).Length);
                report.Add("scripts", await ReadString(
                    "String(document.scripts.length)"));
                report.Add("modules", await ReadString(
                    "String(document.querySelectorAll(" +
                    "'.module-item').length)"));
                report.Add("opened", await ReadString(Measure()));
                // A written report is read after the build, so the two
                // sides are the original code and the code that replaced
                // it - not the screen's "pasted" wording.
                report.Add("labels", await ReadString(
                    "(function(){" +
                    "var cap=document.querySelector('.diff-table caption');" +
                    "var note=document.querySelector(" +
                    "'.diff-column-heading--code .code-pane-note');" +
                    "return JSON.stringify({" +
                    "caption:cap?cap.textContent:''," +
                    "codeNote:note?note.textContent:''});}())"));

                // "\u5909\u66F4\u7B87\u6240\u306E\u307F" collapses the untouched stretches.
                await ClickToggle("\u5909\u66F4\u7B87\u6240\u306E\u307F");
                report.Add("changesOnly", await ReadString(Measure()));
                await ClickToggle("\u5909\u66F4\u7B87\u6240\u306E\u307F");
                report.Add("restored", await ReadString(Measure()));

                // "\u6298\u308A\u8FD4\u3057" is on when the report opens, like the screen.
                await ClickToggle("\u6298\u308A\u8FD4\u3057");
                report.Add("unwrapped", await ReadString(Measure()));
                await ClickToggle("\u6298\u308A\u8FD4\u3057");
                report.Add("wrapped", await ReadString(Measure()));

                // The change navigation moves the marked row.
                await ClickAction("\u6B21\u306E\u5909\u66F4");
                report.Add("afterNext", await ReadString(Measure()));
                await ClickAction("\u524D\u306E\u5909\u66F4");
                report.Add("afterPrevious", await ReadString(Measure()));

                // Walking the changes is the toolbar's whole purpose, so
                // the toolbar has to still be on screen after the page
                // has scrolled to a change well down the file.
                int step;
                for (step = 0; step < 6; step++)
                {
                    await ClickAction("\u6B21\u306E\u5909\u66F4");
                }
                report.Add("walked", await ReadString(ToolbarRect()));

                await Execute(
                    "document.getElementById(" +
                    "'report-theme-toggle').click();");
                await WaitFor(
                    "document.documentElement.getAttribute(" +
                    "'data-theme') === 'dark'");
                report.Add("dark", await ReadString(Measure()));
                await Execute(
                    "document.getElementById(" +
                    "'report-theme-toggle').click();");
                await WaitFor(
                    "document.documentElement.getAttribute(" +
                    "'data-theme') === 'light'");
                report.Add("light", await ReadString(Measure()));

                // A second module can be opened from the list.
                await Execute(
                    "document.querySelectorAll('.module-item')[1]" +
                    ".click();");
                await WaitFor(
                    "document.querySelectorAll('.module-item')[1]" +
                    ".getAttribute('aria-pressed') === 'true'");
                report.Add("second", await ReadString(Measure()));
                // A module with nothing to show still has to lay its
                // toolbar out, and its toolbar is the fullest one there
                // is: the longest type label plus a note saying nothing
                // changed. Measured just above the width where the
                // layout folds into one column, which is where a real
                // window on a scaled display lands.
                window.Width = 1000;
                await Task.Delay(400);
                report.Add("secondToolbar", await ReadString(
                    ToolbarLayout()));
                window.Width = 1366;
                await Task.Delay(300);

                Result = serializer.Serialize(report);
            }

            // Where the toolbar actually sits in the window after the
            // page has scrolled, plus where the column headings landed
            // and whether the switch reads as an icon.
            private static string ToolbarRect()
            {
                return "(function(){" +
                    "var bar=document.querySelector('.diff-toolbar');" +
                    "var head=document.querySelector(" +
                    "'.diff-table thead th');" +
                    "var theme=document.getElementById(" +
                    "'report-theme-toggle');" +
                    "var r=bar.getBoundingClientRect();" +
                    "var h=head?head.getBoundingClientRect():null;" +
                    "return JSON.stringify({" +
                    "scrollY:Math.round(window.scrollY)," +
                    "top:Math.round(r.top)," +
                    "bottom:Math.round(r.bottom)," +
                    "headTop:h?Math.round(h.top):-1," +
                    "themeInToolbar:Boolean(theme&&bar.contains(theme))," +
                    "themeText:theme?theme.textContent.trim():''," +
                    "themeIcons:theme?theme.querySelectorAll(" +
                    "'svg.theme-icon').length:0," +
                    "themeShown:theme?theme.querySelectorAll(" +
                    "'svg.theme-icon:not([hidden])').length:0" +
                    "});}())";
            }

            private async Task ClickToggle(string label)
            {
                await ClickByLabel(".diff-toggle", label);
            }

            private async Task ClickAction(string label)
            {
                await ClickByLabel(".diff-actions .button", label);
            }

            // The reader clicks a button by what it says, so the test
            // does too.
            private async Task ClickByLabel(
                string selector,
                string label)
            {
                string found = await ReadString(
                    "(function(){" +
                    "var nodes=document.querySelectorAll(" +
                    serializer.Serialize(selector) + ");" +
                    "var index;" +
                    "for(index=0;index<nodes.length;index+=1){" +
                    "if(nodes[index].textContent.indexOf(" +
                    serializer.Serialize(label) + ")>=0){" +
                    "nodes[index].click();return 'yes';}}" +
                    "return 'no';}())");

                if (found != "yes")
                {
                    throw new InvalidOperationException(
                        "The report has no control labelled " + label);
                }
                await Task.Delay(60);
            }

            // Where the two halves of the toolbar actually sit, and how
            // far the widest of them reaches. Overlap is measured, not
            // eyeballed: the left group must end before the buttons
            // start.
            private static string ToolbarLayout()
            {
                return "(function(){" +
                    "var bar=document.querySelector('.diff-toolbar');" +
                    "var group=document.querySelector(" +
                    "'.diff-result-group');" +
                    "var actions=document.querySelector('.diff-actions');" +
                    "var notes=group.querySelectorAll('.diff-result-note');" +
                    "var g=group.getBoundingClientRect();" +
                    "var a=actions.getBoundingClientRect();" +
                    "var last=notes.length?notes[notes.length-1]" +
                    ".getBoundingClientRect():g;" +
                    "return JSON.stringify({" +
                    "groupRight:Math.round(g.right)," +
                    "actionsLeft:Math.round(a.left)," +
                    "lastNoteRight:Math.round(last.right)," +
                    "notes:notes.length," +
                    "barScroll:Math.round(bar.scrollWidth-bar.clientWidth)," +
                    "clipped:group.scrollWidth-group.clientWidth" +
                    "});}())";
            }

            // What the engine actually shows, measured from the rendered
            // page rather than from the markup.
            private static string Measure()
            {
                return "(function(){" +
                    "function shown(selector){" +
                    "var nodes=document.querySelectorAll(selector);" +
                    "var count=0;var index;" +
                    "for(index=0;index<nodes.length;index+=1){" +
                    "if(nodes[index].getClientRects().length>0){" +
                    "count+=1;}}" +
                    "return count;}" +
                    "var scroller=document.querySelector(" +
                    "'.diff-table-scroller');" +
                    "var host=document.querySelector('.diff-table-host');" +
                    "var table=document.querySelector('.diff-table');" +
                    "return JSON.stringify({" +
                    "rows:shown('.diff-row')," +
                    "changed:shown('.diff-row--added,.diff-row--removed')," +
                    "gaps:shown('.diff-gap')," +
                    "counter:(document.querySelector(" +
                    "'.diff-change-counter')||{}).textContent||''," +
                    "changesOnlyPressed:(document.querySelector(" +
                    "'.diff-toggle')||{}).getAttribute?" +
                    "document.querySelectorAll('.diff-toggle')[0]" +
                    ".getAttribute('aria-pressed'):''," +
                    "wrapPressed:document.querySelectorAll(" +
                    "'.diff-toggle')[1].getAttribute('aria-pressed')," +
                    "wrappedClass:scroller?" +
                    "scroller.classList.contains('is-wrapped'):false," +
                    "jumpTargets:document.querySelectorAll(" +
                    "'.is-jump-target').length," +
                    "theme:document.documentElement.getAttribute(" +
                    "'data-theme')," +
                    "activeModule:(document.querySelector(" +
                    "'.module-item.is-active .module-name')||{})" +
                    ".textContent||''," +
                    "capped:scroller?" +
                    "(scroller.scrollHeight-scroller.clientHeight>1):true," +
                    "hostHeight:host?Math.round(" +
                    "host.getBoundingClientRect().height):0," +
                    "tableHeight:table?Math.round(" +
                    "table.getBoundingClientRect().height):0," +
                    "horizontal:document.documentElement.scrollWidth>" +
                    "innerWidth," +
                    "editable:document.querySelectorAll(" +
                    "'textarea,input,[contenteditable]').length" +
                    "});}())";
            }

            private async Task Navigate(string url)
            {
                TaskCompletionSource<bool> done =
                    new TaskCompletionSource<bool>();
                EventHandler<CoreWebView2NavigationCompletedEventArgs>
                    handler = null;
                handler = delegate(
                    object sender,
                    CoreWebView2NavigationCompletedEventArgs args)
                {
                    webView.CoreWebView2.NavigationCompleted -= handler;
                    if (args.IsSuccess)
                    {
                        done.TrySetResult(true);
                    }
                    else
                    {
                        done.TrySetException(
                            new InvalidOperationException(
                                "Navigation failed: " + url));
                    }
                };
                webView.CoreWebView2.NavigationCompleted += handler;
                webView.CoreWebView2.Navigate(url);
                await done.Task;
            }

            private async Task Execute(string script)
            {
                await webView.CoreWebView2.ExecuteScriptAsync(script);
            }

            private async Task<string> ReadString(string expression)
            {
                string raw =
                    await webView.CoreWebView2.ExecuteScriptAsync(
                        "String(" + expression + ")");
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
                    "The diff report condition timed out: " + expression);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The diff report smoke test timed out."));
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
