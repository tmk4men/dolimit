// 配置先: iOS の Widget Extension ターゲット（例: DoLimitWidget）の Swift。
// App Group（例: group.dolimit.widget）を Runner と Widget の両ターゲットに付与すること。
import WidgetKit
import SwiftUI

private let appGroupId = "group.dolimit.widget"

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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY 残り")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            Text("\(entry.count)")
                .font(.system(size: 34, weight: .heavy))
            if entry.titles.isEmpty {
                Text("TODAYは空です")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.titles.prefix(3), id: \.self) { t in
                    Text("・\(t)")
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
