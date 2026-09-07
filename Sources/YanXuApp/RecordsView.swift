import Charts
import SwiftUI
import YanXuCore

private enum RecordsSection: String, CaseIterable, Identifiable {
    case dashboard = "看板"
    case habits = "习惯"
    case attendance = "打卡记录"

    var id: String { rawValue }
}

private enum DashboardPeriod: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"

    var id: String { rawValue }
}

struct RecordsView: View {
    @State private var section: RecordsSection = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("记录")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                    Text("科研时长、任务和习惯")
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }
                Spacer()
                Picker("记录页面", selection: $section) {
                    ForEach(RecordsSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 310)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(Color.yanxuCanvas)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            switch section {
            case .dashboard:
                DashboardView()
            case .habits:
                HabitManagementView()
            case .attendance:
                AttendanceHistoryView()
            }
        }
        .background(Color.yanxuCanvas)
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    @State private var period: DashboardPeriod = .week
    @State private var selectedDate = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let interval = selectedInterval
            let duration = store.attendanceDuration(in: interval, now: timeline.date)
            let planned = store.plannedTaskCount(in: interval)
            let completed = store.completedTaskCount(in: interval)
            let habitLogs = store.data.habitLogs.filter { interval.contains($0.timestamp) }.count

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Button { move(-1) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.borderless)
                        Button("今天") { selectedDate = Date() }
                            .buttonStyle(QuietActionStyle())
                        Button { move(1) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.borderless)

                        Text(periodTitle)
                            .font(.headline)
                            .foregroundStyle(Color.yanxuInk)
                            .padding(.leading, 4)

                        Spacer()

                        Picker("周期", selection: $period) {
                            ForEach(DashboardPeriod.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        MetricCard(title: "科研时长", value: Formatters.duration(duration), icon: "clock.fill")
                        MetricCard(title: "完成任务", value: "\(completed) 项", detail: "计划 \(planned) 项", icon: "checkmark.circle.fill")
                        MetricCard(title: "习惯打卡", value: "\(habitLogs) 次", icon: "repeat.circle.fill")
                    }

                    switch period {
                    case .day:
                        dailyAttendance(interval: interval, now: timeline.date)
                    case .week:
                        dailyBarChart(interval: interval, now: timeline.date, title: "每日科研时长")
                    case .month:
                        dailyBarChart(interval: interval, now: timeline.date, title: "本月每日科研时长")
                    }

                    if !store.data.habits.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            PageSectionHeader(title: "习惯记录", detail: periodTitle)
                            SurfaceCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(store.data.habits.enumerated()), id: \.element.id) { index, habit in
                                        let count = store.habitCount(habitID: habit.id, in: interval)
                                        HStack {
                                            Text(habit.name)
                                            Spacer()
                                            Text("\(count) 次")
                                                .foregroundStyle(Color.yanxuMuted)
                                        }
                                        .padding(.vertical, 9)
                                        if index < store.data.habits.count - 1 { Divider() }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 980)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectedInterval: DateInterval {
        switch period {
        case .day: DateIntervals.day(containing: selectedDate, calendar: store.calendar)
        case .week: DateIntervals.week(containing: selectedDate, calendar: store.calendar)
        case .month: DateIntervals.month(containing: selectedDate, calendar: store.calendar)
        }
    }

    private var periodTitle: String {
        switch period {
        case .day:
            return Formatters.shortDate.string(from: selectedDate)
        case .week:
            let interval = DateIntervals.week(containing: selectedDate, calendar: store.calendar)
            let end = store.calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
            return "\(Formatters.shortDate.string(from: interval.start))–\(Formatters.shortDate.string(from: end))"
        case .month:
            return Formatters.monthTitle.string(from: selectedDate)
        }
    }

    private func move(_ direction: Int) {
        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        selectedDate = store.calendar.date(byAdding: component, value: direction, to: selectedDate) ?? selectedDate
    }

    @ViewBuilder
    private func dailyAttendance(interval: DateInterval, now: Date) -> some View {
        let sessions = store.data.attendanceSessions
            .filter { $0.arrivedAt < interval.end && ($0.leftAt ?? now) > interval.start }
            .sorted { $0.arrivedAt < $1.arrivedAt }

        VStack(alignment: .leading, spacing: 10) {
            PageSectionHeader(title: "到达与离开", detail: "\(sessions.count) 段")
            if sessions.isEmpty {
                EmptyState(icon: "building.2", title: "没有打卡记录", message: "点击“到达”后开始记录科研时长。")
            } else {
                SurfaceCard {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            HStack {
                                Label(Formatters.time.string(from: session.arrivedAt), systemImage: "arrow.right.circle")
                                Text("—")
                                    .foregroundStyle(Color.yanxuMuted.opacity(0.6))
                                Label(session.leftAt.map { Formatters.time.string(from: $0) } ?? "进行中", systemImage: "arrow.left.circle")
                                Spacer()
                                Text(Formatters.duration(session.duration(until: now)))
                                    .foregroundStyle(Color.yanxuMuted)
                            }
                            .padding(.vertical, 10)
                            if index < sessions.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func dailyBarChart(interval: DateInterval, now: Date, title: String) -> some View {
        let points = chartPoints(interval: interval, now: now)
        return VStack(alignment: .leading, spacing: 10) {
            PageSectionHeader(title: title, detail: "小时")
            SurfaceCard {
                Chart(points) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("小时", point.hours)
                    )
                    .foregroundStyle(Color.yanxuAccent.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: period == .week ? 7 : 10)) { value in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 250)
            }
        }
    }

    private func chartPoints(interval: DateInterval, now: Date) -> [DailyHours] {
        var cursor = store.calendar.startOfDay(for: interval.start)
        var points: [DailyHours] = []
        while cursor < interval.end {
            let day = DateIntervals.day(containing: cursor, calendar: store.calendar)
            points.append(DailyHours(date: cursor, hours: store.attendanceDuration(in: day, now: now) / 3600))
            cursor = store.calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }
        return points
    }
}

private struct DailyHours: Identifiable {
    let date: Date
    let hours: Double
    var id: Date { date }
}

private struct MetricCard: View {
    let title: String
    let value: String
    var detail: String?
    let icon: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(Color.yanxuAccent)
                    Text(title)
                        .foregroundStyle(Color.yanxuMuted)
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HabitManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingHabit: Habit?
    @State private var showsNewHabit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("每完成一次就 +1，同一天可以记录多次。")
                        .foregroundStyle(Color.yanxuMuted)
                    Spacer()
                    Button {
                        showsNewHabit = true
                    } label: {
                        Label("添加习惯", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryActionStyle())
                }

                if store.data.habits.isEmpty {
                    EmptyState(icon: "repeat", title: "还没有习惯", message: "例如添加“阅读论文”，设置每周目标次数。")
                } else {
                    SurfaceCard {
                        VStack(spacing: 0) {
                            ForEach(Array(store.data.habits.enumerated()), id: \.element.id) { index, habit in
                                HabitQuickRow(habit: habit)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { editingHabit = habit }
                                    .contextMenu {
                                        Button("编辑") { editingHabit = habit }
                                        Button("删除", role: .destructive) { store.deleteHabit(id: habit.id) }
                                    }
                                if index < store.data.habits.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showsNewHabit) {
            HabitEditorView()
                .environmentObject(store)
        }
        .sheet(item: $editingHabit) { habit in
            HabitEditorView(habit: habit)
                .environmentObject(store)
        }
    }
}

private struct HabitEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Habit

    init(habit: Habit? = nil) {
        _draft = State(initialValue: habit ?? Habit(name: "", weeklyTarget: 3))
    }

    private var isEditing: Bool { store.data.habits.contains(where: { $0.id == draft.id }) }
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WEEKLY HABIT")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color.yanxuAccent)
                    Text(isEditing ? "编辑习惯" : "新增习惯")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.yanxuMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.yanxuRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("习惯名称")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.yanxuMuted)
                TextField("例如：阅读论文", text: $draft.name)
                    .editorField()
            }

            VStack(alignment: .leading, spacing: 10) {
                Stepper("每周目标：\(draft.weeklyTarget) 次", value: $draft.weeklyTarget, in: 1...50)
                    .foregroundStyle(Color.yanxuInk)
                Text("不记录连续天数，每次打卡只增加一次计数。")
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)
            }
            .padding(15)
            .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11))

            Spacer(minLength: 0)

            Button(action: save) {
                Text(isEditing ? "保存修改" : "创建习惯")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
            .keyboardShortcut(.defaultAction)
        }
        .padding(26)
        .frame(width: 440, height: 390)
        .background(Color.yanxuCard)
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsertHabit(draft)
        dismiss()
    }
}

