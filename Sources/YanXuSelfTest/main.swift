import Foundation
import YanXuCore

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
calendar.firstWeekday = 2

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("自检失败：\(message)") }
}

var flexibleTask = TodoItem(
    title: "信息采集",
    scheduleKind: .range,
    start: date(2026, 9, 5),
    end: date(2026, 9, 6)
)
check(flexibleTask.occurs(on: date(2026, 9, 5), calendar: calendar), "区间任务应在开始日显示")
check(flexibleTask.occurs(on: date(2026, 9, 6), calendar: calendar), "区间任务应在结束日显示")
check(!flexibleTask.occurs(on: date(2026, 9, 7), calendar: calendar), "区间结束后不应继续显示")
flexibleTask.completedAt = date(2026, 9, 5, 16)
check(flexibleTask.isCompleted(on: date(2026, 9, 6), calendar: calendar), "区间任务只需完成一次")

let meeting = TodoItem(
    title: "开组会",
    scheduleKind: .fixed,
    start: date(2026, 9, 4, 14),
    repeatRule: .weekly
)
check(meeting.occurs(on: date(2026, 9, 11), calendar: calendar), "每周重复应出现在同一星期")
check(!meeting.occurs(on: date(2026, 9, 12), calendar: calendar), "每周重复不应出现在其他星期")

let morning = AttendanceSession(arrivedAt: date(2026, 9, 4, 9), leftAt: date(2026, 9, 4, 12))
let afternoon = AttendanceSession(arrivedAt: date(2026, 9, 4, 13), leftAt: date(2026, 9, 4, 18))
check(abs(morning.duration() + afternoon.duration() - 8 * 60 * 60) < 0.1, "多段打卡必须排除中间休息")

let deadline = DeadlineItem(title: "投稿", dueDate: date(2026, 9, 16))
check(deadline.remainingDays(from: date(2026, 9, 4), calendar: calendar) == 12, "DDL 应按自然日计算")

let tomorrowTask = QuickTaskParser.parse("明天晚上开会", now: date(2026, 9, 4, 10), calendar: calendar)
check(tomorrowTask.title == "晚上开会", "自然语言日期应从任务标题中移除")
check(tomorrowTask.scheduleKind == .day, "没有明确钟点时应创建全天任务")
check(tomorrowTask.start.map { calendar.isDate($0, inSameDayAs: date(2026, 9, 5)) } == true, "明天应解析为下一自然日")

let timedTask = QuickTaskParser.parse("下周五下午2点开组会", now: date(2026, 9, 4, 10), calendar: calendar)
check(timedTask.title == "开组会", "日期和具体时间应从任务标题中移除")
check(timedTask.scheduleKind == .fixed, "明确钟点应创建具体时间任务")
check(timedTask.start == Optional(date(2026, 9, 11, 14)), "下周五下午2点应正确解析")

let datedTask = QuickTaskParser.parse("9月10日提交论文", now: date(2026, 9, 4), calendar: calendar)
check(datedTask.title == "提交论文", "月日表达应从任务标题中移除")
check(datedTask.start.map { calendar.isDate($0, inSameDayAs: date(2026, 9, 10)) } == true, "月日表达应正确解析")

let inboxTask = QuickTaskParser.parse("整理实验数据", now: date(2026, 9, 4, 10), calendar: calendar)
check(inboxTask.scheduleKind == .inbox, "未指定日期时应进入待安排")
check(inboxTask.start == nil, "待安排任务不应带有当天日期")

let undatedTimedTask = QuickTaskParser.parse("下午2点整理报销材料", now: date(2026, 9, 4, 10), calendar: calendar)
check(undatedTimedTask.scheduleKind == .fixed, "只指定具体时间时应默认安排在今天")
check(undatedTimedTask.start == Optional(date(2026, 9, 4, 14)), "下午2点应解析为今天 14:00")
check(undatedTimedTask.title == "整理报销材料", "具体时间应从已安排任务的标题中移除")

let todayTask = QuickTaskParser.parse("今天整理实验数据", now: date(2026, 9, 4, 10), calendar: calendar)
check(todayTask.scheduleKind == .day, "明确指定今天时才应进入今天")
check(todayTask.start.map { calendar.isDate($0, inSameDayAs: date(2026, 9, 4)) } == true, "今天应解析为当前自然日")

let ccfCalendar = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:ICLR 2027 截稿日期 [Paper submission]
DTSTART;TZID="UTC-12:00":20260925T235959
UID:iclr27-paper
URL:https://iclr.cc/Conferences/2027
END:VEVENT
END:VCALENDAR
"""
let ccfDeadlines = CCFDeadlineParser.parse(ccfCalendar)
check(ccfDeadlines.count == 1, "CCFDDL iCalendar 应解析为一条截止日期")
check(ccfDeadlines[0].title == "ICLR 2027 截稿日期", "CCFDDL 标题应移除冗长备注")
let localDeadline = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 19, minute: 59, second: 59))!
check(ccfDeadlines[0].dueDate == localDeadline, "CCFDDL AoE 时间应正确换算为本地绝对时间")

print("研序核心逻辑自检通过：任务日期、中文快速输入、重复、多段打卡、DDL 与 CCFDDL 解析均正常。")
