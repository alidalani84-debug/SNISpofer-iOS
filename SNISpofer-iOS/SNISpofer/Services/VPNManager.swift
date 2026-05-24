// VPNManager.swift - Manages VPN tunnel lifecycle via NetworkExtension
import Foundation
import NetworkExtension
import Combine

@MainActor
class VPNManager: ObservableObject {

    static let shared = VPNManager()

    @Published var state: ConnectionState = .disconnected
    @Published var stats: TrafficStats    = TrafficStats()
    @Published var logs:  [String]        = []

    private var manager:    NETunnelProviderManager?
    private var timer:      Timer?
    private var startDate:  Date?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Task { await loadManager() }
        observeVPNStatus()
    }

    // MARK: - Load / Create Manager

    private func loadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                self.manager = existing
                self.state   = .from(vpnStatus: existing.connection.status)
            } else {
                self.manager = try await createManager()
            }
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }

    private func createManager() async throws -> NETunnelProviderManager {
        let m     = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = VPNConstants.tunnelBundleIdentifier
        proto.serverAddress            = "SNI Spoofer"
        m.protocolConfiguration        = proto
        m.localizedDescription         = VPNConstants.vpnDescription
        m.isEnabled                    = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        return m
    }

    // MARK: - Connect / Disconnect

    func connect(config: AppConfig) {
        ConfigManager.shared.save(config)
        guard let manager = manager else { return }

        do {
            let data    = try JSONEncoder().encode(config)
            let options: [String: NSObject] = ["config": data as NSData]
            try manager.connection.startVPNTunnel(options: options)
            state = .connecting
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        state = .disconnecting
    }

    // MARK: - Status Observation

    private func observeVPNStatus() {
        NotificationCenter.default
            .publisher(for: .NEVPNStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let conn = notification.object as? NEVPNConnection else { return }
                Task { @MainActor in
                    self?.handleStatus(conn.status)
                }
            }
            .store(in: &cancellables)
    }

    private func handleStatus(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            startDate = Date()
            state     = .connected(since: startDate!)
            startStatsTimer()
            addLog("✅ اتصال برقرار شد")
        case .disconnected:
            state = .disconnected
            stopStatsTimer()
            stats = TrafficStats()
            addLog("🔴 اتصال قطع شد")
        case .connecting:
            state = .connecting
            addLog("🟡 در حال اتصال...")
        case .disconnecting:
            state = .disconnecting
            addLog("🟡 در حال قطع اتصال...")
        case .invalid:
            state = .failed("تنظیمات VPN نامعتبر است")
        case .reasserting:
            addLog("🔄 بازیابی اتصال...")
        @unknown default:
            break
        }
    }

    // MARK: - Stats Timer

    private func startStatsTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in
                self.stats.duration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopStatsTimer() {
        timer?.invalidate()
        timer = nil
        startDate = nil
    }

    // MARK: - Logs

    func addLog(_ message: String) {
        logs.append(message)
        if logs.count > 300 { logs.removeFirst(logs.count - 300) }
        ConfigManager.shared.appendLog(message)
    }

    func clearLogs() {
        logs.removeAll()
        ConfigManager.shared.clearLogs()
    }

    func refreshLogs() {
        logs = ConfigManager.shared.getLogs()
    }
}