private struct AttendanceHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingSession: AttendanceSession?

    private var sessions: [AttendanceSession] {
        store.data.attendanceSessions.sorted { $0.arrivedAt > $1.arrivedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AttendanceCard()

                if sessions.isEmpty {
                    EmptyState(icon: "building.2", title: "还没有打卡记录", message: "到达和离开实验室时各点击一次即可。")
                } else {
                    PageSectionHeader(title: "全部记录", detail: "双击编辑")
                    SurfaceCard {
                        VStack(spacing: 0) {
                            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(Formatters.fullDate.string(from: session.arrivedAt))
                                            .font(.subheadline.weight(.medium))
                                        Text("\(Formatters.time.string(from: session.arrivedAt)) – \(session.leftAt.map { Formatters.time.string(from: $0) } ?? "进行中")")
                                            .font(.caption)
                                            .foregroundStyle(Color.yanxuMuted)
                                    }
                                    Spacer()
                                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                                        Text(Formatters.duration(session.duration(until: timeline.date)))
                                            .foregroundStyle(Color.yanxuMuted)
                                    }
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { editingSession = session }
                                .contextMenu {
                                    Button("编辑") { editingSession = session }
                                    Button("删除", role: .destructive) { store.deleteAttendance(id: session.id) }
                                }
                                if index < sessions.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 780)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editingSession) { session in
            AttendanceEditorView(session: session)
                .environmentObject(store)
        }
    }
}

