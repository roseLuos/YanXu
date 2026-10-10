import Foundation

public struct LANSyncMessage: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case hello
        case sync
        case widgetSnapshot
        case snapshot
        case rejected
    }

    public var kind: Kind
    public var pairingCode: String
    public var data: AppData?
    public var message: String?

    public init(kind: Kind, pairingCode: String, data: AppData? = nil, message: String? = nil) {
        self.kind = kind
        self.pairingCode = pairingCode
        self.data = data
        self.message = message
    }
}

public enum LANSyncMerge {
    /// 同一用户通常只在一台设备编辑。合并时优先保留完整记录，并让完成状态、打卡
    /// 与科研时段以并集方式汇合，避免离线期间的记录被另一台设备覆盖。
    public static func merge(_ local: AppData, _ remote: AppData) -> AppData {
        AppData(
            tasks: merge(local.tasks, remote.tasks, id: \.id, choose: preferredTask),
            deadlines: merge(local.deadlines, remote.deadlines, id: \.id, choose: { $0.createdAt >= $1.createdAt ? $0 : $1 }),
            habits: merge(local.habits, remote.habits, id: \.id, choose: { $0.createdAt >= $1.createdAt ? $0 : $1 }),
            habitLogs: merge(local.habitLogs, remote.habitLogs, id: \.id, choose: { $0.timestamp >= $1.timestamp ? $0 : $1 }),
            attendanceSessions: merge(local.attendanceSessions, remote.attendanceSessions, id: \.id, choose: preferredAttendance),
            ignoredOverdueOccurrenceKeys: local.ignoredOverdueOccurrenceKeys.union(remote.ignoredOverdueOccurrenceKeys)
        )
    }

    private static func merge<Value, ID: Hashable>(
        _ lhs: [Value],
        _ rhs: [Value],
        id: (Value) -> ID,
        choose: (Value, Value) -> Value
    ) -> [Value] {
        var result: [ID: Value] = [:]
        for value in lhs + rhs {
            let key = id(value)
            result[key] = result[key].map { choose($0, value) } ?? value
        }
        return Array(result.values)
    }

    private static func preferredTask(_ lhs: TodoItem, _ rhs: TodoItem) -> TodoItem {
        var chosen = lhs.createdAt >= rhs.createdAt ? lhs : rhs
        let other = lhs.createdAt >= rhs.createdAt ? rhs : lhs
        if chosen.completedAt == nil { chosen.completedAt = other.completedAt }
        chosen.completedOccurrenceKeys.formUnion(other.completedOccurrenceKeys)
        return chosen
    }

    private static func preferredAttendance(_ lhs: AttendanceSession, _ rhs: AttendanceSession) -> AttendanceSession {
        guard lhs.leftAt != nil || rhs.leftAt != nil else { return lhs.arrivedAt <= rhs.arrivedAt ? lhs : rhs }
        return (lhs.leftAt ?? .distantPast) >= (rhs.leftAt ?? .distantPast) ? lhs : rhs
    }
}
