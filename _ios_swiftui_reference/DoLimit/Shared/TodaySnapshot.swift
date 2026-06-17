import Foundation

/// ウィジェット表示用の軽量スナップショット。App Group の UserDefaults に JSON で書き出す。
/// （SwiftData をウィジェットから直接読まず、表示用データだけを共有する方針）
struct TodaySnapshot: Codable {
    struct Item: Codable, Identifiable {
        var id: UUID
        var title: String
        var genreName: String?
        var genreColorHex: String?
    }

    var todayCount: Int          // TODAY 未完了数（バッジと一致）
    var todayCapacity: Int
    var boxCount: Int
    var boxCapacity: Int
    var topItems: [Item]         // TODAY 上位（未完了）
    var generatedAt: Date

    static let empty = TodaySnapshot(todayCount: 0,
                                     todayCapacity: Limits.today,
                                     boxCount: 0,
                                     boxCapacity: Limits.box,
                                     topItems: [],
                                     generatedAt: .distantPast)

    private static let key = "todaySnapshot"

    func save() {
        guard let defaults = AppGroup.sharedDefaults,
              let data = try? JSONEncoder.iso.encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    static func load() -> TodaySnapshot {
        guard let defaults = AppGroup.sharedDefaults,
              let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder.iso.decode(TodaySnapshot.self, from: data) else {
            return .empty
        }
        return snap
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
