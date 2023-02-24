import UIKit
import WebKit
import FirebaseMessaging
import SafariServices

class ViewController: UIViewController {
    var webView: WKWebView!
    var createWebView: WKWebView!
    
    // MARK: - 웹뷰 url
    let devSurvey = "http://dev.picaloca.com:3020/intro"
    let devMain = "http://dev.picaloca.com:3020/"
    let testLogin = "http://dev.picaloca.com:3020/test_login"
    let prodSurvey = "https://www.cyberbankapi.com/intro"
    let prodMain = "https://www.cyberbankapi.com/"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        addSubviews()
        makeConstants()
        loadWebPage()
        UserDefaults.standard.set(true, forKey: "isVisited")
    }
    
    func setupWebView() {
        // Swift가 Javascript에게 setPushToken() 호출 요청
        let contentController = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        
        contentController.add(self, name: "setPushToken")
        
        configuration.userContentController = contentController
        webView = WKWebView(frame: .zero, configuration: configuration)
        
        // 캐시 데이터는 앱 실행 시 제거
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0)) {
        }
        
        // 좌 우 스와이프 동작시 뒤로 가기 앞으로 가기 기능 활성화
//        webView.allowsBackForwardNavigationGestures = true
        
        // delegate
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // ui
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "backgroundColor")
    }
    
    func addSubviews() {
        view.addSubview(webView)
    }
    
    func makeConstants() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    }
    
    func loadWebPage() {
        // URL 이동
        if UserDefaults.standard.bool(forKey: "isVisited") {
            if let url = URL(string: prodMain) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        } else {
            if let url = URL(string: prodSurvey) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
        
//        if UserDefaults.standard.bool(forKey: "isVisited") {
//            if let url = URL(string: devMain) {
//                let request = URLRequest(url: url)
//                webView.load(request)
//            }
//        } else {
//            if let url = URL(string: devSurvey) {
//                let request = URLRequest(url: url)
//                webView.load(request)
//            }
//        }
        
//        if let url = URL(string: testLogin) {
//            let request = URLRequest(url: url)
//            webView.load(request)
//        }
    }
    
    // MARK: - FCM 토큰 세팅
    func setPushToken(completionHandler: @escaping (String) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 fetch 에러: \(error)")
            } else if let token = token {
                print("FCM 토큰: \(token)")
                completionHandler(token)
            }
        }
    }
}

// MARK: - 자바스크립트 통신
extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "setPushToken" {
            setPushToken() { [weak self] token in
                guard let self = self else { return }
                
                let dict = [
                    "token": token,
                    "join_type": message.body
                ]
                
                let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8)!
                
                self.webView.evaluateJavaScript("responseToken(\(jsonString))") { result, error in
                    guard error == nil else {
                        print(error as Any)
                        return
                    }
                }
            }
        }
    }
}

extension ViewController: WKUIDelegate, WKNavigationDelegate {
    // MARK: - UIAlert
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "확인", style: .cancel) { _ in
            completionHandler()
        }
        alertController.addAction(cancelAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { _ in
            completionHandler(false)
        }
        let okAction = UIAlertAction(title: "확인", style: .default) { _ in
            completionHandler(true)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - 외부 url은 safari로 open
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
            url.host != "dev.picaloca.com" &&
            url.host != "www.cyberbankapi.com" &&
            url.host != "talk-apps.kakao.com" {
            print(url.scheme as Any)
            print(url.host as Any)
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet

            present(safariVC, animated: true, completion: nil)
            
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

