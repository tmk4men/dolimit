import Foundation

// `.sheet(item:)` などで使うための Identifiable 明示。`id: UUID` を持つため自動合成される。
extension TaskItem: Identifiable {}
extension Genre: Identifiable {}
