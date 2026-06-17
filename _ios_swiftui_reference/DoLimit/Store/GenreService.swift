import Foundation
import SwiftData

/// ジャンル管理（アプリ全体で最大 5 個）
@MainActor
final class GenreService {
    let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func all() -> [Genre] {
        (try? context.fetch(FetchDescriptor<Genre>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    enum AddResult { case added, full, duplicate }

    @discardableResult
    func add(name: String, colorHex: String) -> AddResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .duplicate }
        let existing = all()
        if existing.count >= Limits.genre { return .full }
        if existing.contains(where: { $0.name == trimmed }) { return .duplicate }
        context.insert(Genre(name: trimmed, colorHex: colorHex))
        try? context.save()
        return .added
    }

    func rename(_ genre: Genre, to name: String) {
        genre.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        genre.updatedAt = Date()
        try? context.save()
    }

    func setColor(_ genre: Genre, hex: String) {
        genre.colorHex = hex
        genre.updatedAt = Date()
        try? context.save()
    }

    /// 削除。紐づくタスクの genreId は nil（ジャンルなし）に戻す。
    func delete(_ genre: Genre) {
        let gid = genre.id
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.genreId == gid }))) ?? []
        for t in tasks { t.genreId = nil }
        context.delete(genre)
        try? context.save()
    }

    func suggestedColor() -> String {
        let used = Set(all().map(\.colorHex))
        return Color.genrePalette.first { !used.contains($0) } ?? Color.genrePalette.randomElementSafe
    }
}

private extension Array where Element == String {
    var randomElementSafe: String { first ?? "#5B6470" }
}
