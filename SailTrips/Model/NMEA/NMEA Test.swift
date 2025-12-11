//
//  NMEA Test.swift
//  SailTrips
//
//  Created by jeroen kok on 11/12/2025.
//

import Foundation
import Network


enum NMEAMode: String, CaseIterable, Identifiable {
    case nmea0183 = "NMEA 0183"
    case nmea2000 = "NMEA 2000"

    var id: String { rawValue }
}

struct NMEATestResult {
    var gpsLat: Double?
    var gpsLong: Double?

    var STW: Float?
    var SOG: Float?

    var AWA: Int?
    var AWS: Int?
    var TWA: Int?
    var TWS: Int?
    var TWD: Int?

    var pressure: Float?
    var airTemp: Int?
    var waterTemp: Int?

    var magHeading: Int?
    var heel: Float?

    var error: String?

    var isComplete: Bool {
        gpsLat != nil &&
        gpsLong != nil &&
        STW != nil &&
        SOG != nil &&
        AWA != nil &&
        AWS != nil &&
        TWA != nil &&
        TWS != nil &&
        TWD != nil &&
        pressure != nil &&
        airTemp != nil &&
        waterTemp != nil &&
        magHeading != nil &&
        heel != nil
    }
}

enum NMEAError: Error {
    case invalidHostOrPort
    case connectionFailed(String)
    case receiveFailed(String)
    case cancelled
}

// MARK: - NMEA 0183 parser

struct NMEA0183Parser {
    static func update(result: inout NMEATestResult, from line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.first == "$" || trimmed.first == "!" else { return }

        // Strip checksum part after *
        let sentence: String
        if let star = trimmed.firstIndex(of: "*") {
            sentence = String(trimmed[..<star])
        } else {
            sentence = trimmed
        }

        let fields = sentence.split(separator: ",", omittingEmptySubsequences: false)
        guard !fields.isEmpty else { return }

        let talkerAndType = String(fields[0]) // e.g. "$GPGGA", "!AIVDM"
        guard talkerAndType.count >= 3 else { return }

        let type = String(talkerAndType.suffix(3)) // "GGA", "RMC", "VTG", ...

        switch type {
        case "GGA":
            parseGGA(fields, into: &result)
        case "RMC":
            parseRMC(fields, into: &result)
        case "VTG":
            parseVTG(fields, into: &result)
        case "VHW":
            parseVHW(fields, into: &result)
        case "MWV":
            parseMWV(fields, into: &result)
        case "MWD":
            parseMWD(fields, into: &result)
        case "MMB":
            parseMMB(fields, into: &result)
        case "MTA":
            parseMTA(fields, into: &result)
        case "MTW":
            parseMTW(fields, into: &result)
        case "HDM", "HDG":
            parseHeading(fields, into: &result)
        case "XDR":
            parseXDR(fields, into: &result)
        default:
            break
        }
    }

    // MARK: - Sentence specific parsers

    private static func parseGGA(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxGGA, time, lat, N/S, lon, E/W, ...
        guard f.count >= 6 else { return }
        if let lat = decodeLatLon(dm: String(f[2]), hemi: f[3].first) {
            r.gpsLat = lat
        }
        if let lon = decodeLatLon(dm: String(f[4]), hemi: f[5].first) {
            r.gpsLong = lon
        }
    }

    private static func parseRMC(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxRMC, time, status, lat, N/S, lon, E/W, sogKnots, cog, ...
        guard f.count >= 9 else { return }

        if let lat = decodeLatLon(dm: String(f[3]), hemi: f[4].first) {
            r.gpsLat = lat
        }
        if let lon = decodeLatLon(dm: String(f[5]), hemi: f[6].first) {
            r.gpsLong = lon
        }
        if let sog = Double(f[7]) {
            r.SOG = Float(sog)
        }
    }

    private static func parseVTG(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxVTG, trackTrue, T, trackMag, M, sogKnots, N, sogKmh, K
        guard f.count >= 7 else { return }
        if let sog = Double(f[5]) {
            r.SOG = Float(sog)
        }
    }

    private static func parseVHW(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxVHW, headingTrue, T, headingMag, M, stwKnots, N, stwKmh, K
        guard f.count >= 7 else { return }
        if let stw = Double(f[5]) {
            r.STW = Float(stw)
        }
    }

    private static func parseMWV(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxMWV, angle, ref, speed, units, status, mode
        guard f.count >= 6 else { return }
        guard let angleDeg = Double(f[1]) else { return }
        let units = f[3]
        guard let speedRaw = Double(units.isEmpty ? "0" : f[3]) else { return }

        var speedKnots: Double = speedRaw
        // units: N=knots, M=m/s, K=km/h
        if units == "M" {
            speedKnots = speedRaw * 1.94384
        } else if units == "K" {
            speedKnots = speedRaw * 0.539957
        }

        // ref: R=relative/apparent, T=true
        let ref = f[2]
        if ref == "R" {
            r.AWA = Int(angleDeg.rounded())
            r.AWS = Int(speedKnots.rounded())
        } else if ref == "T" {
            r.TWA = Int(angleDeg.rounded())
            r.TWS = Int(speedKnots.rounded())
        }
    }

    private static func parseMWD(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxMWD, windDirTrue, T, windDirMag, M, speedKnots, N, speedMs, M
        guard f.count >= 2 else { return }
        if let dir = Double(f[1]) {
            r.TWD = Int(dir.rounded())
        }
    }

    private static func parseMMB(_ f: [Substring], into r: inout NMEATestResult) {
        // $--MMB, pressureInches, I, pressureBars, B
        guard f.count >= 4 else { return }
        if let bars = Double(f[3]) {
            r.pressure = Float(bars * 1000.0) // bar -> hPa
        } else if let inches = Double(f[1]) {
            // fallback: inches of mercury to hPa
            r.pressure = Float(inches * 33.8639)
        }
    }

