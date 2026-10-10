import AppIntents
import Foundation
import Network
import SwiftUI
import UIKit
import WidgetKit

struct YanXuWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "连接研序 Mac"
    static var description = IntentDescription("填写 Mac 顶部「同网同步」菜单中的备用地址和 6 位配对码。")

    @Parameter(title: "Mac 地址", description: "例如 MacBook-Pro.local")
    var host: String?

    @Parameter(title: "配对码", description: "在 Mac 端研序的同网同步菜单查看")
    var pairingCode: String?

    init() {}
}

private struct YanXuWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: YanXuWidgetSnapshot?
    let message: String?
}

private enum WidgetPreviewData {
    static let snapshot: YanXuWidgetSnapshot = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let now = Date.now
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        func day(_ offset: Int, hour: Int = 9) -> Date {
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        }

        return YanXuWidgetSnapshot(
            generatedAt: now,
            todayTasks: [
                WidgetTaskSummary(id: "today-1", title: "整理实验结果", date: now, detail: "09:30"),
                WidgetTaskSummary(id: "today-2", title: "修改论文方法章节", date: now),
                WidgetTaskSummary(id: "today-3", title: "与导师讨论进展", date: now, detail: "15:00")
            ],
            weekTasks: [
                WidgetTaskSummary(id: "week-1", title: "整理实验", date: day(0), detail: "09:00"),
                WidgetTaskSummary(id: "week-2", title: "阅读论文", date: day(1)),
                WidgetTaskSummary(id: "week-3", title: "消融实验", date: day(2), detail: "全天"),
                WidgetTaskSummary(id: "week-4", title: "讨论进展", date: day(3, hour: 15), detail: "15:00"),
                WidgetTaskSummary(id: "week-5", title: "课题组周会", date: day(4, hour: 14), detail: "14:00"),
                WidgetTaskSummary(id: "week-6", title: "信息采集", date: day(5)),
                WidgetTaskSummary(id: "week-7", title: "下周计划", date: day(6))
            ],
            deadlines: [
                WidgetDeadlineSummary(id: "ddl-1", title: "论文初稿交给导师", dueDate: now.addingTimeInterval(12 * 86_400)),
                WidgetDeadlineSummary(id: "ddl-2", title: "ICLR 摘要截稿", dueDate: now.addingTimeInterval(15 * 86_400))
            ]
        )
    }()
}

private struct YanXuWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> YanXuWidgetEntry {
        YanXuWidgetEntry(date: .now, snapshot: WidgetPreviewData.snapshot, message: nil)
    }

    func snapshot(for configuration: YanXuWidgetConfigurationIntent, in context: Context) async -> YanXuWidgetEntry {
        await loadEntry(for: configuration)
    }

    func timeline(for configuration: YanXuWidgetConfigurationIntent, in context: Context) async -> Timeline<YanXuWidgetEntry> {
        let entry = await loadEntry(for: configuration)
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func loadEntry(for config: YanXuWidgetConfigurationIntent) async -> YanXuWidgetEntry {
        let host = WidgetLANClient.normalizedHost(config.host ?? "")
        let code = config.pairingCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !host.isEmpty, code.count == 6 else {
            return YanXuWidgetEntry(date: .now, snapshot: nil, message: "长按小组件 → 编辑，填写 Mac 地址和 6 位配对码")
        }
        guard let data = await WidgetLANClient.fetch(host: host, pairingCode: code) else {
            return YanXuWidgetEntry(date: .now, snapshot: nil, message: "未连接 Mac。确认研序正在运行且处于同一 Wi‑Fi")
        }
        return YanXuWidgetEntry(date: .now, snapshot: WidgetSnapshotFactory.make(from: data), message: nil)
    }
}

private enum WidgetLANClient {
    static let port = NWEndpoint.Port(rawValue: 40567)!

    static func normalizedHost(_ value: String) -> String {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("tcp://") { host.removeFirst(6) }
        if host.hasSuffix(":\(port.rawValue)") { host.removeLast(6) }
        return host
    }

