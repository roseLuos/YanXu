import SwiftUI
import YanXuCore

private enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case week = "周"
    case month = "月"

    var id: String { rawValue }
}

private struct NewTaskRequest: Identifiable {
    let id = UUID()
    let date: Date?
    let scheduleKind: TaskScheduleKind
}

private enum TaskVisualKind: Equatable {
    case experiment
    case paper
    case administrative

    init(title: String) {
        let administrativeWords = ["会议", "周会", "组会", "申请", "邮件", "许可", "材料", "考核", "同步"]
        let paperWords = ["论文", "文献", "写作", "参考", "审稿", "投稿", "图表", "章节", "CVPR"]

        if administrativeWords.contains(where: title.contains) {
            self = .administrative
        } else if paperWords.contains(where: title.contains) {
            self = .paper
        } else {
            self = .experiment
        }
    }

    var accent: Color {
        switch self {
        case .experiment: .yanxuAccent
        case .paper: .yanxuSuccess
        case .administrative: .yanxuMuted
        }
    }

    var background: Color {
        accent.opacity(self == .administrative ? 0.07 : 0.10)
    }
}

struct PlanCalendarView: View {
    @EnvironmentObject private var store: AppStore

    @State private var mode: CalendarDisplayMode
    @State private var selectedDate = Date()
    @State private var editingTask: TodoItem?
    @State private var newTaskRequest: NewTaskRequest?
    @State private var showsTaskTray: Bool

