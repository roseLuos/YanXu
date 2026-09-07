import Foundation
import SwiftUI
import UserNotifications
import WidgetKit
import YanXuCore

struct TaskOccurrence: Identifiable, Hashable {
    let taskID: UUID
    let date: Date

    var id: String { "\(taskID.uuidString)-\(DateKey.string(for: date))" }
}

enum CCFDeadlineLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

struct DeadlinePreview: Identifiable {
    let id: String
    let title: String
    let dueDate: Date
    let includesTime: Bool
    let sourceLabel: String?
    let sourceURL: URL?
}

private struct CCFDeadlineCache: Codable {
    let updatedAt: Date
    let deadlines: [CCFDeadline]
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData {
        didSet {
            persist()
            if enablesExternalSync {
                refreshWidgetSnapshot()
                CalendarSyncManager.shared.dataDidChange(data)
            }
        }
    }
    @Published var persistenceError: String?
    @Published private(set) var ccfDeadlines: [CCFDeadline] = []
    @Published private(set) var ccfDeadlineLoadState: CCFDeadlineLoadState = .idle
    @Published private(set) var ccfDeadlineUpdatedAt: Date?

    let calendar: Calendar
    private let fileURL: URL
    private let ccfDeadlineCacheURL: URL
    private let enablesExternalSync: Bool

    static let ccfDeadlineSourceURL = URL(string: "https://ccfddl.com/conference/deadlines_zh_ccf_A_AI.ics")!
    static let ccfDDLWebsiteURL = URL(string: "https://ccfddl.com/")!

    init(fileURL: URL? = nil) {
        var configuredCalendar = Calendar(identifier: .gregorian)
        configuredCalendar.locale = Locale(identifier: "zh_CN")
        configuredCalendar.firstWeekday = 2
        self.calendar = configuredCalendar

        let resolvedFileURL: URL
        let usesDefaultStorage: Bool
        if let fileURL {
            resolvedFileURL = fileURL
            usesDefaultStorage = false
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            resolvedFileURL = applicationSupport
                .appendingPathComponent("YanXu", isDirectory: true)
                .appendingPathComponent("data.json")
            usesDefaultStorage = true
        }
        self.fileURL = resolvedFileURL
        self.enablesExternalSync = usesDefaultStorage
        self.ccfDeadlineCacheURL = resolvedFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("ccfddl-ai-a-cache.json")

        // If the app's persisted data has been removed, stale task reminders should
        // not survive independently in Notification Center.
        if usesDefaultStorage, !FileManager.default.fileExists(atPath: resolvedFileURL.path) {
            NotificationManager.shared.removeAllAppNotifications()
        }

        var initialData = Self.load(from: self.fileURL) ?? AppData()
#if DEBUG
        let shouldSeedDemo = ProcessInfo.processInfo.environment["YANXU_SEED_DEMO"] == "1"
        if shouldSeedDemo {
            initialData = DemoDataFactory.merging(into: initialData, referenceDate: Date(), calendar: configuredCalendar)
        }
#endif
        self.data = initialData
        if let cache = Self.loadCCFDeadlineCache(from: ccfDeadlineCacheURL) {
            self.ccfDeadlines = cache.deadlines
            self.ccfDeadlineUpdatedAt = cache.updatedAt
            self.ccfDeadlineLoadState = .ready
        }
#if DEBUG
        if shouldSeedDemo { persist() }
#endif
        if enablesExternalSync {
            refreshWidgetSnapshot()
            NotificationManager.shared.syncAll(initialData.tasks)
            CalendarSyncManager.shared.appDidLoad(data: initialData)
        }
    }

    // MARK: - Tasks

    func upsertTask(_ task: TodoItem) {
        var copy = data
        if let index = copy.tasks.firstIndex(where: { $0.id == task.id }) {
            copy.tasks[index] = task
        } else {
            copy.tasks.append(task)
        }
        data = copy
        NotificationManager.shared.sync(task)
    }

    func deleteTask(id: UUID) {
        var copy = data
        copy.tasks.removeAll { $0.id == id }
        data = copy
        NotificationManager.shared.removeTaskNotification(id: id)
    }

