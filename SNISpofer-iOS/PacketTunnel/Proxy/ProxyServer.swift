// ProxyServer.swift - A simple local SOCKS5 proxy server that forwards TCP/UDP traffic to our SNI Spoofer or Trojan client
import Foundation
import Network
import os.log

class ProxyServer {
    private let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "proxyserver.listener", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.snispoofer.ios.PacketTunnel", category: "ProxyServer")
    private let config: AppConfig

    init(port: Int, config: AppConfig) {
        self.port = UInt16(port)
        self.config = config
    }

    func start(completion: @escaping (Error?) -> Void) {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    completion(nil)
                case .failed(let err):
                    completion(err)
                default: break
                }
            }
            listener?.start(queue: queue)
        } catch {
            completion(error)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        // Simple SOCKS5 handshake implementation
        // 1. Read method selection message
        conn.receive(minimumIncompleteLength: 2, maximumLength: 257) { [weak self] data, _, _, err in
            guard let self = self, let data = data, err == nil else {
                conn.cancel()
                return
            }
            let bytes = [UInt8](data)
            guard bytes.count >= 2, bytes[0] == 0x05 else {
                conn.cancel() // Only SOCKS5 supported
                return
            }
            
            // Send method response: No authentication required (0x00)
            let response = Data([0x05, 0x00])
            conn.send(content: response, completion: .contentProcessed({ [weak self] sendErr in
                guard let self = self, sendErr == nil else {
                    conn.cancel()
                    return
                }
                self.handleRequest(conn)
            }))
        }
    }

    private func handleRequest(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 4, maximumLength: 512) { [weak self] data, _, _, err in
            guard let self = self, let data = data, err == nil else {
                conn.cancel()
                return
            }
            let bytes = [UInt8](data)
            guard bytes.count >= 4, bytes[0] == 0x05, bytes[1] == 0x01 else {
                conn.cancel() // Only CONNECT command (0x01) supported
                return
            }

            var destHost = ""
            var destPort: UInt16 = 0
            var requestLength = 4

            let atyp = bytes[3]
            if atyp == 0x01 { // IPv4
                guard bytes.count >= 10 else { conn.cancel(); return }
                destHost = "\(bytes[4]).\(bytes[5]).\(bytes[6]).\(bytes[7])"
                destPort = (UInt16(bytes[8]) << 8) | UInt16(bytes[9])
                requestLength = 10
            } else if atyp == 0x03 { // Domain name
                let nameLen = Int(bytes[4])
                guard bytes.count >= 7 + nameLen else { conn.cancel(); return }
                if let host = String(bytes: bytes[5..<(5 + nameLen)], encoding: .utf8) {
                    destHost = host
                }
                destPort = (UInt16(bytes[5 + nameLen]) << 8) | UInt16(bytes[5 + nameLen + 1])
                requestLength = 7 + nameLen
            } else {
                conn.cancel() // IPv6 (0x04) not implemented for simplicity
                return
            }

            // Route connection based on mode
            self.routeConnection(from: conn, destHost: destHost, destPort: destPort, requestLength: requestLength)
        }
    }

    private func routeConnection(from clientConn: NWConnection, destHost: String, destPort: UInt16, requestLength: Int) {
        // Prepare SOCKS5 success reply
        var reply = Data([0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

        // Determine destination endpoint
        let targetHost: String
        let targetPort: UInt16

        if self.config.connectionMode == .sniOnly {
            // Forward everything to our local SNI Spoofer running on listenPort
            targetHost = "127.0.0.1"
            targetPort = UInt16(self.config.listenPort)
        } else {
            // Directly forward to target
            targetHost = destHost
            targetPort = destPort
        }

        let remoteConn = NWConnection(host: NWEndpoint.Host(targetHost), port: NWEndpoint.Port(rawValue: targetPort)!, using: .tcp)
        remoteConn.start(queue: queue)

        remoteConn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                // Send success reply to client
                clientConn.send(content: reply, completion: .contentProcessed({ [weak self] err in
                    guard let self = self, err == nil else {
                        clientConn.cancel()
                        remoteConn.cancel()
                        return
                    }
                    // Start bi-directional piping
                    self.pipe(from: clientConn, to: remoteConn)
                    self.pipe(from: remoteConn, to: clientConn)
                }))
            case .failed(let err):
                self.logger.error("Failed to connect to remote: \(err)")
                clientConn.cancel()
            default: break
            }
        }
    }

    private func pipe(from src: NWConnection, to dst: NWConnection) {
        src.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isDone, err in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                dst.send(content: data, completion: .contentProcessed({ [weak self] sendErr in
                    if sendErr == nil && !isDone {
                        self?.pipe(from: src, to: dst)
                    } else {
                        dst.cancel()
                    }
                }))
            } else {
                dst.cancel()
                src.cancel()
            }
        }
    }
}
