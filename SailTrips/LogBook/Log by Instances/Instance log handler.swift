//
//  Instance log handler.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//

import SwiftUI
import SwiftData

// MARK: - InstanceLogHandler
/// Pure domain helper: knows how to turn changes in `Instances` into `Logs` entries.
/// Can be used from InstancesView *and* the Action system.

final class InstanceLogHandler {
    let instances: Instances
    let stack: LogQueue
    let writer: LogWriter

    init(instances: Instances, stack: LogQueue, context: ModelContext) {
        self.instances = instances
        self.stack = stack
        self.writer = LogWriter(context: context)
    }

    // MARK: - Generic helpers

    func enqueueDelta<T: CustomStringConvertible>(
        key: String,
        label: String,
        value: T,
        apply: ((inout Logs) -> Void)? = nil
    ) {
        stack.enqueue(key: key, text: "\(label) \(value)", apply: apply)
    }

    func flushStack() {
        guard let trip = instances.currentTrip else { return }
        writer.flush(trip: trip, instances: instances, stack: stack)
    }

    // MARK: - Mooring & Nav Status & Zone

    func mooringChanged(from old: MooringType, to newVal: MooringType) {
        guard let trip = instances.currentTrip else { return }
        var text = ""
        switch old {
        case .mooringBall:    text = (newVal == .none) ? "Dropped Mooring Ball" : textForMooring(newVal)
        case .chainMooring:   text = (newVal == .none) ? "Dropped Mooring Chain" : textForMooring(newVal)
        case .mooredOnBuoy:   text = (newVal == .none) ? "Left Buoy" : textForMooring(newVal)
        case .mooredOnShore:  text = (newVal == .none) ? "Dropped Lines" : textForMooring(newVal)
        case .atAnchor:       text = (newVal == .none) ? "Raised Anchor" : textForMooring(newVal)
        case .double:         text = (newVal == .none) ? "Left Mooring, Dropped Lines" : textForMooring(newVal)
        case .anchorMoore:    text = (newVal == .none) ? "Left Mooring and Raised Anchor" : textForMooring(newVal)
        case .medMoore:       text = (newVal == .none) ? "Left Mooring" : textForMooring(newVal)
        case .mooredBowAndStern: text = (newVal == .none) ? "Left Mooring" : textForMooring(newVal)
        case .bowAndStern:    text = (newVal == .none) ? "Left Mooring" : textForMooring(newVal)
        case .other:          text = (newVal == .none) ? "Left Mooring" : textForMooring(newVal)
        case .none:
            text = textForMooring(newVal)
        case .mooredOnDock:   text = (newVal == .none) ? "Left Mooring" : textForMooring(newVal)
            
        }

        // Side effects on Instances
        if newVal != .none {
            instances.navStatus = .stopped
            instances.currentLocation = nil
            if newVal == .mooredOnShore || newVal == .double {
                instances.currentNavZone = .harbour
            } else {
                instances.currentNavZone = .anchorage
            }
        }

        writer.writeMerged(trip: trip, instances: instances, stack: stack, header: text)

    }

    private func textForMooring(_ t: MooringType) -> String {
        switch t {
        case .mooringBall: return "Moored on a ball"
        case .chainMooring: return "Moored on a chain"
        case .mooredOnBuoy: return "Moored on a buoy"
        case .mooredOnShore: return "Mooring lines set"
        case .atAnchor: return "Dropped anchor"
        case .double: return "Double moored"
        case .medMoore: return " moored in mediterranean way"
        case .bowAndStern: return "stopped with bowline and sternline"
        case .mooredBowAndStern: return " moored with bowline and sternline"
        case .other: return "Moored"
        case .none: return "Mooring cleared"
        case .anchorMoore: return "Moored on shore with anchor at the bow"
        case .mooredOnDock: return "Moored at a dock"
        }
    }