    init() {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        _mode = State(initialValue: CalendarDisplayMode(rawValue: environment["YANXU_PREVIEW_CALENDAR_MODE"] ?? "") ?? .week)
        _showsTaskTray = State(initialValue: environment["YANXU_PREVIEW_TASK_TRAY"] == "1")
#else
        _mode = State(initialValue: .week)
        _showsTaskTray = State(initialValue: false)
#endif
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            HStack(spacing: 0) {
                Group {
                    switch mode {
                    case .week:
                        WeekTaskBoard(
                            days: weekDays,
                            selectedDate: selectedDate,
                            onEdit: { editingTask = $0 },
                            onAdd: addTask,
                            onOpenDay: { day in
                                selectedDate = day
                            }
                        )
                    case .month:
                        MonthTaskGrid(
                            month: selectedDate,
                            selectedDate: selectedDate,
                            onSelect: { selectedDate = $0 },
                            onEdit: { editingTask = $0 },
                            onAdd: addTask,
                            onOpenDay: { day in
                                selectedDate = day
                                mode = .week
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsTaskTray {
                    Rectangle().fill(Color.yanxuBorder).frame(width: 1)
                    UnscheduledTaskTray(
                        onEdit: { editingTask = $0 },
                        onAdd: {
                            newTaskRequest = NewTaskRequest(date: nil, scheduleKind: .inbox)
                        }
                    )
                    .frame(width: 238)
                }
            }
        }
        .background(Color.yanxuCard)
        .sheet(item: $newTaskRequest) { request in
            TaskEditorView(defaultDate: request.date, defaultScheduleKind: request.scheduleKind)
                .environmentObject(store)
        }
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
                .environmentObject(store)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 9) {
            Button { moveSelection(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(CalendarIconButtonStyle())

            Button { moveSelection(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(CalendarIconButtonStyle())

            Button("今天") {
                withAnimation(.snappy) { selectedDate = Date() }
            }
            .buttonStyle(CalendarTextButtonStyle())

            Text(navigationTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.yanxuInk)
                .padding(.leading, 5)

            Spacer()

            Picker("视图", selection: $mode) {
                ForEach(CalendarDisplayMode.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 110)

            Button {
                withAnimation(.snappy) { showsTaskTray.toggle() }
            } label: {
                Label("待安排", systemImage: "tray")
            }
            .buttonStyle(CalendarTextButtonStyle(isSelected: showsTaskTray))

            Button {
                addTask(on: selectedDate)
            } label: {
                Label("新建", systemImage: "plus")
            }
            .buttonStyle(PrimaryActionStyle())
        }
        .padding(.horizontal, 18)
        .frame(height: 55)
        .background(Color.yanxuCard)
    }

    private var weekDays: [Date] {
        let interval = DateIntervals.week(containing: selectedDate, calendar: store.calendar)
        return (0..<7).compactMap { store.calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var navigationTitle: String {
        switch mode {
        case .week:
            guard let first = weekDays.first, let last = weekDays.last else { return "" }
            let year = store.calendar.component(.year, from: first)
            return "\(year) 年 \(Formatters.shortDate.string(from: first)) – \(Formatters.shortDate.string(from: last))"
        case .month:
            return Formatters.monthTitle.string(from: selectedDate)
        }
    }

    private func moveSelection(by amount: Int) {
        let component: Calendar.Component
        switch mode {
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        if let date = store.calendar.date(byAdding: component, value: amount, to: selectedDate) {
            withAnimation(.snappy) { selectedDate = date }
        }
    }

    private func addTask(on date: Date) {
        newTaskRequest = NewTaskRequest(
            date: store.calendar.startOfDay(for: date),
            scheduleKind: .day
        )
    }
}

private struct DayTaskList: View {
    @EnvironmentObject private var store: AppStore

    let day: Date
    let onEdit: (TodoItem) -> Void
    let onAdd: () -> Void

    private var occurrences: [TaskOccurrence] {
        store.occurrences(on: day).sorted(by: occurrenceSort)
    }

    private var incomplete: [TaskOccurrence] {
        occurrences.filter { occurrence in
            store.task(id: occurrence.taskID)?.isCompleted(on: occurrence.date, calendar: store.calendar) == false
        }
    }

    private var fixed: [TaskOccurrence] { incomplete.filter { store.task(id: $0.taskID)?.scheduleKind == .fixed } }
    private var dated: [TaskOccurrence] { incomplete.filter { store.task(id: $0.taskID)?.scheduleKind == .day } }
    private var ranged: [TaskOccurrence] { incomplete.filter { store.task(id: $0.taskID)?.scheduleKind == .range } }
    private var completed: [TaskOccurrence] { occurrences.filter { !incomplete.contains($0) } }

    private var deadlines: [DeadlineItem] {
        store.data.deadlines
            .filter { store.calendar.isDate($0.dueDate, inSameDayAs: day) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(dayTitle)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.yanxuInk)
                        Text(incomplete.isEmpty ? "今天没有未完成任务" : "\(incomplete.count) 项待完成")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.yanxuMuted)
                    }
                    Spacer()
                    Button {
                        onAdd()
                    } label: {
                        Label("添加任务", systemImage: "plus")
                    }
                    .buttonStyle(CalendarTextButtonStyle())
                }

                if occurrences.isEmpty && deadlines.isEmpty {
                    DayEmptyState(onAdd: onAdd)
                } else {
                    taskSection("具体时间", detail: "时间只作提示", items: fixed)
                    taskSection("当天任务", items: dated)
                    taskSection("可在当天完成", detail: "日期范围任务", items: ranged)

                    if !deadlines.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            CalendarSectionTitle(title: "DDL", count: deadlines.count)
                            ForEach(deadlines) { deadline in
                                HStack(spacing: 12) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.yanxuDanger)
                                        .frame(width: 20)
                                    Text(deadline.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.yanxuInk)
                                    Spacer()
                                    Text(deadline.includesTime ? Formatters.time.string(from: deadline.dueDate) : "截止")
                                        .font(.caption)
                                        .foregroundStyle(Color.yanxuMuted)
                                }
                                .padding(.vertical, 12)
                                Divider().foregroundStyle(Color.yanxuBorder)
                            }
                        }
                    }

                    taskSection("已完成", items: completed)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { values, _ in
            move(values, to: day)
        }
    }

    @ViewBuilder
    private func taskSection(_ title: String, detail: String? = nil, items: [TaskOccurrence]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CalendarSectionTitle(title: title, detail: detail, count: items.count)
                ForEach(items) { occurrence in
                    DayTaskRow(occurrence: occurrence, onEdit: onEdit)
                    Divider().foregroundStyle(Color.yanxuBorder)
                }
            }
        }
    }

    private var dayTitle: String {
        if store.calendar.isDateInToday(day) { return "今天" }
        if store.calendar.isDateInTomorrow(day) { return "明天" }
        if store.calendar.isDateInYesterday(day) { return "昨天" }
        return Formatters.fullDate.string(from: day)
    }

    private func occurrenceSort(_ lhs: TaskOccurrence, _ rhs: TaskOccurrence) -> Bool {
        guard let left = store.task(id: lhs.taskID), let right = store.task(id: rhs.taskID) else { return false }
        let leftRank = scheduleRank(left.scheduleKind)
        let rightRank = scheduleRank(right.scheduleKind)
        if leftRank != rightRank { return leftRank < rightRank }
        if left.scheduleKind == .fixed, let leftStart = left.start, let rightStart = right.start, leftStart != rightStart {
            return leftStart < rightStart
        }
        return left.createdAt < right.createdAt
    }

    private func scheduleRank(_ kind: TaskScheduleKind) -> Int {
        switch kind {
        case .fixed: 0
        case .day: 1
        case .range: 2
        case .inbox: 3
        }
    }

    private func move(_ values: [String], to date: Date) -> Bool {
        guard let value = values.first, let id = UUID(uuidString: value) else { return false }
        store.moveTask(id: id, to: date)
        return true
    }
}

private struct CalendarSectionTitle: View {
    let title: String
    var detail: String? = nil
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.yanxuInk)
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.yanxuMuted)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.yanxuRaised, in: Capsule())
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)
            }
            Spacer()
        }
        .padding(.bottom, 7)
    }
}