    private static func parseMTA(_ f: [Substring], into r: inout NMEATestResult) {
        // $--MTA, tempC, C
        guard f.count >= 2 else { return }
        if let t = Double(f[1]) {
            r.airTemp = Int(t.rounded())
        }
    }

    private static func parseMTW(_ f: [Substring], into r: inout NMEATestResult) {
        // $--MTW, tempC, C
        guard f.count >= 2 else { return }
        if let t = Double(f[1]) {
            r.waterTemp = Int(t.rounded())
        }
    }

    private static func parseHeading(_ f: [Substring], into r: inout NMEATestResult) {
        // $xxHDM, headingMag, M
        guard f.count >= 2 else { return }
        if let h = Double(f[1]) {
            r.magHeading = Int(h.rounded())
        }
    }

    private static func parseXDR(_ f: [Substring], into r: inout NMEATestResult) {
        // $--XDR, type, value, units, id, ...
        // We look for a "heel" / "roll" measurement.
        guard f.count >= 5 else { return }
        // This sentence can contain multiple groups of 4 fields, we scan all:
        let groupSize = 4
        let startIndex = 1
        let endIndex = f.count - groupSize
        guard endIndex >= startIndex else { return }

        var i = startIndex
        while i <= endIndex {
            let type = f[i]       // e.g. "A" or "N"
            let value = f[i + 1]  // numeric
            let units = f[i + 2]  // e.g. "D" (degrees)
            let id    = f[i + 3].lowercased()

            if units == "D",
               id.contains("heel") || id.contains("roll"),
               let v = Double(value) {
                r.heel = Float(v)
                return
            }

            i += groupSize
        }
    }

    // MARK: - Coordinate helper

    private static func decodeLatLon(dm: String, hemi: Character?) -> Double? {
        guard !dm.isEmpty else { return nil }
        guard let hemi = hemi else { return nil }

        // Lat uses 2 deg digits, Lon 3. Decide based on hemisphere.
        let isLat = (hemi == "N" || hemi == "S")
        let degDigits = isLat ? 2 : 3
        guard dm.count > degDigits else { return nil }

        let degPart = String(dm.prefix(degDigits))
        let minPart = String(dm.suffix(dm.count - degDigits))

        guard let deg = Double(degPart),
              let minutes = Double(minPart) else { return nil }

        var value = deg + minutes / 60.0
        if hemi == "S" || hemi == "W" {
            value = -value
        }
        return value
    }
}

// MARK: - UDP client

final class NMEAUDPClient {
    private let connection: NWConnection
    private let mode: NMEAMode

    init(host: String, port: Int, mode: NMEAMode) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw NMEAError.invalidHostOrPort
        }
        self.mode = mode
        self.connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .udp
        )
    }

    func runSample(timeout: TimeInterval, cancelFlag: @escaping () -> Bool) async throws -> NMEATestResult {
        var result = NMEATestResult()

        let queue = DispatchQueue(label: "NMEAUDPClient")
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                print("NMEA UDP connection failed: \(error)")
            default:
                break
            }
        }
        connection.start(queue: queue)

        // Optional: send a single empty datagram to "open" path / NAT mapping.
        connection.send(content: Data(), completion: .contentProcessed { _ in })

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline && !result.isComplete && !cancelFlag() {
            let data = try await receiveDatagram()
            guard !data.isEmpty else { continue }

            if let text = String(data: data, encoding: .ascii) {
                for line in text.split(whereSeparator: \.isNewline) {
                    let s = String(line)
                    // For now, treat both modes as 0183 text stream.
                    // Later: add dedicated N2K PGN parsing for `.nmea2000`.
                    NMEA0183Parser.update(result: &result, from: s)
                }
            }
        }

        connection.cancel()
        return result
    }

    private func receiveDatagram() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { data, _, _, error in
                if let error {
                    continuation.resume(throwing: NMEAError.receiveFailed(error.localizedDescription))
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
}

final class NMEANetworkService: @unchecked Sendable {
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func runOneShotTest(for boat: Boat, mode: NMEAMode) async -> NMEATestResult {
        isCancelled = false

        let host = boat.wifiNMEAIP
        let port = Int(boat.wifiNMEAPort) ?? 0
        let _ = boat.wifiNMEAPW   // password if you need to send any auth later

        guard !host.isEmpty, port > 0 else {
            return NMEATestResult(
                gpsLat: nil,
                gpsLong: nil,
                STW: nil,
                SOG: nil,
                AWA: nil,
                AWS: nil,
                TWA: nil,
                TWS: nil,
                TWD: nil,
                pressure: nil,
                airTemp: nil,
                waterTemp: nil,
                magHeading: nil,
                heel: nil,
                error: "Missing or invalid NMEA host/port on this boat."
            )
        }

        do {
            let client = try NMEAUDPClient(host: host, port: port, mode: mode)
            // 30 seconds max by default; tweak if you like.
            let result = try await client.runSample(timeout: 30.0) { [weak self] in
                self?.isCancelled ?? false
            }

            return result
        } catch {
            return NMEATestResult(
                gpsLat: nil,
                gpsLong: nil,
                STW: nil,
                SOG: nil,
                AWA: nil,
                AWS: nil,
                TWA: nil,
                TWS: nil,
                TWD: nil,
                pressure: nil,
                airTemp: nil,
                waterTemp: nil,
                magHeading: nil,
                heel: nil,
                error: "Connection / parsing error: \(error)"
            )
        }
    }
}
