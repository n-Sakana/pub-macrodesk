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
    public static class P6WebViewSmoke
    {
        public static string Run(
            string baseDir,
            string bookPath,
            string cacheDir,
            string waitingScreenshot,
            string diffScreenshot,
            string buildScreenshot,
            string failureScreenshot,
            string successScreenshot,
            string reportScreenshot)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                bookPath,
                cacheDir,
                waitingScreenshot,
                diffScreenshot,
                buildScreenshot,
                failureScreenshot,
                successScreenshot,
                reportScreenshot);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(90000))
            {
                throw new TimeoutException(
                    "The P6 WebView smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The P6 WebView smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string bookPath;
            private readonly string cacheDir;
            private readonly string waitingScreenshot;
            private readonly string diffScreenshot;
            private readonly string buildScreenshot;
            private readonly string failureScreenshot;
            private readonly string successScreenshot;
            private readonly string reportScreenshot;

            private Application application;
            private Window window;
            private WebView2 webView;
            private MessageRouter router;
            private DispatcherTimer timeoutTimer;
            private JavaScriptSerializer serializer;
            private IDataObject originalClipboard;
            private bool clipboardCaptured;
            private bool clipboardChanged;
            private string buildOutputPath;
            private string diffOutputPath;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string bookPath,
                string cacheDir,
                string waitingScreenshot,
                string diffScreenshot,
                string buildScreenshot,
                string failureScreenshot,
                string successScreenshot,
                string reportScreenshot)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.bookPath = Path.GetFullPath(bookPath);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.waitingScreenshot = Path.GetFullPath(
                    waitingScreenshot);
                this.diffScreenshot = Path.GetFullPath(
                    diffScreenshot);
                this.buildScreenshot = Path.GetFullPath(
                    buildScreenshot);
                this.failureScreenshot = Path.GetFullPath(
                    failureScreenshot);
                this.successScreenshot = Path.GetFullPath(
                    successScreenshot);
                this.reportScreenshot = Path.GetFullPath(
                    reportScreenshot);
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
                    timeoutTimer.Interval = TimeSpan.FromSeconds(70);
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
                        "The P6 test page navigation failed."));
                    return;
                }

                try
                {
                    await WaitFor(
                        "MacroDeskState.getState().appInfo !== null");
                    await InstallLogCapture();

                    Dictionary<string, object> eventData =
                        new Dictionary<string, object>();
                    eventData.Add("path", bookPath);
                    router.PushEvent("bookDropped", eventData);
                    await WaitFor(
                        "MacroDeskState.getState().book !== null && " +
                        "MacroDeskState.getState().busyAction === null");
                    await Execute(
                        "document.querySelector(" +
                        "'.progress-step[data-step=\"3\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().currentStep === 3");

                    string initial = await ReadJson(
                        "({" +
                        "modules:MacroDeskState.getState()" +
                        ".modules.length," +
                        "selected:MacroDeskState.getState()" +
                        ".selectedModuleName," +
                        "glow:document.querySelectorAll(" +
                        "'.module-item.is-guided-target').length," +
                        "step4:document.querySelector(" +
                        "'.progress-step[data-step=\"4\"]')" +
                        ".classList.contains('is-ready')," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})");

                    await ClickModule("TimerUtils");
                    await WaitFor(
                        "MacroDeskState.getState()" +
                        ".selectedModuleName === 'TimerUtils'");
                    string waiting = await ReadJson(
                        "({" +
                        "panes:document.querySelectorAll(" +
                        "'.step-three-workspace--waiting " +
                        ".code-pane').length," +
                        "sourceRows:document.querySelectorAll(" +
                        "'.source-table tbody tr').length," +
                        "tokens:document.querySelectorAll(" +
                        "'.source-table .vba-token').length," +
                        "paste:document.querySelector(" +
                        "'[data-action=\"paste-response\"]')!==null," +
                        "primary:document.querySelector(" +
                        "'.paste-target.is-primary-target')!==null," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "moduleGlow:document.querySelectorAll(" +
                        "'.module-item.is-guided-target').length" +
                        "})");
                    await Capture(waitingScreenshot);

                    string originalCode = await ReadString(
                        "MacroDeskState.findModule('TimerUtils').code");
                    const string oldLine =
                        "Public Sub Test(): End Sub";
                    const string newLine =
                        "Public Sub Test(): " +
                        "Debug.Print \"changed\": End Sub";
                    if (originalCode.IndexOf(
                        oldLine,
                        StringComparison.Ordinal) < 0)
                    {
                        throw new InvalidOperationException(
                            "TimerUtils test line was not found.");
                    }
                    string changedCode = originalCode.Replace(
                        oldLine,
                        newLine);
                    string fencedCode =
                        "```vba\r\n" +
                        " Attribute VB_Name = \"TimerUtils\"\r\n" +
                        "\r\n" +
                        changedCode +
                        "```\r\n";

                    CaptureClipboard();
                    SetClipboardText(fencedCode);
                    await Task.Delay(250);
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"paste-response\"]').click();");
                    await WaitFor(
                        "MacroDeskState.findModule('TimerUtils')" +
                        ".status === 'changed' && " +
                        "MacroDeskState.getState().busyAction === null");
                    string normal = await ReadJson(
                        "({" +
                        "status:MacroDeskState.findModule(" +
                        "'TimerUtils').status," +
                        "count:MacroDeskState.findModule(" +
                        "'TimerUtils').changedLineCount," +
                        "pasted:MacroDeskState.findModule(" +
                        "'TimerUtils').pastedCode," +
                        "fence:MacroDeskState.findModule(" +
                        "'TimerUtils').pastedCode.indexOf('```')>=0," +
                        "attribute:MacroDeskState.findModule(" +
                        "'TimerUtils').pastedCode" +
                        ".indexOf('Attribute VB_')>=0," +
                        "nonEqual:document.querySelectorAll(" +
                        "'.diff-row--changed,.diff-row--removed," +
                        ".diff-row--added').length," +
                        "inlineMarks:document.querySelectorAll(" +
                        "'.diff-row--changed .diff-inline-mark').length," +
                        "changedTokens:document.querySelectorAll(" +
                        "'.diff-row--changed .vba-token').length," +
                        "result:document.querySelector(" +
                        "'.diff-result').textContent," +
                        "badge:document.querySelector(" +
                        "'[data-module-row-name=\"TimerUtils\"] " +
                        ".module-badge').textContent," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "logs:window.__p6Logs.slice()," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})");
                    await Capture(diffScreenshot);

                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"cancel-paste\"]').click();");
                    await WaitFor(
                        "MacroDeskState.findModule('TimerUtils')" +
                        ".status === 'pending'");
                    string undone = await ReadJson(
                        "({" +
                        "status:MacroDeskState.findModule(" +
                        "'TimerUtils').status," +
                        "pasted:MacroDeskState.findModule(" +
                        "'TimerUtils').pastedCode," +
                        "paste:document.querySelector(" +
                        "'[data-action=\"paste-response\"]')!==null" +
                        "})");

                    await Execute(
                        "MacroDeskApp.acceptPastedText(" +
                        serializer.Serialize(
                            originalCode.Replace("\r\n", "\n")) +
                        ",'TimerUtils');");
                    await WaitFor(
                        "MacroDeskState.findModule('TimerUtils')" +
                        ".status === 'unchanged' && " +
                        "MacroDeskState.getState().busyAction === null");
                    string identical = await ReadJson(
                        "({" +
                        "status:MacroDeskState.findModule(" +
                        "'TimerUtils').status," +
                        "count:MacroDeskState.findModule(" +
                        "'TimerUtils').changedLineCount," +
                        "nonEqual:document.querySelectorAll(" +
                        "'.diff-row--changed,.diff-row--removed," +
                        ".diff-row--added').length," +
                        "badge:document.querySelector(" +
                        "'[data-module-row-name=\"TimerUtils\"] " +
                        ".module-badge').textContent," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch" +
                        "})");

                    await Execute(
                        "(function(){var e=new Event(" +
                        "'paste',{bubbles:true,cancelable:true});" +
                        "Object.defineProperty(e,'clipboardData'," +
                        "{value:{getData:function(type){" +
                        "return type==='text'?" +
                        serializer.Serialize(fencedCode) +
                        ":'';}}});document.dispatchEvent(e);" +
                        "window.__p6PastePrevented=" +
                        "e.defaultPrevented;}());");
                    await WaitFor(
                        "MacroDeskState.findModule('TimerUtils')" +
                        ".status === 'changed' && " +
                        "MacroDeskState.getState().busyAction === null");
                    string keyboard = await ReadJson(
                        "({" +
                        "status:MacroDeskState.findModule(" +
                        "'TimerUtils').status," +
                        "count:MacroDeskState.findModule(" +
                        "'TimerUtils').changedLineCount," +
                        "prevented:window.__p6PastePrevented," +
                        "nextGlow:document.querySelectorAll(" +
                        "'.module-item.is-guided-target').length," +
                        "step4:document.querySelector(" +
                        "'.progress-step[data-step=\"4\"]')" +
                        ".classList.contains('is-ready')" +
                        "})");

                    await Execute(
                        "document.querySelector(" +
                        "'.progress-step[data-step=\"2\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().currentStep === 2");
                    await Execute(
                        "document.querySelector(" +
                        "'.progress-step[data-step=\"3\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().currentStep === 3");
                    string preserved = await ReadJson(
                        "({" +
                        "selected:MacroDeskState.getState()" +
                        ".selectedModuleName," +
                        "status:MacroDeskState.findModule(" +
                        "'TimerUtils').status," +
                        "pasted:MacroDeskState.findModule(" +
                        "'TimerUtils').pastedCode" +
                        "})");

                    await ClickModule("WindowUtils");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-module-toggle=\"WindowUtils\"]')" +
                        ".click();");
                    await WaitFor(
                        "MacroDeskState.findModule('WindowUtils')" +
                        ".status === 'excluded'");
                    string excludedClick = await ReadJson(
                        "({" +
                        "status:MacroDeskState.findModule(" +
                        "'WindowUtils').status," +
                        "strike:document.querySelector(" +
                        "'[data-module-row-name=\"WindowUtils\"]')" +
                        ".parentElement.classList" +
                        ".contains('is-excluded')," +
                        "release:document.querySelector(" +
                        "'[data-module-toggle=\"WindowUtils\"]')" +
                        ".getAttribute('aria-label')" +
                        "})");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-module-toggle=\"WindowUtils\"]')" +
                        ".click();");
                    await WaitFor(
                        "MacroDeskState.findModule('WindowUtils')" +
                        ".status === 'pending'");
                    await Execute(
                        "(function(){" +
                        "var r=document.querySelector(" +
                        "'[data-module-row-name=\"WindowUtils\"]');" +
                        "r.dispatchEvent(new MouseEvent(" +
                        "'contextmenu',{bubbles:true," +
                        "cancelable:true,button:2}));" +
                        "}());");
                    await WaitFor(
                        "MacroDeskState.findModule('WindowUtils')" +
                        ".status === 'excluded'");
                    string excludedContext = await ReadJson(
                        "MacroDeskState.findModule('WindowUtils').status");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-module-toggle=\"WindowUtils\"]')" +
                        ".click();");
                    await WaitFor(
                        "MacroDeskState.findModule('WindowUtils')" +
                        ".status === 'pending'");

                    await ClickModule("AppController");
                    await Execute(
                        "MacroDeskApp.acceptPastedText(" +
                        serializer.Serialize(
                            " \r\n```\r\n" +
                            " Attribute VB_Name = " +
                            "\"AppController\"\r\n") +
                        ",'AppController');");
                    await WaitFor(
                        "MacroDeskState.getState().lastError !== null " +
                        "&& MacroDeskState.getState()" +
                        ".lastError.code === 'E-PASTE-01' && " +
                        "MacroDeskState.getState().busyAction === null");
                    string empty = await ReadJson(
                        "({" +
                        "status:MacroDeskState.findModule(" +
                        "'AppController').status," +
                        "pasted:MacroDeskState.findModule(" +
                        "'AppController').pastedCode," +
                        "toast:document.getElementById(" +
                        "'toast-region').textContent," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "collapsed:MacroDeskState.getState()" +
                        ".lectureCollapsed" +
                        "})");

                    await ClickModule("SystemInfo");
                    await Execute(
                        "MacroDeskApp.acceptPastedText(" +
                        serializer.Serialize(fencedCode) +
                        ",'SystemInfo');");
                    await WaitFor(
                        "MacroDeskState.findModule('SystemInfo')" +
                        ".status === 'changed'");
                    string wrongModule = await ReadJson(
                        "({" +
                        "count:MacroDeskState.findModule(" +
                        "'SystemInfo').changedLineCount," +
                        "nonEqual:document.querySelectorAll(" +
                        "'.diff-row--changed,.diff-row--removed," +
                        ".diff-row--added').length," +
                        "rows:document.querySelectorAll(" +
                        "'.diff-row').length" +
                        "})");

                    await Execute(
                        "document.querySelector(" +
                        "'[data-new-module-intake]')" +
                        ".click();");
                    await WaitFor(
                        "MacroDeskState.getState()" +
                        ".newModuleIntake===true");
                    string newIntake = await ReadJson(
                        "({" +
                        "form:document.querySelector(" +
                        "'.new-module-intake')!==null," +
                        "input:document.getElementById(" +
                        "'new-module-name')!==null," +
                        "guided:document.querySelectorAll(" +
                        "'.is-guided-target').length," +
                        "moduleGlow:document.querySelectorAll(" +
                        "'.module-item.is-guided-target').length," +
                        "step4Guided:document.querySelector(" +
                        "'.progress-step[data-step=\"4\"]')" +
                        ".classList.contains(" +
                        "'is-guided-target')" +
                        "})");

                    const string additionCode =
                        "Option Explicit\r\n\r\n" +
                        "Public Sub RunAddedMacro()\r\n" +
                        "    Debug.Print \"added\"\r\n" +
                        "End Sub\r\n";
                    CaptureClipboard();
                    SetClipboardText(additionCode);
                    await Task.Delay(250);
                    await Execute(
                        "(function(){" +
                        "var i=document.getElementById(" +
                        "'new-module-name');" +
                        "i.value='CommonHelpers';" +
                        "i.dispatchEvent(new Event(" +
                        "'input',{bubbles:true}));" +
                        "document.querySelector(" +
                        "'[data-action=\"import-new-module\"]')" +
                        ".click();" +
                        "}());");
                    await WaitFor(
                        "MacroDeskState.findModule(" +
                        "'CommonHelpers')!==null && " +
                        "MacroDeskState.getState()" +
                        ".busyAction===null");
                    string newModule = await ReadJson(
                        "({" +
                        "count:MacroDeskState.getState()" +
                        ".modules.length," +
                        "selected:MacroDeskState.getState()" +
                        ".selectedModuleName," +
                        "status:MacroDeskState.findModule(" +
                        "'CommonHelpers').status," +
                        "isNew:MacroDeskState.findModule(" +
                        "'CommonHelpers').isNew," +
                        "type:MacroDeskState.findModule(" +
                        "'CommonHelpers').type," +
                        "code:MacroDeskState.findModule(" +
                        "'CommonHelpers').pastedCode," +
                        "badge:document.querySelector(" +
                        "'[data-module-row-name=" +
                        "\"CommonHelpers\"] " +
                        ".module-badge').textContent," +
                        "diff:document.querySelectorAll(" +
                        "'.diff-row--added').length," +
                        "step4:document.querySelector(" +
                        "'.progress-step[data-step=\"4\"]')" +
                        ".classList.contains('is-ready')" +
                        "})");

                    await InstallLargeModule();
                    await WaitFor(
                        "document.querySelector(" +
                        "'[data-action=\"toggle-diff-context\"]')" +
                        "!==null");
                    string largeFull = await ReadJson(
                        "({" +
                        "rows:document.querySelectorAll(" +
                        "'.diff-row').length," +
                        "gaps:document.querySelectorAll(" +
                        "'.diff-gap').length," +
                        "pressed:document.querySelector(" +
                        "'[data-action=\"toggle-diff-context\"]')" +
                        ".getAttribute('aria-pressed')," +
                        "clientHeight:document.querySelector(" +
                        "'.diff-table-scroller').clientHeight," +
                        "scrollHeight:document.querySelector(" +
                        "'.diff-table-scroller').scrollHeight," +
                        "canScroll:document.querySelector(" +
                        "'.diff-table-scroller').scrollHeight>" +
                        "document.querySelector(" +
                        "'.diff-table-scroller').clientHeight," +
                        "hostDisplay:getComputedStyle(" +
                        "document.querySelector(" +
                        "'.diff-table-host')).display" +
                        "})");
                    await Execute(
                        "document.querySelector('.diff-gap-button')" +
                        ".click();");
                    await WaitFor(
                        "document.querySelectorAll('.diff-gap')" +
                        ".length===1");
                    string largeExpanded = await ReadJson(
                        "({" +
                        "rows:document.querySelectorAll(" +
                        "'.diff-row').length," +
                        "gaps:document.querySelectorAll(" +
                        "'.diff-gap').length" +
                        "})");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"toggle-diff-wrap\"]')" +
                        ".click();");
                    await WaitFor(
                        "MacroDeskState.findModule('WindowUtils')" +
                        ".wrapDiff === true");
                    string largeWrapped = await ReadJson(
                        "({" +
                        "pressed:document.querySelector(" +
                        "'[data-action=\"toggle-diff-wrap\"]')" +
                        ".getAttribute('aria-pressed')," +
                        "wrapped:document.querySelector(" +
                        "'.diff-table-scroller').classList" +
                        ".contains('is-wrapped')," +
                        "whiteSpace:getComputedStyle(" +
                        "document.querySelector('.diff-code'))" +
                        ".whiteSpace" +
                        "})");
                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"toggle-diff-context\"]')" +
                        ".click();");
                    await WaitFor(
                        "MacroDeskState.findModule('WindowUtils')" +
                        ".showChangesOnly === false");
                    string largeContext = await ReadJson(
                        "({" +
                        "rows:document.querySelectorAll(" +
                        "'.diff-row').length," +
                        "gaps:document.querySelectorAll(" +
                        "'.diff-gap').length," +
                        "pressed:document.querySelector(" +
                        "'[data-action=\"toggle-diff-context\"]')" +
                        ".getAttribute('aria-pressed')," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})");

                    await Execute(
                        "window.__p7TargetCodes={};" +
                        "MacroDeskState.getState().modules" +
                        ".forEach(function(m){" +
                        "if(m.status==='changed'){" +
                        "window.__p7TargetCodes[m.name]=" +
                        "m.pastedCode;}});");
                    await Execute(
                        "document.querySelector(" +
                        "'.progress-step[data-step=\"4\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().currentStep===4 && " +
                        "document.querySelector(" +
                        "'[data-build-view=\"confirmation\"]')!==null");
                    string buildConfirmation = await ReadJson(
                        "({" +
                        "view:document.querySelector(" +
                        "'[data-build-view]').getAttribute(" +
                        "'data-build-view')," +
                        "targets:document.querySelectorAll(" +
                        "'.build-table tbody tr').length," +
                        "changed:Number(document.querySelector(" +
                        "'.build-count--changed .build-count-value')" +
                        ".textContent)," +
                        "output:document.querySelector(" +
                        "'.build-output-name').textContent," +
                        "timestamp:MacroDeskState.getState()" +
                        ".buildTimestamp," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "build:document.querySelector(" +
                        "'[data-action=\"build-book\"]')!==null," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})");
                    await Capture(buildScreenshot);

                    await Execute(
                        "window.__p7FailNextBuild=true;" +
                        "document.querySelector(" +
                        "'[data-action=\"build-book\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().buildResult && " +
                        "MacroDeskState.getState().buildResult" +
                        ".status==='error' && " +
                        "MacroDeskState.getState().busyAction===null");
                    string buildFailure = await ReadJson(
                        "({" +
                        "view:document.querySelector(" +
                        "'[data-build-view]').getAttribute(" +
                        "'data-build-view')," +
                        "code:MacroDeskState.getState()" +
                        ".buildResult.code," +
                        "rows:document.querySelectorAll(" +
                        "'.build-result-table tbody tr').length," +
                        "result:document.querySelector(" +
                        "'.build-result-value').textContent," +
                        "discarded:document.querySelector(" +
                        "'.build-output-discarded').textContent," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch" +
                        "})");
                    await Capture(failureScreenshot);

                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"retry-build\"]').click();");
                    await WaitFor(
                        "MacroDeskState.getState().buildResult===null && " +
                        "MacroDeskState.getState().lastError===null && " +
                        "document.querySelector(" +
                        "'[data-build-view=\"confirmation\"]')!==null");
                    string buildRetry = await ReadJson(
                        "({" +
                        "view:document.querySelector(" +
                        "'[data-build-view]').getAttribute(" +
                        "'data-build-view')," +
                        "timestamp:MacroDeskState.getState()" +
                        ".buildTimestamp," +
                        "output:document.querySelector(" +
                        "'.build-output-name').textContent" +
                        "})");
                    await Execute(
                        "window.__p7ExpectedOutputName=" +
                        "document.querySelector(" +
                        "'.build-output-name').textContent;" +
                        "window.__p7DelayNextBuild=true;" +
                        "document.querySelector(" +
                        "'[data-action=\"build-book\"]').click();");
                    await WaitFor(
                        "document.querySelector(" +
                        "'[data-build-view=\"progress\"]')!==null");
                    string buildProgress = await ReadJson(
                        "({" +
                        "view:document.querySelector(" +
                        "'[data-build-view]').getAttribute(" +
                        "'data-build-view')," +
                        "spinner:document.querySelector(" +
                        "'.build-progress-spinner')!==null," +
                        "disabled:document.querySelectorAll(" +
                        "'.progress-step:disabled').length" +
                        "})");
                    await WaitFor(
                        "MacroDeskState.getState().buildResult && " +
                        "MacroDeskState.getState().buildResult" +
                        ".status==='success' && " +
                        "MacroDeskState.getState().busyAction===null");
                    buildOutputPath = await ReadString(
                        "MacroDeskState.getState()" +
                        ".buildResult.outputPath");
                    diffOutputPath = await ReadString(
                        "MacroDeskState.getState()" +
                        ".buildResult.diffPath");
                    if (!string.Equals(
                        Path.GetDirectoryName(buildOutputPath),
                        Path.GetDirectoryName(bookPath),
                        StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException(
                            "The P7 output path is outside testdata.");
                    }
                    if (!string.Equals(
                        Path.GetDirectoryName(diffOutputPath),
                        Path.GetDirectoryName(bookPath),
                        StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException(
                            "The diff report path is outside testdata.");
                    }
                    if (!File.Exists(diffOutputPath))
                    {
                        throw new InvalidOperationException(
                            "The diff report file was not created.");
                    }
                    string buildSuccess = await ReadJson(
                        "({" +
                        "view:document.querySelector(" +
                        "'[data-build-view]').getAttribute(" +
                        "'data-build-view')," +
                        "output:document.querySelector(" +
                        "'.build-result-path').textContent," +
                        "expected:window.__p7ExpectedOutputName," +
                        "written:document.querySelectorAll(" +
                        "'.module-badge--written').length," +
                        "results:MacroDeskState.getState()" +
                        ".buildResult.results.filter(function(r){" +
                        "return r.result==='written';}).length," +
                        "diff:MacroDeskState.getState()" +
                        ".buildResult.diffPath," +
                        "diffError:MacroDeskState.getState()" +
                        ".buildResult.diffError," +
                        "reveal:document.querySelector(" +
                        "'[data-action=\"reveal-build-output\"]')" +
                        "!==null," +
                        "excel:document.querySelector(" +
                        "'.build-result-guidance').textContent," +
                        "branch:document.getElementById(" +
                        "'lecture-panel').dataset.branch," +
                        "horizontal:document.documentElement" +
                        ".scrollWidth>innerWidth" +
                        "})");
                    await Capture(successScreenshot);

                    await Execute(
                        "document.querySelector(" +
                        "'[data-action=\"reveal-build-output\"]')" +
                        ".click();");
                    await WaitFor(
                        "window.__p7RevealedPath!==null && " +
                        "MacroDeskState.getState().busyAction===null");
                    string buildReveal = await ReadString(
                        "window.__p7RevealedPath");

                    await Execute(
                        "(function(){" +
                        "var result=MacroDeskState.getState()" +
                        ".buildResult;" +
                        "window.__p6DiffErrorBuildResult={" +
                        "outputPath:result.outputPath," +
                        "results:result.results," +
                        "diffError:'Report write failed.'};" +
                        "MacroDeskState.setBuildResult(null);" +
                        "window.__p6DiffErrorNextBuild=true;" +
                        "MacroDeskApp.buildBook();" +
                        "}());");
                    await WaitFor(
                        "MacroDeskState.getState().buildResult && " +
                        "MacroDeskState.getState().buildResult" +
                        ".status==='success' && " +
                        "MacroDeskState.getState().buildResult" +
                        ".diffError && " +
                        "MacroDeskState.getState().busyAction===null && " +
                        "document.querySelector('.toast--error')!==null");
                    string diffFailure = await ReadJson(
                        "({" +
                        "view:document.querySelector(" +
                        "'[data-build-view]').getAttribute(" +
                        "'data-build-view')," +
                        "output:document.querySelector(" +
                        "'.build-result-path').textContent," +
                        "toast:document.querySelector(" +
                        "'.toast--error .toast-message').textContent," +
                        "announce:document.getElementById(" +
                        "'status-announcer').textContent," +
                        "reveal:document.querySelector(" +
                        "'[data-action=\"reveal-build-output\"]')" +
                        "!==null" +
                        "})");

                    await Execute(
                        "(async function(){" +
                        "var data=await window.__p6RealRequest(" +
                        "'attachBook',{path:" +
                        serializer.Serialize(buildOutputPath) +
                        "});" +
                        "MacroDeskState.setBook(" +
                        "data.book,data.modules);" +
                        "MacroDeskState.navigate(3);" +
                        "Object.keys(window.__p7TargetCodes)" +
                        ".forEach(function(name){" +
                        "MacroDeskApp.acceptPastedText(" +
                        "window.__p7TargetCodes[name],name);" +
                        "});" +
                        "window.__p7SelfLoopDone=true;" +
                        "}());");
                    await WaitFor(
                        "window.__p7SelfLoopDone===true && " +
                        "MacroDeskState.getState().busyAction===null");
                    string selfLoop = await ReadJson(
                        "({" +
                        "targets:Object.keys(" +
                        "window.__p7TargetCodes).length," +
                        "unchanged:Object.keys(" +
                        "window.__p7TargetCodes)" +
                        ".filter(function(name){" +
                        "return MacroDeskState.findModule(name)" +
                        ".status==='unchanged';}).length," +
                        "exact:Object.keys(" +
                        "window.__p7TargetCodes)" +
                        ".filter(function(name){" +
                        "return MacroDeskState.findModule(name)" +
                        ".code===window.__p7TargetCodes[name];" +
                        "}).length," +
                        "changed:MacroDeskState" +
                        ".getChangedModuleCount()," +
                        "step4:document.querySelector(" +
                        "'.progress-step[data-step=\"4\"]')" +
                        ".classList.contains('is-ready')" +
                        "})");

                    await NavigateTo(diffOutputPath);
                    await WaitFor(
                        "document.readyState==='complete' && " +
                        "document.querySelectorAll(" +
                        "'.module-report').length===4");
                    string diffReport = await ReadJson(
                        "({" +
                        "title:document.title," +
                        "book:document.querySelector('h1').textContent," +
                        "modules:document.querySelectorAll(" +
                        "'.module-report').length," +
                        "tables:document.querySelectorAll(" +
                        "'.diff-table').length," +
                        "newModule:Array.prototype.some.call(" +
                        "document.querySelectorAll('.module-report h2')," +
                        "function(node){return node.textContent===" +
                        "'CommonHelpers';})," +
                        "external:document.querySelectorAll(" +
                        "'link[href],script[src],img[src],iframe[src]')" +
                        ".length," +
                        "scripts:document.querySelectorAll('script').length," +
                        "styles:document.querySelectorAll('style').length," +
                        "vertical:document.body.scrollHeight>innerHeight && " +
                        "getComputedStyle(document.documentElement)" +
                        ".overflowY!=='hidden' && " +
                        "getComputedStyle(document.body)" +
                        ".overflowY!=='hidden'," +
                        "horizontal:document.documentElement.scrollWidth>" +
                        "innerWidth," +
                        "scrollers:document.querySelectorAll(" +
                        "'.diff-scroll').length," +
                        "changedRows:document.querySelectorAll(" +
                        "'.diff-row--changed,.diff-row--added," +
                        ".diff-row--removed').length," +
                        "pathLeak:document.documentElement.outerHTML" +
                        ".indexOf(" + serializer.Serialize(bookPath) +
                        ")>=0 || document.documentElement.outerHTML" +
                        ".indexOf(" +
                        serializer.Serialize(buildOutputPath) +
                        ")>=0 || document.documentElement.outerHTML" +
                        ".indexOf(" +
                        serializer.Serialize(diffOutputPath) +
                        ")>=0" +
                        "})");
                    await Capture(reportScreenshot);

                    RestoreClipboard();

                    Dictionary<string, object> result =
                        new Dictionary<string, object>();
                    result.Add("initial", initial);
                    result.Add("waiting", waiting);
                    result.Add("normal", normal);
                    result.Add("undone", undone);
                    result.Add("identical", identical);
                    result.Add("keyboard", keyboard);
                    result.Add("preserved", preserved);
                    result.Add("excludedClick", excludedClick);
                    result.Add("excludedContext", excludedContext);
                    result.Add("empty", empty);
                    result.Add("wrongModule", wrongModule);
                    result.Add("newIntake", newIntake);
                    result.Add("newModule", newModule);
                    result.Add("largeFull", largeFull);
                    result.Add("largeExpanded", largeExpanded);
                    result.Add("largeWrapped", largeWrapped);
                    result.Add("largeContext", largeContext);
                    result.Add(
                        "buildConfirmation",
                        buildConfirmation);
                    result.Add("buildFailure", buildFailure);
                    result.Add("buildRetry", buildRetry);
                    result.Add("buildProgress", buildProgress);
                    result.Add("buildSuccess", buildSuccess);
                    result.Add("buildReveal", buildReveal);
                    result.Add("diffFailure", diffFailure);
                    result.Add("diffReport", diffReport);
                    result.Add("selfLoop", selfLoop);
                    result.Add("buildOutputPath", buildOutputPath);
                    result.Add("diffOutputPath", diffOutputPath);
                    result.Add("originalCode", originalCode);
                    result.Add("changedCode", changedCode);
                    result.Add("additionCode", additionCode);
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
                await Execute(
                    "window.__p6Logs=[];" +
                    "window.__p7FailNextBuild=false;" +
                    "window.__p7DelayNextBuild=false;" +
                    "window.__p7RevealedPath=null;" +
                    "window.__p6DiffErrorNextBuild=false;" +
                    "window.__p6DiffErrorBuildResult=null;" +
                    "window.__p6RealRequest=hostBridge.request;" +
                    "hostBridge.request=function(action,params){" +
                    "if(action==='writeLog'){" +
                    "window.__p6Logs.push(params.message);" +
                    "return Promise.resolve({});" +
                    "}" +
                    "if(action==='revealPath'){" +
                    "window.__p7RevealedPath=params.path;" +
                    "return Promise.resolve({});" +
                    "}" +
                    "if(action==='buildBook'&&" +
                    "window.__p7FailNextBuild){" +
                    "window.__p7FailNextBuild=false;" +
                    "var e=new Error('Verification failed.');" +
                    "e.code='E-BUILD-02';" +
                    "e.data={outputPath:'',results:[{" +
                    "name:'TimerUtils'," +
                    "result:'verify_failed'," +
                    "message:'Verification failed.'}]};" +
                    "return Promise.reject(e);" +
                    "}" +
                    "if(action==='buildBook'&&" +
                    "window.__p6DiffErrorNextBuild){" +
                    "window.__p6DiffErrorNextBuild=false;" +
                    "return Promise.resolve(" +
                    "window.__p6DiffErrorBuildResult);" +
                    "}" +
                    "if(action==='buildBook'&&" +
                    "window.__p7DelayNextBuild){" +
                    "window.__p7DelayNextBuild=false;" +
                    "return new Promise(function(resolve,reject){" +
                    "setTimeout(function(){" +
                    "window.__p6RealRequest(action,params)" +
                    ".then(resolve,reject);},500);});" +
                    "}" +
                    "return window.__p6RealRequest(action,params);" +
                    "};");
            }

            private async Task InstallLargeModule()
            {
                await Execute(
                    "(function(){" +
                    "var m=MacroDeskState.findModule('WindowUtils');" +
                    "var a=[];var b=[];var i;" +
                    "for(i=1;i<=5001;i+=1){" +
                    "a.push(\"' Line \"+i);" +
                    "b.push(\"' Line \"+i);" +
                    "}" +
                    "b[2500]=\"' Changed line\";" +
                    "m.code=a.join('\\r\\n')+'\\r\\n';" +
                    "m.pastedCode=b.join('\\r\\n')+'\\r\\n';" +
                    "m.status='changed';" +
                    "m.changedLineCount=1;" +
                    "m.showChangesOnly=true;" +
                    "m.written=false;" +
                    "MacroDeskState.selectModule('WindowUtils');" +
                    "}());");
            }

            private async Task ClickModule(string name)
            {
                string nameJson = serializer.Serialize(name);
                await Execute(
                    "document.querySelector(" +
                    "'[data-module-name='+" + nameJson + "+']')" +
                    ".click();");
                await WaitFor(
                    "MacroDeskState.getState().selectedModuleName === " +
                    nameJson);
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

            private async Task<string> ReadString(string expression)
            {
                string json = await ReadJson(expression);
                return serializer.Deserialize<string>(json);
            }

            private async Task WaitFor(string expression)
            {
                int attempt;
                for (attempt = 0; attempt < 500; attempt++)
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
                    "The P6 browser condition timed out: " +
                    expression);
            }

            private async Task NavigateTo(string path)
            {
                TaskCompletionSource<bool> completion =
                    new TaskCompletionSource<bool>();
                EventHandler<CoreWebView2NavigationCompletedEventArgs>
                    handler = null;
                handler = delegate(
                    object sender,
                    CoreWebView2NavigationCompletedEventArgs e)
                {
                    webView.CoreWebView2.NavigationCompleted -= handler;
                    if (e.IsSuccess)
                    {
                        completion.TrySetResult(true);
                    }
                    else
                    {
                        completion.TrySetException(
                            new InvalidOperationException(
                                "The diff report navigation failed."));
                    }
                };
                webView.CoreWebView2.NavigationCompleted += handler;
                webView.CoreWebView2.Navigate(
                    new Uri(Path.GetFullPath(path)).AbsoluteUri);
                await completion.Task;
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

            private void CaptureClipboard()
            {
                originalClipboard = Clipboard.GetDataObject();
                clipboardCaptured = true;
            }

            private void SetClipboardText(string text)
            {
                int attempt;
                Exception lastError = null;

                for (attempt = 0; attempt < 40; attempt++)
                {
                    try
                    {
                        Clipboard.SetText(text);
                        clipboardChanged = true;
                        return;
                    }
                    catch (Exception ex)
                    {
                        lastError = ex;
                        Thread.Sleep(50);
                    }
                }
                throw new InvalidOperationException(
                    "The P6 test could not set clipboard text.",
                    lastError);
            }

            private void RestoreClipboard()
            {
                int attempt;
                Exception lastError = null;

                if (!clipboardCaptured || !clipboardChanged)
                {
                    return;
                }

                for (attempt = 0; attempt < 40; attempt++)
                {
                    try
                    {
                        if (originalClipboard == null)
                        {
                            Clipboard.Clear();
                        }
                        else
                        {
                            Clipboard.SetDataObject(
                                originalClipboard,
                                true);
                        }
                        clipboardChanged = false;
                        return;
                    }
                    catch (Exception ex)
                    {
                        lastError = ex;
                        Thread.Sleep(50);
                    }
                }
                throw new InvalidOperationException(
                    "The P6 test could not restore clipboard data.",
                    lastError);
            }

            private void OnTimeout(object sender, EventArgs e)
            {
                Fail(new TimeoutException(
                    "The P6 WebView smoke test timed out."));
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
                    RestoreClipboard();
                }
                catch
                {
                }

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
                    if (!string.IsNullOrEmpty(buildOutputPath) &&
                        File.Exists(buildOutputPath))
                    {
                        File.Delete(buildOutputPath);
                    }
                    if (!string.IsNullOrEmpty(diffOutputPath) &&
                        File.Exists(diffOutputPath))
                    {
                        File.Delete(diffOutputPath);
                    }
                }
                catch
                {
                }
            }
        }
    }
}
