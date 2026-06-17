import SwiftUI
import SwiftData

@main
struct DoLimitApp: App {
    let container: ModelContainer
    @StateObject private var settings = AppSettings.shared
    @StateObject private var toast = ToastCenter()

    init() {
        let schema = Schema([TaskItem.self, Genre.self])
        // App Group 共有ストア（ウィジェットと同じコンテナにする場合）
        let config: ModelConfiguration
        if let _ = AppGroup.sharedDefaults {
            config = ModelConfiguration(schema: schema,
                                        groupContainer: .identifier(AppGroup.id))
        } else {
            config = ModelConfiguration(schema: schema)
        }
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // フォールバック（テスト等）
            container = try! ModelContainer(for: schema,
                                            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(toast)
                .tint(Theme.ink)
        }
        .modelContainer(container)
    }
}

/// オンボーディング未完了ならオンボーディング、完了後はタブへ。
struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if settings.onboardingDone {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { runMaintenance() }
        }
        .task { runMaintenance() }
    }

    private func runMaintenance() {
        let service = TaskService(context: context)
        service.runMaintenance()
        NotificationManager.shared.rescheduleDailyReminders()
    }
}
