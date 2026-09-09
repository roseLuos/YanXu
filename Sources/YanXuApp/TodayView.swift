import SwiftUI
import YanXuCore

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showsTaskEditor: Bool
    private let showsUtilityPanel: Bool

    @State private var editingTask: TodoItem?
    @State private var showsCompleted = false
    @State private var quickTitle: String

    init(showsTaskEditor: Binding<Bool>, showsUtilityPanel: Bool = true) {
        _showsTaskEditor = showsTaskEditor
        self.showsUtilityPanel = showsUtilityPanel
#if DEBUG
        _quickTitle = State(initialValue: ProcessInfo.processInfo.environment["YANXU_PREVIEW_QUICK_TASK"] ?? "")
#else
        _quickTitle = State(initialValue: "")
#endif
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            todayContent(on: timeline.date)
        }
        .background(Color.yanxuCard)
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
                .environmentObject(store)
        }
    }

    private func todayContent(on today: Date) -> some View {
        let groups = todayGroups(on: today)
        let total = groups.fixed.count + groups.required.count + groups.available.count + groups.completed.count

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("今天")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                    Text(Formatters.fullDate.string(from: today))
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }

                Spacer()

                if total > 0 {
                    Text("\(groups.completed.count) / \(total) 已完成")
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }

                Button {
                    showsTaskEditor = true
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .buttonStyle(SecondaryActionStyle())
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            if showsUtilityPanel {
                HStack(spacing: 0) {
                    taskList(groups)

                    Rectangle().fill(Color.yanxuBorder).frame(width: 1)

                    TodayUtilityPanel()
                        .frame(width: 268)
                }
            } else {
                taskList(groups)
            }
        }
    }

    private func taskList(_ groups: TodayGroups) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                quickAdd
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                if groups.overdue.isEmpty && groups.fixed.isEmpty && groups.required.isEmpty && groups.available.isEmpty && groups.inbox.isEmpty && groups.completed.isEmpty {
                    EmptyState(icon: "checkmark.square", title: "今天没有待办", message: "在上方输入一件准备完成的事。")
                        .padding(.top, 64)
                } else {
                            taskSection("已逾期", occurrences: groups.overdue, showsDate: true, tint: .yanxuWarning, rowTint: .yanxuWarningSoft)
                            taskSection("今天", occurrences: groups.fixed + groups.required + groups.available, tint: .yanxuAccent, rowTint: .yanxuAccentSoft.opacity(0.42))

                    if !groups.inbox.isEmpty {
                        inboxSection(groups.inbox)
                    }

                    if !groups.completed.isEmpty {
                        completedSection(groups.completed)
                    }
                }
            }
            .padding(.bottom, 28)
        }
    }

    private var quickAdd: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.yanxuAccent)
            TextField("试试：明天下午 2 点开会", text: $quickTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(addQuickTask)

            if let preview = quickSchedulePreview {
                Text(preview)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.yanxuAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yanxuAccentSoft, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(Color.yanxuBorder, lineWidth: 1)
        }
    }

    private func todayGroups(on today: Date) -> TodayGroups {
        let dayOccurrences = store.occurrences(on: today)
        let incomplete: (TaskOccurrence) -> Bool = { occurrence in
            store.task(id: occurrence.taskID)?.isCompleted(on: occurrence.date, calendar: store.calendar) == false
        }
        let fixed = dayOccurrences.filter {
            store.task(id: $0.taskID)?.scheduleKind == .fixed && incomplete($0)
        }.sorted {
            (store.task(id: $0.taskID)?.start ?? .distantFuture) < (store.task(id: $1.taskID)?.start ?? .distantFuture)
        }
        let required = dayOccurrences.filter {
            store.task(id: $0.taskID)?.scheduleKind == .day && incomplete($0)
        }
        let available = dayOccurrences.filter {
            store.task(id: $0.taskID)?.scheduleKind == .range && incomplete($0)
        }
        let scheduledCompleted = dayOccurrences.filter { !incomplete($0) }
        let scheduledIDs = Set(scheduledCompleted.map(\.taskID))
        let completedElsewhere = store.data.tasks.compactMap { task -> TaskOccurrence? in
            guard !scheduledIDs.contains(task.id),
                  let completedAt = task.completedAt,
                  store.calendar.isDate(completedAt, inSameDayAs: today) else { return nil }
            return TaskOccurrence(taskID: task.id, date: today)
        }

        return TodayGroups(
            overdue: store.overdueOccurrences(asOf: today),
            fixed: fixed,
            required: required,
            available: available,
            inbox: store.inboxTasks(),
            completed: scheduledCompleted + completedElsewhere
        )
    }

    @ViewBuilder
    private func taskSection(
        _ title: String,
        occurrences: [TaskOccurrence],
        showsDate: Bool = false,
        tint: Color,
        rowTint: Color
    ) -> some View {
        if !occurrences.isEmpty {
            listHeader(title, count: occurrences.count, tint: tint)
            VStack(spacing: 0) {
                ForEach(Array(occurrences.enumerated()), id: \.element.id) { index, occurrence in
                    TaskRow(
                        occurrence: occurrence,
                        showsDate: showsDate,
                        rowTint: rowTint,
                        onEdit: { editingTask = store.task(id: occurrence.taskID) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, index < occurrences.count - 1 ? 4 : 0)
                }
            }
        }
    }

    private func inboxSection(_ tasks: [TodoItem]) -> some View {
        VStack(spacing: 0) {
            listHeader("未安排", count: tasks.count, tint: .yanxuMuted)
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                TaskRow(
                    occurrence: TaskOccurrence(taskID: task.id, date: task.createdAt),
                    isDeemphasized: true,
                    onEdit: { editingTask = task }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, index < tasks.count - 1 ? 4 : 0)
            }
        }
    }

    private func completedSection(_ occurrences: [TaskOccurrence]) -> some View {
        DisclosureGroup(isExpanded: $showsCompleted) {
            VStack(spacing: 0) {
                ForEach(Array(occurrences.enumerated()), id: \.element.id) { index, occurrence in
                    TaskRow(
                        occurrence: occurrence,
                        rowTint: Color.yanxuNeutralSoft.opacity(0.55),
                        onEdit: { editingTask = store.task(id: occurrence.taskID) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, index < occurrences.count - 1 ? 4 : 0)
                }
            }
        } label: {
            HStack {
                Text("已完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.yanxuMuted)
                Text("\(occurrences.count)")
                    .font(.caption2)
                    .foregroundStyle(Color.yanxuMuted)
            }
        }
        .tint(Color.yanxuMuted)
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }

    private func listHeader(_ title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.yanxuInk)
            Spacer()
            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.yanxuMuted)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private func addQuickTask() {
        let input = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        let result = QuickTaskParser.parse(input, now: Date(), calendar: store.calendar)
        store.upsertTask(TodoItem(
            title: result.title,
            scheduleKind: result.scheduleKind,
            start: result.start,
            reminderEnabled: result.scheduleKind != .inbox
        ))
        quickTitle = ""
    }

    private var quickSchedulePreview: String? {
        let input = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        let result = QuickTaskParser.parse(input, now: Date(), calendar: store.calendar)
        guard let start = result.start else {
            return "待安排"
        }

        let dateText: String
        if store.calendar.isDateInToday(start) {
            dateText = "今天"
        } else if store.calendar.isDateInTomorrow(start) {
            dateText = "明天"
        } else {
            dateText = Formatters.shortDate.string(from: start)
        }

        if result.recognizedTime {
            return "\(dateText) \(Formatters.time.string(from: start))"
        }
        return dateText
    }
}

