import SwiftUI

/// 全画面共通の右下 ＋ ボタン
struct FloatingActionButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: Icon.plus)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.ink))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .accessibilityLabel("タスクを追加")
    }
}