    func task(id: UUID) -> TodoItem? {
        data.tasks.first { $0.id == id }
    }

    func occurrences(on date: Date) -> [TaskOccurrence] {
        data.tasks
            .filter { $0.occurs(on: date, calendar: calendar) }
            .map { TaskOccurrence(taskID: $0.id, date: calendar.startOfDay(for: date)) }
    }

    func inboxTasks() -> [TodoItem] {
        data.tasks
            .filter { $0.scheduleKind == .inbox && $0.completedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func overdueOccurrences(asOf date: Date = Date(), lookbackDays: Int = 60) -> [TaskOccurrence] {
        let today = calendar.startOfDay(for: date)
        let lookback = calendar.date(byAdding: .day, value: -lookbackDays, to: today) ?? today
        var result: [TaskOccurrence] = []

        for task in data.tasks where task.scheduleKind != .inbox {
            if task.isRecurring {
                var cursor = max(calendar.startOfDay(for: task.start ?? task.createdAt), lookback)
                while cursor < today {
                    if task.occurs(on: cursor, calendar: calendar), !task.isCompleted(on: cursor, calendar: calendar) {
                        result.append(TaskOccurrence(taskID: task.id, date: cursor))
                    }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                }
            } else if let dueDate = task.dueDate,
                      calendar.startOfDay(for: dueDate) < today,
                      task.completedAt == nil {
                result.append(TaskOccurrence(taskID: task.id, date: calendar.startOfDay(for: dueDate)))
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    func toggleTask(id: UUID, occurrenceDate: Date) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        var copy = data
        var task = copy.tasks[index]

        if task.isRecurring {
            let key = DateKey.string(for: occurrenceDate, calendar: calendar)
            if task.completedOccurrenceKeys.contains(key) {
                task.completedOccurrenceKeys.remove(key)
            } else {
                task.completedOccurrenceKeys.insert(key)
            }
        } else {
            task.completedAt = task.completedAt == nil ? Date() : nil
        }

        copy.tasks[index] = task
        data = copy
    }

    func moveTask(id: UUID, to day: Date, minutesFromMidnight: Int? = nil) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return }

        var copy = data
        var task = copy.tasks[index]
        let targetDay = calendar.startOfDay(for: day)
        let oldStart = task.start
        let oldEnd = task.end

        if let minutesFromMidnight {
            let clampedMinutes = min(max(minutesFromMidnight, 0), 23 * 60 + 30)
            let targetStart = calendar.date(byAdding: .minute, value: clampedMinutes, to: targetDay) ?? targetDay
            let wasFixed = task.scheduleKind == .fixed
            let oldDuration = wasFixed ? max(30 * 60, (oldEnd?.timeIntervalSince(oldStart ?? targetStart)) ?? 60 * 60) : 60 * 60

            task.scheduleKind = .fixed
            task.start = targetStart
            task.end = wasFixed && oldEnd != nil ? targetStart.addingTimeInterval(oldDuration) : nil
            task.reminderEnabled = true
        } else if task.scheduleKind == .range, let oldStart {
            let oldStartDay = calendar.startOfDay(for: oldStart)
            let oldEndDay = calendar.startOfDay(for: oldEnd ?? oldStart)
            let daySpan = max(0, calendar.dateComponents([.day], from: oldStartDay, to: oldEndDay).day ?? 0)
            task.start = targetDay
            task.end = calendar.date(byAdding: .day, value: daySpan, to: targetDay)
        } else if task.scheduleKind == .fixed, let oldStart {
            let components = calendar.dateComponents([.hour, .minute], from: oldStart)
            let targetStart = calendar.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: 0,
                of: targetDay
            ) ?? targetDay
            let duration = oldEnd?.timeIntervalSince(oldStart)
            task.start = targetStart
            task.end = duration.map { targetStart.addingTimeInterval(max(0, $0)) }
        } else {
            task.scheduleKind = .day
            task.start = targetDay
            task.end = nil
            task.reminderEnabled = true
        }

        copy.tasks[index] = task
        data = copy
        NotificationManager.shared.sync(task)
    }

    func postponeTask(id: UUID, byDays dayCount: Int = 1) {
        guard dayCount != 0,
              let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].scheduleKind != .inbox,
              let start = data.tasks[index].start else { return }

        var copy = data
        var task = copy.tasks[index]
        task.start = calendar.date(byAdding: .day, value: dayCount, to: start)
        if let end = task.end {
            task.end = calendar.date(byAdding: .day, value: dayCount, to: end)
        }

        copy.tasks[index] = task
        data = copy
        NotificationManager.shared.sync(task)
    }

