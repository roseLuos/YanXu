import AppKit
import SwiftUI
import YanXuCore

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

    private func recomputeSize() {
        if isExpanded {
            size = CGSize(
                width: min(900, max(520, availableWidth - 24)),
                height: min(430, notch.height + 370)
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
    @State private var hovering = false

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
                        .fill(Color(red: 0.035, green: 0.045, blue: 0.062).opacity(0.97))
                }
                .overlay {
                    ResearchIslandShape()
                        .strokeBorder(Color.white.opacity(model.isExpanded ? 0.14 : 0.08), lineWidth: 0.7)
                }
                .clipShape(ResearchIslandShape())
                .shadow(
                    color: Color.yanxuAccent.opacity(hovering || model.isExpanded ? 0.24 : 0.12),
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
                    .foregroundStyle(Color.white.opacity(0.52))
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
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
                .fill(Color.white.opacity(0.09))
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
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("本周计划")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(Formatters.shortDate.string(from: week.start)) — \(Formatters.shortDate.string(from: finalDay))")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.48))
            }

            Spacer()

            headerMetric(title: "今日科研", value: Formatters.duration(researchDuration), tint: .yanxuSuccess)
            headerMetric(title: "任务完成", value: "\(progress.completed)/\(progress.total)", tint: .yanxuAccent)

            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
                    model.setExpanded(false)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("收起灵动岛")
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private func headerMetric(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.46))
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule())
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
                    store: store
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

    var body: some View {
        VStack(spacing: 9) {
            VStack(spacing: 3) {
                Text(weekdayText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isToday ? Color.yanxuAccent : Color.white.opacity(0.42))
                Text("\(store.calendar.component(.day, from: day))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(isToday ? .white : Color.white.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .background(isToday ? Color.yanxuAccent : Color.clear, in: Circle())
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    if occurrences.isEmpty {
                        Text("暂无计划")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .padding(.top, 10)
                    } else {
                        ForEach(occurrences.prefix(8)) { occurrence in
                            if let task = store.task(id: occurrence.taskID) {
                                IslandTaskRow(task: task, occurrence: occurrence, store: store)
                            }
                        }

                        if occurrences.count > 8 {
                            Text("还有 \(occurrences.count - 8) 项")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.38))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            isToday ? Color.yanxuAccent.opacity(0.12) : Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday ? Color.yanxuAccent.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 0.7)
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
                    .foregroundStyle(Color.white.opacity(completed ? 0.36 : 0.86))
                    .strikethrough(completed, color: Color.white.opacity(0.28))
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
    private let window: NSWindow
    private let model: ResearchIslandModel
    private let host: ResearchIslandHostingView
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var trackingTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init(store: AppStore) {
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
    }

    func show() {
        reposition()
        window.orderFrontRegardless()
        installMouseTracking()
        observeScreenChanges()
#if DEBUG
        capturePreviewIfRequested()
#endif
    }

    func hide() {
        window.orderOut(nil)
    }

    deinit {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        trackingTimer?.invalidate()
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

    private func updateMouseRouting() {
        let cursor = NSEvent.mouseLocation
        let windowFrame = window.frame
        let localPoint = NSPoint(x: cursor.x - windowFrame.minX, y: cursor.y - windowFrame.minY)
        let visibleSize = model.size
        let islandRect = NSRect(
            x: windowFrame.width / 2 - visibleSize.width / 2,
            y: windowFrame.height - visibleSize.height,
            width: visibleSize.width,
            height: visibleSize.height
        )
        window.ignoresMouseEvents = !islandRect.contains(localPoint)
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
        window.setFrame(
            NSRect(
                x: screen.frame.midX - hostWidth / 2,
                y: screen.frame.maxY - hostHeight,
                width: hostWidth,
                height: hostHeight
            ),
            display: true
        )
    }

    private static func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

#if DEBUG
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
