import SwiftUI
import YanXuCore

struct DeadlineBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL

    @State private var editingDeadline: DeadlineItem?
    @State private var showsNewDeadline = false
    @State private var showsArchive = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("DDL")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.yanxuInk)
                    Text("我的 DDL 与 CCF A 人工智能会议")
                        .font(.caption)
                        .foregroundStyle(Color.yanxuMuted)
                }
                Spacer()
                Button {
                    showsNewDeadline = true
                } label: {
                    Label("添加 DDL", systemImage: "plus")
                }
                .buttonStyle(PrimaryActionStyle())
            }
            .padding(.horizontal, 18)
            .frame(height: 58)

            Rectangle().fill(Color.yanxuBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageSectionHeader(title: "我的 DDL", detail: "\(store.activeDeadlines.count) 个进行中")

                if store.activeDeadlines.isEmpty {
                    SurfaceCard {
                        EmptyState(icon: "timer", title: "还没有 DDL", message: "添加截止日期后，会按照剩余天数排列。")
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        ForEach(store.activeDeadlines) { deadline in
                            DeadlineLargeCard(deadline: deadline)
                                .onTapGesture { editingDeadline = deadline }
                                .contextMenu {
                                    Button("编辑") { editingDeadline = deadline }
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

                    if store.upcomingCCFDeadlines.isEmpty {
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
                            ForEach(store.upcomingCCFDeadlines) { deadline in
                                CCFDeadlineLargeCard(deadline: deadline)
                            }
                        }
                    }

                    Text("公开数据由 CCFDDL 社区维护，仅供参考；点击会议卡片可打开会议官网。")
                        .font(.caption2)
                        .foregroundStyle(Color.yanxuMuted)
                }
                .padding(.top, 4)

                if !store.archivedDeadlines.isEmpty {
                    DisclosureGroup(isExpanded: $showsArchive) {
                        SurfaceCard {
                            VStack(spacing: 0) {
                                ForEach(Array(store.archivedDeadlines.enumerated()), id: \.element.id) { index, deadline in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(deadline.title)
                                                .foregroundStyle(Color.yanxuInk)
                                            Text(deadline.includesTime ? Formatters.dateTime.string(from: deadline.dueDate) : Formatters.shortDate.string(from: deadline.dueDate))
                                                .font(.caption)
                                                .foregroundStyle(Color.yanxuMuted)
                                        }
                                        Spacer()
                                        Text("已结束")
                                            .font(.caption)
                                            .foregroundStyle(Color.yanxuMuted)
                                    }
                                    .padding(.vertical, 9)
                                    .contextMenu {
                                        Button("编辑") { editingDeadline = deadline }
                                        Button("删除", role: .destructive) { store.deleteDeadline(id: deadline.id) }
                                    }
                                    if index < store.archivedDeadlines.count - 1 {
                                        Divider().foregroundStyle(Color.yanxuBorder)
                                    }
                                }
                            }
                            }
                            .padding(.top, 6)
                    } label: {
                        Text("已归档 · \(store.archivedDeadlines.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.yanxuMuted)
                    }
                    .tint(Color.yanxuMuted)
                }
            }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color.yanxuCanvas)
        .sheet(isPresented: $showsNewDeadline) {
            DeadlineEditorView()
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
                Image(systemName: "timer")
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
            }

            Spacer(minLength: 10)

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(days == 0 ? "今天" : "\(days)")
                    .font(.system(size: days == 0 ? 18 : 28, weight: .semibold))
                    .foregroundStyle(Color.yanxuAccentStrong)
                if days != 0 {
                    Text("天")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.yanxuAccent)
                }
            }
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

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(days == 0 ? "今天" : "\(days)")
                    .font(.system(size: days == 0 ? 18 : 28, weight: .semibold))
                    .foregroundStyle(Color.yanxuAccentStrong)
                if days != 0 {
                    Text("天")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.yanxuAccent)
                }
            }
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

private struct DeadlineEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DeadlineItem

    init(deadline: DeadlineItem? = nil) {
        let initialDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        _draft = State(initialValue: deadline ?? DeadlineItem(title: "", dueDate: initialDate))
    }

    private var isEditing: Bool { store.data.deadlines.contains(where: { $0.id == draft.id }) }
    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COUNTDOWN")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color.yanxuAccent)
                    Text(isEditing ? "编辑 DDL" : "新增 DDL")
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
                Text("DDL 名称")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.yanxuMuted)
                TextField("例如：提交论文初稿", text: $draft.title)
                    .editorField()

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

                HStack {
                    Text("截止时间")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.yanxuInk)
                    Spacer()
                    DatePicker(
                        "截止时间",
                        selection: $draft.dueDate,
                        displayedComponents: draft.includesTime ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                }
                .padding(14)
                .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 11))

                Label("DDL 仅展示倒计时，不发送提醒。", systemImage: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(Color.yanxuMuted)

                Button(action: save) {
                    Text(isEditing ? "保存修改" : "创建 DDL")
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
        .frame(width: 460, height: 460, alignment: .top)
        .background(Color.yanxuCard)
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.includesTime {
            draft.dueDate = store.calendar.startOfDay(for: draft.dueDate)
        }
        store.upsertDeadline(draft)
        dismiss()
    }
}
