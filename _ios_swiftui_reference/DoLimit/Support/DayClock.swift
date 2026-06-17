import Foundation

/// 「今日」の境界・残り時間計算をまとめたヘルパー。
enum DayClock {
    static var calendar: Calendar { Calendar.current }

    static func startOfDay(_ date: Date = Date()) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date = Date()) -> Date {
        let start = startOfDay(date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date
    }

    /// 今日の残り秒
    static func remainingSeconds(now: Date = Date()) -> TimeInterval {
        max(0, endOfDay(now).timeIntervalSince(now))
    }

    static func remainingHours(now: Date = Date()) -> Double {
        remainingSeconds(now: now) / 3600
    }

    /// 「6:42」形式
    static func remainingString(now: Date = Date()) -> String {
        let total = Int(remainingSeconds(now: now))
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    static func isSameDay(_ a: Date?, _ b: Date) -> Bool {
        guard let a else { return false }
        return calendar.isDate(a, inSameDayAs: b)
    }

    /// 指定時刻（時・分）の「今日」での Date
    static func todayAt(hour: Int, minute: Int, now: Date = Date()) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}
