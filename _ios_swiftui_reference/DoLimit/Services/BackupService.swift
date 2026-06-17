import Foundation
import SwiftData

/// ローカルデータを JSON でエクスポート / インポート。対象: Tasks / Genres / Settings。
@MainActor
enum BackupService {

    // MARK: DTO

    struct Backup: Codable {
        var version: Int = 1
        var exportedAt: Date
        var tasks: [TaskDTO]
        var genres: [GenreDTO]
        var settings: SettingsDTO
    }

    struct GenreDTO: Codable {
        var id: UUID, name: String, colorHex: String, createdAt: Date, updatedAt: Date
    }

    struct SettingsDTO: Codable {
        var notificationsEnabled: Bool
        var badgeEnabled: Bool
        var morning: [Int], midday: [Int], settlement: [Int], laterAutoMove: [Int]
    }

    struct TaskDTO: Codable {
        var id: UUID
        var title: String
        var memo: String?
        var status: String
        var genreId: UUID?
        var createdAt: Date
        var updatedAt: Date
        var completedAt: Date?
        var deletedAt: Date?
        var movedToTodayAt: Date?
        var todayOrder: Int
        var todayAddedCount: Int
        var consecutiveUnfinishedDays: Int
        var lastTodayDate: Date?
        var snoozeCountToday: Int
        var lastRemindedAt: Date?
        var startAt: Date?
        var startDateOnly: Bool
        var reminderEnabled: Bool
        var reminderAt: Date?
        var reminderOffsetValue: Int?
        var reminderOffsetUnit: String?
        var autoMoveToToday: Bool
        var pendingMoveToToday: Bool
        var source: String
        var pendingAutoMoveToLater: Bool
        var lastAutoMovedAt: Date?
        var lastSweptAt: Date?
    }

    // MARK: Export

    static func export(context: ModelContext) throws -> Data {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let genres = (try? context.fetch(FetchDescriptor<Genre>())) ?? []
        let s = AppSettings.shared
        let backup = Backup(
            exportedAt: Date(),
            tasks: tasks.map(dto(from:)),
            genres: genres.map { GenreDTO(id: $0.id, name: $0.name, colorHex: $0.colorHex, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            settings: SettingsDTO(
                notificationsEnabled: s.notificationsEnabled,
                badgeEnabled: s.badgeEnabled,
                morning: [s.morning.hour, s.morning.minute],
                midday: [s.midday.hour, s.midday.minute],
                settlement: [s.settlement.hour, s.settlement.minute],
                laterAutoMove: [s.laterAutoMove.hour, s.laterAutoMove.minute])
        )
        return try JSONEncoder.iso.encode(backup)
    }

    // MARK: Import（全置換）

    static func restore(from data: Data, context: ModelContext) throws {
        let backup = try JSONDecoder.iso.decode(Backup.self, from: data)

        // 既存削除
        for t in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] { context.delete(t) }
        for g in (try? context.fetch(FetchDescriptor<Genre>())) ?? [] { context.delete(g) }

        for g in backup.genres {
            context.insert(Genre(id: g.id, name: g.name, colorHex: g.colorHex, createdAt: g.createdAt, updatedAt: g.updatedAt))
        }
        for d in backup.tasks { context.insert(model(from: d)) }
        try context.save()

        // 設定
        let s = AppSettings.shared
        s.notificationsEnabled = backup.settings.notificationsEnabled
        s.badgeEnabled = backup.settings.badgeEnabled
        if backup.settings.morning.count == 2 { s.morning = .init(hour: backup.settings.morning[0], minute: backup.settings.morning[1]) }
        if backup.settings.midday.count == 2 { s.midday = .init(hour: backup.settings.midday[0], minute: backup.settings.midday[1]) }
        if backup.settings.settlement.count == 2 { s.settlement = .init(hour: backup.settings.settlement[0], minute: backup.settings.settlement[1]) }
        if backup.settings.laterAutoMove.count == 2 { s.laterAutoMove = .init(hour: backup.settings.laterAutoMove[0], minute: backup.settings.laterAutoMove[1]) }
    }

    // MARK: 全削除

    static func deleteAll(context: ModelContext) {
        for t in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] { context.delete(t) }
        for g in (try? context.fetch(FetchDescriptor<Genre>())) ?? [] { context.delete(g) }
        try? context.save()
    }

    // MARK: Mapping

    private static func dto(from t: TaskItem) -> TaskDTO {
        TaskDTO(id: t.id, title: t.title, memo: t.memo, status: t.statusRaw, genreId: t.genreId,
                createdAt: t.createdAt, updatedAt: t.updatedAt, completedAt: t.completedAt, deletedAt: t.deletedAt,
                movedToTodayAt: t.movedToTodayAt, todayOrder: t.todayOrder, todayAddedCount: t.todayAddedCount,
                consecutiveUnfinishedDays: t.consecutiveUnfinishedDays, lastTodayDate: t.lastTodayDate,
                snoozeCountToday: t.snoozeCountToday, lastRemindedAt: t.lastRemindedAt,
                startAt: t.startAt, startDateOnly: t.startDateOnly, reminderEnabled: t.reminderEnabled,
                reminderAt: t.reminderAt, reminderOffsetValue: t.reminderOffsetValue,
                reminderOffsetUnit: t.reminderOffsetUnitRaw, autoMoveToToday: t.autoMoveToToday,
                pendingMoveToToday: t.pendingMoveToToday, source: t.sourceRaw,
                pendingAutoMoveToLater: t.pendingAutoMoveToLater, lastAutoMovedAt: t.lastAutoMovedAt,
                lastSweptAt: t.lastSweptAt)
    }

    private static func model(from d: TaskDTO) -> TaskItem {
        let t = TaskItem(title: d.title)
        t.id = d.id; t.memo = d.memo; t.statusRaw = d.status; t.genreId = d.genreId
        t.createdAt = d.createdAt; t.updatedAt = d.updatedAt; t.completedAt = d.completedAt; t.deletedAt = d.deletedAt
        t.movedToTodayAt = d.movedToTodayAt; t.todayOrder = d.todayOrder; t.todayAddedCount = d.todayAddedCount
        t.consecutiveUnfinishedDays = d.consecutiveUnfinishedDays; t.lastTodayDate = d.lastTodayDate
        t.snoozeCountToday = d.snoozeCountToday; t.lastRemindedAt = d.lastRemindedAt
        t.startAt = d.startAt; t.startDateOnly = d.startDateOnly; t.reminderEnabled = d.reminderEnabled
        t.reminderAt = d.reminderAt; t.reminderOffsetValue = d.reminderOffsetValue
        t.reminderOffsetUnitRaw = d.reminderOffsetUnit; t.autoMoveToToday = d.autoMoveToToday
        t.pendingMoveToToday = d.pendingMoveToToday; t.sourceRaw = d.source
        t.pendingAutoMoveToLater = d.pendingAutoMoveToLater; t.lastAutoMovedAt = d.lastAutoMovedAt
        t.lastSweptAt = d.lastSweptAt
        return t
    }
}
