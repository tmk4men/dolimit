import SwiftUI

struct GenreChip: View {
    let genre: Genre?
    var body: some View {
        if let genre {
            HStack(spacing: 5) {
                Circle().fill(genre.color).frame(width: 8, height: 8)
                Text(genre.name).font(.caption.weight(.medium))
            }
            .foregroundStyle(Theme.sub)
        }
    }
}

extension Array where Element == Genre {
    func find(_ id: UUID?) -> Genre? {
        guard let id else { return nil }
        return first { $0.id == id }
    }
}
