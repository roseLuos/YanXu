import Foundation
import YanXuCore

enum DemoDataFactory {
    static func merging(into existing: AppData, referenceDate: Date, calendar: Calendar) -> AppData {
        var result = existing
        let today = calendar.startOfDay(for: referenceDate)

        func date(_ dayOffset: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        func identifier(_ value: Int) -> UUID {
            UUID(uuidString: String(format: "D3A00000-0000-4000-8000-%012d", value))!
        }

        let demoTasks: [TodoItem] = [
            TodoItem(id: identifier(1001), title: "整理实验结果", notes: "汇总主实验与消融实验数据", scheduleKind: .fixed, start: date(0, 9, 30), reminderEnabled: true, createdAt: date(-5, 9)),
            TodoItem(id: identifier(1002), title: "与导师讨论实验进展", scheduleKind: .fixed, start: date(0, 15), reminderEnabled: true, createdAt: date(-4, 11)),
            TodoItem(id: identifier(1003), title: "修改论文方法章节", notes: "补充模型结构和训练细节", scheduleKind: .day, start: date(0), reminderEnabled: true, createdAt: date(-3, 14)),
            TodoItem(id: identifier(1004), title: "回复合作者邮件", scheduleKind: .day, start: date(0), reminderEnabled: true, createdAt: date(-1, 16)),
            TodoItem(id: identifier(1005), title: "统一论文图表格式", scheduleKind: .range, start: date(0), end: date(2), reminderEnabled: true, createdAt: date(-2, 10)),
            TodoItem(id: identifier(1006), title: "完成代码备份", scheduleKind: .day, start: date(0), reminderEnabled: true, completedAt: date(0, 10, 20), createdAt: date(-2, 9)),
            TodoItem(id: identifier(1007), title: "复现实验结果", notes: "使用最终配置重新运行一次", scheduleKind: .fixed, start: date(1, 10), reminderEnabled: true, createdAt: date(-2, 15)),
            TodoItem(id: identifier(1008), title: "阅读并标注相关论文", scheduleKind: .day, start: date(1), reminderEnabled: true, createdAt: date(-1, 12)),
            TodoItem(id: identifier(1009), title: "整理下周实验计划", scheduleKind: .day, start: date(2), reminderEnabled: true, createdAt: date(-1, 13)),
            TodoItem(id: identifier(1010), title: "课题组周会", scheduleKind: .fixed, start: date(3, 14), repeatRule: .weekly, reminderEnabled: true, createdAt: date(-8, 9)),
            TodoItem(id: identifier(1011), title: "整理审稿意见", scheduleKind: .day, start: date(4), reminderEnabled: true, createdAt: date(-1, 14)),
            TodoItem(id: identifier(1012), title: "与合作者同步论文结构", scheduleKind: .fixed, start: date(5, 16), reminderEnabled: true, createdAt: date(-1, 15)),
            TodoItem(id: identifier(1013), title: "提交计算资源申请", scheduleKind: .day, start: date(6), reminderEnabled: true, createdAt: date(-1, 16)),
            TodoItem(id: identifier(1014), title: "补充实验与误差分析", scheduleKind: .range, start: date(7), end: date(9), reminderEnabled: true, createdAt: date(-1, 17)),
            TodoItem(id: identifier(1015), title: "确认数据集使用许可", scheduleKind: .day, start: date(-1), reminderEnabled: true, createdAt: date(-6, 11)),
            TodoItem(id: identifier(1016), title: "清洗训练数据", scheduleKind: .day, start: date(-4), reminderEnabled: true, completedAt: date(-4, 18), createdAt: date(-7, 10)),
            TodoItem(id: identifier(1017), title: "更新实验日志", scheduleKind: .day, start: date(-3), reminderEnabled: true, completedAt: date(-3, 17, 20), createdAt: date(-5, 9)),
            TodoItem(id: identifier(1018), title: "运行消融实验", scheduleKind: .fixed, start: date(-2, 13, 30), reminderEnabled: true, completedAt: date(-2, 20, 40), createdAt: date(-6, 14)),
            TodoItem(id: identifier(1019), title: "整理参考文献", scheduleKind: .day, start: date(-1), reminderEnabled: true, completedAt: date(-1, 18), createdAt: date(-4, 14)),
            TodoItem(id: identifier(1020), title: "梳理博士论文整体大纲", notes: "暂未安排日期", scheduleKind: .inbox, reminderEnabled: false, createdAt: date(-2, 15)),
            TodoItem(id: identifier(1021), title: "尝试新的文献管理工作流", scheduleKind: .inbox, reminderEnabled: false, createdAt: date(-1, 15))
        ]

        let existingTaskIDs = Set(result.tasks.map(\.id))
        result.tasks.append(contentsOf: demoTasks.filter { !existingTaskIDs.contains($0.id) })

        let demoDeadlines: [DeadlineItem] = [
            DeadlineItem(id: identifier(2001), title: "论文初稿交给导师", dueDate: date(12), includesTime: false, createdAt: date(-4)),
            DeadlineItem(id: identifier(2002), title: "数据集申请截止", dueDate: date(18), includesTime: false, createdAt: date(-3)),
            DeadlineItem(id: identifier(2003), title: "补充实验全部完成", dueDate: date(27), includesTime: false, createdAt: date(-2)),
            DeadlineItem(id: identifier(2004), title: "博士中期考核材料", dueDate: date(45), includesTime: false, createdAt: date(-1))
        ]
        let existingDeadlineIDs = Set(result.deadlines.map(\.id))
        result.deadlines.append(contentsOf: demoDeadlines.filter { !existingDeadlineIDs.contains($0.id) })

        let experimentHabitID = identifier(3001)
        let writingHabitID = identifier(3002)
        let demoHabits = [
            Habit(id: experimentHabitID, name: "整理实验记录", weeklyTarget: 5, createdAt: date(-20)),
            Habit(id: writingHabitID, name: "英文写作", weeklyTarget: 4, createdAt: date(-18))
        ]
        let existingHabitIDs = Set(result.habits.map(\.id))
        result.habits.append(contentsOf: demoHabits.filter { !existingHabitIDs.contains($0.id) })

        let demoHabitLogs = [
            HabitLog(id: identifier(3101), habitID: experimentHabitID, timestamp: date(-4, 18, 10)),
            HabitLog(id: identifier(3102), habitID: experimentHabitID, timestamp: date(-3, 17, 30)),
            HabitLog(id: identifier(3103), habitID: experimentHabitID, timestamp: date(-2, 20, 50)),
            HabitLog(id: identifier(3104), habitID: experimentHabitID, timestamp: date(-1, 18, 15)),
            HabitLog(id: identifier(3201), habitID: writingHabitID, timestamp: date(-3, 10, 20)),
            HabitLog(id: identifier(3202), habitID: writingHabitID, timestamp: date(-1, 15, 40))
        ]
        let existingHabitLogIDs = Set(result.habitLogs.map(\.id))
        result.habitLogs.append(contentsOf: demoHabitLogs.filter { !existingHabitLogIDs.contains($0.id) })

        var demoSessions: [AttendanceSession] = []
        for (index, dayOffset) in [-4, -3, -2, -1].enumerated() {
            demoSessions.append(AttendanceSession(
                id: identifier(4001 + index * 2),
                arrivedAt: date(dayOffset, 8, 50 + index * 3),
                leftAt: date(dayOffset, 12, 5 + index * 2)
            ))
            demoSessions.append(AttendanceSession(
                id: identifier(4002 + index * 2),
                arrivedAt: date(dayOffset, 13, 25 - index * 2),
                leftAt: date(dayOffset, 18, 10 + index * 8)
            ))
        }
        demoSessions.append(AttendanceSession(
            id: identifier(4010),
            arrivedAt: date(0, 8, 55),
            leftAt: date(0, 12, 8)
        ))

        let historicalAttendance: [(day: Int, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int)] = [
            (-28, 9, 10, 17, 20), (-27, 9, 0, 18, 10), (-25, 10, 5, 16, 40),
            (-23, 8, 55, 17, 45), (-21, 9, 20, 18, 5), (-20, 9, 5, 16, 30),
            (-18, 10, 0, 19, 10), (-16, 9, 15, 17, 30), (-14, 8, 50, 18, 20),
            (-13, 9, 30, 15, 40), (-12, 9, 5, 19, 0), (-10, 10, 10, 17, 50),
            (-8, 9, 0, 18, 15), (-7, 8, 45, 17, 35), (-6, 9, 25, 16, 55)
        ]
        for (index, item) in historicalAttendance.enumerated() {
            demoSessions.append(AttendanceSession(
                id: identifier(4100 + index),
                arrivedAt: date(item.day, item.startHour, item.startMinute),
                leftAt: date(item.day, item.endHour, item.endMinute)
            ))
        }
        let existingSessionIDs = Set(result.attendanceSessions.map(\.id))
        result.attendanceSessions.append(contentsOf: demoSessions.filter { !existingSessionIDs.contains($0.id) })

        return result
    }
}
