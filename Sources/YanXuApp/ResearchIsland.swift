import AppKit
import SwiftUI
import YanXuCore

enum ResearchIslandAppearance: String {
    case light
    case dark
}

@MainActor
final class ResearchIslandAppearanceStore: ObservableObject {
    static let shared = ResearchIslandAppearanceStore()
    private static let defaultsKey = "YanXu.researchIslandAppearance"

    @Published var mode: ResearchIslandAppearance {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey)
        }
    }

    private init() {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["YANXU_ISLAND_APPEARANCE"],
           let appearance = ResearchIslandAppearance(rawValue: value) {
            mode = appearance
            return
        }
        #endif

        let savedValue = UserDefaults.standard.string(forKey: Self.defaultsKey)
        mode = ResearchIslandAppearance(rawValue: savedValue ?? "") ?? .dark
    }

    func toggle() {
        mode = mode == .dark ? .light : .dark
    }
}

private struct ResearchIslandPalette {
    let mode: ResearchIslandAppearance

    private var isDark: Bool { mode == .dark }

    var background: Color {
        isDark
            ? Color(red: 0.035, green: 0.045, blue: 0.062).opacity(0.97)
            : Color(red: 0.965, green: 0.975, blue: 0.99).opacity(0.985)
    }

    var primaryText: Color {
        isDark ? .white : Color(red: 0.09, green: 0.12, blue: 0.18)
    }

    var secondaryText: Color { primaryText.opacity(isDark ? 0.52 : 0.58) }
    var mutedText: Color { primaryText.opacity(isDark ? 0.30 : 0.38) }
    var border: Color { primaryText.opacity(isDark ? 0.11 : 0.12) }
    var divider: Color { primaryText.opacity(isDark ? 0.09 : 0.10) }
    var controlBackground: Color { primaryText.opacity(isDark ? 0.08 : 0.07) }
    var metricBackground: Color { primaryText.opacity(isDark ? 0.06 : 0.055) }
    var dayBackground: Color { primaryText.opacity(isDark ? 0.045 : 0.04) }
    var dayBorder: Color { primaryText.opacity(isDark ? 0.06 : 0.08) }
    var taskText: Color { primaryText.opacity(isDark ? 0.86 : 0.88) }
    var completedText: Color { primaryText.opacity(isDark ? 0.36 : 0.40) }
    var completedStrike: Color { primaryText.opacity(isDark ? 0.28 : 0.30) }
    var shadow: Color {
        isDark
            ? Color.yanxuAccent.opacity(0.20)
            : Color(red: 0.08, green: 0.15, blue: 0.28).opacity(0.16)
    }
}

@MainActor
final class ResearchIslandModel: ObservableObject {
    enum State {
        case compact
        case expanded
    }

    @Published private(set) var state: State = .compact
    @Published private(set) var size: CGSize = .zero
    @Published private(set) var notch: ResearchIslandNotch

    private var availableWidth: CGFloat
    var moveHandler: ((CGSize, Bool) -> Void)?
    var resetPositionHandler: (() -> Void)?
    var openAppHandler: (() -> Void)?

    init(notch: ResearchIslandNotch, availableWidth: CGFloat) {
        self.notch = notch
        self.availableWidth = availableWidth
        recomputeSize()
    }

    var isExpanded: Bool { state == .expanded }

    func setExpanded(_ expanded: Bool) {
        let nextState: State = expanded ? .expanded : .compact
        guard state != nextState else { return }
        state = nextState
        recomputeSize()
    }

    func update(notch: ResearchIslandNotch, availableWidth: CGFloat) {
        self.notch = notch
        self.availableWidth = availableWidth
        recomputeSize()
    }

    func move(by translation: CGSize, ended: Bool) {
        moveHandler?(translation, ended)
    }

    func resetPosition() {
        resetPositionHandler?()
    }

    func openApp() {
        openAppHandler?()
    }

