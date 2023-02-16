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
    @IBOutlet weak var webView: WKWebView!
    
    // MARK: - 웹뷰 url
    let dev = "http://dev.picaloca.com:3020/main"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webViewInit()
    }

    // MARK: - 웹뷰 초기화
    func webViewInit() {
        // 캐시 데이터는 앱 실행 시 제거
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0)) {
        }
        
        // 좌 우 스와이프 동작시 뒤로 가기 앞으로 가기 기능 활성화
//        webView.allowsBackForwardNavigationGestures = true
        
        if let url = URL(string: dev) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // MARK: - FCM 토큰 세팅
    func setPushToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 fetch 에러: \(error)")
            } else if let token = token {
                print("FCM 토큰: \(token)")
                
            }
        }
    }
}

