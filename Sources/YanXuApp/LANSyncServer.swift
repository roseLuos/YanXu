import Foundation
import Network
import YanXuCore

@MainActor
final class LANSyncServer: ObservableObject {
    static let shared = LANSyncServer()
    static let port = NWEndpoint.Port(rawValue: 40567)!

    @Published private(set) var pairingCode: String
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var listener: NWListener?
    private var snapshot: (() -> AppData)?
    private var apply: ((AppData) -> Void)?
    private let queue = DispatchQueue(label: "com.shurose.yanxu.lan-sync")
    private static let pairingCodeKey = "yanxu.lan.pairing-code"

    private init() {
        pairingCode = UserDefaults.standard.string(forKey: Self.pairingCodeKey) ?? Self.makePairingCode()
        UserDefaults.standard.set(pairingCode, forKey: Self.pairingCodeKey)
    }

    var directEndpoint: String {
        let rawHost = Host.current().name ?? "Mac"
        let host = rawHost.contains(".") ? rawHost : "\(rawHost).local"
        return "\(host):\(Self.port.rawValue)"
    }

    func configure(snapshot: @escaping () -> AppData, apply: @escaping (AppData) -> Void) {
        self.snapshot = snapshot
        self.apply = apply
        startIfNeeded()
    }

    func renewPairingCode() {
        pairingCode = Self.makePairingCode()
        UserDefaults.standard.set(pairingCode, forKey: Self.pairingCodeKey)
        restart()
    }

    private static func makePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    func restart() {
        listener?.cancel()
        listener = nil
        isRunning = false
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: Self.port)
            listener.service = NWListener.Service(name: "YanXu", type: "_yanxu._tcp")
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.receive(on: connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isRunning = true
                        self.lastError = nil
                    case .failed(let error):
                        self.isRunning = false
                        self.lastError = error.localizedDescription
                        self.listener = nil
                    case .cancelled:
                        self.isRunning = false
                    default:
                        break
                    }
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            isRunning = false
            lastError = error.localizedDescription
        }
    }

    private func receive(on connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()

        func readNextChunk() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, _ in
                if let data { buffer.append(data) }
                guard let delimiter = buffer.firstIndex(of: 0x0A) else {
                    if isComplete || buffer.count > 2_000_000 { connection.cancel() } else { readNextChunk() }
                    return
                }
                let payload = buffer.prefix(upTo: delimiter)
                guard let self, let request = try? JSONDecoder().decode(LANSyncMessage.self, from: payload) else {
                    connection.cancel()
                    return
                }
                Task { @MainActor in
                    let response = self.response(for: request)
                    var raw = (try? JSONEncoder().encode(response)) ?? Data()
                    raw.append(0x0A)
                    connection.send(content: raw, completion: .contentProcessed { _ in connection.cancel() })
                }
            }
        }
        readNextChunk()
    }

    private func response(for request: LANSyncMessage) -> LANSyncMessage {
        guard request.pairingCode == pairingCode else {
            return LANSyncMessage(kind: .rejected, pairingCode: "", message: "配对码不正确")
        }
        guard let snapshot else {
            return LANSyncMessage(kind: .rejected, pairingCode: "", message: "Mac 端尚未准备好")
        }
        if request.kind == .sync, let incoming = request.data {
            apply?(LANSyncMerge.merge(snapshot(), incoming))
        }
        return LANSyncMessage(kind: .snapshot, pairingCode: "", data: snapshot())
    }
}
