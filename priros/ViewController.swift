//
//  ViewController.swift
//  priros
//
//  Created by 최한규 on 10/25/24.
//

import UIKit
import WebKit
import UserNotifications
import FirebaseMessaging

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentInteractionControllerDelegate {
    var webView: WKWebView!
    var webViewPops: [WKWebView] = []
    var refreshControl: UIRefreshControl!
    var addedHandlers: Set<String> = []
    var documentInteractionController: UIDocumentInteractionController?
    var fcmToken: String? {
        didSet {
            let js = "window.receiveFCMToken('\(fcmToken ?? "")');"
            webView.evaluateJavaScript(js) { (result, error) in
                if let error = error {
                    print("Error sending FCM token to WebView: \(error)")
                }
            }
        }
    }
    var defaultUrl: String? {
        didSet {
            self.openUrl()
        }
    }
    @IBOutlet weak var webViewContainer: UIView! // 웹 뷰를 추가할 컨테이너
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleFCMTokenReceived(_:)), name: NSNotification.Name("FCMTokenReceived"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUrlReceived(_:)), name: NSNotification.Name("urlReceived"), object: nil)
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.applicationNameForUserAgent = "IOS PRIROS"
        webConfiguration.allowsInlineMediaPlayback = true
        
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        // Safe Area에 맞게 webView의 프레임 설정
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 14.0, *) {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            webView.configuration.preferences.javaScriptEnabled = true
        }
        
        let contentController = WKUserContentController()
        if !addedHandlers.contains("downloadBase64File") {
            contentController.add(self, name: "downloadBase64File")
            webView.configuration.userContentController.add(self, name: "downloadBase64File")
            addedHandlers.insert("downloadBase64File")
        }
        
        webConfiguration.userContentController = contentController
        
        webViewContainer.addSubview(webView)
        
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        
        webView.scrollView.refreshControl = refreshControl
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        
        tapGesture.cancelsTouchesInView = false
        
        view.addGestureRecognizer(tapGesture)
        
        self.openUrl()
    }
    
    func openUrl() {
        if let url = URL(string: defaultUrl ?? "https://app.priros.com") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // alert 처리
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in completionHandler() }))
        self.present(alertController, animated: true, completion: nil)
    }

    // confirm 처리
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in completionHandler(false) }))
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in completionHandler(true) }))
        self.present(alertController, animated: true, completion: nil)
    }

    // window.open을 처리하는 메서드
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            // 새 WKWebView 인스턴스 생성
            let newWebView = WKWebView(frame: .zero, configuration: configuration)
            newWebView.uiDelegate = self
            newWebView.navigationDelegate = self
            
            if #available(iOS 14.0, *) {
                newWebView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            } else {
                newWebView.configuration.preferences.javaScriptEnabled = true
            }
            
            let contentController = WKUserContentController()
            
            // 'closeWindow' 핸들러가 이미 추가되어 있는지 확인
            if !addedHandlers.contains("closeWindow") {
                contentController.add(self, name: "closeWindow")
                newWebView.configuration.userContentController.add(self, name: "closeWindow")
                addedHandlers.insert("closeWindow")
            }
            
            configuration.userContentController = contentController
            
            
            // JavaScript에서 window.close()를 호출할 수 있도록 스크립트 추가
            let closeScript = """
            window.close = function() {
                window.webkit.messageHandlers.closeWindow.postMessage('closeWindow');
            };
            """
            newWebView.evaluateJavaScript(closeScript, completionHandler: nil)
            
            // 새 웹 뷰를 컨테이너에 추가
            webViewContainer.addSubview(newWebView)
            webViewPops.append(newWebView)

            // Auto Layout 설정
            newWebView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                newWebView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                newWebView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                newWebView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
            ])
            
            // 닫기 버튼 추가
            let closeButton = UIButton(type: .system)
            closeButton.setTitle("닫기", for: .normal)
            closeButton.addTarget(self, action: #selector(closeWebView(_:)), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            
            // 닫기 버튼을 컨테이너에 추가
            webViewContainer.addSubview(closeButton)
            
            // 닫기 버튼 Auto Layout 설정
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
            ])
            
            
            // 새 웹 뷰에 URL 로드
