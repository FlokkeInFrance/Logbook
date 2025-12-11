//
//  NMEA 2k data.swift
//  SailTrips
//
//  Created by jeroen kok on 11/12/2025.
//

import Foundation

/// Single snapshot of the data you want to test.
struct NMEA2000Snapshot {
    // Position
    var latitude: Double?      // deg
    var longitude: Double?     // deg
    
    // Speeds (knots)
    var stw: Double?           // Speed Through Water
    var sog: Double?           // Speed Over Ground
    
    // Wind (degrees / knots)
    var awa: Double?           // Apparent Wind Angle, boat-referenced (-180..+180)
    var aws: Double?           // Apparent Wind Speed
    var twa: Double?           // True Wind Angle, boat-referenced (-180..+180)
    var tws: Double?           // True Wind Speed
    var twd: Double?           // True Wind Direction, ground-referenced (0..360)
    
    // Environment
    var barometricPressure: Double? // hPa
    var airTemperature: Double?     // °C
    var waterTemperature: Double?   // °C
    
    // Heading
    var magneticHeading: Double?    // deg (if heading is magnetic)
    var trueHeading: Double?        // deg (if heading is true)
    
    /// Convenience: did we fill every field you want for the test?
    var isCompleteForTest: Bool {
        return latitude != nil &&
               longitude != nil &&
               stw != nil &&
               sog != nil &&
               awa != nil &&
               aws != nil &&
               twa != nil &&
               tws != nil &&
               twd != nil &&
               barometricPressure != nil &&
               airTemperature != nil &&
               waterTemperature != nil &&
               (magneticHeading != nil || trueHeading != nil)
    }
    fileprivate enum N2KParseError: Error {
        case invalidLine
        case invalidCANID
        case notEnoughBytes
    }

    fileprivate struct N2KFrame {
        let pgn: UInt32
        let priority: Int
        let source: UInt8
        let data: [UInt8] // up to 8 bytes
    }

    /// Parse a YDNR RAW N2K line, e.g.
    /// "17:33:21.107 R 19F51323 01 2F 30 70 00 2F 30 70"
    fileprivate func parseRawN2KLine(_ line: String) throws -> N2KFrame {
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        // Expect at least: time, direction, canID, one byte
        guard parts.count >= 4 else { throw N2KParseError.invalidLine }
        
        // parts[0] = time, parts[1] = 'R' or 'T'
        let idString = String(parts[2])
        
        guard let canId = UInt32(idString, radix: 16) else {
            throw N2KParseError.invalidCANID
        }
        
        // Bytes
        var bytes: [UInt8] = []
        for i in 3..<parts.count {
            if let b = UInt8(parts[i], radix: 16) {
                bytes.append(b)
            }
        }
        guard !bytes.isEmpty else { throw N2KParseError.notEnoughBytes }
        
        // Decode PGN from CAN ID (per NMEA 2000 / J1939 header layout) :contentReference[oaicite:3]{index=3}
        let priority = Int((canId >> 26) & 0x7)
        let pf = (canId >> 16) & 0xFF
        let ps = (canId >> 8) & 0xFF
        let sa = UInt8(canId & 0xFF)
        let rdp = (canId >> 24) & 0x3
        
        let pgn: UInt32
        if pf < 240 {
            // PDU1: PGN = [RDP][PF]00
            pgn = (rdp << 16) | (pf << 8)
        } else {
            // PDU2: PGN = [RDP][PF][PS]
            pgn = (rdp << 16) | (pf << 8) | ps
        }
        
        return N2KFrame(pgn: pgn, priority: priority, source: sa, data: bytes)
    }
    fileprivate let radiansToDegrees = 180.0 / Double.pi
    fileprivate let mpsToKnots = 1.9438444924574

    fileprivate func u16(_ data: [UInt8], _ idx: Int) -> UInt16? {
        guard idx + 1 < data.count else { return nil }
        return UInt16(data[idx]) | (UInt16(data[idx + 1]) << 8)
    }

    fileprivate func s16(_ data: [UInt8], _ idx: Int) -> Int16? {
        guard let v = u16(data, idx) else { return nil }
        return Int16(bitPattern: v)
    }

    fileprivate func u32(_ data: [UInt8], _ idx: Int) -> UInt32? {
        guard idx + 3 < data.count else { return nil }
        return UInt32(data[idx]) |
            (UInt32(data[idx + 1]) << 8) |
            (UInt32(data[idx + 2]) << 16) |
            (UInt32(data[idx + 3]) << 24)
    }

    fileprivate func s32(_ data: [UInt8], _ idx: Int) -> Int32? {
        guard let v = u32(data, idx) else { return nil }
        return Int32(bitPattern: v)
    }

    /// NMEA "not available" helpers
    fileprivate func isU16NA(_ v: UInt16, allBits: UInt16 = 0xFFFF) -> Bool {
        return v == allBits
    }

    fileprivate func isS32NA(_ v: Int32) -> Bool {
        return v == Int32(bitPattern: 0x7FFFFFFF)
    }

}
