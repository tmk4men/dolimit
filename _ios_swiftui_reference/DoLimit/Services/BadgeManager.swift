import Foundation
import UserNotifications

/// アプリアイコンバッジ = TODAY の未完了数。
enum BadgeManager {
    /// TODAY 未完了数を反映（設定 OFF or 0 なら非表示）
    static func apply(todayUnfinished count: Int) {
        let enabled = AppSettings.shared.badgeEnabled
        let value = enabled ? count : 0
        UNUserNotificationCenter.current().setBadgeCount(value) { _ in }
    }
}