    func completedTaskCount(in interval: DateInterval) -> Int {
        data.tasks.reduce(into: 0) { total, task in
            if task.isRecurring {
                total += task.completedOccurrenceKeys.compactMap { DateKey.date(from: $0, calendar: calendar) }
                    .filter(interval.contains)
                    .count
            } else if let completedAt = task.completedAt, interval.contains(completedAt) {
                total += 1
            }
        }
    }

    func plannedTaskCount(in interval: DateInterval) -> Int {
        data.tasks.reduce(into: 0) { total, task in
            guard task.scheduleKind != .inbox else { return }
            if task.isRecurring {
                var cursor = max(calendar.startOfDay(for: task.start ?? task.createdAt), calendar.startOfDay(for: interval.start))
                var safety = 0
                while cursor < interval.end, safety < 370 {
                    if task.occurs(on: cursor, calendar: calendar) { total += 1 }
                    cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
                    safety += 1
                }
            } else if let due = task.dueDate, interval.contains(due) {
                total += 1
            }
        }
    }

    // MARK: - Deadlines

    func upsertDeadline(_ deadline: DeadlineItem) {
        var copy = data
        if let index = copy.deadlines.firstIndex(where: { $0.id == deadline.id }) {
            copy.deadlines[index] = deadline
        } else {
            copy.deadlines.append(deadline)
        }
        data = copy
    }

    func deleteDeadline(id: UUID) {
        var copy = data
        copy.deadlines.removeAll { $0.id == id }
        data = copy
    }

