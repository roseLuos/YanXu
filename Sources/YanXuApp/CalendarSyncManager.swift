import AppKit
import Combine
import EventKit
import Foundation
import YanXuCore

enum CalendarSyncState: Equatable {
    case disabled
    case syncing
    case ready(String)
    case failed(String)
}

@MainActor
final class CalendarSyncManager: ObservableObject {
    static let shared = CalendarSyncManager()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var state: CalendarSyncState

    private enum DefaultsKey {
        static let enabled = "yanxu.calendar-sync.enabled"
        static let calendarIdentifier = "yanxu.calendar-sync.calendar-identifier"
        static let eventIdentifiers = "yanxu.calendar-sync.event-identifiers"
    }

    private enum SyncError: LocalizedError {
        case permissionDenied
        case iCloudCalendarUnavailable
        case calendarUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "没有日历访问权限，请在系统设置的“隐私与安全性－日历”中允许研序访问。"
            case .iCloudCalendarUnavailable:
                return "没有找到 iCloud 日历。请先在系统设置中登录 iCloud，并开启“日历”。"
            case .calendarUnavailable:
                return "暂时无法创建或读取“研序”日历。"
            }
        }
    }

    private struct MirrorItem {
        let key: String
        let title: String
        let notes: String
        let startDate: Date
        let endDate: Date
        let isAllDay: Bool
        let recurrenceFrequency: EKRecurrenceFrequency?
        let availability: EKEventAvailability
    }

    private let eventStore = EKEventStore()
    private let defaults = UserDefaults.standard
    private var latestData = AppData()
    private var pendingSync: Task<Void, Never>?

    private init() {
        let enabled = defaults.bool(forKey: DefaultsKey.enabled)
        self.isEnabled = enabled
        self.state = enabled ? .syncing : .disabled
    }

    var statusText: String {
        switch state {
        case .disabled:
            return "尚未开启"
        case .syncing:
            return "正在同步…"
        case .ready(let calendarName):
            return "已同步到 iCloud 日历“\(calendarName)”"
        case .failed(let message):
            return message
        }
    }

    func appDidLoad(data: AppData) {
        latestData = data
        guard isEnabled else { return }

        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            await self?.synchronizeLatest()
        }
    }

    func dataDidChange(_ data: AppData) {
        latestData = data
        guard isEnabled else { return }
        scheduleAutomaticSync(after: 450_000_000)
    }

    func enable(data: AppData) async {
        latestData = data
        pendingSync?.cancel()
        state = .syncing

        do {
            guard try await requestAccessIfNeeded() else {
                throw SyncError.permissionDenied
            }

            eventStore.reset()
            let calendar = try resolveOrCreateCalendar()
            defaults.set(calendar.calendarIdentifier, forKey: DefaultsKey.calendarIdentifier)
            defaults.set(true, forKey: DefaultsKey.enabled)
            isEnabled = true
            try apply(data: latestData, to: calendar)
            state = .ready(calendar.title)
        } catch {
            defaults.set(false, forKey: DefaultsKey.enabled)
            isEnabled = false
            state = .failed(error.localizedDescription)
        }
    }

    func synchronizeNow() async {
        guard isEnabled else { return }
        pendingSync?.cancel()
        await synchronizeLatest()
    }

    func disable() {
        pendingSync?.cancel()
        defaults.set(false, forKey: DefaultsKey.enabled)
        isEnabled = false
        state = .disabled
    }

    private func scheduleAutomaticSync(after delay: UInt64) {
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.synchronizeLatest()
        }
    }

    private func synchronizeLatest() async {
        guard isEnabled else { return }
        state = .syncing

        var finalError: Error?
        let retryDelays: [UInt64] = [700_000_000, 1_800_000_000]

        for attempt in 0...retryDelays.count {
            guard !Task.isCancelled else { return }

            do {
                guard try await requestAccessIfNeeded() else {
                    throw SyncError.permissionDenied
                }

                // EventKit may still hold a stale source/calendar cache immediately
                // after launch even though system permission is already enabled.
                eventStore.reset()
                let calendar = try resolveOrCreateCalendar()
                try apply(data: latestData, to: calendar)
                state = .ready(calendar.title)
                return
            } catch let error as SyncError {
                finalError = error
                if case .permissionDenied = error {
                    state = .failed(error.localizedDescription)
                    return
                }
            } catch {
                finalError = error
            }

            guard attempt < retryDelays.count else { break }
            do {
                try await Task.sleep(nanoseconds: retryDelays[attempt])
            } catch {
                return
            }
        }

        state = .failed(finalError?.localizedDescription ?? "日历同步失败，请稍后重试。")
    }

    private func requestAccessIfNeeded() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined, .writeOnly:
            let granted = try await eventStore.requestFullAccessToEvents()
            if granted { eventStore.reset() }
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func resolveOrCreateCalendar() throws -> EKCalendar {
        if let identifier = defaults.string(forKey: DefaultsKey.calendarIdentifier),
           let calendar = eventStore.calendar(withIdentifier: identifier),
           calendar.allowsContentModifications {
            return calendar
        }

        guard let iCloudSource = eventStore.sources.first(where: {
            $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("iCloud")
        }) else {
            throw SyncError.iCloudCalendarUnavailable
        }

        if let existing = eventStore.calendars(for: .event).first(where: {
            $0.title == "研序" && $0.source.sourceIdentifier == iCloudSource.sourceIdentifier
        }) {
            defaults.set(existing.calendarIdentifier, forKey: DefaultsKey.calendarIdentifier)
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "研序"
        calendar.source = iCloudSource
        calendar.cgColor = NSColor(calibratedRed: 0.31, green: 0.47, blue: 0.96, alpha: 1).cgColor
        try eventStore.saveCalendar(calendar, commit: true)

        guard !calendar.calendarIdentifier.isEmpty else {
            throw SyncError.calendarUnavailable
        }
        defaults.set(calendar.calendarIdentifier, forKey: DefaultsKey.calendarIdentifier)
        return calendar
    }

    private func apply(data: AppData, to calendar: EKCalendar) throws {
        let desiredItems = makeMirrorItems(from: data)
        var identifiers = storedEventIdentifiers

        for (key, item) in desiredItems {
            let existingEvent = identifiers[key].flatMap {
                eventStore.event(withIdentifier: $0)
            }

            if let existingEvent, event(existingEvent, matches: item) {
                identifiers[key] = existingEvent.eventIdentifier
                continue
            }

            let replacement = EKEvent(eventStore: eventStore)
            configure(replacement, with: item, calendar: calendar)
            try eventStore.save(replacement, span: .thisEvent, commit: true)

            if let existingEvent {
                try remove(existingEvent)
            }
            identifiers[key] = replacement.eventIdentifier
        }

        let staleKeys = Set(identifiers.keys).subtracting(desiredItems.keys)
        for key in staleKeys {
            if let identifier = identifiers[key],
               let event = eventStore.event(withIdentifier: identifier) {
                let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
                try eventStore.remove(event, span: span, commit: true)
            }
            identifiers.removeValue(forKey: key)
        }

        storedEventIdentifiers = identifiers
    }

    private func remove(_ event: EKEvent) throws {
        let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
        try eventStore.remove(event, span: span, commit: true)
    }

    private func configure(_ event: EKEvent, with item: MirrorItem, calendar: EKCalendar) {
        if event.calendar?.calendarIdentifier != calendar.calendarIdentifier {
            event.calendar = calendar
        }
        event.title = item.title
        event.notes = item.notes
        event.isAllDay = item.isAllDay
        event.startDate = item.startDate
        event.endDate = item.endDate
        event.availability = item.availability
        event.alarms = nil
        event.recurrenceRules = item.recurrenceFrequency.map {
            [EKRecurrenceRule(recurrenceWith: $0, interval: 1, end: nil)]
        }
    }

    private func event(_ event: EKEvent, matches item: MirrorItem) -> Bool {
        let currentFrequency = event.recurrenceRules?.first?.frequency
        return event.title == item.title
            && event.isAllDay == item.isAllDay
            && abs(event.startDate.timeIntervalSince(item.startDate)) < 1
            && abs(event.endDate.timeIntervalSince(item.endDate)) < 1
            && currentFrequency == item.recurrenceFrequency
            && event.notes == item.notes
            && event.availability == item.availability
    }

    private func makeMirrorItems(from data: AppData) -> [String: MirrorItem] {
        var items: [String: MirrorItem] = [:]
        let calendar = Calendar.current

        for task in data.tasks {
            guard task.scheduleKind != .inbox, let start = task.start else { continue }

            let key = "task-\(task.id.uuidString)"
            let isAllDay = task.scheduleKind != .fixed
            let startDate = isAllDay ? calendar.startOfDay(for: start) : start
            let endDate: Date

            if task.scheduleKind == .range {
                let finalDay = calendar.startOfDay(for: task.end ?? start)
                endDate = inclusiveEndOfDay(finalDay, calendar: calendar)
            } else if isAllDay {
                endDate = inclusiveEndOfDay(startDate, calendar: calendar)
            } else {
                endDate = max(task.end ?? start.addingTimeInterval(3_600), start.addingTimeInterval(60))
            }

            let completedPrefix = !task.isRecurring && task.completedAt != nil ? "✓ " : ""
            let recurrence: EKRecurrenceFrequency?
            if task.scheduleKind == .range {
                recurrence = nil
            } else {
                switch task.repeatRule {
                case .none: recurrence = nil
                case .daily: recurrence = .daily
                case .weekly: recurrence = .weekly
                case .monthly: recurrence = .monthly
                }
            }

            let noteBody = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = noteBody.isEmpty
                ? "由研序管理，请在 Mac 版研序中修改。"
                : "\(noteBody)\n\n由研序管理，请在 Mac 版研序中修改。"

            items[key] = MirrorItem(
                key: key,
                title: completedPrefix + task.title,
                notes: note,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                recurrenceFrequency: recurrence,
                availability: task.scheduleKind == .fixed ? .busy : .free
            )
        }

        for deadline in data.deadlines {
            let key = "deadline-\(deadline.id.uuidString)"
            let startDate = deadline.includesTime ? deadline.dueDate : calendar.startOfDay(for: deadline.dueDate)
            let endDate = deadline.includesTime
                ? deadline.dueDate.addingTimeInterval(1_800)
                : inclusiveEndOfDay(startDate, calendar: calendar)

            items[key] = MirrorItem(
                key: key,
                title: "DDL · \(deadline.title)",
                notes: "由研序管理，请在 Mac 版研序中修改。",
                startDate: startDate,
                endDate: endDate,
                isAllDay: !deadline.includesTime,
                recurrenceFrequency: nil,
                availability: .free
            )
        }

        return items
    }

    private func inclusiveEndOfDay(_ day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return nextDay.addingTimeInterval(-1)
    }

    private var storedEventIdentifiers: [String: String] {
        get {
            defaults.dictionary(forKey: DefaultsKey.eventIdentifiers) as? [String: String] ?? [:]
        }
        set {
            defaults.set(newValue, forKey: DefaultsKey.eventIdentifiers)
        }
    }

}
