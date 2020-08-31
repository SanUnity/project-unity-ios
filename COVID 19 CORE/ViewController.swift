//
//  ViewController.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import WebKit
import SafariServices
import MessageUI
import CoreLocation
import CoreData
import FirebaseAnalytics
import TrustKit
import Contacts

class ViewController: UIViewController {

    @IBOutlet weak var webview: WKWebView!
    @IBOutlet weak var activityLoader: UIActivityIndicatorView!
    @IBOutlet weak var splashImage: UIView!
    @IBOutlet weak var bkImage: UIImageView!
    @IBOutlet weak var centerLogos: UIImageView!
    @IBOutlet weak var bottomImage: UIImageView!
    @IBOutlet weak var logoAPP: UIImageView!
    @IBOutlet weak var noInternetConnectionView: UIView!
    
    var isLoadWeb:Bool = false
    var isTimePass:Bool = false
    var locationTimer: Timer? = nil
    var hasConnection: Bool = true

    override var prefersStatusBarHidden: Bool {
        return !isLoadWeb
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        noInternetConnectionView.layer.cornerRadius = 4
        noInternetConnectionView.layer.shadowColor = UIColor.black.cgColor
        noInternetConnectionView.layer.shadowOpacity = 0.5
        noInternetConnectionView.layer.shadowOffset = CGSize(width: 0, height: 5)
        noInternetConnectionView.layer.shadowRadius = 10
        noInternetConnectionView.clipsToBounds = false
        
        if AppSettings.gpsRequested {
            sendLocation()
            locationTimer = Timer.scheduledTimer(timeInterval: TimeInterval(BluetraceConfig.CentralLocationInterval), target: self, selector: #selector(ViewController.getLocation), userInfo: nil, repeats: true)
        }
        
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenURL(_:)), name: NSNotification.Name.handleOpenUrl, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOnboarding(_:)), name: NSNotification.Name.handleOnboarding, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleReload(_:)), name: NSNotification.Name.handleReload, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateStateTracing(_:)), name: NSNotification.Name.handleUpdateStateTracing, object: nil)

        self.webview.navigationDelegate = self
        self.webview.uiDelegate = self
        self.webview.scrollView.bounces = false
        self.webview.clipsToBounds = true
        self.webview.scrollView.clipsToBounds = false
        self.webview.scrollView.showsHorizontalScrollIndicator = false
        self.webview.scrollView.bouncesZoom = false
        self.webview.scrollView.delegate = self
        if #available(iOS 11.0, *) {
            self.webview.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.webview.allowsBackForwardNavigationGestures = false
        self.webview.allowsLinkPreview = false

        self.webview.configuration.userContentController.add(self, name: "scriptHandler")

        if let url = (UIApplication.shared.delegate as? AppDelegate)?.openUrl {
            self.tryLoad(url)
        } else if let url = URL(string: "\(String.Webapp.URL)\(String.Webapp.PARAMS)") {
            self.tryLoad(url)
        }
        
    }
    
    func tryLoad(_ url: URL) {
        if let reachability = NetworkManager.sharedInstance.reachability {
            switch reachability.connection {
            case .unavailable:
                self.noInternetConnection()
            default:
                self.activityLoader.startAnimating()
                if url.absoluteString.contains("/exposed") || url.absoluteString.contains("exposed=true") {
                    Analytics.logEvent("user_exposed", parameters: nil)
                }
                Logger.DLog("Reload URL: \(url.absoluteString)")
                self.webview.load(URLRequest(url: url))
            }
        } else {
            self.noInternetConnection()
        }
    }
    
    func noInternetConnection() {
        self.hasConnection = false
        self.activityLoader.stopAnimating()
        self.noInternetConnectionView.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if String.General.HAS_ONBOARDING && !AppSettings.isShowOnboarding {
            self.showOnboarding()
        }

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
//        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
//            let keyboardRectangle = keyboardFrame.cgRectValue
//            let keyboardHeight = keyboardRectangle.height
//            self.webview.scrollView.setContentOffset(CGPoint(x: 0, y: keyboardHeight), animated: false)
//        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        self.webview.scrollView.setContentOffset(CGPoint(x: 0, y: webview.scrollView.contentOffset.y), animated: false)
    }

    @objc func handleOpenURL(_ notification:Notification) {
        if let url = notification.object as? URL {
            if !String.Webapp.HOSTS.contains(where: url.absoluteString.contains) {
            // if !url.absoluteString.contains(String.Webapp.HOST) {
                self.openinAppBrowser(url)
            } else if url.absoluteString.contains("?") {
                self.tryLoad(url)
            } else if let newURL = URL(string: "\(url.absoluteString)\(String.Webapp.PARAMS)") {
                self.tryLoad(newURL)
            }
        }
    }

    @objc func handleOnboarding(_ notification:Notification) {
        self.showOnboarding()
    }

    @objc func handleReload(_ notification:Notification) {
        if !self.hasConnection {
            self.hasConnection = true
            self.noInternetConnectionView.isHidden = true
            self.webview.reload()
        }
    }

    @objc func handleUpdateStateTracing(_ notification:Notification) {
        self.setBTStatus()
    }

    func showOnboarding() {
        if let onboardingVC = self.storyboard?.instantiateViewController(withIdentifier: "onboardingVC") as? OnboardingController {
            AppSettings.isShowOnboarding = true
            self.present(onboardingVC, animated: true, completion: nil)
        }
    }
    
    func canOpenRequest(_ url: URL) -> Bool {
        if UIApplication.shared.canOpenURL(url) && (url.absoluteString.contains("http://") || url.absoluteString.contains("https://") || url.absoluteString.contains("mailto:") || url.absoluteString.contains("itms-apps://") || url.absoluteString.contains("tel:")) {
            return true
        }
        return false
    }
    
    func sendMail(_ url: URL) {
        let recipients = url.absoluteString.replacingOccurrences(of: "mailto:", with: "").split(separator: ",").map { (recipientEmail) -> String in
            return String(recipientEmail)
        }
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(recipients)
            self.present(mail, animated: true)
        } else {
            if UIApplication.shared.canOpenURL(url) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
    }
    
    func openinAppBrowser(_ url:URL) {
        let vc = SFSafariViewController(url: url)
        self.present(vc, animated: true, completion: nil)
    }
    

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.url), let newValue = change?[.newKey] as? URL, let oldValue = change?[.oldKey] as? URL, newValue != oldValue {
            print("URL CHANGED: \(newValue.absoluteString)")
            (UIApplication.shared.delegate as? AppDelegate)?.openUrl = newValue
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object:nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object:nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.handleOpenUrl, object:nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.handleReload, object:nil)
        self.webview.scrollView.delegate = nil
    }

}

