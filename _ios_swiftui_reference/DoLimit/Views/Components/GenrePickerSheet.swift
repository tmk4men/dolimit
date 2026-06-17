import SwiftUI
import SwiftData

/// タスクに紐づけるジャンルを 1 つ選ぶ（なしも可）
struct GenrePickerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    @Query(sort: \Genre.createdAt) private var genres: [Genre]

    var body: some View {
        NavigationStack {
            List {
                Button { set(nil) } label: {
                    row(title: "ジャンルなし", dot: nil, selected: task.genreId == nil)
                }
                ForEach(genres) { g in
                    Button { set(g.id) } label: {
                        row(title: g.name, dot: g.color, selected: task.genreId == g.id)
                    }
                }
                if genres.isEmpty {
                    Text("ジャンルは Settings で作成できます。")
                        .font(.footnote).foregroundStyle(Theme.sub)
                }
            }
            .navigationTitle("ジャンル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private func row(title: String, dot: Color?, selected: Bool) -> some View {
        HStack {
            if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
            Text(title).foregroundStyle(Theme.ink)
            Spacer()
            if selected { Image(systemName: Icon.check).foregroundStyle(Theme.ink) }
        }
    }

    private func set(_ id: UUID?) {
        TaskService(context: context).setGenre(task, genreId: id)
        dismiss()
    }
}
