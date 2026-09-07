import Foundation

public struct CCFDeadline: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let dueDate: Date
    public let conferenceURL: URL?

    public init(id: String, title: String, dueDate: Date, conferenceURL: URL?) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.conferenceURL = conferenceURL
    }
}

public enum CCFDeadlineParser {
    public static func parse(_ data: Data) -> [CCFDeadline] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return parse(text)
    }

    public static func parse(_ text: String) -> [CCFDeadline] {
        let lines = unfoldedLines(text)
        var events: [CCFDeadline] = []
        var event: EventFields?

        for line in lines {
            if line == "BEGIN:VEVENT" {
                event = EventFields()
                continue
            }
            if line == "END:VEVENT" {
                if let event, let deadline = makeDeadline(from: event) {
                    events.append(deadline)
                }
                event = nil
                continue
            }
            guard event != nil,
                  let separator = propertySeparator(in: line) else { continue }

            let rawName = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            let name = rawName.split(separator: ";", maxSplits: 1).first.map(String.init) ?? rawName

            switch name {
            case "SUMMARY":
                event?.summary = unescape(value)
            case "UID":
                event?.uid = value
            case "URL":
                event?.url = unescape(value)
            case "DTSTART":
                event?.dateValue = value
                event?.timeZoneID = parameter(named: "TZID", in: rawName)
            default:
                break
            }
        }

        var seen = Set<String>()
        return events
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private struct EventFields {
        var summary: String?
        var uid: String?
        var url: String?
        var dateValue: String?
        var timeZoneID: String?
    }

    private static func makeDeadline(from event: EventFields) -> CCFDeadline? {
        guard let rawTitle = event.summary,
              let value = event.dateValue,
              let dueDate = parseDate(value, timeZoneID: event.timeZoneID) else { return nil }

        let title = rawTitle
            .components(separatedBy: " [")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? rawTitle
        let id = event.uid?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "\(title)-\(dueDate.timeIntervalSince1970)"
        return CCFDeadline(
            id: id,
            title: title,
            dueDate: dueDate,
            conferenceURL: event.url.flatMap(URL.init(string:))
        )
    }

    private static func unfoldedLines(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var result: [String] = []

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !result.isEmpty {
                result[result.count - 1] += String(line.dropFirst())
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func parameter(named name: String, in rawName: String) -> String? {
        for component in rawName.split(separator: ";").dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2, pair[0] == name else { continue }
            return pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }

    private static func propertySeparator(in line: String) -> String.Index? {
        var isInsideQuotes = false
        for index in line.indices {
            let character = line[index]
            if character == "\"" {
                isInsideQuotes.toggle()
            } else if character == ":", !isInsideQuotes {
                return index
            }
        }
        return nil
    }

    private static func parseDate(_ value: String, timeZoneID: String?) -> Date? {
        var dateValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUTC = dateValue.hasSuffix("Z")
        if isUTC { dateValue.removeLast() }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateValue.count == 8 ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss"
        formatter.timeZone = isUTC ? TimeZone(secondsFromGMT: 0) : timeZone(from: timeZoneID)
        return formatter.date(from: dateValue)
    }

    private static func timeZone(from identifier: String?) -> TimeZone {
        guard let identifier else { return TimeZone(secondsFromGMT: 0)! }
        if let zone = TimeZone(identifier: identifier) { return zone }

        let normalized = identifier
            .replacingOccurrences(of: "UTC", with: "")
            .replacingOccurrences(of: ":", with: "")
        guard let sign = normalized.first, sign == "+" || sign == "-" else {
            return TimeZone(secondsFromGMT: 0)!
        }

        let digits = String(normalized.dropFirst())
        let hours = Int(digits.prefix(2)) ?? 0
        let minutes = Int(digits.dropFirst(2).prefix(2)) ?? 0
        let multiplier = sign == "-" ? -1 : 1
        return TimeZone(secondsFromGMT: multiplier * (hours * 3_600 + minutes * 60))
            ?? TimeZone(secondsFromGMT: 0)!
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
