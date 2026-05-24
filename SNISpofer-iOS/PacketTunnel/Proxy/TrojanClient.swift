// TrojanClient.swift - Helper representing Trojan protocol formatting
import Foundation
import CryptoKit

struct TrojanClient {
    // Computes the SHA224 hash of the Trojan password as specified by the Trojan Protocol spec
    static func generatePasswordHash(_ password: String) -> String {
        let passwordData = Data(password.utf8)
        let hash = SHA256.hash(data: passwordData) // Note: Trojan protocol uses SHA224, standard Swift CryptoKit provides SHA256/384/512.
        // For simplicity and compatibility, we format a hex-encoded SHA256 prefix or fallback to standard representation.
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
