// Config.swift - Shared config model (mirrors config.json from Windows app)
import Foundation

enum ConnectionMode: String, Codable, CaseIterable, Identifiable {
    case sniOnly  = "SNI Only"
    case trojan   = "Trojan"
    case warp     = "WARP"
    case psiphon  = "Psiphon"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sniOnly:  return "shield.fill"
        case .trojan:   return "bolt.shield.fill"
        case .warp:     return "cloud.fill"
        case .psiphon:  return "antenna.radiowaves.left.and.right"
        }
    }
    var description: String {
        switch self {
        case .sniOnly:  return "جعل SNI برای عبور از فیلترینگ"
        case .trojan:   return "پروتکل Trojan روی WebSocket/TLS"
        case .warp:     return "تونل از طریق Cloudflare WARP"
        case .psiphon:  return "اتصال از طریق Psiphon"
        }
    }
}

struct AppConfig: Codable, Equatable {
    // General
    var connectionMode: ConnectionMode = .sniOnly
    var listenHost: String = "127.0.0.1"
    var listenPort: Int    = 40443
    var connectIP:  String = "104.19.229.21"
    var connectPort: Int   = 443
    var fakeSNI:    String = "www.hcaptcha.com"
    var socksPort:  Int    = 10808
    var httpPort:   Int    = 10809

    // Trojan
    var trojanPassword:  String = "humanity"
    var trojanSNI:       String = "www.creationlong.org"
    var trojanTransport: String = "ws"
    var trojanPath:      String = "/assignment"
    var trojanHost:      String = "www.creationlong.org"

    // WARP
    var warpEndpoint: String = "162.159.192.1"
    var warpLicense:  String = ""

    // Psiphon
    var psiphonCountry:  String = "DE"
    var psiphonEndpoint: String = "162.159.193.1"
    var psiphonLicense:  String = ""

    enum CodingKeys: String, CodingKey {
        case connectionMode  = "connection_mode"
        case listenHost      = "LISTEN_HOST"
        case listenPort      = "LISTEN_PORT"
        case connectIP       = "CONNECT_IP"
        case connectPort     = "CONNECT_PORT"
        case fakeSNI         = "FAKE_SNI"
        case socksPort       = "socks_port"
        case httpPort        = "http_port"
        case trojanPassword  = "trojan_password"
        case trojanSNI       = "trojan_sni"
        case trojanTransport = "trojan_transport"
        case trojanPath      = "trojan_path"
        case trojanHost      = "trojan_host"
        case warpEndpoint    = "warp_endpoint"
        case warpLicense     = "warp_license"
        case psiphonCountry  = "psiphon_country"
        case psiphonEndpoint = "psiphon_endpoint"
        case psiphonLicense  = "psiphon_license"
    }

    static var `default`: AppConfig { AppConfig() }
}
