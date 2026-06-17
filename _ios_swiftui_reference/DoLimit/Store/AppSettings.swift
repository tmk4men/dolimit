import Foundation
import SwiftUI
import Combine

/// 通知・バッジ・各種時刻の設定。App Group の UserDefaults に保存（ウィジェット/拡張からも読める）。
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private init() {
        defaults = AppGroup.sharedDefaults ?? .standard
        registerDefaults()
    }

    // キー
    private enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let badgeEnabled = "badgeEnabled"
        static let morningHour = "morningHour"
        static let morningMinute = "morningMinute"
        static let middayHour = "middayHour"
        static let middayMinute = "middayMinute"
        static let settlementHour = "settlementHour"
        static let settlementMinute = "settlementMinute"
        static let laterAutoMoveHour = "laterAutoMoveHour"
        static let laterAutoMoveMinute = "laterAutoMoveMinute"
        static let onboardingDone = "onboardingDone"
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.notificationsEnabled: true,
            Key.badgeEnabled: true,
            Key.morningHour: 8, Key.morningMinute: 0,
            Key.middayHour: 15, Key.middayMinute: 0,
            Key.settlementHour: 22, Key.settlementMinute: 30,
            Key.laterAutoMoveHour: 7, Key.laterAutoMoveMinute: 0,
            Key.onboardingDone: false
        ])
    }

    private func set<T>(_ value: T, _ key: String) {
        defaults.set(value, forKey: key)
        objectWillChange.send()
    }

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { set(newValue, Key.notificationsEnabled) }
    }
    var badgeEnabled: Bool {
        get { defaults.bool(forKey: Key.badgeEnabled) }
        set { set(newValue, Key.badgeEnabled) }
    }
    var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { set(newValue, Key.onboardingDone) }
    }

    // 時刻系（時・分のペア）
    var morning: TimeOfDay {
        get { .init(hour: defaults.integer(forKey: Key.morningHour), minute: defaults.integer(forKey: Key.morningMinute)) }
        set { set(newValue.hour, Key.morningHour); set(newValue.minute, Key.morningMinute) }
    }
    var midday: TimeOfDay {
        get { .init(hour: defaults.integer(forKey: Key.middayHour), minute: defaults.integer(forKey: Key.middayMinute)) }
        set { set(newValue.hour, Key.middayHour); set(newValue.minute, Key.middayMinute) }
    }
    var settlement: TimeOfDay {
        get { .init(hour: defaults.integer(forKey: Key.settlementHour), minute: defaults.integer(forKey: Key.settlementMinute)) }
        set { set(newValue.hour, Key.settlementHour); set(newValue.minute, Key.settlementMinute) }
    }
    var laterAutoMove: TimeOfDay {
        get { .init(hour: defaults.integer(forKey: Key.laterAutoMoveHour), minute: defaults.integer(forKey: Key.laterAutoMoveMinute)) }
        set { set(newValue.hour, Key.laterAutoMoveHour); set(newValue.minute, Key.laterAutoMoveMinute) }
    }
}

struct TimeOfDay: Equatable {
    var hour: Int
    var minute: Int

    var asDateToday: Date { DayClock.todayAt(hour: hour, minute: minute) }
    var label: String { String(format: "%d:%02d", hour, minute) }

    /// Date のバインディング（DatePicker 用）
    func with(_ date: Date) -> TimeOfDay {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: c.hour ?? hour, minute: c.minute ?? minute)
    }
}
