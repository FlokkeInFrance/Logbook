//
//  helper classes and enums.swift
//  SailTrips
//
//  Created by jeroen kok on 30/05/2025.
//
import SwiftUI
import SwiftData


class PathManager:ObservableObject{
    @Published var path = NavigationPath()
}

class activations: ObservableObject {
    @Published var activeItem: ChecklistItem? = nil
    @Published var activeSection: ChecklistSection? = nil
    @Published var lastNumberChecked: Int? = nil
    @Published var lastLatitude: Double? = nil
    @Published var lastLongitude: Double? = nil
}

class observedString: ObservableObject {
    @Published var oString: String = ""
}

enum ClipboardEntry {
  case section(
    name: String,
    fontColor: SectionColors,
    items: [ChecklistItemData],
    originalIndex: Int
  )
  case item(
    data: ChecklistItemData,
    originalSectionOrder: Int,
    originalIndex: Int
  )
}

struct ChecklistItemData: Identifiable {
  let id = UUID()
  var itemShortText: String
  var itemLongText: String
  var itemNormalCheck: Bool
  var textAlt1: String
  var textAlt2: String
}

final class Clipboard: ObservableObject {
  @Published var entry: ClipboardEntry?
  @Published var lastActionWasCut = false
}

// MARK: - LogQueue (stack with move-to-top semantics)
final class LogQueue: ObservableObject {
    struct Item: Identifiable, Equatable {
        static func == (lhs: LogQueue.Item, rhs: LogQueue.Item) -> Bool {
           return( lhs.id == rhs.id)
        }
        
let id = UUID()
let key: String // variable key (e.g., "mooringUsed") for de-dup/move-to-top
let text: String // prepared log line
// optional payload changes to copy into Logs model when flushing
let apply: ((inout Logs) -> Void)?
}

@Published private(set) var items: [Item] = []

func enqueue(key: String, text: String, apply: ((inout Logs) -> Void)? = nil) {
// Remove any prior entry with same key, then push to top
items.removeAll { $0.key == key }
items.insert(Item(key: key, text: text, apply: apply), at: 0)
}

func clear() { items.removeAll() }
}

// MARK: - LogWriter
struct LogWriter {
let context: ModelContext

/// Write a single log entry immediately, optionally flushing the queue first.
func writeNow(trip: Trip, instances: Instances, stack: LogQueue, flushStackFirst: Bool = true, header: String? = nil) {
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
log.starboardTack = (inst.tack == .starboard)
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

