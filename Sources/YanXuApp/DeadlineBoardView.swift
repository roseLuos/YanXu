import SwiftUI
import YanXuCore

struct DeadlineBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL

    @State private var editingDeadline: DeadlineItem?
    @State private var showsNewDeadline = false
    @State private var newDeadlineKind: DeadlineKind = .deadline

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("里程碑")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                    Text("DDL、正向里程碑与 CCF A 人工智能会议")
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }
                Spacer()
                Menu {
                    Button {
                        newDeadlineKind = .deadline
                        showsNewDeadline = true
                    } label: {
                        Label("添加 DDL", systemImage: "timer")
                    }
                    Button {
                        newDeadlineKind = .milestone
                        showsNewDeadline = true
                    } label: {
                        Label("添加正向里程碑", systemImage: "flag.fill")
                    }
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .buttonStyle(PrimaryActionStyle())
            }
            .padding(.horizontal, 18)
            .frame(height: 58)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageSectionHeader(title: "我的里程碑", detail: "\(store.personalMilestoneItems.count) 个")

                if store.personalMilestoneItems.isEmpty {
                    SurfaceCard {
                        EmptyState(icon: "flag", title: "还没有里程碑", message: "添加 DDL 倒计时，或记录一件已经坚持多久的事。")
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        ForEach(store.personalMilestoneItems) { deadline in
                            DeadlineLargeCard(deadline: deadline)
                                .onTapGesture { editingDeadline = deadline }
                                .contextMenu {
                                    Button("编辑") { editingDeadline = deadline }
                                    Button("忽略") { store.ignoreDeadline(id: deadline.id) }
                                    Button("删除", role: .destructive) { store.deleteDeadline(id: deadline.id) }
                                }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 9) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CCF A · 人工智能")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.yanxuInk)
                            Text(ccfStatusText)
                                .font(.caption)
                                .foregroundStyle(ccfStatusColor)
                        }
                        Spacer()
                        Button {
                            openURL(AppStore.ccfDDLWebsiteURL)
                        } label: {
                            Label("CCFDDL", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(QuietActionStyle())

                        Button {
                            Task { await store.refreshCCFDeadlines() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(QuietActionStyle())
                        .disabled(store.ccfDeadlineLoadState == .loading)
                    }

                    if store.displayedCCFDeadlines.isEmpty {
                        SurfaceCard {
                            if store.ccfDeadlineLoadState == .loading {
                                HStack(spacing: 9) {
                                    ProgressView().controlSize(.small)
                                    Text("正在读取 CCFDDL…")
                                        .foregroundStyle(Color.yanxuMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                EmptyState(
                                    icon: "globe.asia.australia",
                                    title: "暂无未来截稿日期",
                                    message: "数据来自 CCFDDL 的人工智能类 CCF A 会议。"
                                )
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                            ForEach(store.displayedCCFDeadlines) { deadline in
                                CCFDeadlineLargeCard(deadline: deadline)
                                    .contextMenu {
                                        Button("忽略") { store.ignoreCCFDeadline(id: deadline.id) }
                                    }
                            }
                        }
                    }

                    Text("公开数据由 CCFDDL 社区维护，仅供参考；点击会议卡片可打开会议官网。")
                        .font(.caption2)
                        .foregroundStyle(Color.yanxuMuted)
                }
                .padding(.top, 4)

            }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color.yanxuCanvas)
        .sheet(isPresented: $showsNewDeadline) {
            DeadlineEditorView(kind: newDeadlineKind)
                .environmentObject(store)
        }
        .sheet(item: $editingDeadline) { deadline in
            DeadlineEditorView(deadline: deadline)
                .environmentObject(store)
        }
    }

    private var ccfStatusText: String {
        switch store.ccfDeadlineLoadState {
        case .idle:
            return "等待同步 · 数据来源 CCFDDL"
        case .loading:
            return "正在同步 · 数据来源 CCFDDL"
        case .ready:
            if let updatedAt = store.ccfDeadlineUpdatedAt {
                return "更新于 \(Formatters.dateTime.string(from: updatedAt)) · 数据来源 CCFDDL"
            }
            return "已同步 · 数据来源 CCFDDL"
        case .failed(let message):
            return "\(message) · 已保留本地缓存"
        }
    }

    private var ccfStatusColor: Color {
        if case .failed = store.ccfDeadlineLoadState { return Color.yanxuWarning }
        return Color.yanxuMuted
    }
}

private struct DeadlineLargeCard: View {
    @EnvironmentObject private var store: AppStore
    let deadline: DeadlineItem

    var body: some View {
        let days = deadline.remainingDays(calendar: store.calendar)

        HStack(spacing: 14) {
            HStack {
                Image(systemName: deadline.kind == .milestone ? "flag.fill" : "timer")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.yanxuAccentStrong)
                    .frame(width: 29, height: 29)
                    .background(Color.yanxuAccentSoft, in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(deadline.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                    .lineLimit(2)
                Text(deadline.includesTime ? Formatters.dateTime.string(from: deadline.dueDate) : Formatters.shortDate.string(from: deadline.dueDate))
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)
                if deadline.kind == .milestone {
                    Text("正向里程碑")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.yanxuAccentStrong)
                }
            }

            Spacer(minLength: 10)

            RelativeDayCount(days: days, large: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color.yanxuCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yanxuBorder, lineWidth: 1)
        }
    }
}

private struct CCFDeadlineLargeCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL

    let deadline: CCFDeadline

    var body: some View {
        let days = store.calendar.dateComponents(
            [.day],
            from: store.calendar.startOfDay(for: Date()),
            to: store.calendar.startOfDay(for: deadline.dueDate)
        ).day ?? 0

        HStack(spacing: 14) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.yanxuAccentStrong)
                .frame(width: 29, height: 29)
                .background(Color.yanxuAccentSoft, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(deadline.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.yanxuInk)
                    .lineLimit(2)
                HStack(spacing: 7) {
                    Text(Formatters.dateTime.string(from: deadline.dueDate))
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                    Text("CCF A")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.yanxuAccentStrong)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yanxuAccentSoft, in: Capsule())
                }
            }

            Spacer(minLength: 10)

            RelativeDayCount(days: days, large: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color.yanxuCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yanxuBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let conferenceURL = deadline.conferenceURL {
                openURL(conferenceURL)
            }
        }
        .help("打开会议官网")
    }
}

