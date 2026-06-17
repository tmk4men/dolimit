import SwiftUI
import SwiftData

/// タスク名（とメモ）の編集
struct EditTaskSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    @State private var title = ""
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タスク名", text: $title, axis: .vertical)
                }
                Section("メモ") {
                    TextField("メモ（任意）", text: $memo, axis: .vertical)
                }
            }
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.bold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { title = task.title; memo = task.memo ?? "" }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let service = TaskService(context: context)
        service.setTitle(task, title)
        task.memo = memo.isEmpty ? nil : memo
        service.save()
        dismiss()
    }
}
