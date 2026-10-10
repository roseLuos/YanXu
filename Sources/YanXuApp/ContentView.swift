import AppKit
import SwiftUI
import YanXuCore

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showsTaskEditor: Bool
    @State private var showsDeadlineManager = false
    @State private var showsRecords = false

    init() {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        _showsTaskEditor = State(initialValue: environment["YANXU_PREVIEW_TASK_EDITOR"] == "1")
        _showsDeadlineManager = State(initialValue: environment["YANXU_PREVIEW_PANEL"] == "deadlines")
        _showsRecords = State(initialValue: environment["YANXU_PREVIEW_PANEL"] == "records")
#else
        _showsTaskEditor = State(initialValue: false)
#endif
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceTopBar(
                onManageDeadlines: { showsDeadlineManager = true },
                onShowRecords: { showsRecords = true }
            )

            WorkspaceDashboard()

            Rectangle()
                .fill(Color.yanxuBorder)
                .frame(height: 1)

            UnifiedPlanningView(showsTaskEditor: $showsTaskEditor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.yanxuCanvas)
        .sheet(isPresented: $showsTaskEditor) {
            TaskEditorView(defaultDate: Date())
                .environmentObject(store)
        }
        .sheet(isPresented: $showsDeadlineManager) {
            WorkspaceManagementSheet(title: "里程碑管理") {
                DeadlineBoardView()
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showsRecords) {
            WorkspaceManagementSheet(title: "详细数据与记录") {
                RecordsView()
            }
            .environmentObject(store)
        }
        .alert("无法保存数据", isPresented: Binding(
            get: { store.persistenceError != nil },
            set: { if !$0 { store.persistenceError = nil } }
        )) {
            Button("好") { store.persistenceError = nil }
        } message: {
            Text(store.persistenceError ?? "未知错误")
        }
        .task {
            ResearchIslandCoordinator.shared.show(store: store)
            await store.refreshCCFDeadlines()
        }
    }
}

private struct WorkspaceTopBar: View {
    @EnvironmentObject private var store: AppStore

    let onManageDeadlines: () -> Void
    let onShowRecords: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("研序")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                    Text(Formatters.fullDate.string(from: Date()))
                        .font(.caption2)
                        .foregroundStyle(Color.yanxuMuted)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: WorkspaceWindowSizing.toggle)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: WorkspaceWindowSizing.toggle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onManageDeadlines) {
                Label("里程碑 · \(store.deadlinePreviews.count)", systemImage: "flag.fill")
            }
            .buttonStyle(WorkspaceHeaderButtonStyle())

            Button(action: onShowRecords) {
                Label("详细记录", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(WorkspaceHeaderButtonStyle())

            SettingsLink {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(WorkspaceHeaderButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.yanxuSidebar)
    }
}

@MainActor
private enum WorkspaceWindowSizing {
    private static var restoredFrame: NSRect?

    static func toggle() {
        guard let window = NSApplication.shared.keyWindow,
              let screen = window.screen else { return }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
            return
        }

        let maximumFrame = screen.visibleFrame
        if approximatelyEqual(window.frame, maximumFrame) {
            let fallbackFrame = centeredDefaultFrame(in: maximumFrame)
            let frame = window.constrainFrameRect(restoredFrame ?? fallbackFrame, to: screen)
            window.setFrame(frame, display: true, animate: true)
        } else {
            restoredFrame = window.frame
            window.setFrame(maximumFrame, display: true, animate: true)
        }
    }

    private static func approximatelyEqual(_ lhs: NSRect, _ rhs: NSRect) -> Bool {
        let tolerance: CGFloat = 3
        return abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private static func centeredDefaultFrame(in visibleFrame: NSRect) -> NSRect {
        let width = min(1_280, visibleFrame.width * 0.86)
        let height = min(860, visibleFrame.height * 0.86)
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private struct WorkspaceDashboard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let week = DateIntervals.week(containing: timeline.date, calendar: store.calendar)

            HStack(spacing: 16) {
                WeeklyResearchCard(interval: week, now: timeline.date)
                    .frame(minWidth: 240, maxWidth: .infinity)
                    .frame(height: 148)

                TaskCompletionCard(interval: week)
                    .frame(minWidth: 240, maxWidth: .infinity)
                    .frame(height: 148)

                HabitProgressCard(interval: week)
                    .frame(minWidth: 300, maxWidth: .infinity)
                    .frame(height: 148)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(height: 172)
            .background(Color.yanxuCanvas)
        }
    }
}

private struct WeeklyResearchCard: View {
    @EnvironmentObject private var store: AppStore
    let interval: DateInterval
    let now: Date

    var body: some View {
        let duration = store.attendanceDuration(in: interval, now: now)
        let overlappingSessions = store.data.attendanceSessions.filter {
            $0.arrivedAt < interval.end && ($0.leftAt ?? now) > interval.start
        }
        let earliestArrival = store.data.attendanceSessions
            .map(\.arrivedAt)
            .filter(interval.contains)
            .min { clockTimeValue($0) < clockTimeValue($1) }
        let latestDeparture = store.data.attendanceSessions
            .compactMap(\.leftAt)
            .filter(interval.contains)
            .max { clockTimeValue($0) < clockTimeValue($1) }
        let dailyResearch = dailyResearchDurations(in: interval, now: now)
        let researchDays = dailyResearch.filter { $0.duration > 0 }.count
        let longestDay = dailyResearch.max { $0.duration < $1.duration }

        DashboardCard(title: "本周科研时长", icon: "clock.fill", tint: .yanxuAccent) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(Formatters.duration(duration))
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Color.yanxuInk)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.activeAttendanceSession == nil ? Color.yanxuMuted : Color.yanxuSuccess)
                            .frame(width: 6, height: 6)
                        Text(store.activeAttendanceSession == nil ? "\(overlappingSessions.count) 段" : "记录中 · \(overlappingSessions.count) 段")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.yanxuMuted)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    boundaryMetric(
                        title: "最早到达",
                        value: earliestArrival.map(Formatters.time.string) ?? "—",
                        icon: "sunrise.fill",
                        iconTint: .yanxuWarning,
                        date: earliestArrival
                    )
                    boundaryMetric(
                        title: "最晚离开",
                        value: latestDeparture.map(Formatters.time.string) ?? "—",
                        icon: "moon.stars.fill",
                        iconTint: .yanxuViolet,
                        date: latestDeparture
                    )
                    boundaryMetric(
                        title: "最长时长",
                        value: longestDay.map { compactDuration($0.duration) } ?? "—",
                        icon: "timer",
                        iconTint: .yanxuSuccess,
                        date: longestDay?.date
                    )
                    boundaryMetric(
                        title: "打卡天数",
                        value: "\(researchDays)天",
                        icon: "calendar.badge.checkmark",
                        iconTint: .yanxuAccent,
                        date: nil,
                        helpText: "本周共有 \(researchDays) 个科研打卡日"
                    )
                }
            }
        }
    }

    private func boundaryMetric(
        title: String,
        value: String,
        icon: String,
        iconTint: Color,
        date: Date?,
        helpText: String? = nil
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 18, height: 18)
                .background(iconTint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.yanxuInk)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.yanxuInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .background(Color.yanxuCard, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.yanxuBorder, lineWidth: 0.8)
        }
        .help(helpText ?? date.map(Formatters.dateTime.string) ?? "本周暂无记录")
    }

    private func compactDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours)时" : "\(hours)时\(minutes)分"
        }
        return "\(minutes)分"
    }

    private func dailyResearchDurations(in interval: DateInterval, now: Date) -> [(date: Date, duration: TimeInterval)] {
        var dayStart = store.calendar.startOfDay(for: interval.start)
        var result: [(date: Date, duration: TimeInterval)] = []

        while dayStart < interval.end {
            guard let nextDay = store.calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let dayInterval = DateInterval(
                start: max(dayStart, interval.start),
                end: min(nextDay, interval.end)
            )
            let duration = store.attendanceDuration(in: dayInterval, now: now)
            result.append((dayStart, duration))
            dayStart = nextDay
        }

        return result
    }

    private func clockTimeValue(_ date: Date) -> Int {
        let components = store.calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) * 3_600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0)
    }
}

