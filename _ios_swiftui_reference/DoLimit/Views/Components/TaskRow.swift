import SwiftUI

/// 汎用タスク行（カード）。チェック・タイトル・ジャンル・補助情報・⋯メニュー。
struct TaskRow<Menu: View>: View {
    let task: TaskItem
    let genre: Genre?
    var subtitle: String? = nil
    var subtitleColor: Color = Theme.sub
    var onToggle: () -> Void
    var onTapBody: (() -> Void)? = nil
    @ViewBuilder var menu: () -> Menu

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                CheckBox(isOn: task.status == .done)
            }
            .buttonStyle(.plain)

            Button {
                onTapBody?()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .strikethrough(task.status == .done, color: Theme.sub)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        GenreChip(genre: genre)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(subtitleColor)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onTapBody == nil)

            Menu {
                menu()
            } label: {
                Image(systemName: Icon.menuDots)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.sub)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(Theme.card))
    }
}
