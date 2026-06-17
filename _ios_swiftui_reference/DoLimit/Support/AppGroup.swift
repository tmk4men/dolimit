import Foundation

/// App / Widget で共有する App Group。Xcode の Capabilities に合わせて変更すること。
enum AppGroup {
    static let id = "group.com.dolimit.app"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: id)
    }
}