private struct TaskCompletionCard: View {
    @EnvironmentObject private var store: AppStore
    let interval: DateInterval

    var body: some View {
        let completed = store.completedTaskCount(in: interval)
        let planned = store.plannedTaskCount(in: interval)
        let progress = planned == 0 ? 0 : min(1, Double(completed) / Double(planned))

        DashboardCard(title: "完成任务情况", icon: "checkmark.circle.fill", tint: .yanxuWarning) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(completed)")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Color.yanxuInk)
                    Text("/ \(planned) 项")
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.yanxuBorder.opacity(0.65))
                        Capsule().fill(Color.yanxuAccent.opacity(0.78))
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 7)

                Text(planned == 0 ? "本周还没有计划任务" : "本周完成率 \(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(Color.yanxuMuted)
            }
        }
    }
}

private struct HabitProgressCard: View {
    @EnvironmentObject private var store: AppStore
    let interval: DateInterval

    var body: some View {
        DashboardCard(title: "习惯打卡情况", icon: "repeat.circle.fill", tint: .yanxuSuccess) {
            if store.data.habits.isEmpty {
                Text("还没有习惯")
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.data.habits.prefix(3)) { habit in
                        let count = store.habitCount(habitID: habit.id, in: interval)
                        let progress = min(1, Double(count) / Double(habit.weeklyTarget))
                        HStack(spacing: 7) {
                            Text(habit.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.yanxuInk)
                                .lineLimit(1)
                                .frame(width: 72, alignment: .leading)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.yanxuBorder.opacity(0.65))
                                    Capsule().fill(Color.yanxuSuccess.opacity(0.82))
                                        .frame(width: geometry.size.width * progress)
                                }
                            }
                            .frame(height: 6)
                            Text("\(count)/\(habit.weeklyTarget)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.yanxuMuted)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                Spacer()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yanxuBorder, lineWidth: 1)
        }
    }
}

private struct WorkspaceHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.yanxuInk)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(configuration.isPressed ? Color.yanxuAccentSoft : Color.yanxuCanvas, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.yanxuBorder, lineWidth: 1)
            }
    }
}

private struct WorkspaceManagementSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(QuietActionStyle())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.yanxuSidebar)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 680)
        .background(Color.yanxuCanvas)
    }
}
