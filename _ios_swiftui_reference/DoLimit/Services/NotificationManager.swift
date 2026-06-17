import Foundation
import UserNotifications

/// ローカル通知の集約。広告は一切出さない。
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    enum ID {
        static let morning = "daily.morning"
        static let midday = "daily.midday"
        static let settlement = "daily.settlement"
        static func laterReminder(_ id: UUID) -> String { "later.reminder.\(id.uuidString)" }
        static func laterMove(_ id: UUID) -> String { "later.move.\(id.uuidString)" }
    }

    // MARK: 権限

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: 定期通知（朝 / 日中 / 夜の精算）

    func rescheduleDailyReminders() {
        let s = AppSettings.shared
        center.removePendingNotificationRequests(withIdentifiers: [ID.morning, ID.midday, ID.settlement])
        guard s.notificationsEnabled else { return }

        scheduleDaily(id: ID.morning, time: s.morning,
                      title: "TODAYを確認",
                      body: "今日やることを見返しましょう。")
        scheduleDaily(id: ID.midday, time: s.midday,
                      title: "TODAY 未完了",
                      body: "TODAYに未完了タスクが残っています。")
        scheduleDaily(id: ID.settlement, time: s.settlement,
                      title: "今日の精算",
                      body: "TODAYに未完了タスクがあります。精算しましょう。")
    }

    private func scheduleDaily(id: String, time: TimeOfDay, title: String, body: String) {
        var comps = DateComponents()
        comps.hour = time.hour
        comps.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: LATER 系（単発）

    func scheduleLaterReminder(taskId: UUID, title: String, at date: Date) {
        guard AppSettings.shared.notificationsEnabled, date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "まもなく開始"
        content.body = title
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false)
        center.add(UNNotificationRequest(identifier: ID.laterReminder(taskId), content: content, trigger: trigger))
    }

    func cancelLaterReminder(taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.laterReminder(taskId)])
    }

    // MARK: 即時通知（自動移動 / 自動追放）

    func notifyMovedToToday(title: String) {
        push(title: "TODAYに移動しました", body: title)
    }
    func notifyTodayFull(title: String) {
        push(title: "TODAYがいっぱいです", body: "\(title)を入れるには、TODAYを整理してください")
    }
    func notifyBanishedToLater(title: String) {
        push(title: "LATERへ移動しました", body: "\(title)は3日連続で未完了のため、LATERへ移動しました。")
    }

    private func push(title: String, body: String) {
        guard AppSettings.shared.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
    }
}
