import SwiftUI

struct MobileRootView: View {
    @State private var selectedTab: Int

    init() {
#if DEBUG
        let previewTab = ProcessInfo.processInfo.environment["YANXU_PREVIEW_TAB"]
        let index = ["today": 0, "plan": 1, "research": 2, "ddl": 3, "settings": 4][previewTab ?? "today"] ?? 0
        _selectedTab = State(initialValue: index)
#else
        _selectedTab = State(initialValue: 0)
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MobileTodayView()
                .tabItem { Label("今天", systemImage: "checkmark.circle") }
                .tag(0)

            MobilePlanView()
                .tabItem { Label("计划", systemImage: "calendar") }
                .tag(1)

            MobileFocusView()
                .tabItem { Label("科研", systemImage: "timer") }
                .tag(2)

            MobileDeadlineView()
                .tabItem { Label("DDL", systemImage: "flag") }
                .tag(3)

            MobileSettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(YanXuPalette.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(YanXuPalette.card, for: .tabBar)
    }
}

// MARK: - Visual system

private enum YanXuPalette {
    static let accent = Color(red: 0.25, green: 0.45, blue: 0.93)
    static let accentDeep = Color(red: 0.18, green: 0.35, blue: 0.82)
    static let accentSoft = Color(red: 0.91, green: 0.94, blue: 1.00)
    static let success = Color(red: 0.20, green: 0.67, blue: 0.45)
    static let warning = Color(red: 0.94, green: 0.56, blue: 0.22)
    static let violet = Color(red: 0.53, green: 0.40, blue: 0.91)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let input = Color(uiColor: .tertiarySystemGroupedBackground)
    static let hairline = Color(uiColor: .separator).opacity(0.12)
}

private extension View {
    func yanxuCard() -> some View {
        self
            .background(YanXuPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(YanXuPalette.hairline, lineWidth: 0.5)
            }
    }
}

private struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardHeader: View {
    let title: String
    var detail: String? = nil
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 9) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(YanXuPalette.accent)
                    .frame(width: 28, height: 28)
                    .background(YanXuPalette.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Today

private struct MobileTodayView: View {
    @EnvironmentObject private var store: MobileAppStore
    @State private var quickTask = ""

    private var todayTasks: [TodoItem] { store.taskOccurrences(on: .now) }
    private var inboxTasks: [TodoItem] {
        store.data.tasks.filter { $0.scheduleKind == .inbox && $0.completedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    PageTitle(
                        title: "今天",
                        subtitle: Date.now.formatted(.dateTime.month().day().weekday(.wide))
                    )
                    TodaySummaryCard(tasks: todayTasks, calendar: store.calendar)
                    QuickTaskCard(text: $quickTask, onSubmit: addTask)
                    TaskSectionCard(title: "今天", tasks: todayTasks, date: .now, emptyText: "今天没有待办")

                    if !inboxTasks.isEmpty {
                        TaskSectionCard(
                            title: "未安排",
                            tasks: inboxTasks,
                            date: .now,
                            emptyText: "没有未安排任务",
                            muted: true
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(YanXuPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func addTask() {
        store.addQuickTask(quickTask)
        quickTask = ""
    }
}

private struct TodaySummaryCard: View {
    let tasks: [TodoItem]
    let calendar: Calendar

    private var completed: Int {
        tasks.filter { $0.isCompleted(on: .now, calendar: calendar) }.count
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completed) / Double(tasks.count)
    }

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("DAILY FOCUS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.70))
                Text("把今天过得清楚一点")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("完成 \(completed) 项 · 还剩 \(max(0, tasks.count - completed)) 项")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
            Spacer(minLength: 8)
            ProgressRing(progress: progress, text: "\(completed)/\(tasks.count)")
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [YanXuPalette.accentDeep, YanXuPalette.accent, Color(red: 0.39, green: 0.62, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: YanXuPalette.accent.opacity(0.18), radius: 16, y: 8)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 66, height: 66)
    }
}

private struct QuickTaskCard: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(YanXuPalette.accent, in: Circle())

            TextField("输入任务，如“明天晚上开会”", text: $text)
                .submitLabel(.done)
                .onSubmit(onSubmit)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(YanXuPalette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .yanxuCard()
    }
}

// MARK: - Shared task cards

private struct TaskSectionCard: View {
    @EnvironmentObject private var store: MobileAppStore
    let title: String
    let tasks: [TodoItem]
    let date: Date
    let emptyText: String
    var muted = false

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: title, detail: "\(tasks.count) 项", symbol: muted ? "tray" : "sun.max.fill")
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            if tasks.isEmpty {
                EmptyTaskRow(text: emptyText)
            } else {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 {
                        Divider().padding(.leading, 54)
                    }
                    TaskCardRow(task: task, date: task.scheduleKind == .inbox ? task.createdAt : date)
                }
            }
        }
        .yanxuCard()
    }
}

private struct EmptyTaskRow: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(YanXuPalette.success)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct TaskCardRow: View {
    @EnvironmentObject private var store: MobileAppStore
    let task: TodoItem
    let date: Date

