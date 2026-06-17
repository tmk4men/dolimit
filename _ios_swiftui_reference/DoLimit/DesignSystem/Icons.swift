import SwiftUI

/// モノクロ線画アイコン。SF Symbols（線画ウェイト）を用途名で集約。
/// 必要なら自作 SVG（Shape）に差し替え可能。
enum Icon {
    static let box = "tray"
    static let today = "sun.max"
    static let clock = "clock"
    static let later = "moon"
    static let hourglass = "hourglass"
    static let plus = "plus"
    static let check = "checkmark"
    static let checkCircle = "checkmark.circle"
    static let menuDots = "ellipsis"
    static let bell = "bell"
    static let calendar = "calendar"
    static let trash = "trash"
    static let swipe = "arrow.left.arrow.right"
    static let badge = "app.badge"
    static let home = "house"
    static let settings = "gearshape"
    static let genre = "tag"
    static let mic = "mic"
    static let settlement = "moon.stars"
    static let edit = "pencil"
    static let moveToday = "arrow.right"
    static let moveLater = "arrow.left"
}

/// チェックボックス（線画・モノクロ）
struct CheckBox: View {
    let isOn: Bool
    var size: CGFloat = 26
    var body: some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(isOn ? Theme.ink : Theme.sub)
            .contentTransition(.symbolEffect(.replace))
    }
}

/// スワイプ方向の薄いヒント「← LATER　　TODAY →」
struct SwipeHint: View {
    var body: some View {
        HStack {
            Label("LATER", systemImage: Icon.moveLater)
                .foregroundStyle(Theme.laterAccent.opacity(0.7))
            Spacer()
            Label {
                Text("TODAY")
            } icon: {
                Image(systemName: Icon.moveToday)
            }
            .labelStyle(.trailingIcon)
            .foregroundStyle(Theme.todayAccent.opacity(0.7))
        }
        .font(.caption.weight(.semibold))
    }
}

/// アイコンを右に置く Label スタイル
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { .init() }
}
