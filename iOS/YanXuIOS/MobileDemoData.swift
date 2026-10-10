import Foundation

enum MobileDemoData {
    static func merging(into data: AppData, now: Date, calendar: Calendar) -> AppData {
        guard data.tasks.isEmpty, data.habits.isEmpty, data.deadlines.isEmpty else { return data }

        let today = calendar.startOfDay(for: now)

        func day(_ offset: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        }

        func fixed(_ title: String, _ offset: Int, _ hour: Int, _ minute: Int = 0, done: Bool = false) -> TodoItem {
            TodoItem(
                title: title,
                scheduleKind: .fixed,
                start: day(offset, hour, minute),
                completedAt: done ? day(offset, min(hour + 1, 23), minute) : nil,
                createdAt: day(offset - 4, 10)
            )
        }

        func planned(_ title: String, _ offset: Int, done: Bool = false) -> TodoItem {
            TodoItem(
                title: title,
                scheduleKind: .day,
                start: day(offset),
                completedAt: done ? day(offset, 18) : nil,
                createdAt: day(offset - 5, 9)
            )
        }

        let deepReading = Habit(name: "精读论文", weeklyTarget: 4, createdAt: day(-52))
        let researchJournal = Habit(name: "写研究日志", weeklyTarget: 5, createdAt: day(-47))
        let codeReview = Habit(name: "代码复盘", weeklyTarget: 3, createdAt: day(-41))
        let academicListening = Habit(name: "学术英语听力", weeklyTarget: 4, createdAt: day(-36))

        let tasks: [TodoItem] = [
            // 本周已完成工作：围绕模型可靠性、训练效率和实验工程展开。
            fixed("导出数据漂移诊断报告", -6, 9, done: true),
            fixed("重跑低照度样本评测", -6, 14, done: true),
            planned("整理数据集版本变更记录", -6, done: true),
            fixed("修复数据加载内存峰值", -5, 9, 30, done: true),
            fixed("参加学院博士生午餐会", -5, 12, done: true),
            planned("标注失败案例归因", -5, done: true),
            fixed("汇总跨域泛化结果", -4, 10, done: true),
            fixed("为新生做代码环境答疑", -4, 16, done: true),
            planned("更新服务器排队策略", -4, done: true),
            fixed("撰写模型鲁棒性分析", -3, 9, done: true),
            fixed("参加开题预演", -3, 15, done: true),
            planned("预约下周 GPU 机时", -3, done: true),
            fixed("对比测试集去重结果", -2, 10, done: true),
            planned("制作组会演示动画", -2, done: true),
            fixed("合并合作者实验分支", -1, 11, done: true),
            planned("通读第二轮审稿意见", -1, done: true),
            planned("整理参考文献 BibTeX", -1, done: true),

            // 今天：全天任务、定时任务和跨日任务混合，方便首页截图。
            fixed("核对本月算力账单", 0, 8, 50, done: true),
            planned("整理本周科研周报", 0, done: true),
            planned("清洗开放集测试样本", 0),
            fixed("检查 Docker 镜像依赖", 0, 10, 30),
            fixed("远程参加领域研讨会", 0, 14, 0),
            planned("设计下周实验矩阵", 0),
            fixed("给导师发送周总结", 0, 20, 30),
            TodoItem(
                title: "完成可复现性检查清单",
                scheduleKind: .range,
                start: day(0),
                end: day(2),
                createdAt: day(-4, 11)
            ),

            // 接下来三周：保证周视图和月视图都有自然分布。
            fixed("启动噪声鲁棒性训练", 1, 8, 40),
            planned("更新实验追踪面板", 1),
            planned("精读不确定性估计论文", 1),
            fixed("与数据平台对齐接口", 2, 10),
            planned("完成 OOD 指标脚本", 2),
            fixed("生成困难负样本", 3, 9, 30),
            planned("撰写数据治理小节", 3),
            fixed("参加跨实验室联合讨论", 4, 14),
            planned("制作误差分析图", 4),
            fixed("内部复核投稿合规项", 5, 11),
            planned("冻结第一版实验配置", 5),
            planned("阅读可解释性方法论文", 6),
            planned("规划下个迭代里程碑", 7),
            fixed("运行多卡推理压测", 8, 13, 30),
            planned("分析异常日志根因", 9),
            fixed("汇报推理压测结果", 10, 16),
            planned("生成模型卡初稿", 11),
            planned("校对补充材料排版", 12),
            fixed("预演答辩问答", 14, 15),
            planned("提交数据划分说明", 16),
            planned("完成阶段演示录像", 18),
            fixed("联合项目线上评审", 20, 9, 30),

            // 未安排任务：像真实收件箱一样保留可稍后处理的想法。
            TodoItem(title: "申请校内算力额度", scheduleKind: .inbox, reminderEnabled: false, createdAt: day(-3, 20)),
            TodoItem(title: "整理可公开代码列表", scheduleKind: .inbox, reminderEnabled: false, createdAt: day(-2, 21)),
            TodoItem(title: "确认备选数据集授权情况", scheduleKind: .inbox, reminderEnabled: false, createdAt: day(-1, 22)),
            TodoItem(title: "研究学术海报印刷规格", scheduleKind: .inbox, reminderEnabled: false, createdAt: day(0, 8))
        ]

        let habitLogs: [HabitLog] = [
            HabitLog(habitID: deepReading.id, timestamp: day(-6, 21)),
            HabitLog(habitID: deepReading.id, timestamp: day(-4, 20)),
            HabitLog(habitID: deepReading.id, timestamp: day(-2, 22)),
            HabitLog(habitID: deepReading.id, timestamp: day(-1, 21)),
            HabitLog(habitID: researchJournal.id, timestamp: day(-6, 19)),
            HabitLog(habitID: researchJournal.id, timestamp: day(-5, 19)),
            HabitLog(habitID: researchJournal.id, timestamp: day(-3, 20)),
            HabitLog(habitID: researchJournal.id, timestamp: day(-1, 18)),
            HabitLog(habitID: codeReview.id, timestamp: day(-4, 18)),
            HabitLog(habitID: codeReview.id, timestamp: day(-2, 19)),
            HabitLog(habitID: academicListening.id, timestamp: day(-5, 22)),
            HabitLog(habitID: academicListening.id, timestamp: day(-3, 22)),
            HabitLog(habitID: academicListening.id, timestamp: day(-1, 20))
        ]

        let attendance: [AttendanceSession] = [
            AttendanceSession(arrivedAt: day(-6, 9, 10), leftAt: day(-6, 18, 20)),
            AttendanceSession(arrivedAt: day(-5, 8, 55), leftAt: day(-5, 17, 50)),
            AttendanceSession(arrivedAt: day(-4, 9, 20), leftAt: day(-4, 19, 10)),
            AttendanceSession(arrivedAt: day(-3, 9, 5), leftAt: day(-3, 18, 0)),
            AttendanceSession(arrivedAt: day(-2, 8, 45), leftAt: day(-2, 18, 35)),
            AttendanceSession(arrivedAt: day(-1, 10, 30), leftAt: day(-1, 16, 20)),
            AttendanceSession(arrivedAt: day(-13, 9, 25), leftAt: day(-13, 18, 15)),
            AttendanceSession(arrivedAt: day(-12, 8, 50), leftAt: day(-12, 17, 45)),
            AttendanceSession(arrivedAt: day(-11, 9, 15), leftAt: day(-11, 19, 0)),
            AttendanceSession(arrivedAt: day(-10, 9, 0), leftAt: day(-10, 18, 5)),
            AttendanceSession(arrivedAt: day(-9, 9, 35), leftAt: day(-9, 17, 55))
        ]

        return AppData(
            tasks: tasks,
            deadlines: [
                DeadlineItem(title: "开源仓库清理截止", dueDate: day(9)),
                DeadlineItem(title: "联合项目阶段汇报", dueDate: day(18)),
                DeadlineItem(title: "博士论坛海报终稿", dueDate: day(31))
            ],
            habits: [deepReading, researchJournal, codeReview, academicListening],
            habitLogs: habitLogs,
            attendanceSessions: attendance
        )
    }
}