    private var isDone: Bool { task.isCompleted(on: date, calendar: store.calendar) }

    var body: some View {
        HStack(spacing: 12) {
            Button { store.toggle(task, on: date) } label: {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isDone ? YanXuPalette.success : Color.secondary.opacity(0.65))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone, color: .secondary)
                    .lineLimit(2)

                if let detail = taskDetail {
                    Label(detail.text, systemImage: detail.symbol)
                        .font(.caption)
                        .foregroundStyle(detail.color)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "ellipsis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            if task.start != nil {
                Button { store.postpone(task) } label: {
                    Label("延后一天", systemImage: "calendar.badge.plus")
                }
            }
            Button(role: .destructive) { store.deleteTask(task.id) } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var taskDetail: (text: String, symbol: String, color: Color)? {
        if task.scheduleKind == .fixed, let start = task.start {
            return (start.formatted(.dateTime.hour().minute()), "clock", YanXuPalette.accent)
        }
        if task.scheduleKind == .range, let end = task.end {
            let endText = end.formatted(.dateTime.month().day())
            return ("可完成至 \(endText)", "calendar", .secondary)
        }
        if task.repeatRule != .none {
            return (task.repeatRule.title, "repeat", YanXuPalette.violet)
        }
        return nil
    }
}

// MARK: - Week and month plan

private enum PlanScope: String, CaseIterable, Identifiable {
    case week = "周"
    case month = "月"
    var id: String { rawValue }
}

private struct MobilePlanView: View {
    @EnvironmentObject private var store: MobileAppStore
    @State private var scope: PlanScope
    @State private var selectedDay = Date.now
    @State private var visibleAnchor = Date.now

    init() {
#if DEBUG
        let previewScope = ProcessInfo.processInfo.environment["YANXU_PREVIEW_PLAN_SCOPE"]
        _scope = State(initialValue: previewScope == "month" ? .month : .week)
#else
        _scope = State(initialValue: .week)
#endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    PageTitle(title: "计划", subtitle: "一眼看清这一周和这个月")
                    scopePicker

                    if scope == .week {
                        WeekCalendarCard(selectedDay: $selectedDay, visibleAnchor: $visibleAnchor)
                    } else {
                        MonthCalendarCard(selectedDay: $selectedDay, visibleAnchor: $visibleAnchor)
                    }
                    selectedDayTasks
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(YanXuPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var scopePicker: some View {
        Picker("视图", selection: $scope) {
            ForEach(PlanScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: scope) { _ in visibleAnchor = selectedDay }
    }

    private var selectedDayTasks: some View {
        let tasks = store.taskOccurrences(on: selectedDay)
        let title = store.calendar.isDateInToday(selectedDay)
            ? "今天"
            : selectedDay.formatted(.dateTime.month().day().weekday(.wide))
        return TaskSectionCard(title: title, tasks: tasks, date: selectedDay, emptyText: "这一天还没有计划")
    }
}

private struct CalendarNavigationHeader: View {
    let title: String
    let previous: () -> Void
    let next: () -> Void
    let today: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Spacer()
            Button("今天", action: today)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 10))
            Button(action: previous) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .frame(width: 30, height: 30)
            Button(action: next) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .frame(width: 30, height: 30)
        }
    }
}

private struct WeekCalendarCard: View {
    @EnvironmentObject private var store: MobileAppStore
    @Binding var selectedDay: Date
    @Binding var visibleAnchor: Date

    private var days: [Date] {
        CalendarGrid.week(containing: visibleAnchor, calendar: store.calendar)
    }

    private var title: String {
        guard let first = days.first, let last = days.last else { return "" }
        if store.calendar.component(.month, from: first) == store.calendar.component(.month, from: last) {
            return first.formatted(.dateTime.year().month(.wide))
        }
        return "\(first.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated)))"
    }

