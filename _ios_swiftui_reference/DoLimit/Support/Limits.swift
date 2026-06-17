import Foundation

/// 登録上限。タスクを無限に溜めさせないためのプロダクト中心思想。
enum Limits {
    static let box = 15
    static let today = 10
    static let later = 20
    static let genre = 5

    static func capacity(for status: TaskStatus) -> Int? {
        switch status {
        case .box:   return box
        case .today: return today
        case .later: return later
        default:     return nil
        }
    }

    static func fullMessage(for status: TaskStatus) -> String {
        switch status {
        case .box:   return "BOXがいっぱいです。先に仕分けてください。"
        case .today: return "TODAYがいっぱいです。1件完了するか、LATERへ移動してください。"
        case .later: return "LATERがいっぱいです。整理してください。"
        default:     return ""
        }
    }
}