private struct DayTaskRow: View {
    @EnvironmentObject private var store: AppStore

    let occurrence: TaskOccurrence
    let onEdit: (TodoItem) -> Void

    private var task: TodoItem? { store.task(id: occurrence.taskID) }

    var body: some View {
        if let task {
            let completed = task.isCompleted(on: occurrence.date, calendar: store.calendar)
            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) { store.toggleTask(id: task.id, occurrenceDate: occurrence.date) }
                } label: {
                    Image(systemName: completed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundStyle(completed ? Color.yanxuAccent : Color.yanxuMuted)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14))
                        .foregroundStyle(completed ? Color.yanxuMuted : Color.yanxuInk)
                        .strikethrough(completed)
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.caption)
                            .foregroundStyle(Color.yanxuMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let metadata = taskMetadata(task) {
                    Text(metadata)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(task.scheduleKind == .fixed ? Color.yanxuAccent : Color.yanxuMuted)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(task.scheduleKind == .fixed ? Color.yanxuAccentSoft : Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 6))
                }

                Button {
                    onEdit(task)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.yanxuMuted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onEdit(task) }
            .draggable(task.id.uuidString)
            .opacity(completed ? 0.65 : 1)
            .contextMenu {
                TaskContextMenuItems(
                    task: task,
                    occurrenceDate: occurrence.date,
                    onEdit: { onEdit(task) }
                )
            }
        }
    }

    private func taskMetadata(_ task: TodoItem) -> String? {
        switch task.scheduleKind {
        case .fixed:
            return task.start.map { Formatters.time.string(from: $0) }
        case .range:
            guard let start = task.start, let end = task.end else { return "日期范围" }
            return "\(Formatters.shortDate.string(from: start)) – \(Formatters.shortDate.string(from: end))"
        case .day:
            return task.isRecurring ? task.repeatRule.title : nil
        case .inbox:
            return nil
        }
    }
}

private struct DayEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.yanxuAccent)
            Text("这一天还没有任务")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.yanxuInk)
            Text("可以安排一件要推进的事")
                .font(.caption)
                .foregroundStyle(Color.yanxuMuted)
            Button("添加任务", action: onAdd)
                .buttonStyle(CalendarTextButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(Color.yanxuRaised.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WeekTaskBoard: View {
    @EnvironmentObject private var store: AppStore

    let days: [Date]
    let selectedDate: Date
    let onEdit: (TodoItem) -> Void
    let onAdd: (Date) -> Void
    let onOpenDay: (Date) -> Void

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / 7
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        WeekDayColumn(
                            day: day,
                            isSelected: store.calendar.isDate(day, inSameDayAs: selectedDate),
                            onEdit: onEdit,
                            onAdd: { onAdd(day) },
                            onOpenDay: { onOpenDay(day) }
                        )
                        .frame(width: columnWidth)
                    }
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
    }
}

