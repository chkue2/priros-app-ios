//
//  AppDelegate.swift
//  priros
//
//  Created by 최한규 on 10/25/24.
//

import UIKit
import Firebase
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        requestNotificationAuthorization()
        // Override point for customization after application launch.
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        
        Thread.sleep(forTimeInterval: 2.0)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 등록 토큰 가져오기 오류: \(error)")
            } else if let token = token {
                print("FCM 등록 토큰: \(token)")
                
                NotificationCenter.default.post(name: NSNotification.Name("FCMTokenReceived"), object: token)
            }
        }
    }
    
    func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        center.delegate = self
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // 앱이 포그라운드에 있을 때 푸시 알림을 수신하는 메서드
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 알림을 화면에 표시할지 여부를 설정
        completionHandler([.banner, .sound]) // 배너와 소리로 알림 표시
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        var urlString: String
        
        // "data" 키에서 URL을 추출
        if let url = userInfo["url"] as? String, !url.isEmpty {
            urlString = url
        } else {
            urlString = "https://app.priros.com"
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("urlReceived"), object: urlString)
        
        completionHandler()
    }
}
