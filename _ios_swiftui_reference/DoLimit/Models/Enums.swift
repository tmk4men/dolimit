import Foundation

/// タスクが入っている箱 / 状態
enum TaskStatus: String, Codable, CaseIterable {
    case box      // 未分類タスク（BOX）
    case today    // 今日やるタスク（TODAY）
    case later    // あとでやるタスク（LATER）
    case done     // 完了
    case deleted  // 削除（論理削除）
}

/// タスクの追加元
enum TaskSource: String, Codable, CaseIterable {
    case manual
    case voice
    case widget
}

/// 事前通知のオフセット単位
enum ReminderOffsetUnit: String, Codable, CaseIterable, Identifiable {
    case minute
    case hour
    case day

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minute: return "分前"
        case .hour:   return "時間前"
        case .day:    return "日前"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .hour:   return 3600
        case .day:    return 86400
        }
    }
}

/// 事前通知のプリセット
enum ReminderPreset: Hashable, Identifiable {
    case none
    case onTime
    case offset(value: Int, unit: ReminderOffsetUnit)
    case custom

    var id: String {
        switch self {
        case .none:   return "none"
        case .onTime: return "onTime"
        case .custom: return "custom"
        case let .offset(v, u): return "offset-\(v)-\(u.rawValue)"
        }
    }

    static let standard: [ReminderPreset] = [
        .none,
        .onTime,
        .offset(value: 5, unit: .minute),
        .offset(value: 10, unit: .minute),
        .offset(value: 30, unit: .minute),
        .offset(value: 1, unit: .hour),
        .offset(value: 3, unit: .hour),
        .offset(value: 1, unit: .day),
        .custom
    ]

    var label: String {
        switch self {
        case .none:   return "なし"
        case .onTime: return "開始時刻ちょうど"
        case .custom: return "カスタム"
        case let .offset(v, u): return "\(v)\(u.label)"
        }
    }
}
