import Foundation
import SwiftData

/// タスク操作の中心。限度チェック・状態遷移・バッジ/スナップショット更新・自動処理をまとめる。
@MainActor
final class TaskService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Fetch helpers

    func activeTasks(in status: TaskStatus) -> [TaskItem] {
        let raw = status.rawValue
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.statusRaw == raw },
            sortBy: [SortDescriptor(\.todayOrder), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func count(in status: TaskStatus) -> Int { activeTasks(in: status).count }

    /// TODAY の未完了数（= バッジ）。status==today はすべて未完了扱い（完了は done へ移すため）。
    var todayUnfinishedCount: Int { count(in: .today) }

    func allGenres() -> [Genre] {
        (try? context.fetch(FetchDescriptor<Genre>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    // MARK: - 追加

    enum AddResult { case added, boxFull }

    @discardableResult
    func addToBox(title: String, source: TaskSource = .manual) -> AddResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .added }
        if count(in: .box) >= Limits.box { return .boxFull }
        let task = TaskItem(title: trimmed, status: .box, source: source)
        context.insert(task)
        save()
        return .added
    }

    // MARK: - 移動（限度チェック付き）

    /// 移動を試みる。満杯なら false（メッセージは Limits.fullMessage）。
    @discardableResult
    func move(_ task: TaskItem, to target: TaskStatus) -> Bool {
        if let cap = Limits.capacity(for: target), count(in: target) >= cap {
            return false
        }
        apply(task, to: target)
        save()
        return true
    }

    private func apply(_ task: TaskItem, to target: TaskStatus) {
        task.status = target
        task.updatedAt = Date()
        switch target {
        case .today:
            task.movedToTodayAt = Date()
            task.lastTodayDate = DayClock.startOfDay()
            task.todayAddedCount += 1
            task.todayOrder = (activeTasks(in: .today).map(\.todayOrder).max() ?? 0) + 1
            task.pendingMoveToToday = false
        case .later:
            task.startAt = task.startAt // 保持
            task.pendingAutoMoveToLater = false
        default:
            break
        }
    }

    // MARK: - 完了 / 削除

    func complete(_ task: TaskItem) {
        task.status = .done
        task.completedAt = Date()
        task.updatedAt = Date()
        task.consecutiveUnfinishedDays = 0
        NotificationManager.shared.cancelLaterReminder(taskId: task.id)
        save()
    }

    func delete(_ task: TaskItem) {
        task.status = .deleted
        task.deletedAt = Date()
        task.updatedAt = Date()
        NotificationManager.shared.cancelLaterReminder(taskId: task.id)
        save()
    }

    // MARK: - 編集

    func setTitle(_ task: TaskItem, _ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        task.title = t
        task.updatedAt = Date()
        save()
    }

    func setGenre(_ task: TaskItem, genreId: UUID?) {
        task.genreId = genreId
        task.updatedAt = Date()
        save()
    }

    // MARK: - TODAY 並び替え

    func reorderToday(_ ordered: [TaskItem]) {
        for (i, t) in ordered.enumerated() { t.todayOrder = i }
        save()
    }

    // MARK: - LATER 開始日 / 通知

    func configureLater(_ task: TaskItem,
                        startAt: Date?,
                        startDateOnly: Bool,
                        autoMove: Bool,
                        reminder: ReminderPreset) {
        task.startAt = startAt
        task.startDateOnly = startDateOnly
        task.autoMoveToToday = autoMove
        applyReminder(task, preset: reminder)
        task.updatedAt = Date()
        scheduleReminderIfNeeded(task)
        save()
    }

    private func applyReminder(_ task: TaskItem, preset: ReminderPreset) {
        switch preset {
        case .none:
            task.reminderEnabled = false
            task.reminderAt = nil
            task.reminderOffsetValue = nil
            task.reminderOffsetUnit = nil
        case .onTime:
            task.reminderEnabled = true
            task.reminderOffsetValue = 0
            task.reminderOffsetUnit = .minute
        case let .offset(v, u):
            task.reminderEnabled = true
            task.reminderOffsetValue = v
            task.reminderOffsetUnit = u
        case .custom:
            // カスタムは reminderOffsetValue / Unit が別途設定済み想定
            task.reminderEnabled = true
        }
    }

    /// 開始時刻と事前通知オフセットから実際の通知時刻を求めてスケジュール
    private func scheduleReminderIfNeeded(_ task: TaskItem) {
        NotificationManager.shared.cancelLaterReminder(taskId: task.id)
        guard task.reminderEnabled, let base = effectiveStartDate(task) else {
            task.reminderAt = nil
            return
        }
        let offset = TimeInterval(task.reminderOffsetValue ?? 0) * (task.reminderOffsetUnit?.seconds ?? 60)
        let fireAt = base.addingTimeInterval(-offset)
        task.reminderAt = fireAt
        NotificationManager.shared.scheduleLaterReminder(taskId: task.id, title: task.title, at: fireAt)
    }

    /// 開始「日時」。時刻未指定なら Settings の LATER 自動移動時刻を使う。
    func effectiveStartDate(_ task: TaskItem) -> Date? {
        guard let start = task.startAt else { return nil }
        if task.startDateOnly {
            let t = AppSettings.shared.laterAutoMove
            return Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: start)
        }
        return start
    }

    // MARK: - 自動処理エンジン（起動時 / 日付変更時 / 精算後）

    /// 日付跨ぎ・LATER 自動移動・3日連続自動追放をまとめて実行。
    func runMaintenance(now: Date = Date()) {
        rollOverDayIfNeeded(now: now)
        autoMoveDueLaterTasks(now: now)
        autoBanishStaleTodayTasks(now: now)
        refreshBadgeAndSnapshot()
    }

    /// 日付が変わったら TODAY の lastTodayDate を更新（精算は通知/画面で行う）
    private func rollOverDayIfNeeded(now: Date) {
        let today = DayClock.startOfDay(now)
        for task in activeTasks(in: .today) {
            if !DayClock.isSameDay(task.lastTodayDate, now) {
                task.lastTodayDate = today
            }
        }
    }

    /// 開始日時が到来した LATER を TODAY へ自動移動
    private func autoMoveDueLaterTasks(now: Date) {
        for task in activeTasks(in: .later) where task.autoMoveToToday {
            guard let due = effectiveStartDate(task), due <= now else { continue }
            if count(in: .today) >= Limits.today {
                // TODAY 満杯 → 移動待ち。LATER に残し通知。
                if !task.pendingMoveToToday {
                    task.pendingMoveToToday = true
                    NotificationManager.shared.notifyTodayFull(title: task.title)
                }
                continue
            }
            apply(task, to: .today)
            task.lastAutoMovedAt = now
            NotificationManager.shared.cancelLaterReminder(taskId: task.id)
            NotificationManager.shared.notifyMovedToToday(title: task.title)
        }
        save()
    }

    /// 3日連続未完了の TODAY を LATER へ自動追放
    private func autoBanishStaleTodayTasks(now: Date) {
        for task in activeTasks(in: .today) where task.consecutiveUnfinishedDays >= 3 {
            if count(in: .later) >= Limits.later {
                task.pendingAutoMoveToLater = true // 追放待ち
                continue
            }
            task.status = .later
            task.consecutiveUnfinishedDays = 0
            task.lastAutoMovedAt = now
            task.pendingAutoMoveToLater = false
            task.updatedAt = now
            NotificationManager.shared.notifyBanishedToLater(title: task.title)
        }
        save()
    }

    // MARK: - 今日の精算アクション

    func settleKeepInToday(_ task: TaskItem) {
        task.consecutiveUnfinishedDays += 1
        task.snoozeCountToday = 0
        task.lastSweptAt = Date()
        task.updatedAt = Date()
        save()
    }

    func settleMoveToLater(_ task: TaskItem) {
        // LATER 満杯時は追放待ち扱い
        if count(in: .later) >= Limits.later {
            task.pendingAutoMoveToLater = true
        } else {
            task.status = .later
            task.consecutiveUnfinishedDays = 0
            task.pendingAutoMoveToLater = false
        }
        task.lastSweptAt = Date()
        task.updatedAt = Date()
        save()
    }

    // MARK: - 保存 & 反映

    func save() {
        try? context.save()
        refreshBadgeAndSnapshot()
    }

    func refreshBadgeAndSnapshot() {
        let today = activeTasks(in: .today)
        BadgeManager.apply(todayUnfinished: today.count)
        writeSnapshot(todayTasks: today)
    }

    private func writeSnapshot(todayTasks: [TaskItem]) {
        let genres = Dictionary(uniqueKeysWithValues: allGenres().map { ($0.id, $0) })
        let top = todayTasks.sorted { $0.todayOrder < $1.todayOrder }.prefix(3).map { t -> TodaySnapshot.Item in
            let g = t.genreId.flatMap { genres[$0] }
            return .init(id: t.id, title: t.title, genreName: g?.name, genreColorHex: g?.colorHex)
        }
        let snap = TodaySnapshot(
            todayCount: todayTasks.count,
            todayCapacity: Limits.today,
            boxCount: count(in: .box),
            boxCapacity: Limits.box,
            topItems: Array(top),
            generatedAt: Date()
        )
        snap.save()
        WidgetReloader.reload()
    }
}
