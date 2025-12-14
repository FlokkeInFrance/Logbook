//
//  LogWriter.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//

import SwiftUI
import SwiftData

// MARK: - LogWriter
struct LogWriter {
let context: ModelContext

/// Write a single log entry immediately, optionally flushing the queue first.
/*func writeNow(trip: Trip, instances: Instances, stack: LogQueue, flushStackFirst: Bool = true, header: String? = nil) {
if flushStackFirst, !stack.items.isEmpty {
flush(trip: trip, instances: instances, stack: stack)
}
var entry = Logs(trip: trip)
hydrate(&entry, from: instances)
if let header = header {
entry.logEntry = header
}
context.insert(entry)
try? context.save()
}*/
    
    func writeMerged(trip: Trip,
                     instances: Instances,
                     stack: LogQueue,
                     header: String? = nil)
    {
        let fifo = stack.items.reversed()

        let stackLines = fifo
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let headerLine: String?
        if let h = header?.trimmingCharacters(in: .whitespacesAndNewlines),
           !h.isEmpty {
            headerLine = h
        } else {
            headerLine = nil
        }

        guard !stackLines.isEmpty || headerLine != nil else {
            stack.clear()
            return
        }

        var entry = Logs(trip: trip)
        hydrate(&entry, from: instances)

        for it in fifo { it.apply?(&entry) }

        var lines = stackLines
        if let headerLine { lines.append(headerLine) }
        entry.logEntry = lines.joined(separator: "\n")

        context.insert(entry)
        try? context.save()
        stack.clear()
    }



/// Flush the queue into a single log with all stacked lines in FIFO order (oldest first).
func flush(trip: Trip, instances: Instances, stack: LogQueue) {
guard !stack.items.isEmpty else { return }
var entry = Logs(trip: trip)
hydrate(&entry, from: instances)
// FIFO: reverse the LIFO stack to oldest→newest
let fifo = stack.items.reversed()
entry.logEntry = fifo.map { $0.text }.joined(separator: "\n")
// apply payloads
for it in fifo {
it.apply?(&entry)
}
context.insert(entry)
try? context.save()
stack.clear()
}

private func hydrate(_ log: inout Logs, from inst: Instances) {
log.dateOfLog = Date()
log.posLat = inst.gpsCoordinatesLat
log.posLong = inst.gpsCoordinatesLong
log.SOG = inst.SOG
log.COG = inst.COG
log.propulsion = inst.propulsion
log.steering = inst.steering
log.pointOfSail = inst.pointOfSail.rawValue
log.tack = inst.tack
log.TWS = inst.TWS
log.TWD = inst.TWD
log.windForce = inst.windDescription
log.airTemp = inst.airTemperature
log.waterTemp = inst.waterTemperature
log.seaState = inst.seaState
log.cloudCover = String(inst.cloudiness)
log.precipitation = inst.precipitations
log.severeWeather = inst.severeWeather
log.visibility = inst.visibility
if let wpt = inst.nextWPT { log.nextWaypoint = wpt.Name }
log.distanceSinceLastEntry = 0 // Optional: compute from last log if you like
    log.distanceToWP = 0 //Compute this value
    log.averageSpeedSinceLastEntry = 0 //Compute
    //get from NMEA : pressure, STW, airTemp,waterTemp,SOG, COG, magCourse, speedofcurrent, direction of current,
    //TWS,TWD,windForce, gusts, compute windForce, AWA, AWS, evt autopilot state
}
}
