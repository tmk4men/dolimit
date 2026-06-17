import SwiftUI
import SwiftData

enum AppTab: Hashable { case home, box, today, later, settings }

/// 下部タブ + 全画面共通 FAB（＋）+ 追加フロー。
struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var toast: ToastCenter

    @State private var tab: AppTab = .home
    @State private var showAdd = false
    @State private var showBoxFull = false
    @State private var showComingSoon = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                HomeView(tab: $tab)
                    .tabItem { Label("Home", systemImage: Icon.home) }.tag(AppTab.home)
                BoxView()
                    .tabItem { Label("BOX", systemImage: Icon.box) }.tag(AppTab.box)
                TodayView()
                    .tabItem { Label("TODAY", systemImage: Icon.today) }.tag(AppTab.today)
                LaterView()
                    .tabItem { Label("LATER", systemImage: Icon.later) }.tag(AppTab.later)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: Icon.settings) }.tag(AppTab.settings)
            }

            FloatingActionButton(action: attemptAdd)
        }
        .toast(toast)
        .sheet(isPresented: $showAdd) { AddTaskSheet() }
        .alert("BOXがいっぱいです", isPresented: $showBoxFull) {
            Button("仕分ける") { tab = .box }
            Button("広告で一時的に+5") { showComingSoon = true }   // TODO: 広告SDK
            Button("Proで枠を増やす") { showComingSoon = true }     // TODO: 課金
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("15個たまっています。先に仕分けてください。")
        }
        .alert("今後実装予定", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) {}
        }
    }

    private func attemptAdd() {
        let service = TaskService(context: context)
        if service.count(in: .box) >= Limits.box {
            showBoxFull = true
        } else {
            showAdd = true
        }
    }
}