extension ViewController: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if var url = navigationAction.request.url {
            
            if url.absoluteString.contains("https://itunes.apple.com/"), let appStoreURL = URL(string: url.absoluteString.replacingOccurrences(of: "https://", with: "itms-apps://")) {
                url = appStoreURL
            }
            
            if url.absoluteString.contains("/logout") {
                self.evaluateString("setToken('');")
                AppSettings.logOut()
                decisionHandler(.cancel)
                return
            } else if String.General.EXTERNAL_URLS.contains(where: url.absoluteString.contains) || (navigationAction.targetFrame == nil && self.canOpenRequest(url)) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            } else if url.absoluteString.contains("mailto:") {
                self.sendMail(url)
                decisionHandler(.cancel)
                return
            } else if (url.absoluteString.contains("itms-apps://") || url.absoluteString.contains("tel:") && UIApplication.shared.canOpenURL(url)) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
                decisionHandler(.cancel)
                return
            } else if navigationAction.navigationType == .linkActivated && !String.Webapp.HOSTS.contains(where: url.absoluteString.contains) /* !url.absoluteString.contains(String.Webapp.HOST) */ {
                self.openinAppBrowser(url)
                decisionHandler(.cancel)
                return
            }

        }
        
        decisionHandler(.allow)

    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        if let stylePath = Bundle.main.path(forResource: "styles", ofType: "css") {
            do {
                let cssStyle = try String(contentsOfFile: stylePath).replacingOccurrences(of: "\n", with: "")
                let javaScript = "var css = '\(cssStyle)'; var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style); document.querySelector('meta[name=\"viewport\"]').setAttribute(\"content\", \"width=device-width, initial-scale=1.0, shrink-to-fit=no, user-scalable=no, viewport-fit=cover\");"
                self.evaluateString(javaScript)
            } catch {}
        }

        webView.evaluateJavaScript("document.readyState") { (result, error) in
            if result == nil || error != nil {
                return
            }
            
            self.activityLoader.stopAnimating()

            if !self.isLoadWeb {
                self.isLoadWeb = true
                self.hideSplashScreen()
            }
        }

        if let url = webView.url {
            (UIApplication.shared.delegate as? AppDelegate)?.openUrl = url
            
            print(url.absoluteString)
        }

    }
    
    func hideSplashScreen() {
        self.splashImage.isHidden = true
        if self.view.backgroundColor != .white {
            self.activityLoader.color = self.view.backgroundColor
        }
        self.view.backgroundColor = .white
        self.webview.isHidden = false
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: String.General.ACCEPT, style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: String.General.ACCEPT, style: .default, handler: { (action) in
            completionHandler(true)
        }))
        alertController.addAction(UIAlertAction(title: String.General.CANCEL, style: .default, handler: { (action) in
            completionHandler(false)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .actionSheet)
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        alertController.addAction(UIAlertAction(title: String.General.ACCEPT, style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        alertController.addAction(UIAlertAction(title: String.General.CANCEL, style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if String.Pinning.PUBLIC_KEY_HASHES.count <= 0 || TrustKit.sharedInstance().pinningValidator.handle(challenge, completionHandler: completionHandler) == false {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    
}

extension ViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView.contentOffset.x > 0) {
            scrollView.contentOffset = CGPoint(x: 0, y: scrollView.contentOffset.y)
        }
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

}

extension ViewController: MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
}

extension ViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.body as? String == String.MessageHandler.CT_START || message.body as? String == String.MessageHandler.CT_REQUEST {
            AppSettings.bluetoothRequested = true
            if String.General.PASSPORT_NEEDED {
                if AppSettings.userHasPassport {
                    self.startBluetooth()
                    self.setBTStatus()
                }
            } else {
                self.startBluetooth()
                self.setBTStatus()
            }
        } else if message.body as? String == String.MessageHandler.CT_PAUSE {
            AppSettings.bluetoothRequested = false
            ContactTracingManager.sharedInstance.stopTracing()
            self.setBTStatus()
        } else if message.body as? String == String.MessageHandler.LOGOUT {
            self.evaluateString("setToken('');")
            AppSettings.logOut()
        } else if message.body as? String == String.MessageHandler.CT_SYNC {
            ContactTracingManager.sharedInstance.sync(nil)
        } else if message.body as? String == String.MessageHandler.CT_GETTOKENS || message.body as? String == String.MessageHandler.CT_SETEXPOSED {
            
            ContactTracingManager.sharedInstance.setExposed { (success) in
                if success, let token = AppSettings.userToken, let session = (UIApplication.shared.delegate as? AppDelegate)?.trustKitCertificatePinning?.session {

                    let urlString = "\(String.Api.BASE_URL)\(String.Api.POST_EXPOSED_END)"
                    if let url = URL(string: urlString) {
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.addValue("application/json", forHTTPHeaderField: "content-type")
                        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        request.addValue("ios", forHTTPHeaderField: "API-apptype")

                        let task = session.dataTask(with: request) { data, response, error in
                            DispatchQueue.main.async(execute: { () -> Void in
                                
                                if let error = error {
                                    Logger.DLog(error.localizedDescription)
                                } else if let httpResponse = response as? HTTPURLResponse {
                                    switch httpResponse.statusCode {
                                    case 200:
                                        Logger.DLog("Device token logged")
                                        Analytics.logEvent("user_infected", parameters: nil)
                                    default:
                                        Logger.DLog("Error with status code: \(httpResponse.statusCode)")
                                    }
                                } else {
                                    Logger.DLog("Error: no response")
                                }
                            })
                        }
                        task.resume()
                    }
                    
                }
            }
        } else if message.body as? String == String.MessageHandler.CT_RESET {
            ContactTracingManager.sharedInstance.resetTracing()
        } else if message.body as? String == String.MessageHandler.CT_CLEAN_DATA {
            BluetraceUtils.removeAllData()
        } else if message.body as? String == String.MessageHandler.LOCATION_INIT {
            if locationTimer == nil {
                locationTimer = Timer.scheduledTimer(timeInterval: TimeInterval(BluetraceConfig.CentralLocationInterval), target: self, selector: #selector(ViewController.getLocation), userInfo: nil, repeats: true)
            }
        } else if message.body as? String == String.MessageHandler.LOCATION_DATA {
            sendLocation()
        } else if message.body as? String == String.MessageHandler.SHARE_APP {
            self.shareApp(url: String.Share.URL, name: String.Share.TITLE, description: String.Share.DESCRIPTION)
        } else if let message = message.body as? String, message.contains("id:"), message.split(separator: ",").count == 2, let id = message.split(separator: ",").first, let token = message.split(separator: ",").last {
            // SET USER ID
            if !AppSettings.isUserLogged {
                Analytics.logEvent(AnalyticsEventLogin, parameters: nil)
            }
            AppSettings.userId = String(id).replacingOccurrences(of: "id:", with: "")
            AppSettings.userToken = String(token).replacingOccurrences(of: "token:", with: "")
            (UIApplication.shared.delegate as? AppDelegate)?.registerForPushNotifications()
        } else if let message = message.body as? String, message.contains("saveToken:"), message.split(separator: ":").count == 2, let token = message.split(separator: ":").last {
            AppSettings.userToken = String(token).replacingOccurrences(of: "token:", with: "")
        } else if message.body as? String == String.MessageHandler.TOKEN_GET, let token = AppSettings.userToken {
            self.evaluateString("setToken('\(token)');")
        } else if message.body as? String == String.MessageHandler.CT_STATUS {
            self.setBTStatus()
        } else if message.body as? String == String.MessageHandler.GOTO_SETTINGS {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else if message.body as? String == String.MessageHandler.QR_READ {
            self.readQR()
        } else if message.body as? String == String.MessageHandler.QR_ERROR {
            self.readQRError()
        } else if let message = message.body as? String, message.contains("getDeviceToken:") {
            if let token = AppSettings.userToken, let deviceTokenString = AppSettings.appDeviceToken {
                let stringArray = message.replacingOccurrences(of: "getDeviceToken:", with: "")
                let tokensArray = stringArray.split(separator: ",")
                if tokensArray.count == 0 {
                    (UIApplication.shared.delegate as? AppDelegate)?.setDeviceToken(token, deviceTokenString: deviceTokenString)
                } else {
                    var containsToken:Bool = false
                    for substr in tokensArray {
                        if deviceTokenString.contains(substr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            containsToken = true
                            break
                        }
                    }
                    if !containsToken {
                        (UIApplication.shared.delegate as? AppDelegate)?.setDeviceToken(token, deviceTokenString: deviceTokenString)
                    }
                }
            }
        } else if message.body as? String == String.MessageHandler.CT_EXPOSED_LENGTH {
            self.setExposedLength()
        } else if message.body as? String == String.MessageHandler.CT_GET_WINDOWS {
            self.setWindowLength()
        } else if message.body as? String == String.MessageHandler.CT_CLEAR_WINDOWS {
            AppSettings.windowLength = 0
        } else if message.body as? String == String.MessageHandler.GET_CONTACTS {
            self.getContacts()
        } else if let message = message.body as? String, message.contains("sendWhatsAppMessage:"), message.split(separator: ",").count == 2 {
            // "sendWhatsAppMessage:text=<string_message>,phone=<phone_number>"
            let data = message.replacingOccurrences(of: "sendWhatsAppMessage:", with: "")
            if let text = data.split(separator: ",").first?.replacingOccurrences(of: "text=", with: ""), let phone = data.split(separator: ",").last?.replacingOccurrences(of: "phone=", with: ""), let url = URL(string: "whatsapp://send?phone=\(phone)&text=\(text)"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else if let message = message.body as? String, message.contains("sendSMSMessage:"), message.split(separator: ";").count == 2 {
            // text=<string_message>;phones=<phone_number>
            let data = message.replacingOccurrences(of: "sendSMSMessage:", with: "")
            if let text = data.split(separator: ";").first?.replacingOccurrences(of: "text=", with: ""), let phonesString = data.split(separator: ";").last?.replacingOccurrences(of: "phone=", with: "") {
                let phones = phonesString.split(separator: ",")
                if phones.count > 0 {
                    if MFMessageComposeViewController.canSendText() {
                        let messageComposeVC = MFMessageComposeViewController()
                        messageComposeVC.body = text
                        messageComposeVC.recipients = phones.map { (phone) -> String in
                            return "\(phone)"
                        }
                        messageComposeVC.messageComposeDelegate = self
                        self.present(messageComposeVC, animated: true, completion: nil)
                    }
                }
            }
        } else if let message = message.body as? String, message.contains("setAppData('") {
            AppSettings.appData = message.replacingOccurrences(of: "setAppData('", with: "").replacingOccurrences(of: "')", with: "")
        } else if message.body as? String == "getAppData" {
            let appData = AppSettings.appData
            self.evaluateString("setLocalData('\(appData)');")
        } else if var message = message.body as? String, message.contains("setUserHasPass") {
            message = message.replacingOccurrences(of: "setUserHasPass('", with: "").replacingOccurrences(of: "setUserHasPass(", with: "").replacingOccurrences(of: "')", with: "").replacingOccurrences(of: ")", with: "").lowercased()
            if message == "true" {
                AppSettings.userHasPassport = true
            } else if message == "false" {
                AppSettings.userHasPassport = false
            }
        } else if message.body as? String == String.MessageHandler.GET_LOGS {
            self.setLogs()
        } else if let message = message.body as? String, message.contains("setUserContactTracingPreference") {
            if message.contains("true") {
                AppSettings.dateTracingStoped = nil
                if String.General.PASSPORT_NEEDED {
                    if AppSettings.userHasPassport {
                        AppSettings.bluetoothRequested = true
                        self.startBluetooth()
                        self.setBTStatus()
                    }
                } else {
                    AppSettings.bluetoothRequested = true
                     self.startBluetooth()
                    self.setBTStatus()
                }
            } else if message.contains("false") {
                AppSettings.dateTracingStoped = Date()
                AppSettings.bluetoothRequested = false
                ContactTracingManager.sharedInstance.stopTracing()
                self.setBTStatus()
            }
        } else if let data = (message.body as? String)?.data(using: .utf8), let share = try? JSONDecoder().decode(ShareMessage.self, from: data) {
            self.share(share.message, image: share.image, url: share.url)
        }

        print("Message received: \(message.name) with body: \(message.body)")

    }
    
    func evaluateString(_ javaScriptString: String) {
        self.webview.evaluateJavaScript(javaScriptString) { (result, error) in
            guard error == nil else {
                print(error.debugDescription)
                return
            }
        }
    }
    
    func share(_ message: String, image: URL?, url: URL?) {
        var items: [Any] = [message]
        if let urlImage = image {
            downloadImage(from: urlImage) { (result) in
                if let result = result {
                    items.append(result)
                }
                if let url = url {
                    items.append(url)
                }
                let vc = UIActivityViewController(activityItems: items, applicationActivities: [])
                vc.completionWithItemsHandler = { activity, success, items, error in
                    DispatchQueue.main.async() { [weak self] in
                        self?.shareCompleted(success)
                    }
                }
                self.present(vc, animated: true)
            }
        } else if let url = url {
            items.append(url)
            let vc = UIActivityViewController(activityItems: items, applicationActivities: [])
            vc.completionWithItemsHandler = { activity, success, items, error in
                DispatchQueue.main.async() { [weak self] in
                    self?.shareCompleted(success)
                }
            }
            present(vc, animated: true)
        } else {
            let vc = UIActivityViewController(activityItems: items, applicationActivities: [])
            vc.completionWithItemsHandler = { activity, success, items, error in
                DispatchQueue.main.async() { [weak self] in
                    self?.shareCompleted(success)
                }
            }
            present(vc, animated: true)
        }
        
    }
    
    func shareCompleted(_ success: Bool) {
        let javaScriptString = "shareResult('\(success ? 1 : 2)');"
        self.evaluateString(javaScriptString)
    }
    
    func downloadImage(from url: URL, completion: @escaping (UIImage?)->()) {
        getData(from: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            DispatchQueue.main.async() { [weak self] in
                completion(UIImage(data: data))
            }
        }
    }

    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }

    func setLogs() {
        let logs = AppSettings.logs
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: logs, options: .prettyPrinted)
            let jsonStr = String(decoding: jsonData, as: UTF8.self).replacingOccurrences(of: "\n", with: "")
            let javaScriptString = "setLogs('\(jsonStr)');"
            self.webview.evaluateJavaScript(javaScriptString) { (result, error) in
                guard error == nil else {
                    print(error.debugDescription)
                    return
                }
                if logs.count > 3000 {
                    AppSettings.logs = Array(logs[(logs.count - 1000)..<logs.count])
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func readQR() {
        if let qrVC = self.storyboard?.instantiateViewController(withIdentifier: "qrVC") as? QRViewController {
            qrVC.delegate = self
            self.present(qrVC, animated: true, completion: nil)
        }
    }

    func readQRError() {
        if let qrVC = self.storyboard?.instantiateViewController(withIdentifier: "qrVC") as? QRViewController {
            qrVC.errorMessage = true
            qrVC.delegate = self
            self.present(qrVC, animated: true, completion: nil)
        }
    }
    
    func getContacts() {
        if Bundle.main.contactPermission != nil {
            CNContactStore().requestAccess(for: .contacts) { (access, error) in
                if access {
                    DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
                        var contacts = [CNContact]()
                        let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]
                        let request = CNContactFetchRequest(keysToFetch: keys)

                        do {
                            try CNContactStore().enumerateContacts(with: request) { (contact, stop) in
                                contacts.append(contact)
                            }

                            var parsedContacts = [String:String]()
                            for contact in contacts {
                                let name = "\(contact.givenName) \(contact.familyName)"
                                for number in contact.phoneNumbers {
                                    parsedContacts[number.value.stringValue] = name
                                }
                            }
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.setContacts(parsedContacts)
                            })
                        }
                        catch {
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.evaluateString("setContactsError();")
                            })
                            print("unable to fetch contacts")
                        }
                    })
                } else {
                    self.evaluateString("setContactsError();")
                }
            }
        }
    }
    
    func setContacts(_ contacts: [String:String]) {
        var contactsString = "{"
        for contact in contacts {
            contactsString.append("\"\(contact.key)\":\"\(contact.value)\",")
        }
        contactsString.append("}")
        contactsString = contactsString.replacingOccurrences(of: ",}", with: "}")
        
        let javaScriptString:String
        if let utf8str = contactsString.data(using: .utf8) {
            let base64Encoded = utf8str.base64EncodedData(options: Data.Base64EncodingOptions(rawValue: 0))
            if let string = String(bytes: base64Encoded, encoding: .utf8) {
                javaScriptString = "setContacts('\(string)');"
            } else {
                javaScriptString = "setContacts('\(base64Encoded)');"
            }

        } else {
            javaScriptString = "setContacts('\(contactsString)');"
        }
        
        self.evaluateString(javaScriptString)
        
    }
    
    func startBluetooth() {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification && AppSettings.bluetoothRequested {
            ContactTracingManager.sharedInstance.startTracing()
        } else if String.General.CONTACT_TRACING_MODEL != .exposure_notification && Bundle.main.bluetoothPermission != nil && AppSettings.bluetoothRequested {
            print(AppSettings.bluetoothRequested)

            let blePoweredOn = BluetraceManager.shared.isBluetoothOn()
            // let bleAuthorized = BluetraceManager.shared.isBluetoothAuthorized()

            if String.General.BUSINESS_DAYS_TRACING {
                if AppSettings.dateTracingStoped == nil {
                    BlueTraceLocalNotifications.shared.checkAuthorization { (granted) in
                        if granted && blePoweredOn /*&& bleAuthorized*/ {
                            ContactTracingManager.sharedInstance.startTracing()
                            (UIApplication.shared.delegate as? AppDelegate)?.startAccelerometerUpdates()
                        }
                    }
                }
            } else {
                BlueTraceLocalNotifications.shared.checkAuthorization { (granted) in
                    if granted && blePoweredOn /*&& bleAuthorized*/ {
                        ContactTracingManager.sharedInstance.startTracing()
                        (UIApplication.shared.delegate as? AppDelegate)?.startAccelerometerUpdates()
                    }
                }
            }
            
        }
    }

    func setBTStatus() {
        ContactTracingManager.sharedInstance.getBTStatus { (status) in
            self.evaluateString("setBTStatus('\(status)');")
        }
    }
    
    func setExposedLength() {
        self.evaluateString("setExposedLength(\(AppSettings.exposedLength));")
    }
    
    func setWindowLength() {
        self.evaluateString("setWindowLength(\(AppSettings.windowLength));")
    }

    func shareApp(url:String, name:String, description:String) {
        if let urlToShare = URL(string: url) {
            Analytics.logEvent(AnalyticsEventShare, parameters: nil)
            let objectsToShare = ["\(name). \(description)", urlToShare] as [Any]
            let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    func sendLocation() {
        if let token = AppSettings.userToken {
            self.sendLocations(token: token) { (success) in
                if success {
                    AppSettings.lastGPSData = Date()
                    BluetraceUtils.removeAllLocationData()
                }
            }
        }
    }
    
    func sendLocations(token: String, _ result: @escaping (Bool) -> Void) {
        let manufacturer = "Apple"
        let model = DeviceInfo.getModel().replacingOccurrences(of: " ", with: "")

        let date: Date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let todayDate = dateFormatter.string(from: date)

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            result(false)
            return
        }

        let managedContext = appDelegate.persistentContainer.viewContext

        let recordsFetchRequest: NSFetchRequest<Location> = Location.fetchRequestForLocations()

        managedContext.perform {

            guard let records = try? recordsFetchRequest.execute() else {
                Logger.DLog("Error fetching records")
                result(false)
                return
            }
            
            let data = LocationFileData(manufacturer: manufacturer, model: model, todayDate: todayDate, records: records)

            let encoder = JSONEncoder()
            guard let json = try? encoder.encode(data) else {
                Logger.DLog("Error serializing data")
                result(false)
                return
            }
            
            let jsonString = String(data: json, encoding: .utf8)
            Logger.DLog("JSON to send: \(String(describing: jsonString))")

            let urlString = "\(String.Api.BASE_URL)\(String.Api.POST_LOCATIONS)"

            guard let url = URL(string: urlString) else {
                Logger.DLog("Error api URL")
                result(false)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = json
            request.addValue("application/json", forHTTPHeaderField: "content-type")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("ios", forHTTPHeaderField: "API-apptype")

            if let session = (UIApplication.shared.delegate as? AppDelegate)?.trustKitCertificatePinning?.session {
                let task = session.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async(execute: { () -> Void in
                        if let error = error {
                            print(error.localizedDescription)
                            result(false)
                        } else if let httpResponse = response as? HTTPURLResponse {
                            switch httpResponse.statusCode {
                            case 200:
                                result(true)
                            default:
                                print(httpResponse.statusCode)
                                result(false)
                            }
                        } else {
                            result(false)
                        }
                    })
                }
                task.resume()
            }
            
        }
    }
    
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        let latitude = locValue.latitude
        let longitude = locValue.longitude
        manager.stopUpdatingLocation()

        AppSettings.gpsRequested = true
        Location.saveLocationWithCurrentTime(latitude: latitude, longitude: longitude, accuracy: manager.location?.horizontalAccuracy)
    }
    
    @objc func getLocation() {
        if Bundle.main.locationPermission != nil {
            let locationManager = CLLocationManager()
            locationManager.requestWhenInUseAuthorization()
            if CLLocationManager.locationServicesEnabled() {
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                locationManager.startUpdatingLocation()
            }
        }
    }
    
    
}

extension ViewController: QRViewControllerDelegate {

    func setQRCode(_ code: String) {
        self.evaluateString("setQRString('\(code)');")
    }
    
    func cancelQRScan() {
        self.evaluateString("cancelQR();")
    }
    
}


extension ViewController: MFMessageComposeViewControllerDelegate {

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        switch result.rawValue {
        case 0:
            Logger.DLog("SMS canceled")
        case 1:
            Logger.DLog("SMS sent")
        default:
            Logger.DLog("SMS failed")
        }
    }
    
}

struct ShareMessage: Codable {
    let message: String
    let image: URL?
    let url: URL?
}
