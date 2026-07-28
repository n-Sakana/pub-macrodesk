using System;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows;
using Microsoft.Web.WebView2.Core;

namespace MacroDesk
{
    public static class App
    {
        public static string BaseDir;

        [STAThread]
        public static void Run(string baseDir)
        {
            BaseDir = Path.GetFullPath(baseDir);

            string libDir = Path.Combine(BaseDir, "lib");
            AppDomain.CurrentDomain.AssemblyResolve += delegate(object sender, ResolveEventArgs args)
            {
                string assemblyName = new AssemblyName(args.Name).Name;

                // macrodesk.ps1 loads the WebView2 assemblies from their bytes,
                // which leaves them outside the default binding context. Hand
                // back the copy that is already loaded rather than loading a
                // second one, otherwise the same type would exist twice.
                Assembly[] loaded = AppDomain.CurrentDomain.GetAssemblies();
                for (int i = 0; i < loaded.Length; i++)
                {
                    if (string.Equals(
                        loaded[i].GetName().Name,
                        assemblyName,
                        StringComparison.OrdinalIgnoreCase))
                    {
                        return loaded[i];
                    }
                }

                string assemblyPath = Path.Combine(libDir, assemblyName + ".dll");
                if (File.Exists(assemblyPath))
                {
                    // Bytes rather than the path, so a Mark of the Web on a
                    // zip-downloaded copy cannot block the load.
                    return Assembly.Load(File.ReadAllBytes(assemblyPath));
                }

                return null;
            };

            if (!IsWebView2Available())
            {
                ShowStartupMessage("e-sys-01.txt", null);
                return;
            }

            Exception startupError = null;
            Thread thread = new Thread(delegate()
            {
                try
                {
                    Application application = new Application();
                    application.ShutdownMode = ShutdownMode.OnMainWindowClose;
                    application.Run(new MainWindow());
                }
                catch (Exception ex)
                {
                    startupError = ex;
                }
            });

            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
            thread.Join();

            if (startupError != null)
            {
                ShowStartupMessage("webview-init-error.txt", startupError);
            }
        }

        public static void ShowStartupMessage(string fileName, Exception error)
        {
            WriteStartupError(fileName, error);

            string messagePath = Path.Combine(BaseDir, "assets", "messages", fileName);
            string message = "MacroDesk could not start.";
            if (File.Exists(messagePath))
            {
                message = File.ReadAllText(messagePath, Encoding.UTF8).Trim();
            }

            if (error != null)
            {
                message = message + Environment.NewLine + Environment.NewLine + error.Message;
            }

            MessageBox.Show(
                message,
                "MacroDesk",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }

        private static void WriteStartupError(
            string fileName,
            Exception error)
        {
            try
            {
                string code = string.Equals(
                    fileName,
                    "e-sys-01.txt",
                    StringComparison.OrdinalIgnoreCase) ?
                    "E-SYS-01" :
                    "E-SYS-02";
                string detail = error == null ?
                    "WebView2 runtime is unavailable." :
                    error.ToString();
                HostServices services = new HostServices(
                    null,
                    BaseDir);
                services.WriteLog(
                    "ERROR",
                    "startup error: " + code + " " + detail);
            }
            catch
            {
            }
        }

        private static bool IsWebView2Available()
        {
            try
            {
                string version = CoreWebView2Environment.GetAvailableBrowserVersionString();
                return !string.IsNullOrEmpty(version);
            }
            catch
            {
                return false;
            }
        }
    }
}
