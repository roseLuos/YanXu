import SwiftUI
import WidgetKit
import YanXuCore

private struct YanXuWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: YanXuWidgetSnapshot
}

private struct YanXuWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> YanXuWidgetEntry {
        YanXuWidgetEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (YanXuWidgetEntry) -> Void) {
        completion(YanXuWidgetEntry(date: Date(), snapshot: YanXuWidgetSnapshotStore.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<YanXuWidgetEntry>) -> Void) {
        let now = Date()
        let entry = YanXuWidgetEntry(date: now, snapshot: YanXuWidgetSnapshotStore.load() ?? .preview)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private enum WidgetTheme {
    static let accent = Color(red: 0.32, green: 0.53, blue: 0.96)
    static let ink = Color(red: 0.14, green: 0.17, blue: 0.22)
    static let muted = Color(red: 0.48, green: 0.52, blue: 0.58)
    static let raised = Color(red: 0.96, green: 0.97, blue: 0.99)
}

private struct WidgetHeader: View {
    let title: String
    let icon: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(WidgetTheme.accent)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetTheme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(WidgetTheme.muted)
            }
        }
    }
}

private struct TaskWidgetRow: View {
    let task: WidgetTaskSummary

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "square")
                .font(.system(size: 13))
                .foregroundStyle(WidgetTheme.muted)
            Text(task.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 3)
            if let detail = task.detail {
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetTheme.accent)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 27)
        .background(WidgetTheme.raised, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct TodayWidgetView: View {
    let entry: YanXuWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(
                title: "今天计划",
                icon: "checkmark.square",
                trailing: "\(entry.snapshot.todayTasks.count) 项"
            )
            if entry.snapshot.todayTasks.isEmpty {
                Spacer()
                Text("今天没有待办")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer()
            } else {
                ForEach(entry.snapshot.todayTasks.prefix(family == .systemSmall ? 3 : 5)) { task in
                    TaskWidgetRow(task: task)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: "yanxu://today"))
    }
}

private struct WeekWidgetView: View {
    let entry: YanXuWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(
                title: "本周计划",
                icon: "calendar",
                trailing: "\(entry.snapshot.weekTasks.count) 项"
            )
            ForEach(entry.snapshot.weekTasks.prefix(6)) { task in
                TaskWidgetRow(task: task)
            }
            if entry.snapshot.weekTasks.isEmpty {
                Spacer()
                Text("本周还没有计划")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer()
            }
        }
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: "yanxu://week"))
    }
}

private struct DeadlineWidgetView: View {
    let entry: YanXuWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "最近 DDL", icon: "timer")
            ForEach(entry.snapshot.deadlines.prefix(4)) { deadline in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deadline.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetTheme.ink)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Text(deadline.dueDate, format: .dateTime.month().day())
                            if let source = deadline.source {
                                Text(source)
                                    .foregroundStyle(WidgetTheme.accent)
                            }
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetTheme.muted)
                    }
                    Spacer()
                    Text(remainingDays(until: deadline.dueDate))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WidgetTheme.accent)
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(WidgetTheme.raised, in: RoundedRectangle(cornerRadius: 7))
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: "yanxu://deadlines"))
    }

    private func remainingDays(until date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: entry.date),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return days == 0 ? "今天" : "\(days)天"
    }
}

private struct TodayPlanWidget: Widget {
    let kind = "com.shurose.yanxu.widgets.today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YanXuWidgetProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("今天计划")
        .description("快速查看今天需要完成的任务。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WeekPlanWidget: Widget {
    let kind = "com.shurose.yanxu.widgets.week"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YanXuWidgetProvider()) { entry in
            WeekWidgetView(entry: entry)
        }
        .configurationDisplayName("本周计划")
        .description("在桌面查看本周最近的计划。")
        .supportedFamilies([.systemMedium])
    }
}

private struct DeadlinePlanWidget: Widget {
    let kind = "com.shurose.yanxu.widgets.deadlines"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YanXuWidgetProvider()) { entry in
            DeadlineWidgetView(entry: entry)
        }
        .configurationDisplayName("最近 DDL")
        .description("显示最近的个人和 CCFDDL 截止日期。")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct YanXuWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayPlanWidget()
        WeekPlanWidget()
        DeadlinePlanWidget()
    }
}
