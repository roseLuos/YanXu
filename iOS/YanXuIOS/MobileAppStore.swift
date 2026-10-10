import Foundation
import Combine
import WidgetKit

@MainActor
final class MobileAppStore: ObservableObject {
    @Published private(set) var data: AppData {
        didSet {
            persist()
            refreshWidgetSnapshot()
            scheduleAutomaticMacSync()
        }
    }

    let calendar: Calendar
    private let fileURL: URL
    private let backgroundSync = LANSyncClient()
    private var automaticSyncTask: Task<Void, Never>?
    private var isApplyingRemoteChange = false
    private static let pairingCodeKey = "yanxu.lan.pairing-code"
    private static let manualHostKey = "yanxu.lan.manual-host"

    init(fileURL: URL? = nil) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        self.calendar = calendar

        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("YanXu", isDirectory: true)
            self.fileURL = directory.appendingPathComponent("yanxu-ios-data.json")
        }
        var initial = Self.load(from: self.fileURL) ?? AppData()
#if DEBUG
        if ProcessInfo.processInfo.environment["YANXU_SEED_DEMO"] == "1" {
            initial = MobileDemoData.merging(into: initial, now: .now, calendar: calendar)
        }
#endif
        self.data = initial
        refreshWidgetSnapshot()
        synchronizeWithMacIfConfigured()
    }

    func addQuickTask(_ text: String, now: Date = .now) {
        let parsed = QuickTaskParser.parse(text, now: now, calendar: calendar)
        guard !parsed.title.isEmpty else { return }
        var task = TodoItem(title: parsed.title, scheduleKind: parsed.scheduleKind, start: parsed.start)
        task.reminderEnabled = parsed.scheduleKind != .inbox
        upsertTask(task)
    }

    func upsertTask(_ task: TodoItem) {
        var next = data
        if let index = next.tasks.firstIndex(where: { $0.id == task.id }) {
            next.tasks[index] = task
        } else {
            next.tasks.append(task)
        }
        data = next
    }

    func deleteTask(_ id: UUID) {
        var next = data
        next.tasks.removeAll { $0.id == id }
        data = next
    }

    func taskOccurrences(on date: Date) -> [TodoItem] {
        data.tasks
            .filter { $0.occurs(on: date, calendar: calendar) }
            .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    func toggle(_ task: TodoItem, on date: Date) {
        var changed = task
        if task.isRecurring {
            let key = DateKey.string(for: date, calendar: calendar)
            if changed.completedOccurrenceKeys.contains(key) {
                changed.completedOccurrenceKeys.remove(key)
            } else {
                changed.completedOccurrenceKeys.insert(key)
            }
        } else {
            changed.completedAt = changed.completedAt == nil ? .now : nil
        }
        upsertTask(changed)
    }

    func postpone(_ task: TodoItem) {
        guard let start = task.start else { return }
        var changed = task
        changed.start = calendar.date(byAdding: .day, value: 1, to: start)
        if let end = task.end { changed.end = calendar.date(byAdding: .day, value: 1, to: end) }
        upsertTask(changed)
    }

    func checkIn(_ habitID: UUID) {
        var next = data
        next.habitLogs.append(HabitLog(habitID: habitID))
        data = next
    }

    func upsertHabit(_ habit: Habit) {
        var next = data
        if let index = next.habits.firstIndex(where: { $0.id == habit.id }) {
            next.habits[index] = habit
        } else {
            next.habits.append(habit)
        }
        data = next
    }

    func deleteHabit(_ id: UUID) {
        var next = data
        next.habits.removeAll { $0.id == id }
        next.habitLogs.removeAll { $0.habitID == id }
        data = next
    }

    func habitCount(_ habitID: UUID, in interval: DateInterval) -> Int {
        data.habitLogs.filter { $0.habitID == habitID && interval.contains($0.timestamp) }.count
    }

    var activeAttendance: AttendanceSession? { data.attendanceSessions.first { $0.leftAt == nil } }

    func toggleAttendance() {
        var next = data
        if let index = next.attendanceSessions.firstIndex(where: { $0.leftAt == nil }) {
            next.attendanceSessions[index].leftAt = .now
        } else {
            next.attendanceSessions.append(AttendanceSession())
        }
        data = next
    }

    func researchDuration(in interval: DateInterval, now: Date = .now) -> TimeInterval {
        data.attendanceSessions.reduce(0) { $0 + $1.overlap(with: interval, now: now) }
    }

    func mergeFromMac(_ remote: AppData) {
        isApplyingRemoteChange = true
        data = LANSyncMerge.merge(data, remote)
        isApplyingRemoteChange = false
    }

    func synchronizeWithMacIfConfigured() {
        scheduleAutomaticMacSync()
    }

    var activeDeadlines: [DeadlineItem] {
        data.deadlines
            .filter { calendar.startOfDay(for: $0.dueDate) >= calendar.startOfDay(for: .now) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func upsertDeadline(_ deadline: DeadlineItem) {
        var next = data
        if let index = next.deadlines.firstIndex(where: { $0.id == deadline.id }) {
            next.deadlines[index] = deadline
        } else {
            next.deadlines.append(deadline)
        }
        data = next
    }

    func deleteDeadline(_ id: UUID) {
        var next = data
        next.deadlines.removeAll { $0.id == id }
        data = next
    }

    // MARK: - Widgets

    private func refreshWidgetSnapshot(now: Date = .now) {
        let today = calendar.startOfDay(for: now)
        let week = DateIntervals.week(containing: now, calendar: calendar)

        let todayTasks = taskOccurrences(on: today)
            .filter { !$0.isCompleted(on: today, calendar: calendar) }
            .compactMap { widgetTaskSummary(for: $0, occurrenceDate: today, showsWeekday: false) }

        var weekTasks: [(task: TodoItem, date: Date)] = []
        var cursor = week.start
        while cursor < week.end {
            for task in taskOccurrences(on: cursor) where !task.isCompleted(on: cursor, calendar: calendar) {
                weekTasks.append((task, cursor))
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? week.end
        }
        let weekSummaries = weekTasks
            .sorted { widgetDate(for: $0.task, on: $0.date) < widgetDate(for: $1.task, on: $1.date) }
            .compactMap { widgetTaskSummary(for: $0.task, occurrenceDate: $0.date, showsWeekday: false) }

        let deadlines = activeDeadlines.prefix(6).map {
            WidgetDeadlineSummary(id: $0.id.uuidString, title: $0.title, dueDate: $0.dueDate)
        }
        let snapshot = YanXuWidgetSnapshot(
            generatedAt: now,
            todayTasks: todayTasks,
            weekTasks: weekSummaries,
            deadlines: Array(deadlines)
        )
        try? YanXuWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func widgetTaskSummary(
        for task: TodoItem,
        occurrenceDate: Date,
        showsWeekday: Bool
    ) -> WidgetTaskSummary? {
        let date = widgetDate(for: task, on: occurrenceDate)
        var detailParts: [String] = []
        if showsWeekday {
            detailParts.append(occurrenceDate.formatted(.dateTime.weekday(.short)))
        }
        if task.scheduleKind == .fixed {
            detailParts.append(date.formatted(.dateTime.hour().minute()))
        }
        return WidgetTaskSummary(
            id: "\(task.id.uuidString)-\(DateKey.string(for: occurrenceDate, calendar: calendar))",
            title: task.title,
            date: date,
            detail: detailParts.isEmpty ? nil : detailParts.joined(separator: " ")
        )
    }

    private func widgetDate(for task: TodoItem, on occurrenceDate: Date) -> Date {
        guard task.scheduleKind == .fixed, let start = task.start else { return occurrenceDate }
        let time = calendar.dateComponents([.hour, .minute], from: start)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: occurrenceDate
        ) ?? occurrenceDate
    }

    private static func load(from url: URL) -> AppData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppData.self, from: raw)
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            // 本地保存失败不应阻断当次操作；接入同步时会显示可恢复错误。
        }
    }

    private func scheduleAutomaticMacSync() {
        guard !isApplyingRemoteChange else { return }
        let pairingCode = UserDefaults.standard.string(forKey: Self.pairingCodeKey) ?? ""
        let host = LANSyncClient.normalizedHost(UserDefaults.standard.string(forKey: Self.manualHostKey) ?? "")
        guard pairingCode.count == 6, !host.isEmpty else { return }
        automaticSyncTask?.cancel()
        let localData = data
        automaticSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.backgroundSync.synchronize(data: localData, pairingCode: pairingCode, manualHost: host) { [weak self] remote in
                self?.mergeFromMac(remote)
            }
        }
    }
}