private struct WeekDayColumn: View {
    @EnvironmentObject private var store: AppStore

    let day: Date
    let isSelected: Bool
    let onEdit: (TodoItem) -> Void
    let onAdd: () -> Void
    let onOpenDay: () -> Void

    private var occurrences: [TaskOccurrence] {
        store.occurrences(on: day).sorted { lhs, rhs in
            guard let left = store.task(id: lhs.taskID), let right = store.task(id: rhs.taskID) else { return false }
            if left.scheduleKind == .fixed && right.scheduleKind != .fixed { return true }
            if left.scheduleKind != .fixed && right.scheduleKind == .fixed { return false }
            if let leftStart = left.start, let rightStart = right.start, left.scheduleKind == .fixed, right.scheduleKind == .fixed {
                return leftStart < rightStart
            }
            return left.createdAt < right.createdAt
        }
    }

    private var deadlines: [DeadlineItem] {
        store.data.deadlines.filter { store.calendar.isDate($0.dueDate, inSameDayAs: day) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpenDay) {
                VStack(spacing: 5) {
                    Text(weekdayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(store.calendar.isDateInToday(day) ? Color.yanxuAccent : Color.yanxuMuted.opacity(isWeekend ? 0.62 : 1))
                    Text("\(store.calendar.component(.day, from: day))")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(store.calendar.isDateInToday(day) ? .white : Color.yanxuInk.opacity(isWeekend ? 0.62 : 1))
                        .frame(width: 30, height: 30)
                        .background(store.calendar.isDateInToday(day) ? Color.yanxuAccent : .clear, in: Circle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? Color.yanxuAccentSoft.opacity(0.7) : (isWeekend ? Color.yanxuRaised.opacity(0.55) : Color.yanxuCard))
            }
            .buttonStyle(.plain)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            VStack(spacing: 7) {
                ForEach(occurrences) { occurrence in
                    WeekTaskChip(occurrence: occurrence, onEdit: onEdit)
                }

                ForEach(deadlines) { deadline in
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                        Text(deadline.title).lineLimit(2)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.yanxuDanger)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yanxuDanger.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                }

                Button(action: onAdd) {
                    Label("添加", systemImage: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.yanxuMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 260)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(store.calendar.isDateInToday(day) ? Color.yanxuAccentSoft.opacity(0.18) : (isWeekend ? Color.yanxuRaised.opacity(0.22) : Color.yanxuCard))
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.yanxuBorder).frame(width: 1)
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first, let id = UUID(uuidString: value) else { return false }
            store.moveTask(id: id, to: day)
            return true
        }
    }

    private var weekdayText: String {
        let index = max(0, min(6, store.calendar.component(.weekday, from: day) - 1))
        let symbols = store.calendar.shortWeekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private var isWeekend: Bool {
        store.calendar.isDateInWeekend(day)
    }
}

private struct WeekTaskChip: View {
    @EnvironmentObject private var store: AppStore

    let occurrence: TaskOccurrence
    let onEdit: (TodoItem) -> Void

    var body: some View {
        if let task = store.task(id: occurrence.taskID) {
            let completed = task.isCompleted(on: occurrence.date, calendar: store.calendar)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    Button {
                        withAnimation(.snappy) { store.toggleTask(id: task.id, occurrenceDate: occurrence.date) }
                    } label: {
                        Image(systemName: completed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13))
                            .foregroundStyle(completed ? Color.yanxuAccent : Color.yanxuMuted)
                    }
                    .buttonStyle(.plain)

                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(completed ? Color.yanxuMuted : Color.yanxuInk)
                        .strikethrough(completed)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let detail = detail(for: task) {
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(task.scheduleKind == .fixed ? Color.yanxuAccent : Color.yanxuMuted)
                        .padding(.leading, 19)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(for: task), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent(for: task))
                    .frame(width: 3)
                    .padding(.vertical, 5)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onEdit(task) }
            .draggable(task.id.uuidString)
            .help(task.title)
            .opacity(completed ? 0.58 : 1)
            .contextMenu {
                TaskContextMenuItems(
                    task: task,
                    occurrenceDate: occurrence.date,
                    onEdit: { onEdit(task) }
                )
            }
        }
    }