    func navStatusChanged(from old: NavStatus, to newVal: NavStatus) {
        guard let trip = instances.currentTrip else { return }
        switch newVal {
        case .barepoles:
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Navigation stopped, running under bare poles")
        case .heaveto:
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Navigation stopped, heave to")
        case .stopped:
            break // handled by mooring change
        case .underway:
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Navigation resumed")
            
        case .stormTactics:
            writer.writeMerged(trip: trip, instances: instances, stack: stack, header:"Using storm tactics to ride out the storm")
        case .none:
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Acquiring data to make a decision")
        }

        if newVal != .stopped {
            instances.mooringUsed = .none
            instances.currentLocation = nil
        }
    }

    func navZoneChanged(from old: NavZone, to newVal: NavZone) {
        guard let trip = instances.currentTrip else { return }
        var pre = ""
        if old == .traffic { pre = "Traffic-lane quitted. " }
        if old == .harbour { pre += (pre.isEmpty ? "" : " ") + "Left the harbour. " }
        let tail: String
        
        switch newVal {
        case .coastal: tail = "Cruising in coastal zone"
        case .intracoastalWaterway: tail = "Entered the inland waterway"
        case .protectedWater: tail = "In protected water"
        case .approach: tail = "Approaching the harbour"
        case .openSea: tail = "Navigating in open sea"
        case .harbour: tail = "In harbour zone"
        case .anchorage: tail = "In anchorage"
        case .buoyField: tail = "In a buoy field"
        case .traffic: tail = "Entered a traffic-lane"
        case .none: tail = "Undetermined navigation zone"
        }
        let text = pre + tail

        if newVal != .harbour && newVal != .anchorage {
            instances.mooringUsed = .none
            if instances.navStatus == .stopped || instances.navStatus == .none {
                instances.navStatus = .underway
            }
            instances.currentLocation = nil
        }

        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: text)
    }

    // MARK: - Propulsion / Steering / Autopilot

    func propulsionChanged(from old: PropulsionTool, to newVal: PropulsionTool) {
        guard let trip = instances.currentTrip else { return }
        var text: String? = nil
        switch newVal {
        case .motor: text = "Motor only"
        case .sail: text = "Sails set, Motor Off"
        case .inTow: text = "In Tow"
        case .motorsail: text = "Using both Motor and Sail"
        case .none: text = nil
        }

        if newVal != .none {
            instances.mooringUsed = .none
            if instances.navStatus == .stopped || instances.navStatus == .none {
                instances.navStatus = .underway
            }
        }

        if let text = text {
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: text)
        }
    }

    func steeringChanged(from old: Steering, to newVal: Steering) {
        guard let trip = instances.currentTrip else { return }
        let header: String
        switch newVal {
        case .byHand:   header = "Hand steering engaged"
        case .autopilot: header = "Helm control delegated to autopilot"
        case .fixed:    header = "Rudder fixed"
        case .none:     header = "Rudder free"
        }
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: header)
    }

    func autopilotChanged(from old: Autopilot, to newVal: Autopilot) {
        guard let trip = instances.currentTrip else { return }
        let header: String
        switch newVal {
        case .off: header = "Autopilot switched Off"
        case .onTWA: header = "Autopilot is On, in Windmode: true wind"
        case .onAWA: header = "Autopilot is On in Windmode: apparent wind"
        case .onHdg: header = "Autopilot is On, in heading mode"
        case .onCOG: header = "Autopilot is On, follows Course Over Ground"
        case .onTrack: header = "Autopilot is On, track mode"
        case .unknown: header = "Autopilot is On"
        }
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: header)
    }

    func autopilotDirectionChanged(to newVal: Int) {
        stack.enqueue(
            key: "autopilotDir",
            text: "AP direction set to \(newVal)°"
        )
    }

    // MARK: - Waypoints & Course

    func nextWaypointChanged(to newVal: Location?) {
        if let loc = newVal, let trip = instances.currentTrip {
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Next WPT is now \(loc.Name)")
        } else {
            stack.enqueue(key: "nextWPT", text: "Next WPT cleared")
        }
    }

    func courseOverGroundChanged(to newVal: Int) {
        enqueueDelta(key: "COG",
                     label: "New ground course is",
                     value: "\(newVal)°") { log in
            log.COG = newVal
        }
    }

    func bearingToWPTChanged(to newVal: Int) {
        stack.enqueue(key: "BTW",
                      text: "New course to WPT is \(newVal)°")
    }

    func speedOverGroundChanged(to newVal: Float) {
        enqueueDelta(key: "SOG",
                     label: "Speed over ground is",
                     value: "\(newVal) kn") { log in
            log.SOG = newVal
        }
    }

    // MARK: - Sailing dynamics

    func tackChanged(from old: Tack, to newVal: Tack) {
        guard let trip = instances.currentTrip else { return }
        if old == .none && newVal != .none { return } // defined when hoisting sails
        if newVal == .none { return } // sails down
        if old != .none && old != newVal {
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Tacked, new tack on: \(newVal.rawValue)")
        }
    }

    func pointOfSailChanged(from old: PointOfSail, to newVal: PointOfSail) {
        guard let trip = instances.currentTrip else { return }
        if old == .stopped {
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Boat on \(newVal.rawValue) on tack \(instances.tack.rawValue)")
            return
        }
        let order: [PointOfSail] = [.closeHauled, .closeReach, .beamReach,
                                    .broadReach, .running, .deadRun, .stopped]
        let oi = order.firstIndex(of: old) ?? 0
        let ni = order.firstIndex(of: newVal) ?? 0
        let verb = (ni > oi) ? "luffed to" : (ni < oi ? "fell off to" : "held")
        let text = "\(verb) \(newVal.rawValue) on \(instances.tack.rawValue) tack"
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: text)
    }

    func wingOnWingChanged(isOn: Bool) {
        guard let trip = instances.currentTrip else { return }
        let header = isOn
        ? "Sails set wing-on-wing"
        : "Wing-on-wing configuration broken"
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: header)
    }

    // MARK: - Day / Night

    func dayNightChanged(isDay: Bool) {
        guard let trip = instances.currentTrip else { return }
        let header = isDay
        ? "Daytime navigation selected"
        : "Night navigation (navigation lights set)"
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: header)
    }

    // MARK: - Weather / environment

    func windSpeedChanged(to newVal: Int) {
        enqueueDelta(key: "TWS",
                     label: "Wind changed to",
                     value: "\(newVal) kn") { log in
            log.TWS = newVal
        }
    }

    func windDirectionChanged(to newVal: Int) {
        enqueueDelta(key: "TWD",
                     label: "Wind shifted to",
                     value: "\(newVal)°") { log in
            log.TWD = newVal
        }
    }

    func beaufortChanged(to newVal: Int) {
        guard let trip = instances.currentTrip else { return }
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: "Wind changed to \(newVal) Bft")
    }

    func cloudinessChanged(to newVal: Int) {
        stack.enqueue(
            key: "cloudiness",
            text: "Actual cloud cover: \(newVal)/8"
        ) { log in
            log.cloudCover = String(newVal)
        }
    }

    func visibilityChanged(to newVal: String) {
        guard let trip = instances.currentTrip else { return }
        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: "Visibility is now: \(newVal)")
    }

    func cumulonimbusChanged(isOn: Bool) {
        guard let trip = instances.currentTrip else { return }
        if isOn {
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "There are Cumulonimbus clouds visible nearby")
        } else {
            writer.writeMerged(trip: trip, instances: instances, stack: stack,
                            header: "Cumulonimbus clouds cleared from vicinity")
        }
    }

    func dangersUpdated(newDangers: [EnvironmentDangers], notes: String) {
        guard let trip = instances.currentTrip else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let header: String
        if newDangers.isEmpty || newDangers == [.none] {
            header = trimmedNotes.isEmpty
                ? "Environment dangers cleared"
                : "Environment dangers cleared – notes: \(trimmedNotes)"
        } else {
            let names = newDangers
                .filter { $0 != .none }
                .map { $0.rawValue.replacingOccurrences(of: "_", with: " ") }
                .joined(separator: ", ")

            if trimmedNotes.isEmpty {
                header = "Environment dangers updated: \(names)"
            } else {
                header = "Environment dangers updated: \(names) – notes: \(trimmedNotes)"
            }
        }

        writer.writeMerged(trip: trip, instances: instances, stack: stack,
                        header: header)
    }
}
