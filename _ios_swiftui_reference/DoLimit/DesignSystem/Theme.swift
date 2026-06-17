import SwiftUI

/// 白 / 黒 / グレー基調。TODAY の残り時間だけ赤、LATER だけ青を使う。
enum Theme {
    // ベース
    static let ink = Color.primary
    static let sub = Color.secondary
    static let bg = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let line = Color.gray.opacity(0.25)

    // 箱ごとのアクセント
    static let boxAccent = Color.gray
    static let todayAccent = Color(red: 0.92, green: 0.30, blue: 0.23) // 赤〜オレンジ
    static let laterAccent = Color(red: 0.20, green: 0.48, blue: 0.92) // 青

    static let cardRadius: CGFloat = 18
    static let spacing: CGFloat = 16

    /// 残り時間の色。夜に近づくほど赤くなる。
    static func remainingColor(hoursLeft: Double) -> Color {
        switch hoursLeft {
        case ..<1:  return Color(red: 0.85, green: 0.0, blue: 0.0)   // 強い赤
        case ..<3:  return todayAccent                                // 赤
        case ..<6:  return Color.orange                               // オレンジ
        default:    return ink                                        // 通常
        }
    }
}

extension Color {
    /// "#RRGGBB" / "RRGGBB" から生成
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// ジャンル候補色（モノクロ基調を崩さない範囲の彩度）
    static let genrePalette: [String] = [
        "#5B6470", "#C0392B", "#2E7D9A", "#2E7D32",
        "#8E44AD", "#D68910", "#16A085", "#34495E"
    ]
}
