import Foundation
import Network

@MainActor
final class LANSyncClient: ObservableObject {
    static let port = NWEndpoint.Port(rawValue: 40567)!
    enum Status: Equatable {
        case idle
        case findingMac
        case syncing
        case complete
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSuccessfulSyncAt: Date?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private static let lastSyncKey = "yanxu.lan.last-successful-sync"

    init() {
        let timestamp = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        lastSuccessfulSyncAt = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    func synchronize(
        data: AppData,
        pairingCode: String,
        manualHost: String = "",
        onSnapshot: @escaping (AppData) -> Void
    ) {
        guard pairingCode.count == 6 else {
            status = .failed("请输入 Mac 端显示的 6 位配对码")
            return
        }
        browser?.cancel()
        connection?.cancel()
        let host = Self.normalizedHost(manualHost)
        if !host.isEmpty {
            connect(
                to: .hostPort(host: NWEndpoint.Host(host), port: Self.port),
                data: data,
                pairingCode: pairingCode,
                onSnapshot: onSnapshot
            )
            return
        }
        status = .findingMac
        let browser = NWBrowser(for: .bonjour(type: "_yanxu._tcp", domain: nil), using: .tcp)
        self.browser = browser
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            browser.cancel()
            Task { @MainActor in self?.connect(to: endpoint, data: data, pairingCode: pairingCode, onSnapshot: onSnapshot) }
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                Task { @MainActor in self?.status = .failed(error.localizedDescription) }
            }
        }
        browser.start(queue: .main)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, self.status == .findingMac else { return }
            self.browser?.cancel()
            self.status = .failed("未发现 Mac：确认研序正在运行、两台设备在同一 Wi‑Fi，并允许本地网络权限")
        }
    }

    static func normalizedHost(_ value: String) -> String {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("tcp://") { host.removeFirst(6) }
        if host.hasSuffix(":\(port.rawValue)") { host.removeLast(6) }
        return host
    }

    private func connect(to endpoint: NWEndpoint, data: AppData, pairingCode: String, onSnapshot: @escaping (AppData) -> Void) {
        browser?.cancel()
        status = .syncing
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                Task { @MainActor in self?.status = .failed("无法连接 Mac：\(error.localizedDescription)") }
                return
            }
            guard case .ready = state else { return }
            let request = LANSyncMessage(kind: .sync, pairingCode: pairingCode, data: data)
            guard var raw = try? JSONEncoder().encode(request) else { return }
            raw.append(0x0A)
            connection.send(content: raw, completion: .contentProcessed { error in
                if let error {
                    Task { @MainActor in self?.status = .failed(error.localizedDescription) }
                    return
                }
                var buffer = Data()
                func readNextChunk() {
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { raw, _, isComplete, _ in
                        if let raw { buffer.append(raw) }
                        guard let delimiter = buffer.firstIndex(of: 0x0A) else {
                            if isComplete || buffer.count > 2_000_000 {
                                connection.cancel()
                                Task { @MainActor in self?.status = .failed("未收到完整的 Mac 同步数据") }
                            } else { readNextChunk() }
                            return
                        }
                        defer { connection.cancel() }
                        let payload = buffer.prefix(upTo: delimiter)
                        guard let response = try? JSONDecoder().decode(LANSyncMessage.self, from: payload) else {
                            Task { @MainActor in self?.status = .failed("Mac 返回的数据无法识别") }
                            return
                        }
                        Task { @MainActor in
                            if response.kind == .snapshot, let snapshot = response.data {
                                onSnapshot(snapshot)
                                self?.status = .complete
                                let completedAt = Date()
                                self?.lastSuccessfulSyncAt = completedAt
                                UserDefaults.standard.set(completedAt.timeIntervalSince1970, forKey: Self.lastSyncKey)
                            } else {
                                self?.status = .failed(response.message ?? "同步被拒绝")
                            }
                        }
                    }
                }
                readNextChunk()
            })
        }
        connection.start(queue: .main)
        Task { [weak self, weak connection] in
            try? await Task.sleep(for: .seconds(12))
            guard let self, self.status == .syncing else { return }
            connection?.cancel()
            self.status = .failed("连接超时：请确认 Mac 端研序正在运行，并检查配对码或备用地址")
        }
    }
}
