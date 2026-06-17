import SwiftUI
import SwiftData

/// ＋ から開くタスク追加シート。入力はタスク名のみ。必ず BOX へ。
/// 音声: A案（iOS の音声入力キーボードを使えるテキストフィールドにフォーカス）。
struct AddTaskSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toast: ToastCenter

    @State private var title = ""
    @State private var usedVoice = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    TextField("やることを入力", text: $title, axis: .vertical)
                        .font(.title3)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)

                    // 音声入力（iOS 音声入力キーボードにフォーカス）
                    Button {
                        usedVoice = true
                        focused = true
                        // TODO: SFSpeechRecognizer によるフル音声認識（現状はキーボード音声入力導線）
                    } label: {
                        Image(systemName: Icon.mic)
                            .font(.title3)
                            .foregroundStyle(Theme.sub)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))

                Text("BOXに入れる。左右で仕分ける。TODAYで決着。")
                    .font(.footnote)
                    .foregroundStyle(Theme.sub)

                Spacer()
            }
            .padding()
            .navigationTitle("BOXに追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", action: add)
                        .fontWeight(.bold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(260), .medium])
    }

    private func add() {
        let service = TaskService(context: context)
        let result = service.addToBox(title: title, source: usedVoice ? .voice : .manual)
        switch result {
        case .added:
            toast.show("BOXに追加しました")
            dismiss()
        case .boxFull:
            // 通常はシート提示前に弾くが、念のため
            toast.show(Limits.fullMessage(for: .box))
            dismiss()
        }
    }
}
