//
//  NMEA udpconnect.swift
//  SailTrips
//
//  Created by jeroen kok on 12/12/2025.
//

import Network
import Foundation

final class NMEAUDPBroadcastReceiver {
    private var listener: NWListener?
    private let mode: NMEAMode

    init(mode: NMEAMode) {
        self.mode = mode
    }

    func runSample(port: Int,
                   timeout: TimeInterval,
                   cancelFlag: @escaping () -> Bool) async throws -> NMEATestResult {

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw NMEAError.invalidHostOrPort
        }

        var result = NMEATestResult()
        var n2kSnapshot = NMEA2000Snapshot()
        let n2kParser = NMEA2000Parser()

        let params = NWParameters.udp
        // Helps if the OS thinks something else already used the port briefly.
        params.allowLocalEndpointReuse = true

        let queue = DispatchQueue(label: "NMEAUDPBroadcastReceiver")

        listener = try NWListener(using: params, on: nwPort)

        let deadline = Date().addingTimeInterval(timeout)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .failed(let err):
                print("UDP listener failed:", err)
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            conn.start(queue: queue)

            func receiveLoop() {
                conn.receiveMessage { data, _, _, error in
                    if let error {
                        print("UDP receive error:", error)
                        return
                    }
                    guard let data, !data.isEmpty else {
                        receiveLoop()
                        return
                    }

                    if let text = String(data: data, encoding: .ascii) {
                        for lineSub in text.split(whereSeparator: \.isNewline) {
                            let line = String(lineSub)
                            switch self.mode {
                            case .nmea0183:
                                NMEA0183Parser.update(result: &result, from: line)
                            case .nmea2000:
                                n2kParser.update(fromRawLine: line, into: &n2kSnapshot)
                                self.map(snapshot: n2kSnapshot, into: &result)
                            }
                        }
                    }
                    receiveLoop()
                }
            }

            receiveLoop()
        }

        listener?.start(queue: queue)

        // Poll until complete / timeout / cancel
        while Date() < deadline && !result.isComplete && !cancelFlag() {
            try await Task.sleep(nanoseconds: 150_000_000) // 0.15s
        }

        listener?.cancel()
        listener = nil

        if cancelFlag() {
            throw NMEAError.cancelled
        }

        return result
    }

    /// same mapping you already have
    private func map(snapshot: NMEA2000Snapshot, into result: inout NMEATestResult) {
        if let lat = snapshot.latitude { result.gpsLat = lat }
        if let lon = snapshot.longitude { result.gpsLong = lon }
        if let stw = snapshot.stw { result.STW = Float(stw) }
        if let sog = snapshot.sog { result.SOG = Float(sog) }

        if let awa = snapshot.awa { result.AWA = Int(awa.rounded()) }
        if let aws = snapshot.aws { result.AWS = Int(aws.rounded()) }
        if let twa = snapshot.twa { result.TWA = Int(twa.rounded()) }
        if let tws = snapshot.tws { result.TWS = Int(tws.rounded()) }
        if let twd = snapshot.twd { result.TWD = Int(twd.rounded()) }

        if let p = snapshot.barometricPressure { result.pressure = Float(p) }
        if let tAir = snapshot.airTemperature { result.airTemp = Int(tAir.rounded()) }
        if let tWater = snapshot.waterTemperature { result.waterTemp = Int(tWater.rounded()) }

        if let hMag = snapshot.magneticHeading {
            result.magHeading = Int(hMag.rounded())
        } else if let hTrue = snapshot.trueHeading {
            result.magHeading = Int(hTrue.rounded())
        }
    }
}