private struct TodayGroups {
    let overdue: [TaskOccurrence]
    let fixed: [TaskOccurrence]
    let required: [TaskOccurrence]
    let available: [TaskOccurrence]
    let inbox: [TodoItem]
    let completed: [TaskOccurrence]
}

struct TodayUtilityPanel: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                UtilityModule(title: "科研打卡", icon: "location.fill") {
                    AttendanceCard(embedded: true)
                }

                UtilityModule(title: "本周习惯", icon: "repeat") {
                    if store.data.habits.isEmpty {
                        utilityEmpty("还没有习惯")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.data.habits.enumerated()), id: \.element.id) { index, habit in
                                HabitQuickRow(habit: habit)
                                if index < store.data.habits.count - 1 {
                                    Divider().foregroundStyle(Color.yanxuBorder.opacity(0.7))
                                }
                            }
                        }
                    }
                }

                UtilityModule(title: "最近 DDL", icon: "timer") {
                    VStack(alignment: .leading, spacing: 14) {
                        deadlineGroupTitle("我的 DDL", count: min(2, store.personalDeadlinePreviews.count))
                        if store.personalDeadlinePreviews.isEmpty {
                            utilityEmpty("还没有自己添加的 DDL")
                        } else {
                            VStack(spacing: 9) {
                                ForEach(store.personalDeadlinePreviews.prefix(2)) { deadline in
                                    DeadlineCompactCard(deadline: deadline)
                                }
                            }
                        }

                        Divider().foregroundStyle(Color.yanxuBorder.opacity(0.7))

                        deadlineGroupTitle("CCFDDL · CCF A 人工智能", count: min(4, store.ccfDeadlinePreviews.count))
                        if store.ccfDeadlinePreviews.isEmpty {
                            utilityEmpty(store.ccfDeadlineLoadState == .loading ? "正在同步 CCFDDL…" : "暂无未来会议 DDL")
                        } else {
                            VStack(spacing: 9) {
                                ForEach(store.ccfDeadlinePreviews.prefix(4)) { deadline in
                                    DeadlineCompactCard(deadline: deadline)
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.yanxuCanvas)
    }

    private func utilityEmpty(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.yanxuMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.yanxuCanvas, in: RoundedRectangle(cornerRadius: 8))
    }

    private func deadlineGroupTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.yanxuInk)
            Spacer()
            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.yanxuMuted)
        }
    }
}

private struct UtilityModule<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.yanxuAccent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.yanxuRaised.opacity(0.82))

            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.yanxuCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yanxuBorder, lineWidth: 1)
        }
    }
}