    var body: some View {
        VStack(spacing: 16) {
            CalendarNavigationHeader(title: title, previous: previousWeek, next: nextWeek, today: goToday)
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { date in
                    WeekDayButton(
                        date: date,
                        selected: store.calendar.isDate(date, inSameDayAs: selectedDay),
                        isToday: store.calendar.isDateInToday(date),
                        taskCount: store.taskOccurrences(on: date).count,
                        action: { selectedDay = date }
                    )
                }
            }
        }
        .padding(16)
        .yanxuCard()
    }

    private func previousWeek() {
        visibleAnchor = store.calendar.date(byAdding: .weekOfYear, value: -1, to: visibleAnchor) ?? visibleAnchor
    }

    private func nextWeek() {
        visibleAnchor = store.calendar.date(byAdding: .weekOfYear, value: 1, to: visibleAnchor) ?? visibleAnchor
    }

    private func goToday() {
        selectedDay = .now
        visibleAnchor = .now
    }
}

private struct WeekDayButton: View {
    let date: Date
    let selected: Bool
    let isToday: Bool
    let taskCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                Text(date.formatted(.dateTime.day()))
                    .font(.body.weight(.bold))
                    .foregroundStyle(selected ? .white : (isToday ? YanXuPalette.accent : .primary))
                Circle()
                    .fill(taskCount > 0 ? (selected ? Color.white : YanXuPalette.accent) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(dayBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dayBackground: Color {
        if selected { return YanXuPalette.accent }
        if isToday { return YanXuPalette.accentSoft }
        return .clear
    }
}

private struct MonthCalendarCard: View {
    @EnvironmentObject private var store: MobileAppStore
    @Binding var selectedDay: Date
    @Binding var visibleAnchor: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    private var days: [Date] {
        CalendarGrid.month(containing: visibleAnchor, calendar: store.calendar)
    }

    private var title: String {
        visibleAnchor.formatted(.dateTime.year().month(.wide))
    }

    var body: some View {
        VStack(spacing: 14) {
            CalendarNavigationHeader(title: title, previous: previousMonth, next: nextMonth, today: goToday)
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(days, id: \.self) { date in
                    MonthDayButton(
                        date: date,
                        visibleMonth: visibleAnchor,
                        selectedDay: selectedDay,
                        taskCount: store.taskOccurrences(on: date).count,
                        calendar: store.calendar,
                        action: {
                            selectedDay = date
                            if !store.calendar.isDate(date, equalTo: visibleAnchor, toGranularity: .month) {
                                visibleAnchor = date
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .yanxuCard()
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, name in
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(index >= 5 ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func previousMonth() {
        visibleAnchor = store.calendar.date(byAdding: .month, value: -1, to: visibleAnchor) ?? visibleAnchor
    }

    private func nextMonth() {
        visibleAnchor = store.calendar.date(byAdding: .month, value: 1, to: visibleAnchor) ?? visibleAnchor
    }

    private func goToday() {
        selectedDay = .now
        visibleAnchor = .now
    }
}

private struct MonthDayButton: View {
    let date: Date
    let visibleMonth: Date
    let selectedDay: Date
    let taskCount: Int
    let calendar: Calendar
    let action: () -> Void

    private var selected: Bool { calendar.isDate(date, inSameDayAs: selectedDay) }
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var inMonth: Bool { calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(selected || isToday ? .bold : .medium))
                    .foregroundStyle(dayForeground)
                HStack(spacing: 2) {
                    ForEach(0..<min(taskCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(selected ? Color.white : YanXuPalette.accent)
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(dayBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dayForeground: Color {
        if selected { return .white }
        if !inMonth { return Color.secondary.opacity(0.35) }
        if isToday { return YanXuPalette.accent }
        return .primary
    }

    private var dayBackground: Color {
        if selected { return YanXuPalette.accent }
        if isToday { return YanXuPalette.accentSoft }
        return .clear
    }
}

private enum CalendarGrid {
    static func week(containing date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func month(containing date: Date, calendar: Calendar) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start)?.start ?? month.start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek) }
    }
}

// MARK: - Research

private struct MobileFocusView: View {
    @EnvironmentObject private var store: MobileAppStore

    private var week: DateInterval { DateIntervals.week(containing: .now, calendar: store.calendar) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    PageTitle(title: "科研", subtitle: "记录投入，也保留中断的自由")
                    ResearchDashboardCard(week: week)
                    AttendanceCard(durationText: duration(store.researchDuration(in: week)))
                    HabitCard(week: week)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(YanXuPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        return "\(totalMinutes / 60) 小时 \(totalMinutes % 60) 分"
    }
}

private struct ResearchDashboardCard: View {
    @EnvironmentObject private var store: MobileAppStore
    let week: DateInterval

    private var days: [Date] {
        CalendarGrid.week(containing: week.start, calendar: store.calendar)
    }

    private var taskProgress: (completed: Int, total: Int) {
        days.reduce(into: (completed: 0, total: 0)) { result, date in
            let tasks = store.taskOccurrences(on: date)
            result.total += tasks.count
            result.completed += tasks.filter { $0.isCompleted(on: date, calendar: store.calendar) }.count
        }
    }

    private var habitProgress: (completed: Int, target: Int) {
        let completed = store.data.habitLogs.filter { week.contains($0.timestamp) }.count
        let target = store.data.habits.reduce(0) { $0 + $1.weeklyTarget }
        return (completed, target)
    }

    private var dailyDurations: [TimeInterval] {
        days.map { store.researchDuration(in: DateIntervals.day(containing: $0, calendar: store.calendar)) }
    }

    private var weekDuration: TimeInterval { store.researchDuration(in: week) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeader(title: "本周看板", detail: "周一至周日", symbol: "chart.bar.fill")
            HStack(spacing: 10) {
                DashboardMetric(
                    value: compactDuration(weekDuration),
                    title: "科研时长",
                    color: YanXuPalette.accent
                )
                DashboardMetric(
                    value: "\(taskProgress.completed)/\(taskProgress.total)",
                    title: "完成任务",
                    color: YanXuPalette.success
                )
                DashboardMetric(
                    value: "\(habitProgress.completed)/\(habitProgress.target)",
                    title: "习惯打卡",
                    color: YanXuPalette.violet
                )
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("每日科研投入")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                WeeklyResearchBars(days: days, durations: dailyDurations)
            }
        }
        .padding(16)
        .yanxuCard()
    }

    private func compactDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes >= 60 { return String(format: "%.1fh", Double(minutes) / 60.0) }
        return "\(minutes)m"
    }
}

private struct DashboardMetric: View {
    let value: String
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WeeklyResearchBars: View {
    let days: [Date]
    let durations: [TimeInterval]

    private var maximum: TimeInterval { max(durations.max() ?? 0, 60) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.element) { index, date in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(YanXuPalette.input)
                        Capsule()
                            .fill(Calendar.current.isDateInToday(date) ? YanXuPalette.accent : YanXuPalette.accent.opacity(0.48))
                            .frame(height: barHeight(at: index))
                    }
                    .frame(height: 48)
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(Calendar.current.isDateInToday(date) ? .bold : .regular))
                        .foregroundStyle(Calendar.current.isDateInToday(date) ? YanXuPalette.accent : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(at index: Int) -> CGFloat {
        guard durations.indices.contains(index), durations[index] > 0 else { return 3 }
        return max(5, 48 * CGFloat(durations[index] / maximum))
    }
}

private struct AttendanceCard: View {
    @EnvironmentObject private var store: MobileAppStore
    let durationText: String

    private var active: Bool { store.activeAttendance != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeader(title: "科研打卡", detail: active ? "正在实验室" : "本周累计", symbol: "timer")
            HStack(alignment: .firstTextBaseline) {
                Text(durationText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Circle()
                    .fill(active ? YanXuPalette.success : Color.secondary.opacity(0.25))
                    .frame(width: 9, height: 9)
            }
            Button { store.toggleAttendance() } label: {
                Label(
                    active ? "离开实验室" : "到达实验室",
                    systemImage: active ? "figure.walk.departure" : "mappin.and.ellipse"
                )
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 13))
            .tint(active ? YanXuPalette.warning : YanXuPalette.accent)
        }
        .padding(16)
        .yanxuCard()
    }
}

private struct HabitCard: View {
    @EnvironmentObject private var store: MobileAppStore
    @State private var showsNewHabit = false
    let week: DateInterval

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "leaf.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(YanXuPalette.accent)
                    .frame(width: 28, height: 28)
                    .background(YanXuPalette.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("本周习惯").font(.headline)
                    Text("每完成一次就打卡").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showsNewHabit = true } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("新增习惯")
            }
                .padding(.bottom, 8)
            if store.data.habits.isEmpty {
                Text("还没有习惯")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                ForEach(Array(store.data.habits.enumerated()), id: \.element.id) { index, habit in
                    if index > 0 { Divider() }
                    HabitRow(habit: habit, week: week)
                }
            }
        }
        .padding(16)
        .yanxuCard()
        .sheet(isPresented: $showsNewHabit) {
            HabitEditorView()
        }
    }
}

private struct HabitRow: View {
    @EnvironmentObject private var store: MobileAppStore
    let habit: Habit
    let week: DateInterval

    private var count: Int { store.habitCount(habit.id, in: week) }
    private var progress: Double { min(1, Double(count) / Double(habit.weeklyTarget)) }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(count) / \(habit.weeklyTarget)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(count >= habit.weeklyTarget ? YanXuPalette.success : YanXuPalette.accent)
            }
            Button { store.checkIn(habit.id) } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
        .padding(.vertical, 11)
        .contextMenu {
            Button(role: .destructive) { store.deleteHabit(habit.id) } label: {
                Label("删除习惯", systemImage: "trash")
            }
        }
    }
}

private struct HabitEditorView: View {
    @EnvironmentObject private var store: MobileAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var weeklyTarget = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("习惯") {
                    TextField("例如：阅读论文", text: $name)
                    Stepper("每周 \(weeklyTarget) 次", value: $weeklyTarget, in: 1...14)
                }
                Section {
                    Text("同一天可以打卡多次，每完成一次就点一次 +1。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        store.upsertHabit(Habit(name: cleanName, weeklyTarget: weeklyTarget))
        dismiss()
    }
}

private struct SyncCard: View {
    @EnvironmentObject private var store: MobileAppStore
    @ObservedObject var sync: LANSyncClient
    @Binding var pairingCode: String
    @Binding var manualHost: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "同一 Wi‑Fi 同步", detail: "Mac ↔ iPhone", symbol: "arrow.triangle.2.circlepath")
            HStack(spacing: 7) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(YanXuPalette.accent)
                Text("最近同步")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lastSyncText)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            HStack(spacing: 10) {
                TextField("Mac 上的 6 位配对码", text: $pairingCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(YanXuPalette.input, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button(action: synchronize) {
                    if isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text("同步").fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .disabled(isBusy || pairingCode.count != 6)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("自动发现失败时，可直接粘贴 Mac 的备用地址（支持带 :40567）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("例如：MacBook-Pro.local", text: $manualHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(YanXuPalette.input, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("端口固定为 40567；Mac 端顶部“同网同步”菜单可复制备用地址。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            statusView
        }
        .padding(16)
        .yanxuCard()
    }

    private var isBusy: Bool { sync.status == .findingMac || sync.status == .syncing }

    private var lastSyncText: String {
        guard let date = sync.lastSuccessfulSyncAt else { return "尚未同步" }
        if Calendar.current.isDateInToday(date) {
            return "今天 \(date.formatted(.dateTime.hour().minute()))"
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    private func synchronize() {
        sync.synchronize(data: store.data, pairingCode: pairingCode, manualHost: manualHost) {
            store.mergeFromMac($0)
        }
    }

    @ViewBuilder private var statusView: some View {
        switch sync.status {
        case .findingMac:
            Label("正在同一网络中寻找 Mac…", systemImage: "wifi")
                .foregroundStyle(.secondary)
        case .syncing:
            Label("正在合并两端数据…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .complete:
            Label("同步完成", systemImage: "checkmark.circle.fill")
                .foregroundStyle(YanXuPalette.success)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        default:
            Text("请保持 Mac 版研序正在运行")
                .foregroundStyle(.secondary)
        }
    }
}

private struct MobileSettingsView: View {
    @EnvironmentObject private var store: MobileAppStore
    @StateObject private var sync = LANSyncClient()
    @AppStorage("yanxu.lan.pairing-code") private var pairingCode = ""
    @AppStorage("yanxu.lan.manual-host") private var manualHost = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    PageTitle(title: "设置", subtitle: "同步与本机数据")
                    SyncCard(sync: sync, pairingCode: $pairingCode, manualHost: $manualHost)
                    dataSummary
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(YanXuPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var dataSummary: some View {
        VStack(spacing: 12) {
            CardHeader(title: "本机数据", detail: "自动保存", symbol: "externaldrive.fill")
            HStack {
                DataCount(value: store.data.tasks.count, title: "任务")
                Divider().frame(height: 34)
                DataCount(value: store.data.habits.count, title: "习惯")
                Divider().frame(height: 34)
                DataCount(value: store.data.deadlines.count, title: "DDL")
            }
        }
        .padding(16)
        .yanxuCard()
    }
}

private struct DataCount: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(YanXuPalette.accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Deadlines

private struct MobileDeadlineView: View {
    @EnvironmentObject private var store: MobileAppStore
    @State private var showsNewDeadline = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    PageTitle(title: "DDL", subtitle: "只看还剩多少时间")
                    personalDeadlines
                    ccfDeadlines
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(YanXuPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsNewDeadline) {
                DeadlineEditorView()
            }
        }
    }

    private var personalDeadlines: some View {
        let items = Array(store.activeDeadlines.prefix(2))
        return VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "flag.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(YanXuPalette.accent)
                    .frame(width: 28, height: 28)
                    .background(YanXuPalette.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("我的 DDL").font(.headline)
                    Text("最多展示最近 2 个").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showsNewDeadline = true } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("新增 DDL")
            }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            if items.isEmpty {
                Text("暂无 DDL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 16) }
                    DeadlineRow(
                        title: item.title,
                        dateText: item.dueDate.formatted(.dateTime.year().month().day()),
                        days: item.remainingDays(calendar: store.calendar),
                        source: nil
                    )
                    .contextMenu {
                        Button(role: .destructive) { store.deleteDeadline(item.id) } label: {
                            Label("删除 DDL", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .yanxuCard()
    }

    private var ccfDeadlines: some View {
        VStack(spacing: 0) {
            CardHeader(title: "CCF A · 人工智能", detail: "CCFDDL", symbol: "sparkles")
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
#if DEBUG
            if ProcessInfo.processInfo.environment["YANXU_SEED_DEMO"] == "1" {
                ForEach(Array(demoCCFDeadlines.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 16) }
                    DeadlineRow(
                        title: item.title,
                        dateText: item.dueDate.formatted(.dateTime.year().month().day()),
                        days: max(
                            0,
                            store.calendar.dateComponents(
                                [.day],
                                from: store.calendar.startOfDay(for: .now),
                                to: store.calendar.startOfDay(for: item.dueDate)
                            ).day ?? 0
                        ),
                        source: "CCFDDL"
                    )
                }
            } else {
                ccfPlaceholderRows
            }
#else
            ccfPlaceholderRows
#endif
        }
        .yanxuCard()
    }

    @ViewBuilder
    private var ccfPlaceholderRows: some View {
        CCFPlaceholderRow(title: "NeurIPS", note: "同步后显示最新截稿时间")
        Divider().padding(.leading, 16)
        CCFPlaceholderRow(title: "AAAI", note: "同步后显示最新截稿时间")
        Divider().padding(.leading, 16)
        CCFPlaceholderRow(title: "CVPR", note: "同步后显示最新截稿时间")
        Divider().padding(.leading, 16)
        CCFPlaceholderRow(title: "ICCV", note: "同步后显示最新截稿时间")
    }

#if DEBUG
    private var demoCCFDeadlines: [CCFPreviewDeadline] {
        let offsets = [61, 176, 244, 336]
        let titles = ["CVPR 2027", "ICCV 2027", "NeurIPS 2027", "AAAI 2028"]
        return zip(titles, offsets).map { title, offset in
            CCFPreviewDeadline(
                title: title,
                dueDate: store.calendar.date(byAdding: .day, value: offset, to: .now) ?? .now
            )
        }
    }
#endif
}

#if DEBUG
private struct CCFPreviewDeadline: Identifiable {
    let title: String
    let dueDate: Date
    var id: String { title }
}
#endif

private struct DeadlineEditorView: View {
    @EnvironmentObject private var store: MobileAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("截止事项") {
                    TextField("例如：论文初稿交给导师", text: $title)
                    DatePicker("截止日期", selection: $dueDate, in: Date.now..., displayedComponents: .date)
                }
                Section {
                    Text("DDL 只显示倒计时，不发送提醒。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增 DDL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        store.upsertDeadline(DeadlineItem(title: cleanTitle, dueDate: dueDate, includesTime: false))
        dismiss()
    }
}

private struct DeadlineRow: View {
    let title: String
    let dateText: String
    let days: Int
    let source: String?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(dateText)
                    if let source {
                        Text("· \(source)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("\(days)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(days <= 7 ? YanXuPalette.warning : YanXuPalette.accent)
                Text("天")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct CCFPlaceholderRow: View {
    let title: String
    let note: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(width: 72, alignment: .leading)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(YanXuPalette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
