import Foundation

public struct QuickTaskParseResult: Sendable {
    public let title: String
    public let scheduleKind: TaskScheduleKind
    public let start: Date?
    public let recognizedDate: Bool
    public let recognizedTime: Bool

    public init(
        title: String,
        scheduleKind: TaskScheduleKind,
        start: Date?,
        recognizedDate: Bool,
        recognizedTime: Bool
    ) {
        self.title = title
        self.scheduleKind = scheduleKind
        self.start = start
        self.recognizedDate = recognizedDate
        self.recognizedTime = recognizedTime
    }
}

public enum QuickTaskParser {
    private struct DateExtraction {
        let date: Date
        let range: NSRange
    }

    private struct TimeExtraction {
        let hour: Int
        let minute: Int
        let range: NSRange
    }

    public static func parse(
        _ input: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> QuickTaskParseResult {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateExtraction = extractDate(from: trimmedInput, now: now, calendar: calendar)
        let timeExtraction = extractTime(from: trimmedInput)

        if dateExtraction == nil && timeExtraction == nil {
            return QuickTaskParseResult(
                title: trimmedInput,
                scheduleKind: .inbox,
                start: nil,
                recognizedDate: false,
                recognizedTime: timeExtraction != nil
            )
        }

        let targetDay = calendar.startOfDay(for: dateExtraction?.date ?? now)

        let start: Date
        if let timeExtraction {
            start = calendar.date(
                bySettingHour: timeExtraction.hour,
                minute: timeExtraction.minute,
                second: 0,
                of: targetDay
            ) ?? targetDay
        } else {
            start = targetDay
        }

        let ranges = [dateExtraction?.range, timeExtraction?.range].compactMap { $0 }
        let cleanedTitle = removing(ranges: ranges, from: trimmedInput)

        return QuickTaskParseResult(
            title: cleanedTitle.isEmpty ? trimmedInput : cleanedTitle,
            scheduleKind: timeExtraction == nil ? .day : .fixed,
            start: start,
            recognizedDate: dateExtraction != nil,
            recognizedTime: timeExtraction != nil
        )
    }

    private static func extractDate(from input: String, now: Date, calendar: Calendar) -> DateExtraction? {
        if let match = firstMatch("大后天|后天|明天|明日|今天|今日", in: input),
           let phrase = group(0, in: input, match: match) {
            let offset: Int
            switch phrase {
            case "大后天": offset = 3
            case "后天": offset = 2
            case "明天", "明日": offset = 1
            default: offset = 0
            }
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
            return DateExtraction(date: day, range: match.range)
        }

        if let match = firstMatch("(?:(下下|下|本|这)?(?:周|星期|礼拜))([一二三四五六日天])", in: input),
           let weekdayCharacter = group(2, in: input, match: match),
           let targetWeekday = weekdayNumber(for: weekdayCharacter) {
            let prefix = group(1, in: input, match: match)
            let today = calendar.startOfDay(for: now)
            let target: Date

            if let prefix {
                let weekOffset = prefix == "下下" ? 2 : (prefix == "下" ? 1 : 0)
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
                let weekdayOffset = targetWeekday == 1 ? 6 : targetWeekday - 2
                let days = weekOffset * 7 + weekdayOffset
                target = calendar.date(byAdding: .day, value: days, to: weekStart) ?? today
            } else {
                let currentWeekday = calendar.component(.weekday, from: today)
                let daysAhead = (targetWeekday - currentWeekday + 7) % 7
                target = calendar.date(byAdding: .day, value: daysAhead, to: today) ?? today
            }
            return DateExtraction(date: target, range: match.range)
        }

        if let match = firstMatch("(?:(\\d{4})年)?(\\d{1,2})月(\\d{1,2})[日号]?", in: input),
           let monthText = group(2, in: input, match: match),
           let dayText = group(3, in: input, match: match),
           let month = Int(monthText),
           let day = Int(dayText),
           let date = dateForMonthDay(
                yearText: group(1, in: input, match: match),
                month: month,
                day: day,
                now: now,
                calendar: calendar
           ) {
            return DateExtraction(date: date, range: match.range)
        }

        if let match = firstMatch("(?<!\\d)(\\d{1,2})/(\\d{1,2})(?!\\d)", in: input),
           let monthText = group(1, in: input, match: match),
           let dayText = group(2, in: input, match: match),
           let month = Int(monthText),
           let day = Int(dayText),
           let date = dateForMonthDay(yearText: nil, month: month, day: day, now: now, calendar: calendar) {
            return DateExtraction(date: date, range: match.range)
        }

        return nil
    }

    private static func extractTime(from input: String) -> TimeExtraction? {
        let chinesePattern = "(?:(凌晨|早上|上午|中午|下午|傍晚|晚上|今晚))?\\s*([01]?\\d|2[0-3])\\s*(?:点|时)(?:\\s*(半|([0-5]?\\d)\\s*分?))?"
        if let match = firstMatch(chinesePattern, in: input),
           let hourText = group(2, in: input, match: match),
           var hour = Int(hourText) {
            let period = group(1, in: input, match: match)
            let half = group(3, in: input, match: match) == "半"
            let minute = half ? 30 : (group(4, in: input, match: match).flatMap(Int.init) ?? 0)

            switch period {
            case "凌晨", "早上", "上午":
                if hour == 12 { hour = 0 }
            case "中午":
                if hour < 11 { hour += 12 }
            case "下午", "傍晚", "晚上", "今晚":
                if hour < 12 { hour += 12 }
            default:
                break
            }

            return TimeExtraction(hour: hour, minute: minute, range: match.range)
        }

        if let match = firstMatch("(?<!\\d)([01]?\\d|2[0-3]):([0-5]\\d)(?!\\d)", in: input),
           let hourText = group(1, in: input, match: match),
           let minuteText = group(2, in: input, match: match),
           let hour = Int(hourText),
           let minute = Int(minuteText) {
            return TimeExtraction(hour: hour, minute: minute, range: match.range)
        }

        return nil
    }

    private static func dateForMonthDay(
        yearText: String?,
        month: Int,
        day: Int,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let explicitYear = yearText.flatMap(Int.init)
        var year = explicitYear ?? calendar.component(.year, from: now)

        func makeDate(year: Int) -> Date? {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  calendar.component(.year, from: date) == year,
                  calendar.component(.month, from: date) == month,
                  calendar.component(.day, from: date) == day else { return nil }
            return calendar.startOfDay(for: date)
        }

        guard var date = makeDate(year: year) else { return nil }
        if explicitYear == nil && date < calendar.startOfDay(for: now) {
            year += 1
            guard let nextYearDate = makeDate(year: year) else { return nil }
            date = nextYearDate
        }
        return date
    }

    private static func weekdayNumber(for character: String) -> Int? {
        switch character {
        case "一": 2
        case "二": 3
        case "三": 4
        case "四": 5
        case "五": 6
        case "六": 7
        case "日", "天": 1
        default: nil
        }
    }

    private static func firstMatch(_ pattern: String, in input: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        return expression.firstMatch(in: input, range: NSRange(input.startIndex..., in: input))
    }

    private static func group(_ index: Int, in input: String, match: NSTextCheckingResult) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: input) else { return nil }
        return String(input[swiftRange])
    }

    private static func removing(ranges: [NSRange], from input: String) -> String {
        let mutable = NSMutableString(string: input)
        for range in ranges.sorted(by: { $0.location > $1.location }) where NSMaxRange(range) <= mutable.length {
            mutable.replaceCharacters(in: range, with: " ")
        }

        return (mutable as String)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \\t\\n,，。；;：:、-"))
    }
}
