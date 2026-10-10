import AppKit
import SwiftUI

struct YanXuSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            SyncSettingsPane()
                .tabItem {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 640, height: 520)
        .background(Color.yanxuCanvas)
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var researchIsland = ResearchIslandCoordinator.shared
    @ObservedObject private var appearance = ResearchIslandAppearanceStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsHeading(
                title: "灵动岛",
                detail: "管理桌面灵动岛的显示方式与外观。"
            )

            SurfaceCard {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        settingsIcon("capsule.fill", tint: .yanxuAccent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("显示灵动岛")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.yanxuInk)
                            Text(researchIsland.isVisible ? "正在桌面顶部显示" : "当前已隐藏")
                                .font(.caption)
                                .foregroundStyle(Color.yanxuMuted)
                        }

                        Spacer()

                        Toggle("", isOn: islandVisibility)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.vertical, 2)

                    Divider()
                        .foregroundStyle(Color.yanxuBorder)
                        .padding(.vertical, 13)

                    HStack(spacing: 14) {
                        settingsIcon(
                            appearance.mode == .dark ? "moon.fill" : "sun.max.fill",
                            tint: appearance.mode == .dark ? .yanxuViolet : .yanxuWarning
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("灵动岛外观")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.yanxuInk)
                            Text("仅改变灵动岛，不影响主界面。")
                                .font(.caption)
                                .foregroundStyle(Color.yanxuMuted)
                        }

                        Spacer()

                        Picker("灵动岛外观", selection: $appearance.mode) {
                            Text("浅色").tag(ResearchIslandAppearance.light)
                            Text("深色").tag(ResearchIslandAppearance.dark)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    .padding(.vertical, 2)
                }
            }

            Text("灵动岛关闭后，可随时在这里重新显示。拖动位置和收起状态仍可直接在灵动岛上操作。")
                .font(.caption2)
                .foregroundStyle(Color.yanxuMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
    }

    private var islandVisibility: Binding<Bool> {
        Binding(
            get: { researchIsland.isVisible },
            set: { isVisible in
                if isVisible {
                    researchIsland.show(store: store)
                } else {
                    researchIsland.hide()
                }
            }
        )
    }

}

private struct SyncSettingsPane: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var calendarSync = CalendarSyncManager.shared
    @ObservedObject private var lanSync = LANSyncServer.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeading(
                    title: "同步",
                    detail: "集中管理 Apple 日历与同一网络中的设备同步。"
                )

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            settingsIcon("iphone.and.arrow.forward", tint: .yanxuAccent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Apple 日历")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.yanxuInk)
                                Text("将有日期的计划和我的 DDL 单向写入 iCloud 日历。")
                                    .font(.caption)
                                    .foregroundStyle(Color.yanxuMuted)
                            }
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Circle()
                                .fill(calendarStatusColor)
                                .frame(width: 7, height: 7)
                            Text(calendarSync.statusText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(calendarStatusColor)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            if case .syncing = calendarSync.state {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .padding(10)
                        .background(calendarStatusColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

                        if calendarSync.isEnabled {
                            HStack(spacing: 9) {
                                Button {
                                    Task { await calendarSync.synchronizeNow() }
                                } label: {
                                    Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(PrimaryActionStyle())
                                .disabled(calendarSync.state == .syncing)

                                Button("暂停同步") {
                                    calendarSync.disable()
                                }
                                .buttonStyle(SecondaryActionStyle())
                            }
                        } else {
                            Button {
                                Task { await calendarSync.enable(data: store.data) }
                            } label: {
                                Label("开启 Apple 日历同步", systemImage: "calendar.badge.plus")
                            }
                            .buttonStyle(PrimaryActionStyle())
                            .disabled(calendarSync.state == .syncing)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            settingsIcon(lanSync.isRunning ? "wifi" : "wifi.slash", tint: .yanxuSuccess)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("同网同步")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.yanxuInk)
                                Text("供同一局域网中的研序设备配对使用。")
                                    .font(.caption)
                                    .foregroundStyle(Color.yanxuMuted)
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(lanSync.isRunning ? Color.yanxuSuccess : Color.yanxuDanger)
                                    .frame(width: 7, height: 7)
                                Text(lanSync.isRunning ? "运行中" : "未运行")
                                    .font(.caption)
                                    .foregroundStyle(Color.yanxuMuted)
                            }
                        }

                        HStack(spacing: 12) {
                            syncValue(title: "配对码", value: lanSync.pairingCode)
                            syncValue(title: "备用地址", value: lanSync.directEndpoint)
                        }

                        if let error = lanSync.lastError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(Color.yanxuDanger)
                        }

                        HStack(spacing: 9) {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(lanSync.directEndpoint, forType: .string)
                            } label: {
                                Label("复制备用地址", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(SecondaryActionStyle())

                            Button {
                                lanSync.renewPairingCode()
                            } label: {
                                Label("更新配对码", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(SecondaryActionStyle())
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var calendarStatusColor: Color {
        switch calendarSync.state {
        case .ready: .yanxuSuccess
        case .failed: .yanxuDanger
        case .syncing: .yanxuAccent
        case .disabled: .yanxuMuted
        }
    }

    private func syncValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.yanxuMuted)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.yanxuInk)
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yanxuRaised, in: RoundedRectangle(cornerRadius: 8))
    }
}

private func settingsHeading(title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.yanxuInk)
        Text(detail)
            .font(.system(size: 12))
            .foregroundStyle(Color.yanxuMuted)
    }
}

private func settingsIcon(_ name: String, tint: Color) -> some View {
    Image(systemName: name)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 34, height: 34)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
}
