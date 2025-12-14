//
//  Log Pipeline.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//

import Foundation
import CoreLocation
import SwiftData

// MARK: - ActionLogPipeline
enum ActionLogPipeline {

    struct Fix {
        var sogKn: Float?
        var cogDeg: Int?
        var stwKn: Float?
        var magHeadingDeg: Int?
        var awsKn: Int?
        var awaDeg: Int?
        var twsKn: Int?
        var twdDeg: Int?
    }

    struct PositionStamp {
        let date: Date
        let lat: Double
        let lon: Double
    }

    static func logNow(headerText: String, using ctx: ActionContext) {
        Task { @MainActor in
            await logNowAsync(headerText: headerText, using: ctx)
        }
    }

    @MainActor
    private static func logNowAsync(headerText: String, using ctx: ActionContext) async {
        guard let trip = ctx.instances.currentTrip else {
            ctx.showBanner("No active Trip – action not logged.")
            return
        }

        // 1) P1
        let p1 = await acquirePosition(using: ctx, fallbackToInstances: true)

        // 2) background “completion” delay (your spec)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // 3) P2
        var p2 = await acquirePosition(using: ctx, fallbackToInstances: true)

        // 4) validate P1→P2 vector vs last-log vector; maybe do P2'
        let last = fetchLastLog(for: trip, in: ctx.modelContext)
        if needsSecondMeasurement(p1: p1, p2: p2, lastLog: last) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s extra
            let p2b = await acquirePosition(using: ctx, fallbackToInstances: true)
            if needsSecondMeasurement(p1: p1, p2: p2b, lastLog: last) {
                ctx.showBanner("Position vector unreliable — using last-log average for SOG/COG.")
                p2 = p2b // keep last P2’ for Instances, even if “unreliable”
            } else {
                p2 = p2b
            }
        }

        // 5) Keep P2 in Instances
        ctx.instances.gpsCoordinatesLat = p2.lat
        ctx.instances.gpsCoordinatesLong = p2.lon

        // 6) Compute dynamic nav/wind fixes (only fill missing/weak values)
        var fix = Fix()
        applyNavFixes(
            into: &fix,
            p1: p1,
            p2: p2,
            lastLog: last,
            instances: ctx.instances,
            nmea: ctx.nmeaSnapshot()
        )


        // 7) COG vs bearing (magHeading) tier logic + prompt if needed
        await applyBearingDiscrepancyPolicy(into: &fix, ctx: ctx)

        // 8) Write log: P1 into log; fixes applied; everything else copied from Instances by LogWriter.
        let stack = LogQueue()
        let writer = LogWriter(context: ctx.modelContext)

        // Force log timestamp + position from P1 (your spec)
        stack.enqueue(key: "P1", text: "") { log in
            log.dateOfLog = p1.date
            log.posLat = p1.lat
            log.posLong = p1.lon
        }

        // Apply computed fixes to the log (without fighting the global “Instances -> Logs” mapping)
        applyFixToLogQueue(fix, stack: stack)

        writer.writeMerged(trip: trip, instances: ctx.instances, stack: stack,
            header: headerText
        )

        ctx.showBanner("Logged: \(headerText)")
    }
}

// MARK: - Position acquisition
private extension ActionLogPipeline {
    
    @MainActor
    static func acquirePosition(using ctx: ActionContext, fallbackToInstances: Bool) async -> PositionStamp {
        
        // 1) Prefer fresh NMEA position
        if let snap = ctx.nmeaSnapshot(),
           snap.isFresh(),
           let lat = snap.latitude,
           let lon = snap.longitude {
            return PositionStamp(
                date: snap.timestamp,
                lat: lat,
                lon: lon
            )
        }
        
        // 2) Phone GPS (one-shot)
        if let pos = ctx.positionUpdater {
            pos.requestOnce()
            try? await Task.sleep(nanoseconds: 350_000_000)
            let lat = pos.currentLatitude
            let lon = pos.currentLongitude
            if abs(lat) > 0.0001 || abs(lon) > 0.0001 {
                return PositionStamp(date: Date(), lat: lat, lon: lon)
            }
        }
        
        // 3) Fallback: Instances
        if fallbackToInstances {
            return PositionStamp(
                date: Date(),
                lat: ctx.instances.gpsCoordinatesLat,
                lon: ctx.instances.gpsCoordinatesLong
            )
        }
        
        return PositionStamp(date: Date(), lat: 0, lon: 0)
    }
}
// MARK: - Last log lookup
private extension ActionLogPipeline {

