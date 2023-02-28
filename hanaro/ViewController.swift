import UIKit
import WebKit
import FirebaseMessaging
import SafariServices
import AuthenticationServices
import Alamofire

class ViewController: UIViewController {
    var webView: WKWebView!
    var createWebView: WKWebView!
    
    // MARK: - 웹뷰 url
    let devSurvey = "http://dev.picaloca.com:3020/intro"
    let devMain = "http://dev.picaloca.com:3020/"
    let testLogin = "https://api.cyberbankapi.com/"
    let prodSurvey = "https://www.cyberbankapi.com/intro"
    let prodMain = "https://www.cyberbankapi.com/"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        addSubviews()
        makeConstants()
        loadWebPage()
        getUserAgent()
        UserDefaults.standard.set(true, forKey: "isVisited")
    }
    
    // MARK: - 웹뷰 세팅
    func setupWebView() {
        // Swift가 Javascript에게 함수 호출 요청
        let contentController = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        
        contentController.add(self, name: "setPushToken")
        contentController.add(self, name: "appleLoginBtnClick")
        contentController.add(self, name: "appleQuitBtnClick")
        
        configuration.userContentController = contentController
        webView = WKWebView(frame: .zero, configuration: configuration)
        
        // 캐시 데이터는 앱 실행 시 제거
        removeCache() {
            print("캐시 제거")
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
    
    // MARK: - 뷰 추가
    func addSubviews() {
        view.addSubview(webView)
    }
    
    // MARK: - 뷰 제약조건 설정
    func makeConstants() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    }
    
    // MARK: - 웹뷰 로드
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
    
    // MARK: - 웹뷰와 웹브라우저 구분
    func getUserAgent() {
        webView.evaluateJavaScript("navigator.userAgent"){ result, error in
            let originUserAgent = result as! String
            let agent = originUserAgent + " APP_WISHROOM_IOS"
            self.webView.customUserAgent = agent
        }
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
    
    // MARK: - 캐시 제거
    func removeCache(completionHandler: @escaping () -> Void) {
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeOfflineWebApplicationCache], modifiedSince: Date(timeIntervalSince1970: 0)) {
            completionHandler()
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
                    "push_token": token
                ]
                
                let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
                let jsonString = String(data: jsonData, encoding: .utf8)!
                
                if message.body as! String == "e" {
                    self.webView.evaluateJavaScript("responseTokenEMAIL(\(jsonString))") { result, error in
                        guard error == nil else {
                            print(error as Any)
                            return
                        }
                    }
                } else {
                    self.webView.evaluateJavaScript("responseTokenSNS(\(jsonString))") { result, error in
                        guard error == nil else {
                            print(error as Any)
                            return
                        }
                    }
                }
            }
        } else if message.name == "appleLoginBtnClick" {
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self as? ASAuthorizationControllerPresentationContextProviding
            authorizationController.performRequests()
            
        } else if message.name == "appleQuitBtnClick" {
            
            if let clientSecret = UserDefaults.standard.string(forKey: "AppleClientSecret"),
               let refreshToken = UserDefaults.standard.string(forKey: "AppleRefreshToken") {
               
                // MARK: - 애플에 탈퇴 요청
                AF.request("https://appleid.apple.com/auth/revoke",
                           method: .post,
                           parameters: [
                            "client_id": "com.cbfinancial.app",
                            "client_secret": clientSecret,
                            "token": refreshToken
                            ],
                           headers: ["Content-Type": "application/x-www-form-urlencoded"])
                .validate(statusCode: 200..<600)
                .responseData {  response in
                    guard let statusCode = response.response?.statusCode else { return }
                    if statusCode == 200 {
                        print("애플 탈퇴 success")
                        
                        UserDefaults.standard.set(nil, forKey: "AppleClientSecret")
                        UserDefaults.standard.set(nil, forKey: "AppleRefreshToken")
                        
                        let dict = [
                            "isRevoked": "S"
                        ]
                        
                        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
                        let jsonString = String(data: jsonData, encoding: .utf8)!
                        
                        self.webView.evaluateJavaScript("appleQuitResponse(\(jsonString))") { result, error in
                            guard error == nil else {
                                print(error as Any)
                                return
                            }
                        }
                    } else {
                        print("애플 탈퇴 failed")
                        
                        let dict = [
                            "isRevoked": "F"
                        ]
                        
                        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
                        let jsonString = String(data: jsonData, encoding: .utf8)!
                        
                        self.webView.evaluateJavaScript("appleQuitResponse(\(jsonString))") { result, error in
                            guard error == nil else {
                                print(error as Any)
                                return
                            }
                        }
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

// MARK: - 애플로그인
extension ViewController: ASAuthorizationControllerDelegate {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.webView.window!
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
            // Apple ID
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            // 계정 정보 가져오기
            //            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            var email = appleIDCredential.email
            
            if let authorizationCode = appleIDCredential.authorizationCode,
               let identityToken = appleIDCredential.identityToken,
               let authCodeString = String(data: authorizationCode, encoding: .utf8),
               let identityTokenString = String(data: identityToken, encoding: .utf8) {
                
                email = Utils.decode(jwtToken: identityTokenString)["email"] as? String ?? ""
                let seed = Utils.decode(jwtToken: identityTokenString)["sub"] as? String ?? ""
                
                print(email ?? "nil")
                print(seed)
                
                // MARK: - 가입 여부 체크
                AF.request("\(prodMain)api/member/chk/join?email=\(email ?? "")",
                           method: .get,
                           encoding: URLEncoding.default,
                           headers: ["Content-Type": "application/x-www-form-urlencoded"])
                .validate(statusCode: 200..<300)
                .responseData { [weak self] response in
                    guard let self = self else { return }
                    
                    switch response.result {
                    case .success:
                        print("member/chk/join success")
                        
                        guard let data = response.value else { return }
                        let dataDictionary = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                        guard let ret = dataDictionary["ret"] as? String else { return }
                        
                        print(ret)
                        
                        if ret == "S" {
                            print("가입 가능")
                            
                            self.setPushToken() { token in
                                let familyName = fullName?.familyName ?? ""
                                let givenName = fullName?.givenName ?? ""
                                
                                let dict = [
                                    "email": email,
                                    "fullName": familyName + givenName,
                                    "seed": seed,
                                    "pushToken": token
                                ]
                                
                                let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [])
                                let jsonString = String(data: jsonData, encoding: .utf8)!
                                
                                self.webView.evaluateJavaScript("appleLoginToJoin(\(jsonString))") { result, error in
                                    guard error == nil else {
                                        print(error as Any)
                                        return
                                    }
                                }
                            }
                            
                            // MARK: - 백엔드에 클라이언트 시크릿 요청
                            AF.request("\(self.prodMain)api/member/auth/apple",
                                       method: .get,
                                       encoding: URLEncoding.default,
                                       headers: ["Content-Type": "application/x-www-form-urlencoded"])
                            .validate(statusCode: 200..<300)
                            .responseData { [weak self] response in
                                guard let _ = self else { return }
                                
                                switch response.result {
                                case .success:
                                    print("member/auth/apple success")
                                    
                                    guard let data = response.data else { return }
                                    
                                    guard let output = try? JSONDecoder().decode(AppleLoginResponse.self, from: data) else {
                                        print("Error: JSON Data Parsing failed")
                                        return
                                    }
                                    
                                    let clientSecret = output.data.clientSecret ?? ""
                                    
                                    print("client_secret: \(clientSecret)")
                                    
                                    UserDefaults.standard.set(clientSecret, forKey: "AppleClientSecret")
                                    
                                    // MARK: - 애플에 리프레시 토큰 요청
                                    AF.request("https://appleid.apple.com/auth/token",
                                               method: .post,
                                               parameters: [
                                                "client_id": "com.cbfinancial.app",
                                                "client_secret": clientSecret,
                                                "code": authCodeString,
                                                "grant_type": "authorization_code"
                                               ],
                                               headers: ["Content-Type": "application/x-www-form-urlencoded"])
                                    .validate(statusCode: 200..<300)
                                    .responseData { response in
                                        switch response.result {
                                        case .success:
                                            
                                            guard let data = response.value else { return }
                                            let dataDictionary = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                                            guard let refreshToken = dataDictionary["refresh_token"] as? String else { return }
                                            
                                            UserDefaults.standard.set(refreshToken, forKey: "AppleRefreshToken")
                                            
                                            print("refresh_token: \(refreshToken)")
                                            
                                        case .failure:
                                            print("애플 토큰 생성 실패 - \(response.error.debugDescription)")
                                        }
                                    }
                                case .failure(let error):
                                    print(error)
                                }
                            }
                            
                        } else if ret == "F" {
                            print("이미 가입")
                            
                            // MARK: - 백엔드에 sns로그인 요청
                            self.setPushToken() { token in
                                AF.request("\(self.prodMain)api/member/login/sns",
                                           method: .post,
                                           parameters: [
                                            "seed": seed,
                                            "email": email ?? "",
                                            "join_type": "A",
                                            "platform": "i",
                                            "push_token": token
                                           ],
                                           encoding: URLEncoding.default,
                                           headers: ["Content-Type": "application/x-www-form-urlencoded"])
                                .validate(statusCode: 200..<300)
                                .responseData { response in
                                    switch response.result {
                                    case .success:
                                        
                                        print("로그인 성공")
                                        
                                        self.removeCache() {
                                            print("캐시 제거")
                                    
                                            self.webView.evaluateJavaScript("moveToMain()") { result, error in
                                                guard error == nil else {
                                                    print(error as Any)
                                                    return
                                                }
                                            }
                                        }
                    
                                    case .failure:
                                        print("로그인 실패")
                                    }
                                }
                            }
                        }
                        
                    case .failure:
                        break
                    }
                }
            }
            
        case let passwordCredential as ASPasswordCredential:
            // Sign in using an existing iCloud Keychain credential.
            let username = passwordCredential.user
            let password = passwordCredential.password
            
            print("username: \(username)")
            print("password: \(password)")
        default:
            break
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print(error)
    }
}
