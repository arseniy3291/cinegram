import SwiftUI
import WebKit
import CineGramCore

struct CinemaWebView: View {
    @State private var loading = true
    @State private var error: String?
    @State private var attempt = 0
    @StateObject private var navigation = NativeGlassNavigation()
    var body: some View {
        ZStack {
            CinemaBrowser(loading: $loading, error: $error, navigation: navigation).id(attempt)
            if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .phone,
               navigation.visible, !loading, error == nil {
                VStack {
                    Spacer()
                    LiquidGlassNavigation(navigation: navigation)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
            if let error {
                VStack(spacing: 20) {
                    Text("Не удалось открыть CineGram").font(.headline)
                    Text(error).multilineTextAlignment(.center)
                    Button("Повторить") { self.error = nil; loading = true; attempt += 1 }
                        .buttonStyle(.borderedProminent).tint(.red)
                }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black).foregroundStyle(.white)
            } else if loading {
                ProgressView("Загрузка CineGram…").padding().background(Color.black.opacity(0.8))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct CinemaBrowser: UIViewRepresentable {
    @Binding var loading: Bool
    @Binding var error: String?
    @ObservedObject var navigation: NativeGlassNavigation
    func makeCoordinator() -> Coordinator { Coordinator(loading: $loading, error: $error, navigation: navigation) }
    func makeUIView(context:Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let deviceClass = UIDevice.current.userInterfaceIdiom == .pad ? "cinegram-ipad" : "cinegram-iphone"
        let nativeGlass: Bool
        if #available(iOS 26.0, *) { nativeGlass = UIDevice.current.userInterfaceIdiom == .phone }
        else { nativeGlass = false }
        let markDevice = WKUserScript(source: "if (document.documentElement) { document.documentElement.classList.add('\(deviceClass)'); \(nativeGlass ? "document.documentElement.classList.add('cinegram-native-glass');" : "") } else { document.addEventListener('DOMContentLoaded', function () { document.documentElement.classList.add('\(deviceClass)'); \(nativeGlass ? "document.documentElement.classList.add('cinegram-native-glass');" : "") }); }", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(markDevice)
        if nativeGlass {
            config.userContentController.add(context.coordinator, name: "cinegramNav")
            let observeNavigation = WKUserScript(source: Self.navigationObserver, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            config.userContentController.addUserScript(observeNavigation)
        }
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.isElementFullscreenEnabled = true
        let view = WKWebView(frame:.zero,configuration:config)
        view.navigationDelegate = context.coordinator;view.uiDelegate = context.coordinator
        view.isOpaque = false;view.backgroundColor = .black;view.scrollView.backgroundColor = .black
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.allowsBackForwardNavigationGestures = true
        navigation.webView = view
        view.load(URLRequest(url:URL(string:LocalServer.origin)!))
        return view
    }
    func updateUIView(_ uiView:WKWebView,context:Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "cinegramNav")
    }
    private static let navigationObserver = """
    (function () {
      function start() {
        var original = document.getElementById('bottom-nav');
        var nav = document.getElementById('iphone-glass-nav');
        var sheet = document.querySelector('.glass-sheet-backdrop');
        var search = document.getElementById('search-overlay');
        if (!original || !nav) return;
        function sync() {
          var active = nav.querySelector('.glass-tab.active');
          var visible = !nav.hidden && (!sheet || sheet.hidden) && (!search || !search.classList.contains('active'));
          window.webkit.messageHandlers.cinegramNav.postMessage({ visible: visible, selected: active ? active.dataset.glassScreen : 'home' });
        }
        var observer = new MutationObserver(sync);
        [original, nav, sheet, search].forEach(function (node) {
          if (node) observer.observe(node, { attributes: true, attributeFilter: ['hidden', 'style', 'class', 'aria-current'], subtree: true });
        });
        sync();
      }
      if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
      else start();
    })();
    """
    final class Coordinator:NSObject,WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler {
        private var loading: Binding<Bool>
        private var error: Binding<String?>
        private let navigation: NativeGlassNavigation
        init(loading: Binding<Bool>, error: Binding<String?>, navigation: NativeGlassNavigation) {
            self.loading = loading; self.error = error; self.navigation = navigation
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "cinegramNav", message.frameInfo.isMainFrame,
                  message.frameInfo.securityOrigin.host == "127.0.0.1", message.frameInfo.securityOrigin.port == 31849,
                  let state = message.body as? [String: Any] else { return }
            navigation.visible = state["visible"] as? Bool ?? false
            navigation.selected = state["selected"] as? String ?? "home"
        }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("CineGram: local page committed")
            loading.wrappedValue = false
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loading.wrappedValue = false
            webView.evaluateJavaScript("JSON.stringify({ready:document.readyState,body:!!document.body,children:document.body?.children.length})") { result, _ in
                print("CineGram: page loaded \(result ?? "unknown")")
            }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) { show(failure) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError failure: Error) { show(failure) }
        private func show(_ failure: Error) {
            guard (failure as NSError).code != NSURLErrorCancelled else { return }
            print("CineGram: navigation failed \(failure)")
            loading.wrappedValue = false
            error.wrappedValue = failure.localizedDescription
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loading.wrappedValue = false
            error.wrappedValue = "Процесс интерфейса завершился. Нажмите «Повторить»."
        }
        func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
            guard navigationAction.targetFrame?.isMainFrame == true else { decisionHandler(.allow);return }
            guard let url = navigationAction.request.url else { decisionHandler(.cancel);return }
            if url.scheme == "http" && url.host == "127.0.0.1" && url.port == 31849 { decisionHandler(.allow);return }
            if navigationAction.navigationType == .linkActivated && ["https","http"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }
        func webView(_ webView:WKWebView,createWebViewWith configuration:WKWebViewConfiguration,for navigationAction:WKNavigationAction,windowFeatures:WKWindowFeatures) -> WKWebView? {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url,["https","http"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
            return nil
        }
        func webView(_ webView:WKWebView,requestMediaCapturePermissionFor origin:WKSecurityOrigin,initiatedByFrame frame:WKFrameInfo,type:WKMediaCaptureType,decisionHandler:@escaping(WKPermissionDecision)->Void) { decisionHandler(.deny) }
    }
}


@MainActor private final class NativeGlassNavigation: ObservableObject {
    @Published var visible = false
    @Published var selected = "home"
    weak var webView: WKWebView?

    func activate(_ screen: String) {
        // These fixed selectors invoke existing application actions and preserve
        // their routing, sheets and keyboard behaviour.
        let selector: String
        switch screen {
        case "home": selector = "[data-glass-screen=home]"
        case "collections": selector = "[data-glass-screen=collections]"
        case "profile": selector = "[data-glass-screen=profile]"
        case "search": selector = ".glass-search"
        default: return
        }
        webView?.evaluateJavaScript("document.querySelector('" + selector + "')?.click()", completionHandler: nil)
    }
}

@available(iOS 26.0, *)
private struct LiquidGlassNavigation: View {
    @ObservedObject var navigation: NativeGlassNavigation
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let items: [(id: String, title: String, symbol: String)] = [
        ("home", "Главная", "house.fill"),
        ("collections", "Подборки", "square.grid.2x2.fill"),
        ("profile", "Профиль", "person.crop.circle.fill")
    ]
    var body: some View {
        HStack(spacing: 8) {
            glassTabs
            glassSearch
        }
        .frame(height: 68)
    }
    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.id) { item in
                Button { navigation.activate(item.id) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol).font(.system(size: 24, weight: .semibold))
                        Text(item.title).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(navigation.selected == item.id ? Color.red : Color.white)
                    .background {
                        if navigation.selected == item.id { Capsule().fill(.white.opacity(0.18)) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(navigation.selected == item.id ? .isSelected : [])
            }
        }
        .padding(4)
    }
    @ViewBuilder private var glassTabs: some View {
        if reduceTransparency {
            tabs.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else {
            tabs.glassEffect(.clear.interactive(), in: Capsule())
        }
    }
    private var search: some View {
        Button { navigation.activate("search") } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Поиск")
    }
    @ViewBuilder private var glassSearch: some View {
        if reduceTransparency {
            search.background(Color(uiColor: .secondarySystemBackground), in: Circle())
        } else {
            search.glassEffect(.clear.interactive(), in: Circle())
        }
    }
}
