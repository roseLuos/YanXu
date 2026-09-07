import Foundation

public enum TaskScheduleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case inbox
    case day
    case fixed
    case range

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .inbox: "无日期"
        case .day: "某一天"
        case .fixed: "具体时间"
        case .range: "日期范围"
        }
    }
}

public enum TaskRepeatRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case daily
    case weekly
    case monthly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: "不重复"
        case .daily: "每天"
        case .weekly: "每周"
        case .monthly: "每月"
        }
    }
}

public struct TodoItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var scheduleKind: TaskScheduleKind
    public var start: Date?
    public var end: Date?
    public var repeatRule: TaskRepeatRule
    public var reminderEnabled: Bool
    public var completedAt: Date?
    public var completedOccurrenceKeys: Set<String>
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        scheduleKind: TaskScheduleKind = .inbox,
        start: Date? = nil,
        end: Date? = nil,
        repeatRule: TaskRepeatRule = .none,
        reminderEnabled: Bool = true,
        completedAt: Date? = nil,
        completedOccurrenceKeys: Set<String> = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.scheduleKind = scheduleKind
        self.start = start
        self.end = end
        self.repeatRule = repeatRule
        self.reminderEnabled = reminderEnabled
        self.completedAt = completedAt
        self.completedOccurrenceKeys = completedOccurrenceKeys
        self.createdAt = createdAt
    }

    public var isRecurring: Bool { repeatRule != .none }

    public func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        guard scheduleKind != .inbox, let start else { return false }

        let day = calendar.startOfDay(for: date)
        let firstDay = calendar.startOfDay(for: start)
        guard day >= firstDay else { return false }

        if scheduleKind == .range {
            let lastDay = calendar.startOfDay(for: end ?? start)
            return day <= lastDay
        }

        switch repeatRule {
        case .none:
            return calendar.isDate(day, inSameDayAs: firstDay)
        case .daily:
            return true
        case .weekly:
            return calendar.component(.weekday, from: day) == calendar.component(.weekday, from: firstDay)
        case .monthly:
            return calendar.component(.day, from: day) == calendar.component(.day, from: firstDay)
        }
    }

    public func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        if isRecurring {
            return completedOccurrenceKeys.contains(DateKey.string(for: date, calendar: calendar))
        }
        return completedAt != nil
    }

    public var dueDate: Date? {
        scheduleKind == .range ? (end ?? start) : start
    }
}

public struct DeadlineItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var dueDate: Date
    public var includesTime: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date,
        includesTime: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.includesTime = includesTime
        self.createdAt = createdAt
    }

    public func remainingDays(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: start, to: due).day ?? 0
    }
}

public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var weeklyTarget: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, weeklyTarget: Int = 1, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.weeklyTarget = max(1, weeklyTarget)
        self.createdAt = createdAt
    }
}

public struct HabitLog: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var habitID: UUID
    public var timestamp: Date

    public init(id: UUID = UUID(), habitID: UUID, timestamp: Date = Date()) {
        self.id = id
        self.habitID = habitID
        self.timestamp = timestamp
    }
}

public struct AttendanceSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var arrivedAt: Date
    public var leftAt: Date?

    public init(id: UUID = UUID(), arrivedAt: Date = Date(), leftAt: Date? = nil) {
        self.id = id
        self.arrivedAt = arrivedAt
        self.leftAt = leftAt
    }

    public func duration(until now: Date = Date()) -> TimeInterval {
        max(0, (leftAt ?? now).timeIntervalSince(arrivedAt))
    }

    public func exceedsContinuousDuration(
        _ threshold: TimeInterval = 8 * 60 * 60,
        until now: Date = Date()
    ) -> Bool {
        duration(until: now) > threshold
    }

    public func overlap(with interval: DateInterval, now: Date = Date()) -> TimeInterval {
        let sessionEnd = leftAt ?? now
        let start = max(arrivedAt, interval.start)
        let end = min(sessionEnd, interval.end)
        return max(0, end.timeIntervalSince(start))
    }
}

public struct AppData: Codable, Sendable {
    public var tasks: [TodoItem]
    public var deadlines: [DeadlineItem]
    public var habits: [Habit]
    public var habitLogs: [HabitLog]
    public var attendanceSessions: [AttendanceSession]

    public init(
        tasks: [TodoItem] = [],
        deadlines: [DeadlineItem] = [],
        habits: [Habit] = [],
        habitLogs: [HabitLog] = [],
        attendanceSessions: [AttendanceSession] = []
    ) {
        self.tasks = tasks
        self.deadlines = deadlines
        self.habits = habits
        self.habitLogs = habitLogs
        self.attendanceSessions = attendanceSessions
    }
}

public enum DateKey {
    public static func string(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

public enum DateIntervals {
    public static func day(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? day(containing: date, calendar: calendar)
    }

    public static func month(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? day(containing: date, calendar: calendar)
    }
}