    var activeDeadlines: [DeadlineItem] {
        let today = calendar.startOfDay(for: Date())
        return data.deadlines
            .filter { calendar.startOfDay(for: $0.dueDate) >= today }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var archivedDeadlines: [DeadlineItem] {
        let today = calendar.startOfDay(for: Date())
        return data.deadlines
            .filter { calendar.startOfDay(for: $0.dueDate) < today }
            .sorted { $0.dueDate > $1.dueDate }
    }

    var upcomingCCFDeadlines: [CCFDeadline] {
        let now = Date()
        return ccfDeadlines
            .filter { $0.dueDate >= now }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var personalDeadlinePreviews: [DeadlinePreview] {
        activeDeadlines.map {
            DeadlinePreview(
                id: "personal-\($0.id.uuidString)",
                title: $0.title,
                dueDate: $0.dueDate,
                includesTime: $0.includesTime,
                sourceLabel: nil,
                sourceURL: nil
            )
        }
    }

    var ccfDeadlinePreviews: [DeadlinePreview] {
        upcomingCCFDeadlines.map {
            DeadlinePreview(
                id: "ccf-\($0.id)",
                title: $0.title,
                dueDate: $0.dueDate,
                includesTime: true,
                sourceLabel: "CCF A · AI",
                sourceURL: $0.conferenceURL
            )
        }
    }

    var deadlinePreviews: [DeadlinePreview] {
        (personalDeadlinePreviews + ccfDeadlinePreviews)
            .sorted { $0.dueDate < $1.dueDate }
    }

    func refreshCCFDeadlines() async {
        guard ccfDeadlineLoadState != .loading else { return }
        ccfDeadlineLoadState = .loading

        do {
            var request = URLRequest(url: Self.ccfDeadlineSourceURL)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 15
            let (rawData, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let parsed = CCFDeadlineParser.parse(rawData)
            guard !parsed.isEmpty else { throw URLError(.cannotParseResponse) }

            let updatedAt = Date()
            ccfDeadlines = parsed
            ccfDeadlineUpdatedAt = updatedAt
            ccfDeadlineLoadState = .ready
            persistCCFDeadlineCache(CCFDeadlineCache(updatedAt: updatedAt, deadlines: parsed))
            refreshWidgetSnapshot()
        } catch {
            ccfDeadlineLoadState = .failed("暂时无法连接 CCFDDL")
        }
    }

    // MARK: - Habits

    func upsertHabit(_ habit: Habit) {
        var copy = data
        if let index = copy.habits.firstIndex(where: { $0.id == habit.id }) {
            copy.habits[index] = habit
        } else {
            copy.habits.append(habit)
        }
        data = copy
    }

    func deleteHabit(id: UUID) {
        var copy = data
        copy.habits.removeAll { $0.id == id }
        copy.habitLogs.removeAll { $0.habitID == id }
        data = copy
    }

    func checkIn(habitID: UUID, at date: Date = Date()) {
        var copy = data
        copy.habitLogs.append(HabitLog(habitID: habitID, timestamp: date))
        data = copy
    }

    func undoLatestHabitCheckIn(habitID: UUID) {
        guard let latest = data.habitLogs
            .filter({ $0.habitID == habitID })
            .max(by: { $0.timestamp < $1.timestamp }) else { return }
        var copy = data
        copy.habitLogs.removeAll { $0.id == latest.id }
        data = copy
    }

    func habitCount(habitID: UUID, in interval: DateInterval) -> Int {
        data.habitLogs.filter { $0.habitID == habitID && interval.contains($0.timestamp) }.count
    }

    // MARK: - Attendance

    var activeAttendanceSession: AttendanceSession? {
        data.attendanceSessions.first { $0.leftAt == nil }
    }

    func clockIn(at date: Date = Date()) {
        guard activeAttendanceSession == nil else { return }
        var copy = data
        copy.attendanceSessions.append(AttendanceSession(arrivedAt: date))
        data = copy
    }

    func clockOut(at date: Date = Date()) {
        guard let index = data.attendanceSessions.firstIndex(where: { $0.leftAt == nil }) else { return }
        var copy = data
        copy.attendanceSessions[index].leftAt = max(date, copy.attendanceSessions[index].arrivedAt)
        data = copy
    }

    func updateAttendance(_ session: AttendanceSession) {
        guard let index = data.attendanceSessions.firstIndex(where: { $0.id == session.id }) else { return }
        var copy = data
        copy.attendanceSessions[index] = session
        data = copy
    }

    func deleteAttendance(id: UUID) {
        var copy = data
        copy.attendanceSessions.removeAll { $0.id == id }
        data = copy
    }

    func attendanceDuration(in interval: DateInterval, now: Date = Date()) -> TimeInterval {
        data.attendanceSessions.reduce(0) { $0 + $1.overlap(with: interval, now: now) }
    }

    // MARK: - Widgets

    private func refreshWidgetSnapshot(now: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        let week = DateIntervals.week(containing: now, calendar: calendar)

        let todayTasks = occurrences(on: today)
            .filter { occurrence in
                task(id: occurrence.taskID)?.isCompleted(on: occurrence.date, calendar: calendar) == false
            }
            .sorted(by: widgetOccurrenceSort)
            .compactMap { widgetTaskSummary(for: $0, showsWeekday: false) }

        var weekOccurrences: [TaskOccurrence] = []
        var cursor = week.start
        while cursor < week.end {
            weekOccurrences.append(contentsOf: occurrences(on: cursor).filter { occurrence in
                task(id: occurrence.taskID)?.isCompleted(on: occurrence.date, calendar: calendar) == false
            })
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? week.end
        }
        let weekTasks = weekOccurrences
            .sorted(by: widgetOccurrenceSort)
            .compactMap { widgetTaskSummary(for: $0, showsWeekday: true) }

        let deadlines = deadlinePreviews.prefix(6).map {
            WidgetDeadlineSummary(
                id: $0.id,
                title: $0.title,
                dueDate: $0.dueDate,
                source: $0.sourceLabel
            )
        }

        let snapshot = YanXuWidgetSnapshot(
            generatedAt: now,
            todayTasks: todayTasks,
            weekTasks: weekTasks,
            deadlines: deadlines
        )
        try? YanXuWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func widgetOccurrenceSort(_ lhs: TaskOccurrence, _ rhs: TaskOccurrence) -> Bool {
        let leftDate = widgetDate(for: lhs)
        let rightDate = widgetDate(for: rhs)
        if leftDate != rightDate { return leftDate < rightDate }
        return (task(id: lhs.taskID)?.createdAt ?? .distantPast) < (task(id: rhs.taskID)?.createdAt ?? .distantPast)
    }

    private func widgetDate(for occurrence: TaskOccurrence) -> Date {
        guard let task = task(id: occurrence.taskID),
              task.scheduleKind == .fixed,
              let start = task.start else { return occurrence.date }
        let time = calendar.dateComponents([.hour, .minute], from: start)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: occurrence.date
        ) ?? occurrence.date
    }

    private func widgetTaskSummary(for occurrence: TaskOccurrence, showsWeekday: Bool) -> WidgetTaskSummary? {
        guard let task = task(id: occurrence.taskID) else { return nil }
        let date = widgetDate(for: occurrence)
        let weekday = date.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .locale(Locale(identifier: "zh_CN"))
        )

        let detail: String?
        if showsWeekday, task.scheduleKind == .fixed {
            detail = "\(weekday) \(Formatters.time.string(from: date))"
        } else if showsWeekday {
            detail = weekday
        } else if task.scheduleKind == .fixed {
            detail = Formatters.time.string(from: date)
        } else if task.scheduleKind == .range {
            detail = "日期范围"
        } else {
            detail = nil
        }

        return WidgetTaskSummary(
            id: occurrence.id,
            title: task.title,
            date: date,
            detail: detail
        )
    }

    // MARK: - Persistence

    private static func load(from url: URL) -> AppData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppData.self, from: raw)
    }

