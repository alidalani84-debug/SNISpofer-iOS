import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var proxyServer: ProxyServer?
    private var sniSpoofer: SNISpofer? // Will point to SNISpoofer instance
    private var customSpoofer: SNISpoofer?
    private let logger = Logger(subsystem: "com.snispoofer.ios.PacketTunnel", category: "Provider")

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting VPN Tunnel...")

        // 1. Decode Configuration
        var config = AppConfig.default
        if let options = options, let configData = options["config"] as? Data {
            if let decoded = try? JSONDecoder().decode(AppConfig.self, from: configData) {
                config = decoded
            }
        }

        // 2. Setup Tunnel Network Settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // Routes: route all traffic through the tunnel
        settings.ipv4Settings = NEIPv4Settings(addresses: ["192.168.89.1"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        
        // DNS Server Settings
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings?.matchDomains = [""] // match all

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("Failed to set tunnel network settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            // 3. Initialize & Start Custom SNI Spoofer if in SNI Only mode
            if config.connectionMode == .sniOnly {
                self.customSpoofer = SNISpoofer(
                    listenPort: config.listenPort,
                    targetHost: config.connectIP,
                    targetPort: config.connectPort,
                    fakeSNI: config.fakeSNI
                )
                self.customSpoofer?.start { [weak self] spooferError in
                    if let spooferError = spooferError {
                        self?.logger.error("Failed to start SNISpoofer: \(spooferError.localizedDescription)")
                        completionHandler(spooferError)
                        return
                    }
                    self?.startLocalProxy(config: config, completionHandler: completionHandler)
                }
            } else {
                // For other modes (Trojan/WARP/Psiphon) we fallback or run proxy direct
                self.startLocalProxy(config: config, completionHandler: completionHandler)
            }
        }
    }

    private func startLocalProxy(config: AppConfig, completionHandler: @escaping (Error?) -> Void) {
        // Start local SOCKS5 proxy server
        proxyServer = ProxyServer(port: config.socksPort, config: config)
        proxyServer?.start { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to start SOCKS5 Proxy: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            self?.logger.info("VPN Tunnel started successfully. SOCKS5 active on :\(config.socksPort)")
            completionHandler(nil)
            
            // Start reading packet flow in background loop
            self?.readPackets()
        }
    }

    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, versions in
            guard let self = self else { return }
            
            // Normally we would parse IP/TCP packets here and feed them into SOCKS/TUN bridge
            // For a lightweight app, routing is primarily driven by DNS settings and Proxy settings
            // We loop back to keep the connection flow alive
            self.packetFlow.writePackets(packets, withProtocols: versions)
            self.readPackets()
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping VPN Tunnel...")
        proxyServer?.stop()
        customSpoofer?.stop()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        switch message {
        case TunnelMessageType.getStatus.rawValue:
            let status = "Running"
            completionHandler?(status.data(using: .utf8))
        case TunnelMessageType.clearLogs.rawValue:
            ConfigManager.shared.clearLogs()
            completionHandler?("Success".data(using: .utf8))
        default:
            completionHandler?(nil)
        }
    }
}
