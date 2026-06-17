import SwiftUI

enum GenreFilter: Equatable {
    case all
    case none
    case genre(UUID)

    func matches(_ task: TaskItem) -> Bool {
        switch self {
        case .all: return true
        case .none: return task.genreId == nil
        case let .genre(id): return task.genreId == id
        }
    }
}

/// TODAY / LATER 上部のジャンルフィルター
struct GenreFilterBar: View {
    let genres: [Genre]
    @Binding var selection: GenreFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "すべて", active: selection == .all) { selection = .all }
                chip(title: "ジャンルなし", active: selection == .none) { selection = .none }
                ForEach(genres) { g in
                    chip(title: g.name, active: selection == .genre(g.id), dot: g.color) {
                        selection = .genre(g.id)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(title: String, active: Bool, dot: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                Text(title).font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(active ? Theme.ink : Theme.card))
            .foregroundStyle(active ? Color(.systemBackground) : Theme.ink)
            .overlay(Capsule().stroke(Theme.line, lineWidth: active ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}