    private func detail(for task: TodoItem) -> String? {
        if task.scheduleKind == .fixed, let start = task.start { return Formatters.time.string(from: start) }
        if task.scheduleKind == .range { return "日期范围" }
        if task.isRecurring { return task.repeatRule.title }
        return nil
    }

    private func background(for task: TodoItem) -> Color {
        TaskVisualKind(title: task.title).background
    }

    private func accent(for task: TodoItem) -> Color {
        TaskVisualKind(title: task.title).accent
    }
}

private struct MonthTaskGrid: View {
    @EnvironmentObject private var store: AppStore

    let month: Date
    let selectedDate: Date
    let onSelect: (Date) -> Void
    let onEdit: (TodoItem) -> Void
    let onAdd: (Date) -> Void
    let onOpenDay: (Date) -> Void

    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    var body: some View {
        GeometryReader { geometry in
            let headerHeight: CGFloat = 34
            let rowHeight = max(54, (geometry.size.height - headerHeight) / 6)
            let visibleTaskCount = rowHeight >= 90 ? 3 : (rowHeight >= 72 ? 2 : 1)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) { index, weekday in
                        Text(weekday)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.yanxuMuted.opacity(index >= 5 ? 0.62 : 1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: headerHeight)
                .background(Color.yanxuRaised.opacity(0.7))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(gridDates, id: \.self) { day in
                        MonthDayCell(
                            day: day,
                            displayedMonth: month,
                            isSelected: store.calendar.isDate(day, inSameDayAs: selectedDate),
                            maxVisibleTasks: visibleTaskCount,
                            onSelect: { onSelect(day) },
                            onEdit: onEdit,
                            onAdd: { onAdd(day) },
                            onOpenDay: { onOpenDay(day) }
                        )
                        .frame(height: rowHeight)
                    }
                }
            }
        }
    }

    private var gridDates: [Date] {
        guard let monthInterval = store.calendar.dateInterval(of: .month, for: month),
              let firstWeek = store.calendar.dateInterval(of: .weekOfYear, for: monthInterval.start) else { return [] }
        return (0..<42).compactMap { store.calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }
}

private struct MonthDayCell: View {
    @EnvironmentObject private var store: AppStore

    let day: Date
    let displayedMonth: Date
    let isSelected: Bool
    let maxVisibleTasks: Int
    let onSelect: () -> Void
    let onEdit: (TodoItem) -> Void
    let onAdd: () -> Void
    let onOpenDay: () -> Void

    private var occurrences: [TaskOccurrence] {
        store.occurrences(on: day).sorted { lhs, rhs in
            guard let left = store.task(id: lhs.taskID), let right = store.task(id: rhs.taskID) else { return false }
            if left.scheduleKind == .fixed && right.scheduleKind != .fixed { return true }
            if left.scheduleKind != .fixed && right.scheduleKind == .fixed { return false }
            return left.createdAt < right.createdAt
        }
    }

    private var deadlines: [DeadlineItem] {
        store.data.deadlines.filter { store.calendar.isDate($0.dueDate, inSameDayAs: day) }
    }

    private var visibleItems: Int { min(maxVisibleTasks, occurrences.count) }

    private var shownDeadlineCount: Int {
        !deadlines.isEmpty && occurrences.count < maxVisibleTasks ? 1 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(store.calendar.component(.day, from: day))")
                    .font(.system(size: 11, weight: store.calendar.isDateInToday(day) ? .semibold : .regular))
                    .foregroundStyle(store.calendar.isDateInToday(day) ? .white : dayNumberColor)
                    .frame(width: 23, height: 23)
                    .background(store.calendar.isDateInToday(day) ? Color.yanxuAccent : .clear, in: Circle())
                Spacer()
                if isSelected && !store.calendar.isDateInToday(day) {
                    Circle().fill(Color.yanxuAccent).frame(width: 4, height: 4)
                }
            }

