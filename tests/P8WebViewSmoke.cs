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
    public static class P8WebViewSmoke
    {
        public static string Run(
            string baseDir,
            string cacheDir,
            string presetScreenshot,
            string guidedScreenshot,
            string errorScreenshot)
        {
            SmokeRunner runner = new SmokeRunner(
                baseDir,
                cacheDir,
                presetScreenshot,
                guidedScreenshot,
                errorScreenshot);
            Thread thread = new Thread(runner.Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();

            if (!thread.Join(90000))
            {
                throw new TimeoutException(
                    "The P8 WebView smoke test did not stop.");
            }
            if (runner.Error != null)
            {
                throw new InvalidOperationException(
                    "The P8 WebView smoke test failed.",
                    runner.Error);
            }
            return runner.Result;
        }

        private sealed class SmokeRunner
        {
            private readonly string baseDir;
            private readonly string cacheDir;
            private readonly string presetScreenshot;
            private readonly string guidedScreenshot;
            private readonly string errorScreenshot;

            private Application application;
            private Window window;
            private WebView2 webView;
            private DispatcherTimer timeoutTimer;
            private JavaScriptSerializer serializer;

            public string Result;
            public Exception Error;

            public SmokeRunner(
                string baseDir,
                string cacheDir,
                string presetScreenshot,
                string guidedScreenshot,
                string errorScreenshot)
            {
                this.baseDir = Path.GetFullPath(baseDir);
                this.cacheDir = Path.GetFullPath(cacheDir);
                this.presetScreenshot = Path.GetFullPath(
                    presetScreenshot);
                this.guidedScreenshot = Path.GetFullPath(
                    guidedScreenshot);
                this.errorScreenshot = Path.GetFullPath(
                    errorScreenshot);
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
                        "The P8 test page navigation failed."));
                    return;
                }

                try
                {
                    await WaitFor(
                        "window.MacroDeskApp && " +
                        "document.querySelector('.screen')");
                    await InstallTestHelpers();

                    Dictionary<string, object> result =
                        new Dictionary<string, object>();
                    Dictionary<string, string> guided =
                        new Dictionary<string, string>();
                    Dictionary<string, string> errors =
                        new Dictionary<string, string>();
                    Dictionary<string, string> builds =
                        new Dictionary<string, string>();

                    string themeLight = await ReadThemeMetrics();
                    await Execute(
                        "document.getElementById('theme-toggle').click();");
                    string themeDark = await ReadThemeMetrics();
                    string themeRestored;

                    await Execute("window.__p8SetBase();");
                    guided.Add("step1Unattached", await ReadMetrics());

                    await Execute(
                        "MacroDeskState.setBook(" +
                        "window.__p8Book,window.__p8Modules());");
                    guided.Add("step1Attached", await ReadMetrics());

                    await Execute("MacroDeskState.navigate(2);");
                    guided.Add("step2Empty", await ReadMetrics());
                    await Capture(presetScreenshot);
                    await Execute(
                        "MacroDeskState.setAppInfo(" +
                        "{version:'1.0',presets:[]});");
                    guided.Add(
                        "step2EmptyNoPresets",
                        await ReadMetrics());
                    await Execute(
                        "MacroDeskState.setAppInfo(" +
                        "window.__p8AppInfo);");
                    await Execute(
                        "document.getElementById('theme-toggle').click();");
                    themeRestored = await ReadThemeMetrics();

                    await Execute(
                        "MacroDeskState.setRequestText(" +
                        "'Please change the macro.');");
                    guided.Add("step2Text", await ReadMetrics());

                    await Execute(
                        "MacroDeskState.setRequestFilePath(" +
                        "'output\\\\request.txt');");
                    guided.Add("step2Created", await ReadMetrics());

                    await Execute(
                        "window.__p8SetBase();" +
                        "MacroDeskState.setBook(" +
                        "window.__p8Book,window.__p8Modules());" +
                        "MacroDeskState.navigate(3);");
                    guided.Add("step3Unselected", await ReadMetrics());

                    await Execute(
                        "MacroDeskState.selectModule('ModuleA');");
                    guided.Add("step3Selected", await ReadMetrics());

                    await Execute(
                        "MacroDeskState.acceptModuleCode(" +
                        "'ModuleA','Option Explicit\\r\\n" +
                        "Public Sub Test(): End Sub\\r\\n',1);");
                    guided.Add(
                        "step3ChangedPending",
                        await ReadMetrics());
                    await Capture(guidedScreenshot);

                    await Execute(
                        "MacroDeskState.toggleModuleExcluded(" +
                        "'ModuleB');" +
                        "MacroDeskState.toggleModuleExcluded(" +
                        "'ModuleC');");
                    guided.Add(
                        "step3ChangedComplete",
                        await ReadMetrics());

                    await Execute(
                        "window.__p8SetBase();" +
                        "MacroDeskState.setBook(" +
                        "window.__p8Book,window.__p8Modules());" +
                        "MacroDeskState.navigate(3);" +
                        "MacroDeskState.toggleModuleExcluded('ModuleA');" +
                        "MacroDeskState.toggleModuleExcluded('ModuleB');" +
                        "MacroDeskState.toggleModuleExcluded('ModuleC');");
                    guided.Add(
                        "step3NoChange",
                        await ReadMetrics());

                    await Execute(
                        "window.__p8SetBase();" +
                        "MacroDeskState.setBook(" +
                        "window.__p8Book,window.__p8Modules());" +
                        "MacroDeskState.navigate(3);" +
                        "MacroDeskState.acceptModuleCode(" +
                        "'ModuleA','Option Explicit\\r\\n" +
                        "Public Sub Test(): End Sub\\r\\n',1);" +
                        "MacroDeskState.toggleModuleExcluded('ModuleB');" +
                        "MacroDeskState.toggleModuleExcluded('ModuleC');" +
                        "MacroDeskApp.prepareBuildConfirmation();" +
                        "MacroDeskState.navigate(4);");
                    guided.Add("step4Confirmation", await ReadMetrics());

                    string[] buildCodes = new string[]
                    {
                        "E-BUILD-01",
                        "E-BUILD-02",
                        "E-BUILD-03"
                    };
                    int index;
                    for (index = 0; index < buildCodes.Length; index++)
                    {
                        string code = buildCodes[index];
                        await Execute(
                            "MacroDeskState.setLectureCollapsed(true);" +
                            "window.__p8BuildCode='" + code + "';" +
                            "MacroDeskApp.buildBook();");
                        await WaitFor(
                            "MacroDeskState.getState().buildResult && " +
                            "MacroDeskState.getState().buildResult.code===" +
                            "'" + code + "' && " +
                            "MacroDeskState.getState().busyAction===null");
                        builds.Add(code, await ReadMetrics());
                        if (code == "E-BUILD-02")
                        {
                            await Capture(errorScreenshot);
                        }
                        await Execute(
                            "document.querySelector(" +
                            "'[data-action=\"retry-build\"]').click();");
                        await WaitFor(
                            "MacroDeskState.getState().buildResult===null");
                    }

                    await Execute(
                        "MacroDeskState.setBuildResult({" +
                        "status:'success'," +
                        "outputPath:'output\\\\output.xlsm'," +
                        "results:[]});" +
                        "MacroDeskState.setLastError(null);");
                    guided.Add("step4Success", await ReadMetrics());

                    string[] errorCodes = new string[]
                    {
                        "E-ATTACH-02",
                        "E-ATTACH-03",
                        "E-GEN-01",
                        "E-GEN-02",
                        "E-SYS-01",
                        "E-SYS-02"
                    };
                    for (index = 0; index < errorCodes.Length; index++)
                    {
                        string code = errorCodes[index];
                        await Execute(
                            "window.__p8SetBase();" +
                            "MacroDeskState.setLectureCollapsed(true);" +
                            "MacroDeskApp.handleHostError({" +
                            "code:'" + code + "'," +
                            "message:'RAW HOST DETAIL'}," +
                            "'samples\\\\sample.xlsm');");
                        errors.Add(code, await ReadMetrics());
                    }

                    await Execute(
                        "window.__p8SetBase();" +
                        "MacroDeskState.setBook(" +
                        "window.__p8Book,window.__p8Modules());" +
                        "MacroDeskState.navigate(3);" +
                        "MacroDeskState.selectModule('ModuleA');" +
                        "MacroDeskState.setLectureCollapsed(true);" +
                        "MacroDeskApp.acceptPastedText(''," +
                        "'ModuleA');");
                    errors.Add("E-PASTE-01", await ReadMetrics());

                    result.Add("guided", guided);
                    result.Add("errors", errors);
                    result.Add("builds", builds);
                    result.Add("themeLight", themeLight);
                    result.Add("themeDark", themeDark);
                    result.Add("themeRestored", themeRestored);
                    result.Add(
                        "logRecords",
                        await ReadJson("window.__p8Logs"));
                    result.Add(
                        "lectureRender",
                        await ReadLectureMatrix());
                    Result = serializer.Serialize(result);
                    Stop();
                }
                catch (Exception ex)
                {
                    Fail(ex);
                }
            }

            private async Task InstallTestHelpers()
            {
                await Execute(
                    "window.__p8Logs=[];" +
                    "window.__p8BuildCode=null;" +
                    "hostBridge.request=function(action,params){" +
                    "if(action==='writeLog'){" +
                    "window.__p8Logs.push(params);" +
                    "return Promise.resolve({});" +
                    "}" +
                    "if(action==='buildBook'){" +
                    "var code=window.__p8BuildCode||'E-BUILD-01';" +
                    "var e=new Error('RAW BUILD DETAIL');" +
                    "e.code=code;" +
                    "e.data={outputPath:'',results:[{" +
                    "name:'ModuleA',result:code==='E-BUILD-02'?" +
                    "'verify_failed':'io_error'," +
                    "message:'RAW RESULT DETAIL'}]};" +
                    "return Promise.reject(e);" +
                    "}" +
                    "return Promise.resolve({});" +
                    "};" +
                    "window.__p8Book={" +
                    "name:'sample.xlsm'," +
                    "path:'samples\\\\sample.xlsm'," +
                    "ext:'.xlsm',totalLines:6};" +
                    "window.__p8Modules=function(){return[" +
                    "{name:'ModuleA',type:'standard'," +
                    "typeLabel:'Standard module',lineCount:2," +
                    "attributes:'Attribute VB_Name = " +
                    "\\\"ModuleA\\\"\\r\\n'," +
                    "code:'Option Explicit\\r\\n" +
                    "Public Sub Test(): Debug.Print 1: End Sub\\r\\n'}," +
                    "{name:'ModuleB',type:'standard'," +
                    "typeLabel:'Standard module',lineCount:2," +
                    "attributes:'Attribute VB_Name = " +
                    "\\\"ModuleB\\\"\\r\\n'," +
                    "code:'Option Explicit\\r\\n" +
                    "Public Sub TestB(): End Sub\\r\\n'}," +
                    "{name:'ModuleC',type:'standard'," +
                    "typeLabel:'Standard module',lineCount:2," +
                    "attributes:'Attribute VB_Name = " +
                    "\\\"ModuleC\\\"\\r\\n'," +
                    "code:'Option Explicit\\r\\n" +
                    "Public Sub TestC(): End Sub\\r\\n'}" +
                    "];};" +
                    "window.__p8AppInfo={version:'1.0'," +
                    "buildFileLabel:'\\u6539\\u4FEE\\u6E08'," +
                    "presets:[" +
                    "{name:'Preset A',file:'a.md'}," +
                    "{name:'Preset B',file:'b.md'}]};" +
                    "window.__p8SetBase=function(){" +
                    "MacroDeskState.reset();" +
                    "MacroDeskState.setAppInfo(window.__p8AppInfo);" +
                    "};");
            }

            private async Task<string> ReadMetrics()
            {
                return await ReadJson(
                    "(function(){" +
                    "var q=function(s){return document.querySelector(s);};" +
                    "var guided=[].slice.call(" +
                    "document.querySelectorAll('.is-guided-target'));" +
                    "var active=document.activeElement;" +
                    "var focus=active?getComputedStyle(active):null;" +
                    "var panel=q('#lecture-panel');" +
                    "var toast=q('.toast');" +
                    "var card=q('.inline-error-card');" +
                    "var build=q('[data-build-view]');" +
                    "var focusRule=false;" +
                    "[].slice.call(document.styleSheets)" +
                    ".forEach(function(sheet){" +
                    "[].slice.call(sheet.cssRules||[])" +
                    ".forEach(function(rule){" +
                    "if(rule.selectorText&&" +
                    "rule.selectorText.indexOf(" +
                    "'button:focus-visible')>=0&&" +
                    "rule.style&&rule.style.outline){" +
                    "focusRule=true;}});});" +
                    "return {" +
                    "step:MacroDeskState.getState().currentStep," +
                    "guided:guided.length," +
                    "guidedAction:guided.map(function(x){" +
                    "return x.getAttribute('data-action')||" +
                    "x.getAttribute('data-step')||" +
                    "x.getAttribute('data-module-name')||" +
                    "(x.querySelector('[data-module-name]')&&" +
                    "x.querySelector('[data-module-name]')" +
                    ".getAttribute('data-module-name'))||" +
                    "x.className;}).join('|')," +
                    "step4Ready:q('.progress-step[data-step=\"4\"]')" +
                    ".classList.contains('is-ready')," +
                    "step4Guided:q('.progress-step[data-step=\"4\"]')" +
                    ".classList.contains('is-guided-target')," +
                    "doneBar:q('.step-done-bar')!==null," +
                    "branch:panel.dataset.branch," +
                    "errorCode:panel.getAttribute('data-error-code')||'',"+
                    "title:q('#lecture-title').textContent," +
                    "body:q('#lecture-body').textContent," +
                    "collapsed:MacroDeskState.getState()" +
                    ".lectureCollapsed," +
                    "toast:toast?toast.textContent:''," +
                    "toastRole:toast?toast.getAttribute('role'):''," +
                    "card:card?card.textContent:''," +
                    "cardRole:card?card.getAttribute('role'):''," +
                    "buildView:build?build.getAttribute(" +
                    "'data-build-view'):''," +
                    "activeAction:active&&active.getAttribute?" +
                    "active.getAttribute('data-action')||'':''," +
                    "focusOutline:focus?focus.outlineStyle:''," +
                    "focusRule:focusRule," +
                    "font:getComputedStyle(document.body).fontFamily," +
                    "horizontal:document.documentElement.scrollWidth>" +
                    "innerWidth" +
                    "};}())");
            }

            private async Task<string> ReadThemeMetrics()
            {
                return await ReadJson(
                    "({" +
                    "theme:document.documentElement" +
                    ".getAttribute('data-theme')," +
                    "stored:localStorage.getItem('macrodesk.theme')," +
                    "background:getComputedStyle(document.body)" +
                    ".backgroundColor," +
                    "label:document.getElementById('theme-toggle')" +
                    ".getAttribute('aria-label')," +
                    "announced:document.getElementById(" +
                    "'status-announcer').textContent," +
                    "visibleIcons:document.querySelectorAll(" +
                    "'#theme-toggle .theme-icon:not([hidden])').length," +
                    "guided:document.getElementById('theme-toggle')" +
                    ".classList.contains('is-guided-target')" +
                    "})");
            }

            private async Task<string> ReadLectureMatrix()
            {
                return await ReadJson(
                    "(function(){" +
                    "var keys=Object.keys(" +
                    "MacroDeskLecture.contentByKey);" +
                    "var errors=Object.keys(" +
                    "MacroDeskLecture.errorContentByCode);" +
                    "return {branches:keys.length,errors:errors.length," +
                    "branchLines:keys.every(function(key){" +
                    "var n=MacroDeskLecture.contentByKey[key]" +
                    ".body.split('\\n').length;" +
                    "return n>=2&&n<=4;})," +
                    "errorLines:errors.every(function(key){" +
                    "var n=MacroDeskLecture.errorContentByCode[key]" +
                    ".body.split('\\n').length;" +
                    "return n>=2&&n<=4;})};}())");
            }

            private async Task Execute(string script)
            {
                await webView.CoreWebView2.ExecuteScriptAsync(script);
                await Task.Delay(40);
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
                    "The P8 browser condition timed out: " +
                    expression);
            }

            private async Task Capture(string path)
            {
                await Task.Delay(120);
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
                    "The P8 WebView smoke test timed out."));
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
