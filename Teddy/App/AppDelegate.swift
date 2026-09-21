//
//  AppDelegate.swift
//  Teddy
//

import SwiftData
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    let modelContainer: ModelContainer
    let notificationDelegate = NotificationDelegate()

    override init() {
        do {
            modelContainer = try ModelContainer(for: Reminder.self, HomeLeaveSettings.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        super.init()
        notificationDelegate.modelContainer = modelContainer
        LocationMonitor.shared.configure(modelContainer: modelContainer)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        NotificationScheduler.registerCategories()
        LocationMonitor.shared.refreshMonitoring()
        return true
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var modelContainer: ModelContainer?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == NotificationScheduler.doneActionIdentifier else { return }
        guard let modelContainer else { return }

        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo[NotificationScheduler.reminderIDKey] as? String,
              let reminderID = UUID(uuidString: idString)
        else {
            return
        }

        await NotificationScheduler.completeToday(reminderID: reminderID, modelContainer: modelContainer)
    }
}
