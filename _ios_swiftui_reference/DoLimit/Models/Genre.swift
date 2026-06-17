import Foundation
import SwiftData
import SwiftUI

/// ジャンル（アプリ全体で最大 5 個・TODAY / LATER 共有）
@Model
final class Genre {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         name: String,
         colorHex: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var color: Color { Color(hex: colorHex) ?? .gray }
}
