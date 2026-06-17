import Foundation
import SwiftData

/// アプリの中心となるタスク。BOX / TODAY / LATER を `status` で表す。
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var memo: String?
    var statusRaw: String
    var genreId: UUID?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var deletedAt: Date?

    // MARK: TODAY 関連
    var movedToTodayAt: Date?
    var todayOrder: Int
    var todayAddedCount: Int
    var consecutiveUnfinishedDays: Int
    var lastTodayDate: Date?
    var snoozeCountToday: Int
    var lastRemindedAt: Date?

    // MARK: LATER 関連
    var startAt: Date?
    var startDateOnly: Bool
    var reminderEnabled: Bool
    var reminderAt: Date?
    var reminderOffsetValue: Int?
    var reminderOffsetUnitRaw: String?
    var autoMoveToToday: Bool
    var pendingMoveToToday: Bool

    // MARK: その他
    var sourceRaw: String
    var pendingAutoMoveToLater: Bool
    var lastAutoMovedAt: Date?
    var lastSweptAt: Date?

    init(title: String,
         status: TaskStatus = .box,
         source: TaskSource = .manual,
         genreId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.memo = nil
        self.statusRaw = status.rawValue
        self.genreId = genreId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = nil
        self.deletedAt = nil

        self.movedToTodayAt = nil
        self.todayOrder = 0
        self.todayAddedCount = 0
        self.consecutiveUnfinishedDays = 0
        self.lastTodayDate = nil
        self.snoozeCountToday = 0
        self.lastRemindedAt = nil

        self.startAt = nil
        self.startDateOnly = false
        self.reminderEnabled = false
        self.reminderAt = nil
        self.reminderOffsetValue = nil
        self.reminderOffsetUnitRaw = nil
        self.autoMoveToToday = true
        self.pendingMoveToToday = false

        self.sourceRaw = source.rawValue
        self.pendingAutoMoveToLater = false
        self.lastAutoMovedAt = nil
        self.lastSweptAt = nil
    }

    // MARK: - Computed accessors (enum bridging)

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .box }
        set { statusRaw = newValue.rawValue }
    }

    var source: TaskSource {
        get { TaskSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var reminderOffsetUnit: ReminderOffsetUnit? {
        get { reminderOffsetUnitRaw.flatMap(ReminderOffsetUnit.init(rawValue:)) }
        set { reminderOffsetUnitRaw = newValue?.rawValue }
    }

    /// TODAY 画面に出す「放置日数」表示
    var ageLabel: String {
        if consecutiveUnfinishedDays >= 3 {
            return "3日連続未完了"
        }
        guard let moved = movedToTodayAt else { return "今日追加" }
        let days = Calendar.current.dateComponents([.day],
                                                   from: Calendar.current.startOfDay(for: moved),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        if days <= 0 { return "今日追加" }
        return "放置\(days)日目"
    }
}
