//
//  NMEAAdapter.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//


import Foundation

final class NMEAAdapter: ObservableObject {

    @Published private(set) var latestSnapshot: NMEASnapshot?

    /// Temporary bridge: builds a coherent snapshot from the test result.
    /// Used ONLY while the NMEA test infrastructure is active.
    func updateFromTestResult(_ test: NMEATestResult) {
        latestSnapshot = NMEASnapshot(
            timestamp: Date(),   // test data has no true GPS time

            latitude: test.gpsLat,
            longitude: test.gpsLong,

            hdop: nil,
            fixQuality: nil,

            sog: test.SOG,
            cog: nil,            // not provided by test result
            stw: test.STW,

            magneticHeading: test.magHeading,
            trueHeading: nil,

            awa: test.AWA,
            aws: test.AWS,
            twd: test.TWD,
            tws: test.TWS,

            pressure: test.pressure,
            airTemperature: test.airTemp,
            waterTemperature: test.waterTemp,

            sourceID: "NMEA-Test"
        )
    }
}