    private func recomputeSize() {
        if isExpanded {
            size = CGSize(
                width: min(900, max(520, availableWidth - 24)),
                height: min(460, notch.height + 410)
            )
        } else {
            let centerGap = notch.hasNotch ? notch.width : 34
            size = CGSize(
                width: min(max(420, centerGap + 292), availableWidth - 24),
                height: max(38, notch.height)
            )
        }
    }
}

struct ResearchIslandNotch: Equatable {
    let width: CGFloat
    let height: CGFloat
    let hasNotch: Bool

    static func detect(from screen: NSScreen?) -> ResearchIslandNotch {
        guard let screen else {
            return ResearchIslandNotch(width: 34, height: 38, hasNotch: false)
        }

        let safeTop = screen.safeAreaInsets.top
        let measuredMenuBar = max(0, screen.frame.maxY - screen.visibleFrame.maxY - 1)
        let height = max(24, safeTop > 0 ? safeTop : measuredMenuBar)

        guard safeTop > 0 else {
            return ResearchIslandNotch(width: 34, height: height, hasNotch: false)
        }

        let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
        let detectedWidth = leftWidth > 0 && rightWidth > 0
            ? screen.frame.width - leftWidth - rightWidth
            : 200
        return ResearchIslandNotch(width: detectedWidth, height: height, hasNotch: true)
    }
}

private struct ResearchIslandShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: 18,
                bottomTrailing: 18,
                topTrailing: 0
            ),
            style: .continuous
        )
        .path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> ResearchIslandShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

struct ResearchIslandRootView: View {
    @ObservedObject var model: ResearchIslandModel
    @ObservedObject var store: AppStore
    @ObservedObject private var appearance = ResearchIslandAppearanceStore.shared
    @State private var hovering = false
    @State private var quickTaskTitle: String

    init(model: ResearchIslandModel, store: AppStore) {
        self.model = model
        self.store = store
#if DEBUG
        _quickTaskTitle = State(
            initialValue: ProcessInfo.processInfo.environment["YANXU_ISLAND_DEMO_QUICK_TASK"] ?? ""
        )
#else
        _quickTaskTitle = State(initialValue: "")
#endif
    }

    private var palette: ResearchIslandPalette {
        ResearchIslandPalette(mode: appearance.mode)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                Group {
                    if model.isExpanded {
                        expandedContent(now: timeline.date)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    } else {
                        compactContent(now: timeline.date)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    }
                }
                .frame(width: model.size.width, height: model.size.height, alignment: .top)
                .background {
                    ResearchIslandShape()
                        .fill(palette.background)
                }
                .overlay {
                    ResearchIslandShape()
                        .strokeBorder(palette.border.opacity(model.isExpanded ? 1 : 0.72), lineWidth: 0.7)
                }
                .clipShape(ResearchIslandShape())
                .shadow(
                    color: palette.shadow.opacity(hovering || model.isExpanded ? 1 : 0.62),
                    radius: model.isExpanded ? 24 : 12,
                    y: model.isExpanded ? 12 : 4
                )
                .contentShape(ResearchIslandShape())
                .onHover { hovering = $0 }
                .onTapGesture {
                    guard !model.isExpanded else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        model.setExpanded(true)
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.84), value: model.size)
                .animation(.easeInOut(duration: 0.22), value: appearance.mode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func compactContent(now: Date) -> some View {
        let today = DateIntervals.day(containing: now, calendar: store.calendar)
        let researchDuration = store.attendanceDuration(in: today, now: now)
        let progress = taskProgress(on: now)
        let centerGap = model.notch.hasNotch ? model.notch.width : 34

        return HStack(spacing: 0) {
            compactMetric(
                icon: store.activeAttendanceSession == nil ? "clock" : "location.fill",
                title: "今日科研",
                value: compactDuration(researchDuration),
                tint: .yanxuSuccess
            )

            Color.clear
                .frame(width: centerGap)

            compactMetric(
                icon: "checkmark.circle.fill",
                title: "今日任务",
                value: progress.total == 0 ? "0 项" : "\(progress.completed)/\(progress.total)",
                tint: .yanxuAccent
            )
        }
        .padding(.horizontal, 10)
        .frame(height: model.size.height)
        .simultaneousGesture(islandDragGesture)
        .contextMenu {
            Button("回到屏幕顶部") {
                model.resetPosition()
            }
        }
        .help("拖动以移动灵动岛")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日科研 \(Formatters.duration(researchDuration))，今日任务完成 \(progress.completed) 项，共 \(progress.total) 项")
    }

    private func compactMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func expandedContent(now: Date) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: model.notch.height)