    static func fetch(host: String, pairingCode: String) async -> AppData? {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.shurose.yanxu.widget-sync")
            let connection = NWConnection(to: .hostPort(host: NWEndpoint.Host(host), port: port), using: .tcp)
            var finished = false
            func finish(_ result: AppData?) {
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let request = LANSyncMessage(kind: .widgetSnapshot, pairingCode: pairingCode)
                    guard var raw = try? JSONEncoder().encode(request) else { finish(nil); return }
                    raw.append(0x0A)
                    connection.send(content: raw, completion: .contentProcessed { error in
                        guard error == nil else { finish(nil); return }
                        receive(on: connection, finish: finish)
                    })
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 8) { finish(nil) }
        }
    }

    private static func receive(on connection: NWConnection, finish: @escaping (AppData?) -> Void) {
        var buffer = Data()
        func next() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { raw, _, completed, _ in
                if let raw { buffer.append(raw) }
                guard let end = buffer.firstIndex(of: 0x0A) else {
                    if completed || buffer.count > 2_000_000 { finish(nil) } else { next() }
                    return
                }
                let payload = buffer.prefix(upTo: end)
                let response = try? JSONDecoder().decode(LANSyncMessage.self, from: payload)
                finish(response?.kind == .snapshot ? response?.data : nil)
            }
        }
        next()
    }
}

private enum WidgetSnapshotFactory {
    static func make(from data: AppData, now: Date = .now) -> YanXuWidgetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        let todayTasks = tasks(in: data, on: today, calendar: calendar)
        let week = DateIntervals.week(containing: now, calendar: calendar)
        var weekly: [(TodoItem, Date)] = []
        var cursor = week.start
        while cursor < week.end {
            weekly += tasks(in: data, on: cursor, calendar: calendar).map { ($0, cursor) }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? week.end
        }
        let deadlines = data.deadlines
            .filter { calendar.startOfDay(for: $0.dueDate) >= today }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(6)
            .map { WidgetDeadlineSummary(id: $0.id.uuidString, title: $0.title, dueDate: $0.dueDate) }
        return YanXuWidgetSnapshot(
            generatedAt: now,
            todayTasks: todayTasks.map { summary($0, on: today, weekday: false, calendar: calendar) },
            weekTasks: weekly.sorted { timestamp($0.0, on: $0.1, calendar: calendar) < timestamp($1.0, on: $1.1, calendar: calendar) }
                .map { summary($0.0, on: $0.1, weekday: false, calendar: calendar) },
            deadlines: Array(deadlines)
        )
    }

    private static func tasks(in data: AppData, on day: Date, calendar: Calendar) -> [TodoItem] {
        data.tasks.filter { $0.occurs(on: day, calendar: calendar) && !$0.isCompleted(on: day, calendar: calendar) }
    }

    private static func summary(_ task: TodoItem, on day: Date, weekday: Bool, calendar: Calendar) -> WidgetTaskSummary {
        let date = timestamp(task, on: day, calendar: calendar)
        var details: [String] = weekday ? [day.formatted(.dateTime.weekday(.short))] : []
        if task.scheduleKind == .fixed { details.append(date.formatted(.dateTime.hour().minute())) }
        return WidgetTaskSummary(
            id: "\(task.id.uuidString)-\(DateKey.string(for: day, calendar: calendar))",
            title: task.title,
            date: date,
            detail: details.isEmpty ? nil : details.joined(separator: " ")
        )
    }

    private static func timestamp(_ task: TodoItem, on day: Date, calendar: Calendar) -> Date {
        guard task.scheduleKind == .fixed, let start = task.start else { return day }
        let time = calendar.dateComponents([.hour, .minute], from: start)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
    }
}

private let widgetCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "zh_CN")
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}()

private enum WidgetPalette {
    static let accent = Color(red: 0.27, green: 0.49, blue: 0.94)
    static let accentSoft = accent.opacity(0.12)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let elevated = Color(uiColor: .tertiarySystemBackground)
    static let border = Color(uiColor: .separator)
    static let background = Color(uiColor: .systemBackground)
}

