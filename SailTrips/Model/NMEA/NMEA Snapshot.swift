//
//  NMEASnapshot.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//


import Foundation
import CoreLocation

/// A coherent navigation + environment snapshot coming from NMEA sources
/// (0183, N2K, proprietary PGNs, etc.).
///
/// All values are optional: availability depends on the connected instruments.
struct NMEASnapshot: Sendable {

    // MARK: - Position & time

    /// UTC timestamp provided by GPS (preferred) or reception time
    var timestamp: Date

    /// Position (WGS84, degrees)
    var latitude: Double?
    var longitude: Double?

    /// GPS quality / fix info (optional, future use)
    var hdop: Float?
    var fixQuality: GPSFixQuality?

    // MARK: - Navigation (ground / water)

    /// Speed Over Ground (knots)
    var sog: Float?

    /// Course Over Ground (degrees true, 0–359)
    var cog: Int?

    /// Speed Through Water (knots)
    var stw: Float?

    /// Heading (magnetic, degrees, 0–359)
    var magneticHeading: Int?

    /// Heading (true, degrees, 0–359), if directly available
    var trueHeading: Int?

    // MARK: - Wind

    /// Apparent Wind Angle (degrees, signed or unsigned by convention)
    var awa: Int?

    /// Apparent Wind Speed (knots)
    var aws: Int?

    /// True Wind Direction (degrees true)
    var twd: Int?

    /// True Wind Speed (knots)
    var tws: Int?

    // MARK: - Environment

    /// Atmospheric pressure (hPa)
    var pressure: Float?

    /// Air temperature (°C)
    var airTemperature: Int?

    /// Water temperature (°C)
    var waterTemperature: Int?

    // MARK: - Source metadata

    /// Identifier of the source (e.g. "NMEA0183", "NMEA2000", "Raymarine", "YDNR-02")
    var sourceID: String?

    /// Age of the snapshot in seconds (computed)
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    /// Is this snapshot fresh enough to be trusted for logging?
    func isFresh(maxAge: TimeInterval = 2.5) -> Bool {
        age <= maxAge
    }
}

// Optional helper enum
enum GPSFixQuality: Int, Sendable {
    case invalid = 0
    case gps = 1
    case dgps = 2
    case pps = 3
    case rtk = 4
}