    static func fetchLastLog(for trip: Trip, in context: ModelContext) -> Logs? {
        let tripID = trip.persistentModelID

        var desc = FetchDescriptor<Logs>(
            predicate: #Predicate<Logs> { log in
                log.trip.persistentModelID == tripID
            },
            sortBy: [SortDescriptor(\.dateOfLog, order: .reverse)]
        )
        desc.fetchLimit = 1
        return try? context.fetch(desc).first
    }

}

// MARK: - Vector math
private extension ActionLogPipeline {

    static func needsSecondMeasurement(p1: PositionStamp, p2: PositionStamp, lastLog: Logs?) -> Bool {
        guard let lastLog else { return false }
        guard lastLog.posLat != 0, lastLog.posLong != 0 else { return false }

        // speed from last log → P1
        let dt1 = max(1.0, p1.date.timeIntervalSince(lastLog.dateOfLog))
        let d1 = DistanceCalculator.distanceNM(
            lat1: lastLog.posLat, lon1: lastLog.posLong,
            lat2: p1.lat, lon2: p1.lon
        )
        let avgSog1 = (d1 / (dt1 / 3600.0)) // knots

        // speed from P1 → P2
        let dt2 = max(1.0, p2.date.timeIntervalSince(p1.date))
        let d2 = DistanceCalculator.distanceNM(
            lat1: p1.lat, lon1: p1.lon,
            lat2: p2.lat, lon2: p2.lon
        )
        let sog2 = (d2 / (dt2 / 3600.0))

        if avgSog1 < 0.2 { return false } // basically stopped -> don’t over-trigger

        let ratio = abs(sog2 - avgSog1) / max(avgSog1, 0.1)
        if ratio > 0.20 { return true }   // >20% discrepancy

        // optional: track discrepancy if both are meaningful
        let track1 = bearingDeg(fromLat: lastLog.posLat, fromLon: lastLog.posLong, toLat: p1.lat, toLon: p1.lon)
        let track2 = bearingDeg(fromLat: p1.lat, fromLon: p1.lon, toLat: p2.lat, toLon: p2.lon)
        let delta = angularDelta(track1, track2)
        return delta > 20
    }

    static func bearingDeg(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) -> Int {
        let φ1 = fromLat * .pi / 180
        let φ2 = toLat * .pi / 180
        let Δλ = (toLon - fromLon) * .pi / 180


        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(y, x) * 180 / .pi
        return normalizeDeg(Int(round(θ)))
    }

    static func angularDelta(_ a: Int, _ b: Int) -> Int {
        let d = abs(normalizeDeg(a) - normalizeDeg(b))
        return min(d, 360 - d)
    }

    static func normalizeDeg(_ deg: Int) -> Int {
        var d = deg % 360
        if d < 0 { d += 360 }
        return d
    }
}

// MARK: - Compute missing nav values (SOG/COG primarily)
private extension ActionLogPipeline {

    static func applyNavFixes(
        into fix: inout Fix,
        p1: PositionStamp,
        p2: PositionStamp,
        lastLog: Logs?,
        instances: Instances,
        nmea: NMEASnapshot? = nil
    ) {
        // Tier A — authoritative NMEA
        if let nmea, nmea.isFresh() {
            fix.sogKn = nmea.sog
            fix.cogDeg = nmea.cog
            fix.stwKn = nmea.stw
            fix.magHeadingDeg = nmea.magneticHeading

            fix.awaDeg = nmea.awa
            fix.awsKn = nmea.aws
            fix.twdDeg = nmea.twd
            fix.twsKn = nmea.tws
        }

        // If SOG/COG look missing, derive from P1->P2.
        if instances.SOG <= 0.1 || instances.COG <= 0 {
            let dt = max(1.0, p2.date.timeIntervalSince(p1.date))
            let dNm = DistanceCalculator.distanceNM(lat1: p1.lat, lon1: p1.lon, lat2: p2.lat, lon2: p2.lon)
            let sog = Float(dNm / (dt / 3600.0))
            let cog = bearingDeg(fromLat: p1.lat, fromLon: p1.lon, toLat: p2.lat, toLon: p2.lon)

            // if vector is “known bad”, prefer last-log average instead
            if let lastLog, needsSecondMeasurement(p1: p1, p2: p2, lastLog: lastLog) {
                let dtL = max(1.0, p1.date.timeIntervalSince(lastLog.dateOfLog))
                let dL = DistanceCalculator.distanceNM(
                    lat1: lastLog.posLat, lon1: lastLog.posLong,
                    lat2: p1.lat, lon2: p1.lon
                )
                fix.sogKn = Float(dL / (dtL / 3600.0))
                fix.cogDeg = bearingDeg(fromLat: lastLog.posLat, fromLon: lastLog.posLong, toLat: p1.lat, toLon: p1.lon)
            } else {
                fix.sogKn = sog
                fix.cogDeg = cog
            }
        }

        // STW policy (your “if STW missing => assume STW=SOG” baseline)
        if instances.STW <= 0.1 {
            if let sog = fix.sogKn {
                fix.stwKn = sog
            }
        }

        // AWA default from point of sail if missing
        if instances.AWA == 0 {
            fix.awaDeg = defaultAWA(pointOfSail: instances.pointOfSail, tack: instances.tack)
        }

        // TWS default from Beaufort if missing
        if instances.TWS == 0, instances.windDescription > 0 {
            fix.twsKn = approxTwsFromBeaufort(instances.windDescription)
        }
    }

