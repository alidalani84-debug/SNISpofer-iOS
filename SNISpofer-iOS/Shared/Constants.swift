// Constants.swift - Shared between App & PacketTunnel targets
import Foundation

enum AppGroup {
    static let identifier = "group.com.snispoofer.ios"
    static let configKey  = "AppConfig"
    static let logsKey    = "TunnelLogs"
}

enum VPNConstants {
    static let appBundleIdentifier    = "com.snispoofer.ios"
    static let tunnelBundleIdentifier = "com.snispoofer.ios.PacketTunnel"
    static let vpnDescription         = "SNI Spoofer"
}

enum TunnelMessageType: String {
    case getStatus = "getStatus"
    case getLogs   = "getLogs"
    case clearLogs = "clearLogs"
}
