N//
//  Untitled.swift
//  SailTrips
//
//  Created by jeroen kok on 11/12/2025.
//

import Foundation
/// Parser for the subset of NMEA 2000 PGNs used in your AF15 test.
final class NMEA2000Parser {
    
    /// Main entry point: feed one RAW line; it updates the snapshot in-place.
    /// Returns true if any of the fields changed.
    func update(fromRawLine line: String, into snapshot: inout NMEA2000Snapshot) {
        guard let frame = try? parseRawN2KLine(line) else { return }
        
        switch frame.pgn {
        case 129025: // Position, Rapid Update :contentReference[oaicite:4]{index=4}
            decode129025(frame, into: &snapshot)
            
        case 128259: // Speed, Water referenced :contentReference[oaicite:5]{index=5}
            decode128259(frame, into: &snapshot)
            
        case 129026: // COG & SOG, Rapid Update :contentReference[oaicite:6]{index=6}
            decode129026(frame, into: &snapshot)
            
        case 130306: // Wind Data :contentReference[oaicite:7]{index=7}
            decode130306(frame, into: &snapshot)
            
        case 130310: // Environmental Parameters (obsolete but widely used) :contentReference[oaicite:8]{index=8}
            decode130310(frame, into: &snapshot)
            
        case 130311: // Environmental Parameters (with TemperatureSource) :contentReference[oaicite:9]{index=9}
            decode130311(frame, into: &snapshot)
            
        case 130312: // Temperature (extra safety) :contentReference[oaicite:10]{index=10}
            decode130312(frame, into: &snapshot)
            
        case 130314: // Actual Pressure :contentReference[oaicite:11]{index=11}
            decode130314(frame, into: &snapshot)
            
        case 127250: // Vessel Heading :contentReference[oaicite:12]{index=12}
            decode127250(frame, into: &snapshot)
            
        default:
            break
        }
    }
    fileprivate func decode129025(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 8,
              let latRaw = s32(d, 0),
              let lonRaw = s32(d, 4),
              !isS32NA(latRaw),
              !isS32NA(lonRaw)
        else { return }
        
        // 1e-7 degrees :contentReference[oaicite:13]{index=13}
        snapshot.latitude = Double(latRaw) * 1e-7
        snapshot.longitude = Double(lonRaw) * 1e-7
    }
    fileprivate func decode128259(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 5,
              let stwRaw = u16(d, 1),
              !isU16NA(stwRaw)
        else { return }
        
        // Speed Water Referenced: 0.01 m/s :contentReference[oaicite:14]{index=14}
        let stwMps = Double(stwRaw) * 0.01
        let stwKn = stwMps * mpsToKnots
        snapshot.stw = stwKn
    }
    fileprivate func decode129026(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 7 else { return }
        
        // COG: bytes 2-3, 0.0001 rad; SOG: bytes 4-5, 0.01 m/s :contentReference[oaicite:15]{index=15}
        if let cogRaw = u16(d, 2), !isU16NA(cogRaw) {
            let cogRad = Double(cogRaw) * 0.0001
            var cogDeg = cogRad * radiansToDegrees
            // Normalise 0..360
            cogDeg.formTruncatingRemainder(dividingBy: 360.0)
            if cogDeg < 0 { cogDeg += 360 }
            // COG is not required in your test list, but you may want it later.
            // For now we do not store it directly; you could add a field if useful.
        }
        
        if let sogRaw = u16(d, 4), !isU16NA(sogRaw) {
            let sogMps = Double(sogRaw) * 0.01
            snapshot.sog = sogMps * mpsToKnots
        }
    }
    fileprivate func decode130306(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 7,
              let speedRaw = u16(d, 1),
              let angleRaw = u16(d, 3),
              !isU16NA(speedRaw),
              !isU16NA(angleRaw)
        else { return }
        
        // Wind Speed: 0.01 m/s; Wind Angle: 0.0001 rad :contentReference[oaicite:17]{index=17}
        let windMps = Double(speedRaw) * 0.01
        let windKn = windMps * mpsToKnots
        
        let angleRad = Double(angleRaw) * 0.0001
        var angleDeg = angleRad * radiansToDegrees
        // Convert 0..360 -> signed -180..+180 for boat-referenced angles
        while angleDeg > 180 { angleDeg -= 360 }
        while angleDeg < -180 { angleDeg += 360 }
        
        let ref = d[5] & 0x07 // 3-bit WIND_REFERENCE
        
        switch ref {
        case 2: // Apparent
            snapshot.aws = windKn
            snapshot.awa = angleDeg
            
        case 0: // True, ground referenced to North -> direction (TWD)
            snapshot.tws = windKn
            var dir = angleRad * radiansToDegrees
            dir.formTruncatingRemainder(dividingBy: 360)
            if dir < 0 { dir += 360 }
            snapshot.twd = dir
            
        case 3, 4: // True, boat / water referenced -> TWA/TWS
            snapshot.tws = windKn
            snapshot.twa = angleDeg
            
        default:
            break
        }
    }
    fileprivate func decode130310(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 7 else { return }
        
        // Water Temperature: bytes 1-2, 0.01 K
        if let rawWater = u16(d, 1), !isU16NA(rawWater) {
            let tempK = Double(rawWater) * 0.01
            let tempC = tempK - 273.15
            snapshot.waterTemperature = tempC
        }
        
        // Outside Air Temperature: bytes 3-4, 0.01 K
        if let rawAir = u16(d, 3), !isU16NA(rawAir) {
            let tempK = Double(rawAir) * 0.01
            let tempC = tempK - 273.15
            snapshot.airTemperature = tempC
        }
        
        // Atmospheric Pressure: bytes 5-6, 100 Pa (i.e. hPa directly) :contentReference[oaicite:18]{index=18}
        if let rawP = u16(d, 5), !isU16NA(rawP) {
            snapshot.barometricPressure = Double(rawP) // hPa
        }
    }
    fileprivate func decode130311(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 8 else { return }
        
        // Temperature 0.01 K at bytes 3-4; Pressure 100 Pa at bytes 6-7 :contentReference[oaicite:19]{index=19}
        if let tRaw = u16(d, 3), !isU16NA(tRaw) {
            let tempK = Double(tRaw) * 0.01
            let tempC = tempK - 273.15
            
            // We don't decode TEMPERATURE_SOURCE here, but if you want
            // to distinguish air vs water later, you can use d[1].
            // For now, if airTemperature is still nil, we fill it.
            if snapshot.airTemperature == nil {
                snapshot.airTemperature = tempC
            }
        }
        
        if let pRaw = u16(d, 6), !isU16NA(pRaw) {
            let hPa = Double(pRaw) // 100 Pa -> hPa
            if snapshot.barometricPressure == nil {
                snapshot.barometricPressure = hPa
            }
        }
    }

