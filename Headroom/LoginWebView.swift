import SwiftUI
import WebKit

/// A WebView that loads claude.ai login, monitors cookies for the sessionKey,
/// and calls back when authentication succeeds.
struct LoginWebView: NSViewRepresentable {
    let onSessionKey: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionKey: onSessionKey)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

        context.coordinator.mainWebView = webView

        // Load Claude login page
        if let url = URL(string: "https://claude.ai/login") {
            webView.load(URLRequest(url: url))
        }

        // Start polling cookies
        context.coordinator.startCookiePolling(webView: webView)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onSessionKey: (String) -> Void
        private var cookieTimer: Timer?
        private var foundSession = false
        weak var mainWebView: WKWebView?
        private var popupWindow: NSWindow?
        private var popupWebView: WKWebView?

        init(onSessionKey: @escaping (String) -> Void) {
            self.onSessionKey = onSessionKey
        }

        func startCookiePolling(webView: WKWebView) {
            cookieTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak webView] _ in
                guard let self = self, !self.foundSession, let webView = webView else { return }
                self.checkCookies(webView: webView)
            }
        }

        private func checkCookies(webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.foundSession else { return }

                for cookie in cookies {
                    if cookie.name == "sessionKey" && cookie.domain.contains("claude") {
                        self.foundSession = true
                        self.cookieTimer?.invalidate()
                        self.cookieTimer = nil

                        DispatchQueue.main.async {
                            self.closePopup()
                            self.onSessionKey(cookie.value)
                        }
                        return
                    }
                }
            }
        }

        private func closePopup() {
            popupWindow?.close()
            popupWindow = nil
            popupWebView = nil
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(webView: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate

        /// Handle window.open() / target="_blank" for OAuth popups.
        /// Creates a real popup window with its own WebView sharing the same data store.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Create a popup WebView using the provided configuration
            // (this shares the same WKProcessPool and data store)
            let popupWebView = WKWebView(frame: .zero, configuration: configuration)
            popupWebView.navigationDelegate = self
            popupWebView.uiDelegate = self
            popupWebView.customUserAgent =
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Sign in with Google"
            window.contentView = popupWebView
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)

            self.popupWindow = window
            self.popupWebView = popupWebView

            return popupWebView
        }

        /// Handle the popup requesting to close itself (window.close())
        func webViewDidClose(_ webView: WKWebView) {
            if webView == popupWebView {
                closePopup()
                // Check cookies on the main webview -- the OAuth may have completed
                if let mainWebView = mainWebView {
                    checkCookies(webView: mainWebView)
                }
            }
        }

        deinit {
            cookieTimer?.invalidate()
        }
    }
}
