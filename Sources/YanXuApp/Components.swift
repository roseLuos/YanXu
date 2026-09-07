import SwiftUI
import YanXuCore

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(Color.yanxuCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.yanxuBorder, lineWidth: 1)
            }
    }
}

struct PageSectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.yanxuInk)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)
            }
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject private var store: AppStore
    @State private var isHovering = false

    let occurrence: TaskOccurrence
    var showsDate = false
    var rowTint: Color = .clear
    var isDeemphasized = false
    var onEdit: (() -> Void)?

    private var task: TodoItem? { store.task(id: occurrence.taskID) }

    var body: some View {
        if let task {
            let completed = task.isCompleted(on: occurrence.date, calendar: store.calendar)
            HStack(spacing: 11) {
                Button {
                    withAnimation(.snappy) {
                        store.toggleTask(id: task.id, occurrenceDate: occurrence.date)
                    }
                } label: {
                    Image(systemName: completed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(completed ? Color.yanxuAccent : Color.yanxuMuted)
                }
                .buttonStyle(.plain)
                .help(completed ? "撤销完成" : "标记完成")

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .strikethrough(completed)
                        .foregroundStyle(completed || isDeemphasized ? Color.yanxuMuted : Color.yanxuInk)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if task.scheduleKind == .fixed, let start = task.start {
                            Label(Formatters.time.string(from: start), systemImage: "clock")
                        } else if showsDate {
                            Label(Formatters.shortDate.string(from: occurrence.date), systemImage: "calendar")
                        }
                        if task.isRecurring {
                            Label(task.repeatRule.title, systemImage: "repeat")
                        }
                        if task.scheduleKind == .range, let start = task.start, let end = task.end {
                            Text("\(Formatters.shortDate.string(from: start))–\(Formatters.shortDate.string(from: end))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)
                }

                Spacer(minLength: 8)

                if onEdit != nil {
                    Button {
                        onEdit?()
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.yanxuMuted)
                    }
                    .buttonStyle(.plain)
                    .help("编辑任务")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(
                isHovering ? Color.yanxuAccentSoft.opacity(0.72) : rowTint,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture(count: 2) { onEdit?() }
            .contextMenu {
                TaskContextMenuItems(
                    task: task,
                    occurrenceDate: occurrence.date,
                    onEdit: onEdit
                )
            }
            .opacity(completed ? 0.52 : (isDeemphasized ? 0.74 : 1))
        }
    }
}

struct TaskContextMenuItems: View {
    @EnvironmentObject private var store: AppStore

    let task: TodoItem
    var occurrenceDate: Date?
    var onEdit: (() -> Void)?

    var body: some View {
        let completed = occurrenceDate.map {
            task.isCompleted(on: $0, calendar: store.calendar)
        } ?? (task.completedAt != nil)

        if task.scheduleKind != .inbox && !completed {
            Button {
                store.postponeTask(id: task.id)
            } label: {
                Label("延后一天", systemImage: "arrow.right")
            }
        }

        if let onEdit {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
        }

        Divider()

        Button(role: .destructive) {
            store.deleteTask(id: task.id)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
}

struct DeadlineCompactCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    let deadline: DeadlinePreview

    var body: some View {
        let days = store.calendar.dateComponents(
            [.day],
            from: store.calendar.startOfDay(for: Date()),
            to: store.calendar.startOfDay(for: deadline.dueDate)
        ).day ?? 0
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(deadline.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(deadline.includesTime ? Formatters.dateTime.string(from: deadline.dueDate) : Formatters.shortDate.string(from: deadline.dueDate))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.yanxuMuted)
                if let sourceLabel = deadline.sourceLabel {
                    Text(sourceLabel)
                            .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.yanxuAccentStrong)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                        .background(Color.yanxuAccentSoft, in: Capsule())
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(days == 0 ? "今天" : "\(days)")
                    .font(.system(size: days == 0 ? 16 : 23, weight: .semibold))
                    .foregroundStyle(Color.yanxuAccent)
                if days != 0 {
                    Text("天")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.yanxuAccent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yanxuBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let sourceURL = deadline.sourceURL {
                openURL(sourceURL)
            }
        }
        .help(deadline.sourceURL == nil ? deadline.title : "打开会议官网")
    }
}

struct AttendanceCard: View {
    @EnvironmentObject private var store: AppStore
    var embedded = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let today = DateIntervals.day(containing: timeline.date, calendar: store.calendar)
            let duration = store.attendanceDuration(in: today, now: timeline.date)
            let cardContent = HStack(spacing: 13) {
                    Image(systemName: store.activeAttendanceSession == nil ? "building.2" : "location.fill")
                        .font(.title2)
                        .foregroundStyle(Color.yanxuAccent)
                        .frame(width: 34, height: 34)
                        .background(Color.yanxuAccentSoft, in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 3) {
                        if let active = store.activeAttendanceSession {
                            Text("已在实验室 \(Formatters.duration(duration))")
                                .font(embedded ? .system(size: 18, weight: .semibold) : .headline)
                            Text("\(Formatters.time.string(from: active.arrivedAt)) 到达 · 今日累计")
                                .font(.caption)
                                .foregroundStyle(Color.yanxuMuted)
                        } else {
                            Text(duration > 0 ? "今日科研 \(Formatters.duration(duration))" : "尚未到达实验室")
                                .font(embedded ? .system(size: 18, weight: .semibold) : .headline)
                            Text(duration > 0 ? "可以继续开始新的时段" : "到达后开始记录科研时长")
                                .font(.caption)
                                .foregroundStyle(Color.yanxuMuted)
                        }
                    }

                    Spacer()

                    Button(store.activeAttendanceSession == nil ? "到达" : "离开") {
                        if store.activeAttendanceSession == nil {
                            store.clockIn()
                        } else {
                            store.clockOut()
                        }
                    }
                    .buttonStyle(PrimaryActionStyle())
                }

            if embedded {
                cardContent
                    .padding(.vertical, 3)
            } else {
                SurfaceCard {
                    cardContent
                }
            }
        }
    }
}

struct HabitQuickRow: View {
    @EnvironmentObject private var store: AppStore
    let habit: Habit

    var body: some View {
        let week = DateIntervals.week(containing: Date(), calendar: store.calendar)
        let count = store.habitCount(habitID: habit.id, in: week)

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                Text(habit.name)
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.yanxuBorder.opacity(0.65))
                            Capsule().fill(Color.yanxuSuccess.opacity(0.82))
                                .frame(width: geometry.size.width * min(1, Double(count) / Double(habit.weeklyTarget)))
                        }
                    }
                    .frame(height: 5)
                    Text("\(count)/\(habit.weeklyTarget)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.yanxuMuted)
                }
            }
            Spacer()
            Button {
                store.undoLatestHabitCheckIn(habitID: habit.id)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.yanxuMuted)
            .disabled(count == 0)
            .help("撤销最近一次")

            Button {
                withAnimation(.snappy) { store.checkIn(habitID: habit.id) }
            } label: {
                Label("+1", systemImage: "checkmark")
            }
            .buttonStyle(HabitCheckInButtonStyle())
        }
        .padding(.vertical, 10)
    }
}

private struct HabitCheckInButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.yanxuAccent)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.yanxuAccentSoft.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Color.yanxuAccent.opacity(0.58))
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.yanxuInk)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.yanxuMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
