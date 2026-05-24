// TLSParser.swift - Parses TLS 1.2/1.3 ClientHello and finds/replaces SNI
import Foundation

struct TLSParser {

    // TLS record structure:
    // [0]     ContentType   (0x16 = Handshake)
    // [1-2]   Version       (0x0301..0x0303)
    // [3-4]   Length        (uint16 big-endian)
    // [5]     HandshakeType (0x01 = ClientHello)
    // [6-8]   HandshakeLen  (uint24 big-endian)
    // [9-10]  ClientVersion
    // [11-42] Random        (32 bytes)
    // [43]    SessionIDLen
    // ...

    struct SNILocation {
        let nameStart:  Int   // byte offset of the hostname bytes
        let nameLength: Int   // current hostname byte count
    }

    /// Returns the location of the SNI hostname inside `bytes`, or nil.
    static func findSNI(in bytes: [UInt8]) -> SNILocation? {
        guard bytes.count > 43 else { return nil }
        guard bytes[0] == 0x16 else { return nil }          // Handshake record
        guard bytes[5] == 0x01 else { return nil }          // ClientHello

        var offset = 43

        // Skip SessionID
        guard offset < bytes.count else { return nil }
        let sidLen = Int(bytes[offset]); offset += 1 + sidLen

        // Skip CipherSuites
        guard offset + 2 <= bytes.count else { return nil }
        let csLen = (Int(bytes[offset]) << 8) | Int(bytes[offset+1])
        offset += 2 + csLen

        // Skip Compression Methods
        guard offset < bytes.count else { return nil }
        let cmLen = Int(bytes[offset]); offset += 1 + cmLen

        // Extensions total length
        guard offset + 2 <= bytes.count else { return nil }
        offset += 2

        // Walk extensions
        while offset + 4 <= bytes.count {
            let extType   = (Int(bytes[offset]) << 8) | Int(bytes[offset+1])
            let extLen    = (Int(bytes[offset+2]) << 8) | Int(bytes[offset+3])
            offset += 4

            if extType == 0x0000 {   // SNI extension (RFC 6066)
                // server_name_list_length (2) | name_type (1) | name_length (2) | name
                guard offset + 5 <= bytes.count else { return nil }
                let nameLen  = (Int(bytes[offset+3]) << 8) | Int(bytes[offset+4])
                let nameStart = offset + 5
                guard nameStart + nameLen <= bytes.count else { return nil }
                return SNILocation(nameStart: nameStart, nameLength: nameLen)
            }
            offset += extLen
        }
        return nil
    }

    /// Returns a new Data with the SNI hostname replaced by `newSNI`.
    /// Correctly patches all enclosing length fields.
    static func replaceSNI(in data: Data, with newSNI: String) -> Data? {
        var bytes   = [UInt8](data)
        guard let loc = findSNI(in: bytes) else { return nil }

        let oldName = Array(bytes[loc.nameStart ..< loc.nameStart + loc.nameLength])
        let newName = Array(newSNI.utf8)
        let delta   = newName.count - oldName.count   // may be 0, +, or -

        // Splice in new name
        bytes.replaceSubrange(loc.nameStart ..< loc.nameStart + loc.nameLength,
                              with: newName)

        if delta == 0 { return Data(bytes) }

        // Patch length fields (all are big-endian):
        //  TLS record length:          bytes[3..4]  (uint16)
        //  Handshake body length:      bytes[6..8]  (uint24)
        //  ClientHello body length is implicit via Handshake length
        //  Extensions total length:    located after compression methods
        //  SNI extension data length:  ext body at (SNI ext offset + 2..3)
        //  server_name_list_length:    SNI body + 0..1
        //  name_length:                SNI body + 3..4

        // We patch only TLS record and Handshake — the inner extension/list
        // lengths are already correct because we spliced the exact bytes.
        // But we MUST also fix: ext_data_len, list_len, name_len (they are
        // *before* our splice point so their offsets did not shift).

        func patchU16(at i: Int, delta: Int) {
            let v = (Int(bytes[i]) << 8 | Int(bytes[i+1])) + delta
            bytes[i]   = UInt8((v >> 8) & 0xFF)
            bytes[i+1] = UInt8(v & 0xFF)
        }
        func patchU24(at i: Int, delta: Int) {
            let v = (Int(bytes[i]) << 16 | Int(bytes[i+1]) << 8 | Int(bytes[i+2])) + delta
            bytes[i]   = UInt8((v >> 16) & 0xFF)
            bytes[i+1] = UInt8((v >> 8) & 0xFF)
            bytes[i+2] = UInt8(v & 0xFF)
        }

        patchU16(at: 3, delta: delta)    // TLS record length
        patchU24(at: 6, delta: delta)    // Handshake message length

        // Re-find SNI extension offsets in the (now mutated) buffer to fix inner lengths
        if let loc2 = findSNI(in: bytes) {
            // name_length sits 2 bytes before nameStart
            patchU16(at: loc2.nameStart - 2, delta: delta)  // name_length
            patchU16(at: loc2.nameStart - 4, delta: delta)  // server_name_list_length
            patchU16(at: loc2.nameStart - 8, delta: delta)  // ext_data_length  (ext body - 2)
        }

        return Data(bytes)
    }
}
