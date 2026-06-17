import SwiftUI
import Combine

/// 「BOXに追加しました」などの短いトースト。
@MainActor
final class ToastCenter: ObservableObject {
    @Published var message: String?
    private var clearTask: Task<Void, Never>?

    func show(_ text: String) {
        message = text
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run { self?.message = nil }
        }
    }
}

/// トーストのオーバーレイ
struct ToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = center.message {
                Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Capsule().fill(.black.opacity(0.85)))
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: center.message)
    }
}
extension View {
    func toast(_ center: ToastCenter) -> some View { modifier(ToastOverlay(center: center)) }
}