    private static func loadCCFDeadlineCache(from url: URL) -> CCFDeadlineCache? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CCFDeadlineCache.self, from: raw)
    }

    private func persistCCFDeadlineCache(_ cache: CCFDeadlineCache) {
        do {
            try FileManager.default.createDirectory(
                at: ccfDeadlineCacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let raw = try encoder.encode(cache)
            try raw.write(to: ccfDeadlineCacheURL, options: .atomic)
        } catch {
            // 网络数据缓存失败不影响用户自己的任务与 DDL。
        }
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "数据保存失败：\(error.localizedDescription)"
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func syncAll(_ tasks: [TodoItem]) {
        for task in tasks {
            sync(task)
        }
    }

    func sync(_ task: TodoItem) {
        removeTaskNotification(id: task.id)
        guard task.reminderEnabled,
              task.scheduleKind != .inbox,
              let reminderDate = reminderDate(for: task) else { return }

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { self.schedule(task, reminderDate: reminderDate) }
                }
            case .authorized, .provisional:
                self.schedule(task, reminderDate: reminderDate)
            default:
                break
            }
        }
    }

    func removeTaskNotification(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: id)])
    }

    func removeAllAppNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func schedule(_ task: TodoItem, reminderDate: Date) {
        var components: DateComponents
        let calendar = Calendar.current

        switch task.repeatRule {
        case .none:
            guard reminderDate > Date() else { return }
            components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        case .daily:
            components = calendar.dateComponents([.hour, .minute], from: reminderDate)
        case .weekly:
            components = calendar.dateComponents([.weekday, .hour, .minute], from: reminderDate)
        case .monthly:
            components = calendar.dateComponents([.day, .hour, .minute], from: reminderDate)
        }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.scheduleKind == .fixed ? "即将开始" : "今天记得完成"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: task.repeatRule != .none)
        let request = UNNotificationRequest(identifier: identifier(for: task.id), content: content, trigger: trigger)
        center.add(request)
    }

    private func reminderDate(for task: TodoItem) -> Date? {
        guard let start = task.start else { return nil }
        let calendar = Calendar.current
        switch task.scheduleKind {
        case .inbox:
            return nil
        case .day, .range:
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: start)
        case .fixed:
            return calendar.date(byAdding: .minute, value: -10, to: start)
        }
    }

    private func identifier(for id: UUID) -> String { "yanxu-task-\(id.uuidString)" }
}
