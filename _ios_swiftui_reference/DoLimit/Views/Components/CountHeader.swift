import SwiftUI

/// 「BOX 8/15」のような数字中心ヘッダー
struct CountHeader: View {
    let title: String
    let count: Int
    let capacity: Int
    var accent: Color = Theme.ink

    var isFull: Bool { count >= capacity }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(accent)
            Text("\(count)/\(capacity)")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(isFull ? Theme.todayAccent : Theme.sub)
            Spacer()
        }
    }
}
