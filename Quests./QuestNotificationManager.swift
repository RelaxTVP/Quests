import Foundation
import UserNotifications

enum QuestNotificationManager {
    private static let prefix = "quest.reminder."

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if !granted {
                return
            }
        } catch {
            print("Notification auth error:", error.localizedDescription)
        }
    }

    static func refresh(for quests: [AppQuest]) {
        Task {
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
            let existing = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: existing)

            let calendar = Calendar.current
            let now = Date()

            for quest in quests where !quest.deleted && !quest.archived && !quest.completed {
                let scheduleDate = calendar.startOfDay(for: Date(timeIntervalSince1970: quest.scheduledDate ?? now.timeIntervalSince1970))
                var triggerDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: scheduleDate) ?? scheduleDate
                if triggerDate <= now {
                    triggerDate = now.addingTimeInterval(60)
                }

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("notification_quest_title", comment: "")
                content.body = String(
                    format: NSLocalizedString("notification_quest_body_format", comment: ""),
                    quest.title
                )
                content.sound = .default

                let dayStamp = Int(calendar.startOfDay(for: scheduleDate).timeIntervalSince1970)
                let id = "\(prefix)\(quest.id.uuidString).\(dayStamp)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                } catch {
                    print("Notification add error:", error.localizedDescription)
                }
            }
        }
    }
}

