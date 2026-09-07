import Foundation

public struct WidgetTaskSummary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let date: Date
    public let detail: String?

    public init(id: String, title: String, date: Date, detail: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.detail = detail
    }
}

public struct WidgetDeadlineSummary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let dueDate: Date
    public let source: String?

    public init(id: String, title: String, dueDate: Date, source: String? = nil) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.source = source
    }
}

public struct YanXuWidgetSnapshot: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let todayTasks: [WidgetTaskSummary]
    public let weekTasks: [WidgetTaskSummary]
    public let deadlines: [WidgetDeadlineSummary]

    public init(
        generatedAt: Date = Date(),
        todayTasks: [WidgetTaskSummary],
        weekTasks: [WidgetTaskSummary],
        deadlines: [WidgetDeadlineSummary]
    ) {
        self.generatedAt = generatedAt
        self.todayTasks = todayTasks
        self.weekTasks = weekTasks
        self.deadlines = deadlines
    }

    public static let preview = YanXuWidgetSnapshot(
        todayTasks: [
            WidgetTaskSummary(id: "preview-1", title: "整理实验结果", date: Date(), detail: "09:30"),
            WidgetTaskSummary(id: "preview-2", title: "修改论文方法章节", date: Date()),
            WidgetTaskSummary(id: "preview-3", title: "与导师讨论实验进展", date: Date(), detail: "15:00")
        ],
        weekTasks: [
            WidgetTaskSummary(id: "preview-week-1", title: "课题组周会", date: Date(), detail: "周五 14:00"),
            WidgetTaskSummary(id: "preview-week-2", title: "完成消融实验", date: Date(), detail: "周六"),
            WidgetTaskSummary(id: "preview-week-3", title: "整理审稿意见", date: Date(), detail: "周日")
        ],
        deadlines: [
            WidgetDeadlineSummary(id: "preview-ddl-1", title: "论文初稿交给导师", dueDate: Date().addingTimeInterval(12 * 86_400)),
            WidgetDeadlineSummary(id: "preview-ddl-2", title: "ICLR 2027 摘要截稿", dueDate: Date().addingTimeInterval(15 * 86_400), source: "CCF A · AI")
        ]
    )
}

public enum YanXuWidgetSnapshotStore {
    public static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("YanXu", isDirectory: true)
            .appendingPathComponent("widget-snapshot.json")
    }

    public static func load() -> YanXuWidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(YanXuWidgetSnapshot.self, from: data)
    }

    public static func save(_ snapshot: YanXuWidgetSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
