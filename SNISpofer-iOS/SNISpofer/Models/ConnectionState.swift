// ConnectionState.swift
import Foundation
import NetworkExtension

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayTitle: String {
        switch self {
        case .disconnected:   return "غیر متصل"
        case .connecting:     return "در حال اتصال..."
        case .connected:      return "متصل"
        case .disconnecting:  return "در حال قطع..."
        case .failed(let e):  return "خطا: \(e)"
        }
    }

    var color: String {
        switch self {
        case .connected:    return "green"
        case .connecting,
             .disconnecting: return "yellow"
        case .disconnected: return "gray"
        case .failed:       return "red"
        }
    }

    static func from(vpnStatus: NEVPNStatus) -> ConnectionState {
        switch vpnStatus {
        case .connected:     return .connected(since: Date())
        case .connecting:    return .connecting
        case .disconnecting: return .disconnecting
        case .disconnected:  return .disconnected
        case .invalid,
             .reasserting:   return .disconnected
        @unknown default:    return .disconnected
        }
    }

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.disconnecting, .disconnecting):
            return true
        case (.connected(let a), .connected(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

struct TrafficStats {
    var bytesIn:  Int64 = 0
    var bytesOut: Int64 = 0
    var duration: TimeInterval = 0

    var formattedIn:  String { formatBytes(bytesIn) }
    var formattedOut: String { formatBytes(bytesOut) }
    var formattedDuration: String { formatDuration(duration) }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