private extension View {
    func yanxuWidgetSurface() -> some View {
        containerBackground(WidgetPalette.background, for: .widget)
    }
}

private struct WidgetHeader: View {
    let title: String
    let icon: String
    let trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetPalette.accent)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(1)
            Spacer(minLength: 5)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WidgetPalette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(WidgetPalette.accentSoft, in: Capsule())
                    .fixedSize()
            }
        }
    }
}

private struct TodayTaskRow: View {
    let task: WidgetTaskSummary

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(WidgetPalette.muted.opacity(0.72), lineWidth: 1.2)
                .frame(width: 12, height: 12)

            Text(task.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            if let detail = task.detail {
                Text(detail)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(WidgetPalette.accent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WidgetPalette.border.opacity(0.65))
                .frame(height: 0.5)
                .padding(.leading, 18)
        }
        .clipped()
    }
}

private struct EmptyState: View {
    let message: String?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(WidgetPalette.accent.opacity(0.72))
            Text(message ?? "没有需要显示的内容")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetPalette.muted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct TodayWidgetView: View {
    let entry: YanXuWidgetEntry

    private var tasks: [WidgetTaskSummary] {
        entry.snapshot?.todayTasks ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            WidgetHeader(title: "今天", icon: "checkmark.square", trailing: entry.snapshot.map { "\($0.todayTasks.count) 项" })
            Text(entry.date, format: .dateTime.month().day().weekday(.wide))
                .font(.system(size: 9))
                .foregroundStyle(WidgetPalette.muted)

            if !tasks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(tasks.prefix(3)) { task in
                        TodayTaskRow(task: task)
                    }
                }
                if tasks.count > 3 {
                    Text("还有 \(tasks.count - 3) 项")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(WidgetPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            } else {
                EmptyState(message: entry.snapshot == nil ? entry.message : "今天没有待办")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .yanxuWidgetSurface()
        .widgetURL(URL(string: "yanxu://today"))
    }
}

private struct WeekTaskChip: View {
    let task: WidgetTaskSummary

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            Circle()
                .stroke(WidgetPalette.accent.opacity(0.85), lineWidth: 1)
                .frame(width: 7, height: 7)
                .padding(.top, 1.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                if let detail = task.detail {
                    Text(detail)
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(WidgetPalette.accent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 37, alignment: .topLeading)
        .background(WidgetPalette.elevated, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .clipped()
    }
}

private struct WeekDayColumn: View {
    let date: Date
    let tasks: [WidgetTaskSummary]
    let isToday: Bool

    private var weekdayLabel: String {
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = widgetCalendar.component(.weekday, from: date)
        return labels[max(0, min(labels.count - 1, weekday - 1))]
    }

    private var weekdayColor: Color {
        let weekday = widgetCalendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 ? WidgetPalette.muted : WidgetPalette.ink
    }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 3) {
                Text("周\(weekdayLabel)")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(weekdayColor)
                Text("\(widgetCalendar.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? Color.white : WidgetPalette.ink)
                    .frame(width: 23, height: 23)
                    .background(isToday ? WidgetPalette.accent : Color.clear, in: Circle())
            }

            Rectangle()
                .fill(WidgetPalette.border)
                .frame(height: 0.5)

            VStack(spacing: 5) {
                ForEach(tasks.prefix(5)) { task in
                    WeekTaskChip(task: task)
                }
                if tasks.count > 5 {
                    Text("+\(tasks.count - 5) 项")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(WidgetPalette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(isToday ? WidgetPalette.accentSoft : WidgetPalette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isToday ? WidgetPalette.accent.opacity(0.28) : WidgetPalette.border.opacity(0.7), lineWidth: 0.7)
        }
        .clipped()
    }
}

private struct WeekWidgetView: View {
    let entry: YanXuWidgetEntry

    private var weekDays: [Date] {
        guard let start = widgetCalendar.dateInterval(of: .weekOfYear, for: entry.date)?.start else {
            return [entry.date]
        }
        return (0..<7).compactMap { widgetCalendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var rangeText: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(first.formatted(.dateTime.month().day())) – \(last.formatted(.dateTime.month().day()))"
    }

    private func tasks(on date: Date, in snapshot: YanXuWidgetSnapshot) -> [WidgetTaskSummary] {
        snapshot.weekTasks.filter { widgetCalendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "本周计划", icon: "calendar", trailing: entry.snapshot.map { "\($0.weekTasks.count) 项" })
            Text(rangeText)
                .font(.system(size: 9))
                .foregroundStyle(WidgetPalette.muted)

            if let snapshot = entry.snapshot {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(weekDays, id: \.self) { day in
                        WeekDayColumn(
                            date: day,
                            tasks: tasks(on: day, in: snapshot),
                            isToday: widgetCalendar.isDate(day, inSameDayAs: entry.date)
                        )
                    }
                }
            } else {
                EmptyState(message: entry.message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .yanxuWidgetSurface()
        .widgetURL(URL(string: "yanxu://week"))
    }
}

private struct DeadlineWidgetView: View {
    let entry: YanXuWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(title: "最近 DDL", icon: "timer", trailing: nil)
            if let snapshot = entry.snapshot, !snapshot.deadlines.isEmpty {
                ForEach(snapshot.deadlines.prefix(3)) { deadline in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deadline.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(WidgetPalette.ink).lineLimit(1)
                            Text(deadline.dueDate, format: .dateTime.month().day()).font(.system(size: 9)).foregroundStyle(WidgetPalette.muted)
                        }
                        Spacer(minLength: 4)
                        Text(days(until: deadline.dueDate)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(WidgetPalette.accent)
                    }.padding(.horizontal, 9).frame(height: 32)
                    .background(WidgetPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .leading) { Capsule().fill(WidgetPalette.accent).frame(width: 2, height: 16).padding(.leading, 3) }
                }
                if snapshot.deadlines.count > 3 {
                    Text("还有 \(snapshot.deadlines.count - 3) 个 DDL")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(WidgetPalette.muted)
                }
                Spacer(minLength: 0)
            } else { EmptyState(message: entry.snapshot == nil ? entry.message : "暂无 DDL") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .yanxuWidgetSurface()
        .widgetURL(URL(string: "yanxu://deadlines"))
    }

    private func days(until date: Date) -> String {
        let value = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date), to: Calendar.current.startOfDay(for: date)).day ?? 0
        return value == 0 ? "今天" : "\(value) 天"
    }
}

private struct TodayPlanWidget: Widget {
    let kind = "com.shurose.yanxu.ios.widgets.today"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: YanXuWidgetConfigurationIntent.self, provider: YanXuWidgetProvider()) { TodayWidgetView(entry: $0) }
            .configurationDisplayName("今天计划").description("用小组件快速查看今天的任务。").supportedFamilies([.systemSmall])
    }
}

private struct WeekPlanWidget: Widget {
    let kind = "com.shurose.yanxu.ios.widgets.week"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: YanXuWidgetConfigurationIntent.self, provider: YanXuWidgetProvider()) { WeekWidgetView(entry: $0) }
            .configurationDisplayName("本周计划").description("按周一到周日分栏查看本周计划。").supportedFamilies([.systemLarge])
    }
}

private struct DeadlinePlanWidget: Widget {
    let kind = "com.shurose.yanxu.ios.widgets.deadlines"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: YanXuWidgetConfigurationIntent.self, provider: YanXuWidgetProvider()) { DeadlineWidgetView(entry: $0) }
            .configurationDisplayName("最近 DDL").description("从同一 Wi‑Fi 的 Mac 研序读取最近截止日期。").supportedFamilies([.systemMedium])
    }
}

@main
struct YanXuWidgetsBundle: WidgetBundle {
    var body: some Widget { TodayPlanWidget(); WeekPlanWidget(); DeadlinePlanWidget() }
}