private struct RelativeDayCount: View {
    let days: Int
    var large = false

    var body: some View {
        if days == 0 {
            Text("今天")
                .font(.system(size: large ? 18 : 16, weight: .semibold))
                .foregroundStyle(Color.yanxuAccentStrong)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: large ? 5 : 3) {
                Text(days < 0 ? "已经" : "还有")
                    .font(.system(size: large ? 12 : 10, weight: .medium))
                    .foregroundStyle(Color.yanxuMuted)
                Text("\(abs(days))")
                    .font(.system(size: large ? 28 : 23, weight: .semibold))
                    .foregroundStyle(Color.yanxuAccentStrong)
                Text("天")
                    .font(.system(size: large ? 14 : 11, weight: .medium))
                    .foregroundStyle(Color.yanxuAccent)
            }
        }
    }
}

private struct DeadlineEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DeadlineItem

    init(deadline: DeadlineItem? = nil, kind: DeadlineKind = .deadline) {
        let initialDate = kind == .deadline
            ? (Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
            : Date()
        _draft = State(initialValue: deadline ?? DeadlineItem(title: "", dueDate: initialDate, kind: kind))
    }

    private var isEditing: Bool { store.data.deadlines.contains(where: { $0.id == draft.id }) }
    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.kind == .deadline ? "COUNTDOWN" : "COUNT UP")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color.yanxuAccent)
                    Text(isEditing ? "编辑\(draft.kind.title)" : "新增\(draft.kind.title)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.yanxuMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.yanxuRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 17) {
                Picker("类型", selection: $draft.kind) {
                    ForEach(DeadlineKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Text(draft.kind == .deadline ? "DDL 名称" : "里程碑名称")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.yanxuMuted)
                TextField(draft.kind == .deadline ? "例如：提交论文初稿" : "例如：开始减肥", text: $draft.title)
                    .editorField()

                if draft.kind == .deadline {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("具体时间")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.yanxuInk)
                            Text("关闭时只计算到日期")
                                .font(.caption)
                                .foregroundStyle(Color.yanxuMuted)
                        }
                        Spacer()
                        Toggle("包含具体时间", isOn: $draft.includesTime)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color.yanxuAccent)
                    }
                    .padding(14)
                    .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11))
                }

                HStack {
                    Text(draft.kind == .deadline ? "截止时间" : "起始日期")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.yanxuInk)
                    Spacer()
                    DatePicker(
                        draft.kind == .deadline ? "截止时间" : "起始日期",
                        selection: $draft.dueDate,
                        displayedComponents: draft.kind == .deadline && draft.includesTime ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                }
                .padding(14)
                .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11))

                Label(
                    draft.kind == .deadline
                        ? "日期过去后会继续显示“已经 X 天”，可右键忽略。"
                        : "从起始日期计算已经坚持的天数。",
                    systemImage: draft.kind == .deadline ? "timer" : "flag.fill"
                )
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)

                Button(action: save) {
                    Text(isEditing ? "保存修改" : "创建\(draft.kind.title)")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 22)
        }
        .padding(26)
        .frame(width: 460, height: 520, alignment: .top)
        .background(Color.yanxuCard)
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.kind == .milestone {
            draft.includesTime = false
        }
        if !draft.includesTime {
            draft.dueDate = store.calendar.startOfDay(for: draft.dueDate)
        }
        store.upsertDeadline(draft)
        dismiss()
    }
}
