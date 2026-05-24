// SNISpoofer.swift - TCP listener that intercepts TLS and replaces SNI
import Foundation
import Network
import os.log

final class SNISpoofer {

    private let listenPort: UInt16
    private let targetHost: String
    private let targetPort: UInt16
    private let fakeSNI:    String
    private let logger = Logger(subsystem: "com.snispoofer.ios.PacketTunnel",
                                category: "SNISpoofer")
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "snispoofer.listener", qos: .userInitiated)

    init(listenPort: Int, targetHost: String, targetPort: Int, fakeSNI: String) {
        self.listenPort = UInt16(listenPort)
        self.targetHost = targetHost
        self.targetPort = UInt16(targetPort)
        self.fakeSNI    = fakeSNI
    }

    // MARK: - Start / Stop

    func start(completion: @escaping (Error?) -> Void) {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params,
                                      on: NWEndpoint.Port(rawValue: listenPort)!)

            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleInbound(conn)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.logger.info("SNI Spoofer listening on :\(self?.listenPort ?? 0)")
                    completion(nil)
                case .failed(let err):
                    self?.logger.error("Listener failed: \(err)")
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
        logger.info("SNI Spoofer stopped")
    }

    // MARK: - Handle Inbound Connection

    private func handleInbound(_ inbound: NWConnection) {
        inbound.start(queue: queue)

        // Read the first TLS record (≤16 KB)
        inbound.receive(minimumIncompleteLength: 1,
                        maximumLength: 16_384) { [weak self] data, _, _, error in
            guard let self else { return }

            if let error {
                self.logger.warning("Read error: \(error)")
                inbound.cancel(); return
            }
            guard let data, !data.isEmpty else {
                inbound.cancel(); return
            }

            // Attempt SNI replacement; fall back to original data
            let outboundFirst = TLSParser.replaceSNI(in: data, with: self.fakeSNI) ?? data
            self.logger.debug("SNI patched (\(data.count) → \(outboundFirst.count) bytes)")

            // Open connection to real server (plain TCP — no TLS here,
            // the client's TLS goes straight through after SNI is swapped)
            let outbound = NWConnection(
                host:       NWEndpoint.Host(self.targetHost),
                port:       NWEndpoint.Port(rawValue: self.targetPort)!,
                using:      .tcp
            )
            outbound.start(queue: self.queue)

            outbound.stateUpdateHandler = { state in
                if case .ready = state {
                    // Send patched ClientHello
                    outbound.send(content: outboundFirst,
                                  completion: .contentProcessed { _ in
                        // Pipe remaining bytes in both directions
                        self.pipe(from: inbound,  to: outbound)
                        self.pipe(from: outbound, to: inbound)
                    })
                } else if case .failed(let e) = state {
                    self.logger.error("Outbound failed: \(e)")
                    inbound.cancel()
                }
            }
        }
    }

    // MARK: - Bidirectional Pipe

    private func pipe(from src: NWConnection, to dst: NWConnection) {
        src.receive(minimumIncompleteLength: 1,
                    maximumLength: 65_536) { [weak self] data, _, isDone, error in
            if let data, !data.isEmpty {
                dst.send(content: data, completion: .contentProcessed { _ in
                    if !isDone { self?.pipe(from: src, to: dst) }
                })
            } else {
                dst.cancel()
            }
        }
    }
}