    static func defaultAWA(pointOfSail: PointOfSail, tack: Tack) -> Int {
        let base: Int = switch pointOfSail {
        case .closeHauled: 35
        case .closeReach:  45
        case .beamReach:   90
        case .broadReach:  120
        case .running:     120
        case .deadRun:     170
        case .stopped:     0
        }
        // encode side in sign (optional); keep positive for now if you prefer
        return base
    }

    static func approxTwsFromBeaufort(_ bft: Int) -> Int {
        // “low end” knots approximation; enough for v1.
        switch bft {
        case 0: 0
        case 1: 1
        case 2: 4
        case 3: 7
        case 4: 11
        case 5: 17
        case 6: 22
        case 7: 28
        case 8: 34
        case 9: 41
        case 10: 48
        case 11: 56
        default: 64
        }
    }
}

// MARK: - Bearing discrepancy policy (COG vs magHeading)
private extension ActionLogPipeline {

    @MainActor
    static func applyBearingDiscrepancyPolicy(into fix: inout Fix, ctx: ActionContext) async {
        let cog = fix.cogDeg ?? ctx.instances.COG
        if cog <= 0 { return }

        var heading = fix.magHeadingDeg ?? ctx.instances.magHeading
        if heading <= 0 { return }

        let delta = angularDelta(cog, heading)

        if delta <= 20 { return }

        if delta > 40 {
            // stop bothering the user: force equality
            fix.magHeadingDeg = cog
            return
        }

        // 20°..40° => ask once for “actual compass bearing”
        ctx.showBanner("COG differs from bearing by \(delta)°. Please confirm compass bearing.")
        if let answer = await ctx.promptSingleLine(
            title: "Bearing check",
            message: "COG \(cog)° differs from bearing \(heading)°.\nEnter actual magnetic bearing (0–359):",
            placeholder: "e.g. 245",
            initialText: "\(heading)",
            allowEmpty: false
        ),
        let val = Int(answer.trimmingCharacters(in: .whitespacesAndNewlines)),
        (0...359).contains(val) {
            heading = val
            fix.magHeadingDeg = val
        }

        // re-evaluate; if still big, stop bothering and set equal
        let delta2 = angularDelta(cog, heading)
        if delta2 > 40 {
            fix.magHeadingDeg = cog
        }
    }
}

// MARK: - Apply computed fixes to LogQueue
private extension ActionLogPipeline {

    static func applyFixToLogQueue(_ fix: Fix, stack: LogQueue) {
        if let sog = fix.sogKn {
            stack.enqueue(key: "SOGfix", text: "") { log in log.SOG = sog }
        }
        if let cog = fix.cogDeg {
            stack.enqueue(key: "COGfix", text: "") { log in log.COG = cog }
        }
        if let stw = fix.stwKn {
            stack.enqueue(key: "STWfix", text: "") { log in log.STW = stw }
        }
        if let hdg = fix.magHeadingDeg {
            stack.enqueue(key: "HDGfix", text: "") { log in log.magHeading = hdg }
        }
        if let awa = fix.awaDeg {
            stack.enqueue(key: "AWAfix", text: "") { log in log.AWA = awa }
        }
        if let tws = fix.twsKn {
            stack.enqueue(key: "TWSfix", text: "") { log in log.TWS = tws }
        }
        if let twd = fix.twdDeg {
            stack.enqueue(key: "TWDfix", text: "") { log in log.TWD = twd }
        }
        if let aws = fix.awsKn {
            stack.enqueue(key: "AWSfix", text: "") { log in log.AWS = aws }
        }
    }
}