            ForEach(Array(occurrences.prefix(visibleItems))) { occurrence in
                MonthTaskLine(occurrence: occurrence, onEdit: onEdit)
            }

            if let deadline = deadlines.first, shownDeadlineCount == 1 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(deadline.title).lineLimit(1)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.yanxuDanger)
            }

            let hidden = max(0, occurrences.count - visibleItems) + max(0, deadlines.count - shownDeadlineCount)
            if hidden > 0 {
                Text("还有 \(hidden) 项")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.yanxuMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cellBackground)
        .overlay {
            Rectangle().stroke(Color.yanxuBorder, lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onOpenDay() }
        .contextMenu {
            Button("添加任务", action: onAdd)
            Button("打开日视图", action: onOpenDay)
        }
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first, let id = UUID(uuidString: value) else { return false }
            store.moveTask(id: id, to: day)
            return true
        }
    }

    private var isInDisplayedMonth: Bool {
        store.calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
    }

    private var dayNumberColor: Color {
        isInDisplayedMonth ? Color.yanxuInk : Color.yanxuMuted.opacity(0.55)
    }

    private var cellBackground: Color {
        if isSelected { return Color.yanxuAccentSoft.opacity(0.55) }
        if !isInDisplayedMonth { return Color.yanxuRaised.opacity(0.4) }
        if store.calendar.isDateInWeekend(day) { return Color.yanxuRaised.opacity(0.28) }
        return Color.yanxuCard
    }
}

private struct MonthTaskLine: View {
    @EnvironmentObject private var store: AppStore
    let occurrence: TaskOccurrence
    let onEdit: (TodoItem) -> Void

    var body: some View {
        if let task = store.task(id: occurrence.taskID) {
            let completed = task.isCompleted(on: occurrence.date, calendar: store.calendar)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(TaskVisualKind(title: task.title).accent)
                    .frame(width: 3, height: 11)
                if task.scheduleKind == .fixed, let start = task.start {
                    Text(Formatters.time.string(from: start))
                        .foregroundStyle(Color.yanxuAccent)
                }
                Text(task.title)
                    .foregroundStyle(completed ? Color.yanxuMuted : Color.yanxuInk)
                    .strikethrough(completed)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 17, alignment: .leading)
            .background(TaskVisualKind(title: task.title).background, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onEdit(task) }
            .draggable(task.id.uuidString)
            .help(task.title)
            .opacity(completed ? 0.58 : 1)
            .contextMenu {
                TaskContextMenuItems(
                    task: task,
                    occurrenceDate: occurrence.date,
                    onEdit: { onEdit(task) }
                )
            }
        }
    }
}

private struct UnscheduledTaskTray: View {
    @EnvironmentObject private var store: AppStore
    let onEdit: (TodoItem) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("待安排")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                    Text("拖到某一天即可安排")
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .buttonStyle(CalendarIconButtonStyle())
            }
            .padding(16)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            if store.inboxTasks().isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 25, weight: .light))
                        .foregroundStyle(Color.yanxuMuted)
                    Text("没有待安排任务")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.yanxuMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 54)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.inboxTasks()) { task in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "square")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.yanxuMuted)
                                Text(task.title)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.yanxuInk)
                                    .lineLimit(3)
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onEdit(task) }
                            .draggable(task.id.uuidString)
                            .contextMenu {
                                TaskContextMenuItems(
                                    task: task,
                                    occurrenceDate: nil,
                                    onEdit: { onEdit(task) }
                                )
                            }
                        }
                    }
                    .padding(12)
                }
            }

            Spacer(minLength: 0)
        }
        .background(Color.yanxuSidebar)
    }
}

private struct CalendarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.yanxuInk)
            .frame(width: 30, height: 30)
            .background(configuration.isPressed ? Color.yanxuAccentSoft : Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct CalendarTextButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isSelected ? Color.yanxuAccent : Color.yanxuInk)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(isSelected ? Color.yanxuAccentSoft : (configuration.isPressed ? Color.yanxuRaised : Color.clear), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.clear : Color.yanxuBorder, lineWidth: 1)
            }
    }
}
