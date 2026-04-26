import SwiftUI
import WebKit

struct BrowserView: View {
    let platform: Platform

    @ObservedObject private var timerManager = TimerManager.shared
    @State private var showLockScreen = false
    @State private var timer: Timer?

    @Environment(\.scenePhase) private var scenePhase

    private var remainingSeconds: Int {
        timerManager.getRemainingSeconds(for: platform)
    }

    private var isLocked: Bool {
        timerManager.isLocked(for: platform)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Timer bar - fixed height at top, respects safe area
            TimerOverlay(remainingSeconds: remainingSeconds, platformColor: platform.color)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Color.black)

            // WKWebView - fills remaining space
            WebViewContainer(platform: platform)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .navigationBarBackButtonHidden(false)
        .navigationDestination(isPresented: $showLockScreen) {
            LockView(platform: platform)
        }
        .onAppear {
            timerManager.loadPlatformState(for: platform)

            // Check if platform is already locked
            if isLocked {
                showLockScreen = true
            } else {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                timerManager.checkAndResetIfNeeded()
                if isLocked {
                    showLockScreen = true
                } else {
                    startTimer()
                }
            case .background, .inactive:
                stopTimer()
            @unknown default:
                break
            }
        }
    }

    private func startTimer() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timerManager.decrementTime(for: platform)
            if isLocked {
                stopTimer()
                showLockScreen = true
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct WebViewContainer: UIViewRepresentable {
    let platform: Platform

    func makeUIView(context: Context) -> WKWebView {
        // Configure WKWebView to behave like Safari and avoid detection
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Use default website data store for proper cookie handling
        configuration.websiteDataStore = .default()

        // Set application name to appear as Safari
        configuration.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"

        // Enable JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // Inject JavaScript early to hide WKWebView indicators
        let hideWebKitScript = """
        (function() {
            // Remove webkit message handlers that Twitter uses to detect WKWebView
            delete window.webkit;

            // Override properties that might reveal embedded webview
            Object.defineProperty(navigator, 'standalone', {
                value: false,
                writable: false
            });
        })();
        """

        let userScript = WKUserScript(
            source: hideWebKitScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Set custom user agent to mimic Safari Mobile
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        // Allow link preview and other Safari-like features
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true

        // Assign delegates for external link handling
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        if let requestURL = URL(string: platform.url) {
            webView.load(URLRequest(url: requestURL))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(allowedDomains: platform.allowedDomains)
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        let allowedDomains: [String]

        init(allowedDomains: [String]) {
            self.allowedDomains = allowedDomains
            super.init()
        }

        // MARK: - WKUIDelegate (handles window.open() for Instagram Stories links)

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // window.open() is always user-initiated — open every URL externally regardless of domain.
            // isExternalURL is not consulted here: redirect domains like l.instagram.com appear
            // "internal" by domain match but always point to external content.
            if let url = navigationAction.request.url {
                openInExternalBrowser(url)
            }

            // Always return nil - never create a new WKWebView
            return nil
        }

        // MARK: - WKNavigationDelegate (handles standard navigation)

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                // Nil URL - allow through to prevent breaking internal behavior
                decisionHandler(.allow)
                return
            }

            // Check if URL is external
            if isExternalURL(url) {
                // Only open in external browser if it's a user tap, not an automatic redirect
                if navigationAction.navigationType == .linkActivated {
                    openInExternalBrowser(url)
                    decisionHandler(.cancel)
                } else {
                    // Automatic redirect (like twitter.com → x.com or instagram → facebook auth)
                    // Allow it to load in WKWebView
                    decisionHandler(.allow)
                }
            } else {
                // Internal navigation - allow normally
                decisionHandler(.allow)
            }
        }

        // MARK: - Helper Methods

        private func isExternalURL(_ url: URL) -> Bool {
            guard let host = url.host else {
                // No host - treat as internal
                return false
            }

            // Check if host matches any of the allowed domains
            for domain in allowedDomains {
                if host.contains(domain) {
                    return false // Internal - host contains one of our allowed domains
                }
            }

            return true // External - host doesn't match any allowed domain
        }

        private func openInExternalBrowser(_ url: URL) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }
}

struct TimerOverlay: View {
    let remainingSeconds: Int
    let platformColor: Color

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.system(size: 14, weight: .semibold))

            Text(timeString(from: remainingSeconds))
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(platformColor.opacity(0.85))
        )
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    NavigationStack {
        BrowserView(platform: instagram)
    }
}
