// 配置先: iOS の Widget Extension ターゲット（例: DoLimitWidget）の Swift。
// App Group（例: group.dolimit.widget）を Runner と Widget の両ターゲットに付与すること。
import WidgetKit
import SwiftUI
import UIKit

private let appGroupId = "group.dolimit.widget"

// アプリ本体の配色に合わせる（ライト/ダークで自動切替）。
// todayAccent: light #F23B30 / dark #FF5B50、card: white / #1A1C21
private let dolimitAccent = Color(UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.357, blue: 0.314, alpha: 1)   // #FF5B50
        : UIColor(red: 0.949, green: 0.231, blue: 0.188, alpha: 1) // #F23B30
})
private let dolimitCard = Color(UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 0.102, green: 0.110, blue: 0.129, alpha: 1)  // #1A1C21
        : UIColor.white
})

struct DoLimitEntry: TimelineEntry {
    let date: Date
    let count: Int
    let titles: [String]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DoLimitEntry {
        DoLimitEntry(date: Date(), count: 0, titles: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (DoLimitEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoLimitEntry>) -> Void) {
        // 30分ごとに更新（アプリ側の updateWidget でも即時更新される）
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [readEntry()], policy: .after(next)))
    }

    private func readEntry() -> DoLimitEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let count = defaults?.integer(forKey: "today_count") ?? 0
        let raw = defaults?.string(forKey: "today_titles") ?? ""
        let titles = raw.isEmpty ? [] : raw.components(separatedBy: "\n")
        return DoLimitEntry(date: Date(), count: count, titles: titles)
    }
}

struct DoLimitWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    // small は狭いので 2 件、medium 以上は 3 件。
    private var maxTitles: Int { family == .systemSmall ? 2 : 3 }
    private var isCleared: Bool { entry.count == 0 && entry.titles.isEmpty }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // タップでアプリを起動して TODAY を開く（Dart 側が dolimit://today を待ち受ける）。
            .widgetURL(URL(string: "dolimit://today"))
            .widgetBackground(dolimitCard)
    }

    @ViewBuilder private var content: some View {
        if isCleared {
            // TODAY を片づけ切った達成状態。アプリ本体の「今日は決着！」と揃える。
            VStack(alignment: .leading, spacing: 6) {
                Text("🎉").font(.system(size: 26))
                Text("今日は決着！")
                    .font(.system(size: 15, weight: .heavy))
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY 残り")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(entry.count)")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(dolimitAccent)
                ForEach(entry.titles.prefix(maxTitles), id: \.self) { t in
                    Text("・\(t)")
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                Spacer()
            }
        }
    }
}

// iOS 17 は containerBackground が必須。旧OSは background() にフォールバック。
private extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}

@main
struct DoLimitWidget: Widget {
    let kind: String = "DoLimitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DoLimitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DoLimit")
        .description("TODAY の残り件数と上位タスクを表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