    fileprivate func decode130312(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 7 else { return }
        
        // Actual Temperature 0.01 K at bytes 4-5; Source in byte 3 :contentReference[oaicite:20]{index=20}
        if let rawT = u16(d, 4), !isU16NA(rawT) {
            let tempK = Double(rawT) * 0.01
            let tempC = tempK - 273.15
            
            let source = d[3]
            // Very rough heuristic:
            // (You can refine using TEMPERATURE_SOURCE enum later.)
            if snapshot.waterTemperature == nil {
                snapshot.waterTemperature = tempC
            } else if snapshot.airTemperature == nil {
                snapshot.airTemperature = tempC
            } else {
                _ = source  // keep the compiler quiet for now
            }
        }
    }

    fileprivate func decode130314(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 8 else { return }
        
        // Pressure: 0.1 Pa, 32-bit signed at bytes 4-7 :contentReference[oaicite:21]{index=21}
        if let rawP = s32(d, 4), !isS32NA(rawP) {
            let pa = Double(rawP) * 0.1
            let hPa = pa / 100.0
            if snapshot.barometricPressure == nil {
                snapshot.barometricPressure = hPa
            }
        }
    }
    fileprivate func decode127250(_ frame: N2KFrame, into snapshot: inout NMEA2000Snapshot) {
        let d = frame.data
        guard d.count >= 6,
              let headingRaw = u16(d, 1),
              !isU16NA(headingRaw)
        else { return }
        
        let headingRad = Double(headingRaw) * 0.0001
        var hdgDeg = headingRad * radiansToDegrees
        hdgDeg.formTruncatingRemainder(dividingBy: 360)
        if hdgDeg < 0 { hdgDeg += 360 }
        
        // Reference: 0 = True, 1 = Magnetic :contentReference[oaicite:23]{index=23}
        let referenceBits = d[5] & 0x03
        switch referenceBits {
        case 0:
            snapshot.trueHeading = hdgDeg
        case 1:
            snapshot.magneticHeading = hdgDeg
        default:
            // Unknown reference, store as true if nothing else is present
            if snapshot.trueHeading == nil && snapshot.magneticHeading == nil {
                snapshot.trueHeading = hdgDeg
            }
        }
    }

}

