//
//  ViewController.swift
//  hanaro
//
//  Created by Financial CB on 2023/02/16.
//

import UIKit
import WebKit
import FirebaseMessaging

class ViewController: UIViewController {
    var webView: WKWebView!
    
    // MARK: - 웹뷰 url
    let devSurvey = "http://dev.picaloca.com:3020/intro"
    let devMain = "http://dev.picaloca.com:3020/main"
    let testLogin = "http://dev.picaloca.com:3020/test_login"
    
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
        webView.allowsBackForwardNavigationGestures = true
        
        // delegate
        webView.uiDelegate = self
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
            if let url = URL(string: devMain) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        } else {
            if let url = URL(string: devSurvey) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
        
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
                    "token": token
                ]
                
                let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8)!
                
                self.webView.evaluateJavaScript("testCode(\(jsonString))") { result, error in
                    guard error == nil else {
                        print(error as Any)
                        return
                    }
                }
            }
        }
    }
}

// MARK: - 얼럿 extension
extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "확인", style: .cancel) { _ in
            completionHandler()
        }
        alertController.addAction(cancelAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
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
}