private struct AttendanceEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AttendanceSession
    @State private var hasLeft: Bool

    init(session: AttendanceSession) {
        _draft = State(initialValue: session)
        _hasLeft = State(initialValue: session.leftAt != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ATTENDANCE")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color.yanxuAccent)
                    Text("修改打卡记录")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.yanxuMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.yanxuRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            VStack(spacing: 14) {
                HStack {
                    Text("到达")
                        .foregroundStyle(Color.yanxuInk)
                    Spacer()
                    DatePicker("到达", selection: $draft.arrivedAt, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                Divider().foregroundStyle(Color.yanxuBorder)
                HStack {
                    Text("已经离开")
                        .foregroundStyle(Color.yanxuInk)
                    Spacer()
                    Toggle("已经离开", isOn: $hasLeft)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color.yanxuAccent)
                }
                if hasLeft {
                    Divider().foregroundStyle(Color.yanxuBorder)
                    HStack {
                        Text("离开")
                            .foregroundStyle(Color.yanxuInk)
                        Spacer()
                        DatePicker("离开", selection: Binding(
                            get: { draft.leftAt ?? draft.arrivedAt },
                            set: { draft.leftAt = $0 }
                        ), in: draft.arrivedAt..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                    }
                }
            }
            .padding(15)
            .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11))

            Spacer(minLength: 0)

            Button(action: save) {
                Text("保存修改")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(26)
        .frame(width: 460, height: 400)
        .background(Color.yanxuCard)
    }

    private func save() {
        if hasLeft {
            let proposed = draft.leftAt ?? draft.arrivedAt
            draft.leftAt = max(proposed, draft.arrivedAt)
        } else {
            draft.leftAt = nil
        }
        store.updateAttendance(draft)
        dismiss()
    }
}
