using System;
using Microsoft.Web.WebView2.Core;

namespace MacroStudio
{
    // The edge between the host and the page.
    //
    // The page is part of the product: it is served from one virtual host
    // and it is the only thing allowed to ask the host to do work or to
    // take the window somewhere. Everything else - another origin, a
    // remote page, a local file, a data URI, a second window, a frame -
    // is refused here rather than half-trusted further in.
    //
    // Both the product and the WebView2 tests go through this one class,
    // so what is tested is what ships.
    public static class WebViewSecurity
    {
        public const string TrustedHost = "macrostudio.local";
        public const string TrustedScheme = "https";
        public static readonly string TrustedOrigin =
            TrustedScheme + "://" + TrustedHost;
        public static readonly string StartPage =
            TrustedOrigin + "/index.html";

        // There is no exception for startup. This was measured rather
        // than assumed: tests\test-webview-security.ps1 records every
        // navigation the runtime asks for while the window comes up, and
        // the only one is the product page itself. No about:blank or other
        // pre-load navigation reaches the handler, so nothing needs to be
        // tolerated and no temporary allowance is carried.

        // Whether a message or a navigation comes from the product page.
        //
        // Scheme, host and port must all be the canonical ones. A prefix
        // test would accept https://macrostudio.local.example.com/ and
        // https://macrostudio.local:8443/, which are different origins
        // that anybody could stand up.
        public static bool IsTrustedSource(string source)
        {
            Uri uri;

            if (string.IsNullOrEmpty(source))
            {
                return false;
            }
            if (!Uri.TryCreate(source, UriKind.Absolute, out uri))
            {
                return false;
            }
            if (!string.Equals(
                uri.Scheme,
                TrustedScheme,
                StringComparison.Ordinal))
            {
                return false;
            }
            if (!string.Equals(
                uri.Host,
                TrustedHost,
                StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
            if (!uri.IsDefaultPort)
            {
                return false;
            }
            // An origin never carries credentials. Something that does is
            // not the product page.
            if (!string.IsNullOrEmpty(uri.UserInfo))
            {
                return false;
            }
            return true;
        }

        // Locks the window down and installs the refusals. The log
        // callback records what was refused; it may be null.
        public static void Apply(CoreWebView2 core, Action<string> log)
        {
            if (core == null)
            {
                throw new ArgumentNullException("core");
            }

            CoreWebView2Settings settings = core.Settings;

            settings.AreDefaultContextMenusEnabled = false;
            settings.AreDevToolsEnabled = false;
            // F12, Ctrl+Shift+I, Ctrl+R, Ctrl+P and the rest of the
            // browser keys. Text editing keys (Ctrl+C/V/X/A) are not
            // browser accelerators and keep working, which the intake
            // screen depends on.
            settings.AreBrowserAcceleratorKeysEnabled = false;
            // The app adds no host object, so nothing legitimate asks for
            // one.
            settings.AreHostObjectsAllowed = false;
            settings.IsStatusBarEnabled = false;
            // Web messages are how the page asks the host to work, so
            // this one stays on. Which messages are believed is decided
            // by IsTrustedSource.
            settings.IsWebMessageEnabled = true;

            core.NavigationStarting += delegate(
                object sender,
                CoreWebView2NavigationStartingEventArgs e)
            {
                if (IsTrustedSource(e.Uri))
                {
                    return;
                }
                e.Cancel = true;
                Report(log, "navigation refused: " + Describe(e.Uri));
            };

            core.FrameNavigationStarting += delegate(
                object sender,
                CoreWebView2NavigationStartingEventArgs e)
            {
                // The app has no frames. Anything that appears in one is
                // not part of the product.
                if (IsTrustedSource(e.Uri))
                {
                    return;
                }
                e.Cancel = true;
                Report(log, "frame navigation refused: " + Describe(e.Uri));
            };

            core.NewWindowRequested += delegate(
                object sender,
                CoreWebView2NewWindowRequestedEventArgs e)
            {
                // Handled with no window created and nothing handed to
                // the system browser: the app has no feature that opens a
                // second window.
                e.Handled = true;
                Report(log, "new window refused: " + Describe(e.Uri));
            };
        }

        // Refused targets are recorded, but a hostile URI is not copied
        // into the log at full length.
        public static string Describe(string uri)
        {
            if (string.IsNullOrEmpty(uri))
            {
                return "(empty)";
            }
            if (uri.Length > 200)
            {
                return uri.Substring(0, 200) + "...";
            }
            return uri;
        }

        private static void Report(Action<string> log, string message)
        {
            if (log == null)
            {
                return;
            }

            try
            {
                log(message);
            }
            catch (Exception)
            {
                // Refusing is the point; failing to write it down must
                // not undo the refusal.
            }
        }
    }
}
