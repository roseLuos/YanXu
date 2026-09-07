import SwiftUI
import YanXuCore

struct TaskEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TodoItem
    @State private var hasEndTime: Bool

    init(task: TodoItem? = nil, defaultDate: Date? = Date(), defaultScheduleKind: TaskScheduleKind? = nil) {
        let scheduleKind = defaultScheduleKind ?? (defaultDate == nil ? .inbox : .day)
        let newTask = task ?? TodoItem(
            title: "",
            scheduleKind: scheduleKind,
            start: defaultDate,
            reminderEnabled: defaultDate != nil
        )
        _draft = State(initialValue: newTask)
        _hasEndTime = State(initialValue: newTask.end != nil && newTask.scheduleKind == .fixed)
    }

    private var isEditing: Bool { store.task(id: draft.id) != nil }
    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("NEW TASK")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color.yanxuAccent)
                    Text(isEditing ? "编辑待办" : "新增待办")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.yanxuMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.yanxuRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    editorLabel("待办名称")
                    TextField("例如：周五下午 2 点开组会", text: $draft.title)
                        .editorField()

                    editorLabel("安排方式")
                    Picker("安排方式", selection: $draft.scheduleKind) {
                        ForEach(TaskScheduleKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: draft.scheduleKind) { _, kind in
                        updateSchedule(for: kind)
                    }

                    VStack(alignment: .leading, spacing: 13) {
                        scheduleFields
                    }
                    .padding(15)
                    .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.yanxuBorder, lineWidth: 1)
                    }

                    if draft.scheduleKind != .inbox && draft.scheduleKind != .range {
                        editorLabel("重复")
                        Picker("重复", selection: $draft.repeatRule) {
                            ForEach(TaskRepeatRule.allCases) { rule in
                                Text(rule.title).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if draft.scheduleKind != .inbox {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("默认提醒")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.yanxuInk)
                                if draft.reminderEnabled {
                                    Text(reminderDescription)
                                        .font(.caption)
                                        .foregroundStyle(Color.yanxuMuted)
                                }
                            }
                            Spacer()
                            Toggle("提醒", isOn: $draft.reminderEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(Color.yanxuAccent)
                        }
                        .padding(15)
                        .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }

                    editorLabel("备注 · 可选")
                    TextField("补充一点必要信息", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...5)
                        .editorField()

                    Button(action: save) {
                        Text(isEditing ? "保存修改" : "创建待办")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(PrimaryActionStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(26)
            }
        }
        .frame(width: 500, height: 650)
        .background(Color.yanxuCard)
    }

    private func editorLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.yanxuMuted)
            .padding(.bottom, -12)
    }

    @ViewBuilder
    private var scheduleFields: some View {
        switch draft.scheduleKind {
        case .inbox:
            Label("暂不安排日期，任务会保存在收件箱中。", systemImage: "tray")
                .font(.caption)
                .foregroundStyle(Color.yanxuMuted)
        case .day:
            editorDateRow("日期") {
                DatePicker("日期", selection: requiredStart, displayedComponents: .date)
            }
        case .fixed:
            editorDateRow("开始") {
                DatePicker("开始", selection: requiredStart, displayedComponents: [.date, .hourAndMinute])
            }
            Divider().foregroundStyle(Color.yanxuBorder)
            HStack {
                Text("设置结束时间")
                    .font(.subheadline)
                    .foregroundStyle(Color.yanxuInk)
                Spacer()
                Toggle("设置结束时间", isOn: $hasEndTime)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.yanxuAccent)
            }
            if hasEndTime {
                Divider().foregroundStyle(Color.yanxuBorder)
                editorDateRow("结束") {
                    DatePicker("结束", selection: requiredEnd, in: requiredStart.wrappedValue..., displayedComponents: [.date, .hourAndMinute])
                }
            }
        case .range:
            editorDateRow("开始日期") {
                DatePicker("开始日期", selection: requiredStart, displayedComponents: .date)
            }
            Divider().foregroundStyle(Color.yanxuBorder)
            editorDateRow("结束日期") {
                DatePicker("结束日期", selection: requiredEnd, in: requiredStart.wrappedValue..., displayedComponents: .date)
            }
        }
    }

    private func editorDateRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.yanxuInk)
            Spacer()
            content()
                .labelsHidden()
        }
    }

    private var requiredStart: Binding<Date> {
        Binding(get: { draft.start ?? Date() }, set: { draft.start = $0 })
    }

    private var requiredEnd: Binding<Date> {
        Binding(get: { draft.end ?? draft.start ?? Date() }, set: { draft.end = $0 })
    }

    private var reminderDescription: String {
        switch draft.scheduleKind {
        case .inbox: ""
        case .day: "当天上午 9:00 提醒"
        case .fixed: "开始前 10 分钟提醒"
        case .range: "开始日期上午 9:00 提醒一次"
        }
    }

    private func updateSchedule(for kind: TaskScheduleKind) {
        switch kind {
        case .inbox:
            draft.start = nil
            draft.end = nil
            draft.repeatRule = .none
            draft.reminderEnabled = false
        case .day:
            draft.start = draft.start ?? Date()
            draft.end = nil
            draft.reminderEnabled = true
        case .fixed:
            draft.start = draft.start ?? Date()
            draft.end = hasEndTime ? (draft.end ?? Calendar.current.date(byAdding: .hour, value: 1, to: draft.start ?? Date())) : nil
            draft.reminderEnabled = true
        case .range:
            draft.start = draft.start ?? Date()
            draft.end = draft.end ?? Calendar.current.date(byAdding: .day, value: 1, to: draft.start ?? Date())
            draft.repeatRule = .none
            draft.reminderEnabled = true
        }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        switch draft.scheduleKind {
        case .inbox:
            draft.start = nil
            draft.end = nil
            draft.repeatRule = .none
            draft.reminderEnabled = false
        case .day:
            draft.end = nil
        case .fixed:
            if !hasEndTime { draft.end = nil }
        case .range:
            draft.repeatRule = .none
            if let start = draft.start, let end = draft.end, end < start {
                draft.end = start
            }
        }

        store.upsertTask(draft)
        dismiss()
    }
}