//            if let url = navigationAction.request.url {
//                newWebView.load(URLRequest(url: url))
//            }
            
            // 닫기 버튼에 대한 참조를 저장
            closeButton.accessibilityIdentifier = "closeButton_\(newWebView.hash)"
            newWebView.accessibilityIdentifier = "webView_\(newWebView.hash)"
            
            return newWebView
        }
        return nil
    }
    
    // 닫기 버튼 클릭 시 호출되는 메서드
    @objc func closeWebView(_ sender: UIButton) {
        // 닫기 버튼이 눌린 웹 뷰를 찾기
        if let superview = sender.superview {
            for subview in superview.subviews {
                if let webView = subview as? WKWebView, webView.accessibilityIdentifier == "webView_\(sender.accessibilityIdentifier?.split(separator: "_").last ?? "")" {
                    webView.removeFromSuperview() // 웹 뷰 제거
                    webViewPops.removeAll { $0 == webView } // 배열에서 제거
                    break
                }
            }
            sender.removeFromSuperview() // 닫기 버튼 제거
        }
    }
    
    // JavaScript에서 메시지를 수신하는 메서드
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "closeWindow" {
            // 현재 웹 뷰를 닫는 로직을 추가
            if let webView = webViewPops.last { // 마지막 웹 뷰를 닫는 예시
                // 닫기 버튼을 찾기
                if let superview = webView.superview {
                    for subview in superview.subviews {
                        if let button = subview as? UIButton, button.accessibilityIdentifier?.contains("closeButton_") == true {
                            // 닫기 버튼 클릭
                            closeWebView(button)
                            break
                        }
                    }
                }
            }
        }
        if message.name == "downloadBase64File", let dict = message.body as? [String: Any],
           let base64String = dict["base64"] as? String,
           let fileName = dict["filename"] as? String {
            if let base64Data = base64String.components(separatedBy: ",").last {
                downloadBase64File(base64Data: base64Data, fileName: fileName)
            }
        }
    }

    // 웹 뷰 닫기 메서드
    func closeWebViewWindowClose(_ webView: WKWebView) {
        webView.removeFromSuperview() // 웹 뷰를 제거
        webViewPops.removeAll { $0 == webView } // 배열에서 제거
    }
    
    // 웹 뷰가 닫힐 때 호출되는 메서드
    func webView(_ webView: WKWebView, didClose window: WKWebView) {
        if let index = webViewPops.firstIndex(of: window) {
            webViewPops.remove(at: index)
            window.removeFromSuperview()
            window.stopLoading()
            window.navigationDelegate = nil
            window.uiDelegate = nil
        }
    }
    
    // Base64 파일 다운로드 메서드
    func downloadBase64File(base64Data: String, fileName: String) {
        NSLog(base64Data)
        
        // Base64 디코딩
        guard let data = Data(base64Encoded: base64Data) else {
            print("Base64 디코딩 실패")
            return
        }
        
        // 파일 경로 설정
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("문서 디렉토리의 경로를 찾을 수 없습니다.")
            return
        }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            // 파일 저장
            try data.write(to: fileURL)
            print("파일 저장 완료: \(fileURL.path)")
            // 파일 미리보기
            previewFile(at: fileURL)
        } catch {
            print("파일 저장 실패: \(error.localizedDescription)")
            self.showToastMessage(self: self, font: UIFont.systemFont(ofSize: 10), message: "파일 다운로드 실패")
        }
    }
    
    func previewFile(at url: URL) {
        documentInteractionController = UIDocumentInteractionController(url: url)
        documentInteractionController?.delegate = self
        documentInteractionController?.presentPreview(animated: true)
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @objc func handleTap() {
        print("View tapped")
    }
    // 동시에 인식할 수 있도록 허용
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    //글자수 계산
    func getTextSize(text : String,font: UIFont)->CGSize{// 글자 사이즈 계산용
       let fontAttributes = [NSAttributedString.Key.font: font]
       let text = text
       let size = (text as NSString).size(withAttributes: fontAttributes as [NSAttributedString.Key : Any])
       return size // 여기서 나오는 사이즈를 기반으로 크기가 결정됩니다.
   }
    // toast message 생성
   func showToastMessage(self: UIViewController,font: UIFont,message : String){
       let customSize = getTextSize(text: message, font: font)
       let customWidth = customSize.width + 40 // 줄이시면 좌우 여백이 줄어듭니다.
       let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - customWidth/2, y: self.view.frame.size.height-100, width: customWidth, height: customSize.height+32))
       toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
       toastLabel.textColor = UIColor.white
       toastLabel.font = font
       toastLabel.textAlignment = .center
       toastLabel.text = message
       toastLabel.alpha = 1.0
       toastLabel.layer.cornerRadius = 8; // 좀더 둥글둥글한걸 원하시면 늘리시면됩니다.
       toastLabel.clipsToBounds  =  true
       self.view.addSubview(toastLabel)
       UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
       }, completion: {(isCompleted) in
           toastLabel.removeFromSuperview()
       })
   }
    
    @objc func handleFCMTokenReceived(_ notification: Notification) {
        if let token = notification.object as? String {
            self.fcmToken = token
        }
    }
    
    @objc func handleUrlReceived(_ notification: Notification) {
        if let url = notification.object as? String {
            self.defaultUrl = url
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func refreshWebView() {
        webView.reload()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.webView.evaluateJavaScript("window.scrollTo(0, 0);") { (result, error) in
                if let error = error {
                    print("Error scrolling: \(error)")
                }
            }
            self.refreshControl.endRefreshing()
        }
    }
}