            expandedHeader(now: now)

            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)

            quickTaskInput

            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)

            weekGrid(now: now)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
        }
    }

    private func expandedHeader(now: Date) -> some View {
        let week = DateIntervals.week(containing: now, calendar: store.calendar)
        let finalDay = store.calendar.date(byAdding: .day, value: 6, to: week.start) ?? week.end
        let today = DateIntervals.day(containing: now, calendar: store.calendar)
        let researchDuration = store.attendanceDuration(in: today, now: now)
        let progress = taskProgress(on: now)

        return HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("本周计划")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Button {
                        model.openApp()
                    } label: {
                        Text("\(Formatters.shortDate.string(from: week.start)) — \(Formatters.shortDate.string(from: finalDay))")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("在研序中打开")
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(islandDragGesture)
            .contextMenu {
                Button("回到屏幕顶部") {
                    model.resetPosition()
                }
            }
            .help("拖动以移动灵动岛")

            Spacer()

            headerMetric(title: "今日科研", value: Formatters.duration(researchDuration), tint: .yanxuSuccess)
            headerMetric(title: "任务完成", value: "\(progress.completed)/\(progress.total)", tint: .yanxuAccent)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    appearance.toggle()
                }
            } label: {
                Image(systemName: appearance.mode == .dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appearance.mode == .dark ? Color.orange : Color.yanxuAccent)
                    .frame(width: 28, height: 28)
                    .background(palette.controlBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .help(appearance.mode == .dark ? "切换到白天模式" : "切换到黑夜模式")
            .accessibilityLabel(appearance.mode == .dark ? "切换到白天模式" : "切换到黑夜模式")

            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
                    model.setExpanded(false)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.primaryText.opacity(0.68))
                    .frame(width: 28, height: 28)
                    .background(palette.controlBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .help("收起灵动岛")
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var quickTaskInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.yanxuAccent)

            TextField(
                "",
                text: $quickTaskTitle,
                prompt: Text("新增任务，如：明天下午 2 点讨论实验")
                    .foregroundColor(palette.mutedText)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(palette.primaryText)
            .onSubmit(addQuickTask)
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(palette.metricBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(palette.border.opacity(0.8), lineWidth: 0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func addQuickTask() {
        let input = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        let result = QuickTaskParser.parse(input, now: Date(), calendar: store.calendar)
        store.upsertTask(TodoItem(
            title: result.title,
            scheduleKind: result.scheduleKind,
            start: result.start,
            reminderEnabled: result.scheduleKind != .inbox
        ))
        quickTaskTitle = ""
    }

    private var islandDragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                model.move(by: value.translation, ended: false)
            }
            .onEnded { value in
                model.move(by: value.translation, ended: true)
            }
    }

    private func headerMetric(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(palette.metricBackground, in: Capsule())
    }

    private func weekGrid(now: Date) -> some View {
        let week = DateIntervals.week(containing: now, calendar: store.calendar)
        let days = (0..<7).compactMap {
            store.calendar.date(byAdding: .day, value: $0, to: week.start)
        }

        return HStack(alignment: .top, spacing: 8) {
            ForEach(days, id: \.self) { day in
                IslandDayColumn(
                    day: day,
                    isToday: store.calendar.isDate(day, inSameDayAs: now),
                    occurrences: sortedOccurrences(on: day),
                    store: store,
                    palette: palette,
                    onOpenApp: model.openApp
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func sortedOccurrences(on day: Date) -> [TaskOccurrence] {
        store.occurrences(on: day).sorted { lhs, rhs in
            guard let left = store.task(id: lhs.taskID),
                  let right = store.task(id: rhs.taskID) else { return lhs.taskID.uuidString < rhs.taskID.uuidString }
            let leftDate = left.start ?? left.createdAt
            let rightDate = right.start ?? right.createdAt
            if left.scheduleKind == .fixed && right.scheduleKind != .fixed { return true }
            if left.scheduleKind != .fixed && right.scheduleKind == .fixed { return false }
            return leftDate < rightDate
        }
    }

    private func taskProgress(on date: Date) -> (completed: Int, total: Int) {
        let occurrences = store.occurrences(on: date)
        let completed = occurrences.filter { occurrence in
            store.task(id: occurrence.taskID)?.isCompleted(on: occurrence.date, calendar: store.calendar) == true
        }.count
        return (completed, occurrences.count)
    }

    private func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 60 { return "\(minutes)分" }
        return String(format: "%d时%02d分", minutes / 60, minutes % 60)
    }
}

private struct IslandDayColumn: View {
    let day: Date
    let isToday: Bool
    let occurrences: [TaskOccurrence]
    @ObservedObject var store: AppStore
    let palette: ResearchIslandPalette
    let onOpenApp: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Button(action: onOpenApp) {
                VStack(spacing: 3) {
                    Text(weekdayText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isToday ? Color.yanxuAccent : palette.secondaryText)
                    Text("\(store.calendar.component(.day, from: day))")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isToday ? Color.white : palette.primaryText.opacity(0.82))
                        .frame(width: 28, height: 28)
                        .background(isToday ? Color.yanxuAccent : Color.clear, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .help("在研序中打开")

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    if occurrences.isEmpty {
                        Text("暂无计划")
                            .font(.system(size: 9))
                            .foregroundStyle(palette.mutedText)
                            .padding(.top, 10)
                    } else {
                        ForEach(occurrences.prefix(8)) { occurrence in
                            if let task = store.task(id: occurrence.taskID) {
                                IslandTaskRow(task: task, occurrence: occurrence, store: store, palette: palette)
                            }
                        }

                        if occurrences.count > 8 {
                            Text("还有 \(occurrences.count - 8) 项")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            isToday ? Color.yanxuAccent.opacity(0.12) : palette.dayBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday ? Color.yanxuAccent.opacity(0.35) : palette.dayBorder, lineWidth: 0.7)
        }
    }

    private var weekdayText: String {
        day.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}

private struct IslandTaskRow: View {
    let task: TodoItem
    let occurrence: TaskOccurrence
    @ObservedObject var store: AppStore
    let palette: ResearchIslandPalette

    var body: some View {
        let completed = task.isCompleted(on: occurrence.date, calendar: store.calendar)

        HStack(alignment: .top, spacing: 5) {
            Button {
                store.toggleTask(id: task.id, occurrenceDate: occurrence.date)
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(completed ? Color.yanxuSuccess : taskTint.opacity(0.85))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(completed ? palette.completedText : palette.taskText)
                    .strikethrough(completed, color: palette.completedStrike)
                    .lineLimit(2)

                if task.scheduleKind == .fixed, let start = task.start {
                    Text(Formatters.time.string(from: start))
                        .font(.system(size: 8, design: .rounded))
                        .foregroundStyle(taskTint.opacity(completed ? 0.32 : 0.72))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .background(taskTint.opacity(completed ? 0.035 : 0.09), in: RoundedRectangle(cornerRadius: 7))
    }

    private var taskTint: Color {
        switch task.scheduleKind {
        case .fixed: .yanxuAccent
        case .range: .yanxuSuccess
        case .day: Color(red: 0.72, green: 0.66, blue: 0.98)
        case .inbox: .yanxuMuted
        }
    }
}

final class ResearchIslandWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ResearchIslandHostingView: NSHostingView<AnyView> {
    let islandModel: ResearchIslandModel

    init(rootView: AnyView, model: ResearchIslandModel) {
        self.islandModel = model
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init(rootView: AnyView) {
        fatalError("Use init(rootView:model:)")
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let visibleSize = islandModel.size
        let islandRect = NSRect(
            x: bounds.midX - visibleSize.width / 2,
            y: bounds.maxY - visibleSize.height,
            width: visibleSize.width,
            height: visibleSize.height
        )
        return islandRect.contains(point) ? super.hitTest(point) : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class ResearchIslandWindowController {
    private static let positionXKey = "YanXu.researchIslandPositionX"
    private static let positionYKey = "YanXu.researchIslandPositionY"
    private static let positionScreenKey = "YanXu.researchIslandScreen"

    private let window: NSWindow
    private let model: ResearchIslandModel
    private let host: ResearchIslandHostingView
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var trackingTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var positionOffset: CGSize
    private var dragStart: (cursor: NSPoint, windowOrigin: NSPoint)?
    private var dragScreen: NSScreen?
#if DEBUG
    private var demoCaptureTimer: Timer?
#endif

    init(store: AppStore) {
        positionOffset = CGSize(
            width: UserDefaults.standard.double(forKey: Self.positionXKey),
            height: UserDefaults.standard.double(forKey: Self.positionYKey)
        )
        let screen = Self.targetScreen()
        let hostWidth = min(960, screen?.frame.width ?? 960)
        let hostHeight = min(470, screen?.frame.height ?? 470)
        model = ResearchIslandModel(
            notch: ResearchIslandNotch.detect(from: screen),
            availableWidth: hostWidth
        )

        window = ResearchIslandWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: hostWidth, height: hostHeight)),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true

        let root = ResearchIslandRootView(model: model, store: store)
        host = ResearchIslandHostingView(rootView: AnyView(root), model: model)
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        model.moveHandler = { [weak self] _, ended in
            self?.moveIsland(ended: ended)
        }
        model.resetPositionHandler = { [weak self] in
            self?.resetPosition()
        }
        model.openAppHandler = { [weak self] in
            self?.openMainApp()
        }
    }

    func show() {
        reposition()
        window.orderFrontRegardless()
        installMouseTracking()
        installClickTracking()
        observeScreenChanges()
#if DEBUG
        capturePreviewIfRequested()
        captureDemoFramesIfRequested()
        verifyOpenAppIfRequested()
#endif
    }

    func hide() {
        window.orderOut(nil)
    }

    deinit {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        trackingTimer?.invalidate()
#if DEBUG
        demoCaptureTimer?.invalidate()
#endif
    }

    private func installMouseTracking() {
        guard globalMouseMonitor == nil, localMouseMonitor == nil else { return }
        window.ignoresMouseEvents = true

        let update: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in
                self?.updateMouseRouting()
                self?.trackingTimer?.invalidate()
                self?.trackingTimer = nil
            }
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: update)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            update(event)
            return event
        }

        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMouseRouting() }
        }
    }

    private func installClickTracking() {
        guard globalClickMonitor == nil, localClickMonitor == nil else { return }
        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]

        let handleClick: (NSEvent) -> Void = { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.collapseIfClickOutside(at: location)
            }
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask, handler: handleClick)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { event in
            handleClick(event)
            return event
        }
    }

    private func collapseIfClickOutside(at point: NSPoint) {
        guard model.isExpanded, !globalIslandFrame.contains(point) else { return }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            model.setExpanded(false)
        }
        updateMouseRouting()
    }

    private func updateMouseRouting() {
        if dragStart != nil {
            window.ignoresMouseEvents = false
            return
        }
        let cursor = NSEvent.mouseLocation
        window.ignoresMouseEvents = !globalIslandFrame.contains(cursor)
    }

    private var globalIslandFrame: NSRect {
        let windowFrame = window.frame
        let visibleSize = model.size
        return NSRect(
            x: windowFrame.minX + (windowFrame.width - visibleSize.width) / 2,
            y: windowFrame.maxY - visibleSize.height,
            width: visibleSize.width,
            height: visibleSize.height
        )
    }

    private func moveIsland(ended: Bool) {
        if dragStart == nil {
            dragStart = (NSEvent.mouseLocation, window.frame.origin)
            dragScreen = window.screen ?? Self.targetScreen()
        }

        guard let dragStart else { return }
        let cursor = NSEvent.mouseLocation
        let screen = Self.screen(containing: cursor) ?? dragScreen ?? window.screen ?? Self.targetScreen()
        if let screen, screen !== dragScreen {
            dragScreen = screen
            model.update(
                notch: ResearchIslandNotch.detect(from: screen),
                availableWidth: min(960, screen.frame.width)
            )
        }
        let proposed = NSPoint(
            x: dragStart.windowOrigin.x + cursor.x - dragStart.cursor.x,
            y: dragStart.windowOrigin.y + cursor.y - dragStart.cursor.y
        )
        window.setFrameOrigin(proposed)

        guard ended, let screen else {
            updateMouseRouting()
            return
        }
        window.setFrameOrigin(constrainedOrigin(window.frame.origin, on: screen))
        let anchor = anchorOrigin(on: screen)
        positionOffset = CGSize(
            width: window.frame.origin.x - anchor.x,
            height: window.frame.origin.y - anchor.y
        )
        UserDefaults.standard.set(positionOffset.width, forKey: Self.positionXKey)
        UserDefaults.standard.set(positionOffset.height, forKey: Self.positionYKey)
        if let identifier = Self.identifier(for: screen) {
            UserDefaults.standard.set(identifier, forKey: Self.positionScreenKey)
        }
        self.dragStart = nil
        dragScreen = nil
        updateMouseRouting()
    }

    private func resetPosition() {
        positionOffset = .zero
        UserDefaults.standard.removeObject(forKey: Self.positionXKey)
        UserDefaults.standard.removeObject(forKey: Self.positionYKey)
        guard let screen = window.screen ?? Self.targetScreen() else { return }
        if let identifier = Self.identifier(for: screen) {
            UserDefaults.standard.set(identifier, forKey: Self.positionScreenKey)
        }
        model.update(
            notch: ResearchIslandNotch.detect(from: screen),
            availableWidth: min(960, screen.frame.width)
        )
        window.setFrameOrigin(constrainedOrigin(anchorOrigin(on: screen), on: screen))
        updateMouseRouting()
    }

    private func openMainApp() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
            model.setExpanded(false)
        }

        if !MainWindowCoordinator.shared.show(in: NSApp) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false
            NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: configuration
            )
        }
        updateMouseRouting()
    }

    private var mainAppWindow: NSWindow? {
        MainWindowCoordinator.shared.window ?? NSApp.windows.first(where: {
            $0 !== window && !$0.isExcludedFromWindowsMenu && $0.styleMask.contains(.titled)
        }) ?? NSApp.windows.first(where: { $0 !== window && !$0.isExcludedFromWindowsMenu })
    }

    private func anchorOrigin(on screen: NSScreen) -> NSPoint {
        NSPoint(
            x: screen.frame.midX - window.frame.width / 2,
            y: screen.frame.maxY - window.frame.height
        )
    }

    private func constrainedOrigin(_ proposed: NSPoint, on screen: NSScreen) -> NSPoint {
        let localIslandX = (window.frame.width - model.size.width) / 2
        let localIslandY = window.frame.height - model.size.height
        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 8
        let minX = screen.visibleFrame.minX + horizontalPadding - localIslandX
        let maxX = screen.visibleFrame.maxX - horizontalPadding - localIslandX - model.size.width
        let minY = screen.visibleFrame.minY + verticalPadding - localIslandY
        let maxY = screen.frame.maxY - localIslandY - model.size.height

        return NSPoint(
            x: min(max(proposed.x, minX), maxX),
            y: min(max(proposed.y, minY), maxY)
        )
    }

    private func observeScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }
    }

    private func reposition() {
        guard let screen = Self.targetScreen() else { return }
        let hostWidth = min(960, screen.frame.width)
        let hostHeight = min(470, screen.frame.height)
        model.update(
            notch: ResearchIslandNotch.detect(from: screen),
            availableWidth: hostWidth
        )
        let anchor = NSPoint(
            x: screen.frame.midX - hostWidth / 2,
            y: screen.frame.maxY - hostHeight
        )
        let proposed = NSPoint(
            x: anchor.x + positionOffset.width,
            y: anchor.y + positionOffset.height
        )
        window.setFrame(
            NSRect(
                origin: proposed,
                size: CGSize(width: hostWidth, height: hostHeight)
            ),
            display: true
        )
        window.setFrameOrigin(constrainedOrigin(window.frame.origin, on: screen))
    }

    private static func targetScreen() -> NSScreen? {
        if let savedIdentifier = UserDefaults.standard.string(forKey: positionScreenKey),
           let savedScreen = NSScreen.screens.first(where: { identifier(for: $0) == savedIdentifier }) {
            return savedScreen
        }
        return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
    }

    private static func identifier(for screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }

#if DEBUG
    private func verifyOpenAppIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let resultPath = environment["YANXU_ISLAND_OPEN_APP_TEST_PATH"] else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            let mainWindow = self.mainAppWindow
            mainWindow?.orderOut(nil)
            self.model.setExpanded(true)
            self.model.openApp()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let result: [String: Bool] = [
                    "appActive": NSApp.isActive,
                    "mainWindowVisible": mainWindow?.isVisible == true,
                    "mainWindowKey": mainWindow?.isKeyWindow == true
                ]
                if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]) {
                    try? data.write(to: URL(fileURLWithPath: resultPath))
                }
                NSApp.terminate(nil)
            }
        }
    }

    private func captureDemoFramesIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let directoryPath = environment["YANXU_ISLAND_DEMO_FRAMES_DIR"] else { return }

        let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        ResearchIslandAppearanceStore.shared.mode = .dark
        model.setExpanded(false)

        let startedAt = Date()
        var frameIndex = 0
        var expandedDark = false
        var switchedLight = false
        var switchedDark = false
        var collapsed = false
        var finalExpansion = false

        demoCaptureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed >= 1.2, !expandedDark {
                    expandedDark = true
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        self.model.setExpanded(true)
                    }
                }
                if elapsed >= 3.8, !switchedLight {
                    switchedLight = true
                    withAnimation(.easeInOut(duration: 0.22)) {
                        ResearchIslandAppearanceStore.shared.mode = .light
                    }
                }
                if elapsed >= 6.0, !switchedDark {
                    switchedDark = true
                    withAnimation(.easeInOut(duration: 0.22)) {
                        ResearchIslandAppearanceStore.shared.mode = .dark
                    }
                }
                if elapsed >= 7.8, !collapsed {
                    collapsed = true
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
                        self.model.setExpanded(false)
                    }
                }
                if elapsed >= 9.3, !finalExpansion {
                    finalExpansion = true
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        self.model.setExpanded(true)
                    }
                }

                self.captureDemoFrame(index: frameIndex, directoryURL: directoryURL)
                frameIndex += 1

                if elapsed >= 11.0 {
                    timer.invalidate()
                    self.demoCaptureTimer = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }

    private func captureDemoFrame(index: Int, directoryURL: URL) {
        guard let contentView = window.contentView,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(contentView.bounds.width),
                pixelsHigh: Int(contentView.bounds.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else { return }
        bitmap.size = contentView.bounds.size
        window.displayIfNeeded()
        contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        let frameURL = directoryURL.appendingPathComponent(String(format: "frame-%04d.png", index))
        try? data.write(to: frameURL)
    }

    private func capturePreviewIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["YANXU_ISLAND_CAPTURE_PATH"] else { return }
        if environment["YANXU_ISLAND_EXPANDED"] == "1" {
            model.setExpanded(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self,
                  let contentView = self.window.contentView,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
                NSApp.terminate(nil)
                return
            }
            contentView.displayIfNeeded()
            contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
    }
#endif
}

@MainActor
final class ResearchIslandCoordinator {
    static let shared = ResearchIslandCoordinator()
    private var controller: ResearchIslandWindowController?

    private init() {}

    func show(store: AppStore) {
        if controller == nil {
            controller = ResearchIslandWindowController(store: store)
        }
        controller?.show()
    }

    func hide() {
        controller?.hide()
        controller = nil
    }
}
