using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;

namespace MacroDesk
{
    public class MainWindow : Window
    {
        private readonly Grid rootGrid;
        private readonly WebView2 webView;
        private Border loadingOverlay;
        private HostServices hostServices;
        private MessageRouter messageRouter;

        public MainWindow()
        {
            Title = "MacroDesk";
            Width = 1200;
            Height = 740;
            MinWidth = 1100;
            MinHeight = 700;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = new SolidColorBrush(Color.FromRgb(20, 22, 28));
            AllowDrop = true;

            rootGrid = new Grid();
            rootGrid.AllowDrop = true;

            webView = new WebView2();
            webView.AllowExternalDrop = false;
            webView.DefaultBackgroundColor = System.Drawing.Color.FromArgb(20, 22, 28);
            webView.Visibility = Visibility.Hidden;
            rootGrid.Children.Add(webView);

            loadingOverlay = CreateLoadingOverlay();
            rootGrid.Children.Add(loadingOverlay);
            Content = rootGrid;

            AddHandler(
                DragDrop.PreviewDragOverEvent,
                new DragEventHandler(OnPreviewDragOver),
                true);
            AddHandler(
                DragDrop.PreviewDropEvent,
                new DragEventHandler(OnPreviewDrop),
                true);

            PreviewKeyDown += OnPreviewKeyDown;
            webView.PreviewKeyDown += OnPreviewKeyDown;
            Loaded += OnLoaded;
            Closing += OnClosing;
            Closed += OnClosed;
        }

        private Border CreateLoadingOverlay()
        {
            Border overlay = new Border();
            overlay.Background = new SolidColorBrush(Color.FromRgb(20, 22, 28));

            TextBlock text = new TextBlock();
            text.Text = "Loading...";
            text.HorizontalAlignment = HorizontalAlignment.Center;
            text.VerticalAlignment = VerticalAlignment.Center;
            text.Foreground = new SolidColorBrush(Color.FromRgb(148, 156, 176));
            text.FontSize = 13;
            overlay.Child = text;

            return overlay;
        }

        private async void OnLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                string userDataFolder = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "MacroDesk",
                    "WebView2Cache");

                CoreWebView2Environment environment =
                    await CoreWebView2Environment.CreateAsync(null, userDataFolder, null);
                await webView.EnsureCoreWebView2Async(environment);

                webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
                webView.CoreWebView2.Settings.AreDevToolsEnabled = true;
                webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                    "macrodesk.local",
                    Path.Combine(App.BaseDir, "assets"),
                    CoreWebView2HostResourceAccessKind.Allow);

                hostServices = new HostServices(this, App.BaseDir);
                WriteLifecycleLog("startup");
                messageRouter = new MessageRouter(
                    webView,
                    hostServices);
                webView.CoreWebView2.WebMessageReceived +=
                    messageRouter.OnWebMessageReceived;
                webView.CoreWebView2.NavigationCompleted += OnFirstNavigationCompleted;
                webView.CoreWebView2.Navigate("https://macrodesk.local/index.html");
            }
            catch (Exception ex)
            {
                Close();
                App.ShowStartupMessage("webview-init-error.txt", ex);
            }
        }

        private void OnClosing(
            object sender,
            System.ComponentModel.CancelEventArgs e)
        {
            WriteLifecycleLog("shutdown");
        }

        private void OnClosed(object sender, EventArgs e)
        {
            if (webView.CoreWebView2 != null &&
                messageRouter != null)
            {
                webView.CoreWebView2.WebMessageReceived -=
                    messageRouter.OnWebMessageReceived;
            }
            webView.Dispose();
        }

        private void WriteLifecycleLog(string action)
        {
            if (hostServices == null)
            {
                return;
            }

            try
            {
                hostServices.WriteLog(
                    "INFO",
                    action + ": " + App.BaseDir);
            }
            catch
            {
            }
        }

        private void OnFirstNavigationCompleted(
            object sender,
            CoreWebView2NavigationCompletedEventArgs e)
        {
            webView.CoreWebView2.NavigationCompleted -= OnFirstNavigationCompleted;
            Dispatcher.BeginInvoke(new Action(delegate()
            {
                webView.Visibility = Visibility.Visible;
                if (loadingOverlay != null)
                {
                    rootGrid.Children.Remove(loadingOverlay);
                    loadingOverlay = null;
                }
            }));
        }

        private void OnPreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.F12 && webView.CoreWebView2 != null)
            {
                webView.CoreWebView2.OpenDevToolsWindow();
                e.Handled = true;
            }
        }

        private void OnPreviewDragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
                e.Handled = true;
            }
        }

        private void OnPreviewDrop(object sender, DragEventArgs e)
        {
            if (!e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                return;
            }

            e.Handled = true;
            string[] paths = e.Data.GetData(DataFormats.FileDrop) as string[];
            if (paths == null ||
                paths.Length == 0 ||
                messageRouter == null)
            {
                return;
            }

            Dictionary<string, object> data =
                new Dictionary<string, object>();
            data.Add("path", paths[0]);
            messageRouter.PushEvent("bookDropped", data);
        }
    }
}
