//
//  InstancesView.swift
//  SailTrips
//
//  Created by jeroen kok on 10/09/2025.
//


import SwiftUI
import SwiftData

// MARK: - InstancesView
struct InstancesView: View {
    //New code
    @Environment(\.modelContext) private var context

    let settings: LogbookSettings
    @Bindable var instances: Instances

    // Feeds odometer from GPS
    @StateObject private var position = PositionUpdater()
    @State private var tracker: OdometerTracker? = nil

    // Stack for deferred logs
    @StateObject private var logQueue = LogQueue()

    // For pickers
    @Query(sort: \Location.Name) private var allLocations: [Location]

    // Helpers
    private var writer: LogWriter { .init(context: context) }

    var body: some View {
        //have to correct this
        Form {
            Section(header: Text("Mooring & Status")) {
                Picker("Mooring", selection: $instances.mooringUsed) {
                    ForEach(MooringType.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.mooringUsed) { old, newVal in
                    handleMooringChange(old: old, newVal: newVal)
                }

                Picker("Nav Status", selection: $instances.navStatus) {
                    ForEach(NavStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.navStatus) { old, newVal in
                    handleNavStatusChange(old: old, newVal: newVal)
                }

                Picker("Nav Zone", selection: $instances.currentNavZone) {
                    ForEach(NavZone.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.currentNavZone) { old, newVal in
                    handleNavZoneChange(old: old, newVal: newVal)
                }
            }

            Section(header: Text("Propulsion & Pilot")) {
                Picker("Propulsion", selection: $instances.propulsion) {
                    ForEach(PropulsionTool.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.propulsion) { old, newVal in
                    handlePropulsionChange(old: old, newVal: newVal)
                }

                Picker("Autopilot", selection: $instances.autopilot) {
                    ForEach(Autopilot.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.autopilot) { old, newVal in
                    handleAutopilotChange(old: old, newVal: newVal)
                }

                if instances.autopilot != .off {
                    BearingView(label: "AP Direction", inBearing: $instances.autopilotDirection)
                        .onChange(of: instances.autopilotDirection) { _, _ in
                            // append to last autopilot log line when it was immediate
                            logQueue.enqueue(key: "autopilotDir", text: ", AP dir: \(instances.autopilotDirection)") { log in
                                // no dedicated field on Logs except maybe magCourse; keep as text only
                            }
                        }
                }
            }

            Section(header: Text("Waypoints & Course")) {
                Picker("Next WPT", selection: Binding(get: { instances.nextWPT?.id }, set: { id in
                    if let id = id, let loc = allLocations.first(where: { $0.id == id }) {
                        instances.nextWPT = loc
                    } else {
                        instances.nextWPT = nil
                    }
                })) {
                    Text("— None —").tag(UUID?.none)
                    ForEach(allLocations) { loc in Text(loc.Name).tag(Optional(loc.id)) }
                }
                .onChange(of: instances.nextWPT) { _, newVal in
                    if let loc = newVal, let trip = instances.currentTrip {
                        writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Next WPT is now \(loc.Name)")
                    } else {
                        logQueue.enqueue(key: "nextWPT", text: "Next WPT cleared")
                    }
                }

                BearingView(label: "COG", inBearing: $instances.COG)
                    .onChange(of: instances.COG) { _, newVal in
                        enqueueDelta(key: "COG", label: "New ground course is", value: newVal) { log in log.COG = newVal }
                    }

                BearingView(label: "Bearing to WPT", inBearing: $instances.bearingToNextWPT)
                    .onChange(of: instances.bearingToNextWPT) { _, newVal in
                        logQueue.enqueue(key: "BTW", text: "New course to WPT is \(newVal)°")
                    }

                NumberField(label: "SOG (kn)", inData: Binding(get: { instances.SOG }, set: { instances.SOG = $0 }))
                    .onChange(of: instances.SOG) { _, newVal in
                        enqueueDelta(key: "SOG", label: "Speed over ground is", value: newVal) { log in log.SOG = newVal }
                    }
            }

            Section(header: Text("Sails")) {
                ForEach(instances.selectedBoat.sails, id: \.id) { sail in
                    SailStateRow(sail: sail)
                }
            }

            Section(header: Text("Sailing Dynamics")) {
                Picker("Tack", selection: $instances.tack) {
                    ForEach(Tack.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.tack) { old, newVal in
                    handleTackChange(old: old, newVal: newVal)
                }

                Picker("Point of Sail", selection: $instances.pointOfSail) {
                    ForEach(PointOfSail.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.pointOfSail) { old, newVal in
                    handlePointOfSailChange(old: old, newVal: newVal)
                }
            }

            Section(header: Text("Weather (Beaufort & Sky)")) {
                IntField(label: "TWS", inData: $instances.TWS)
                    .onChange(of: instances.TWS) { old, newVal in
                        enqueueDelta(key: "TWS", label: "Wind changed to", value: newVal) { log in log.TWS = newVal }
                    }
                BearingView(label: "TWD", inBearing: $instances.TWD)
                    .onChange(of: instances.TWD) { _, newVal in
                        enqueueDelta(key: "TWD", label: "Wind shifted to", value: newVal) { log in log.TWD = newVal }
                    }
                IntField(label: "Beaufort", inData: $instances.windDescription)
                    .onChange(of: instances.windDescription) { old, newVal in
                        if let trip = instances.currentTrip { writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Wind changed to \(newVal) Bft") }
                    }
                IntField(label: "Cloudiness (oktas)", inData: $instances.cloudiness)
                    .onChange(of: instances.cloudiness) { _, newVal in
                        logQueue.enqueue(key: "cloudiness", text: "Actual cloud cover: \(newVal)") { log in log.cloudCover = String(newVal) }
                    }
                TextField("Visibility", text: $instances.visibility)
                    .onSubmit { if let trip = instances.currentTrip { writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Visibility is now: \(instances.visibility)") } }
                Toggle("Cumulonimbus nearby", isOn: $instances.presenceOfCn)
                    .onChange(of: instances.presenceOfCn) { _, newVal in
                        if newVal, let trip = instances.currentTrip {
                            writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "There are Cumulonimbus clouds visible nearby")
                        }
                    }
            }

            if !logQueue.items.isEmpty {
                Section {
                    Button(role: .none) {
                        flushStack()
                    } label: {
                        Label("Log modifications (\(logQueue.items.count))", systemImage: "doc.text")
                    }
                }
            }
        }
        .navigationTitle("Instances")
        .onAppear {
            // Position autoload setup
            position.setupAutoloadSettings(autoUpdate: settings.autoUpdatePosition, period: settings.autoUpdatePeriodicity)
            if settings.autoReadposition { position.requestOnce() }
            if settings.autoUpdatePosition { position.startUpdating() }

            // Tracker
            let t = OdometerTracker(pos: position, instances: instances)
            t.start()
            tracker = t
        }
        .onReceive(position.$currentLatitude.combineLatest(position.$currentLongitude)) { lat, lon in
            tracker?.onNewFix(lat: lat, lon: lon)
        }
        .alert("Location access denied", isPresented: $position.locationDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable Location permissions in Settings for GPS updates.")
        }
    }

    // MARK: - Enqueue helpers
    private func enqueueDelta<T: CustomStringConvertible>(key: String, label: String, value: T, apply: @escaping (inout Logs) -> Void) {
        logQueue.enqueue(key: key, text: "\(label) \(value)", apply: apply)
    }

    private func flushStack() {
        guard let trip = instances.currentTrip else { return }
        writer.flush(trip: trip, instances: instances, stack: logQueue)
    }

    // MARK: - Handlers implementing your logging rules (A…H)

    private func handleMooringChange(old: MooringType, newVal: MooringType) {
        guard let trip = instances.currentTrip else { return }
        var text = ""
        switch old {
        case .mooringBall:    text = (newVal == .none) ? "Dropped Mooring Ball" : textForMooring(newVal)
        case .chainMooring:   text = (newVal == .none) ? "Dropped Mooring Chain" : textForMooring(newVal)
        case .mooredOnBuoy:   text = (newVal == .none) ? "Left Buoy" : textForMooring(newVal)
        case .mooredOnShore:  text = (newVal == .none) ? "Dropped Lines" : textForMooring(newVal)
        case .atAnchor:       text = (newVal == .none) ? "Raised Anchor" : textForMooring(newVal)
        case .double:         text = (newVal == .none) ? "Left Mooring, Dropped Lines" : textForMooring(newVal)
        case .other:          text = (newVal == .none) ? "Left Mooring" : textForMooring(newVal)
        case .none:
            text = textForMooring(newVal)
        }

        // Side effects (2)
        if newVal != .none {
            instances.navStatus = .stopped
            instances.currentLocation = nil
            if newVal == .mooredOnShore || newVal == .double { instances.currentNavZone = .harbour } else { instances.currentNavZone = .anchorage }
        }

        writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: true, header: text)
    }

    private func textForMooring(_ t: MooringType) -> String {
        switch t {
        case .mooringBall: return "Moored on a ball"
        case .chainMooring: return "Moored on a chain"
        case .mooredOnBuoy: return "Moored on a buoy"
        case .mooredOnShore: return "Mooring lines set"
        case .atAnchor: return "Dropped anchor"
        case .double: return "Double moored"
        case .other: return "Moored"
        case .none: return "Mooring cleared"
        }
    }

    private func handleNavStatusChange(old: NavStatus, newVal: NavStatus) {
        guard let trip = instances.currentTrip else { return }
        switch newVal {
        case .barepoles: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: true, header: "Navigation stopped, running under bare poles")
        case .heaveto:   writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: true, header: "Navigation stopped, heave to")
        case .stopped:   break // handled by mooring change
        case .underway:  writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: true, header: "Navigation resumed")
        case .none:      writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: true, header: "Acquiring data to make a decision")
        }

        if newVal != .stopped {
            instances.mooringUsed = .none
            instances.currentLocation = nil
        }
    }

    private func handleNavZoneChange(old: NavZone, newVal: NavZone) {
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

        writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: true, header: text)
    }

    private func handlePropulsionChange(old: PropulsionTool, newVal: PropulsionTool) {
        guard let trip = instances.currentTrip else { return }
        var text: String? = nil
        switch newVal {
        case .motor: text = "Motor only"
        case .sail: text = "Sails set, Motor Off"
        case .inTow: text = "In Tow"
        case .motorsail: text = "Using both Motor and Sail"
        case .none: text = nil // do not log
        }

        if newVal != .none {
            instances.mooringUsed = .none
            if instances.navStatus == .stopped || instances.navStatus == .none {
                instances.navStatus = .underway
            }
        }

        if let text = text { writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: text) }
    }

    private func handleAutopilotChange(old: Autopilot, newVal: Autopilot) {
        guard let trip = instances.currentTrip else { return }
        switch newVal {
        case .off: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot switched Off")
        case .onTWA: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot is On, in Windmode: true wind")
        case .onAWA: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot is On in Windmode: apparent wind")
        case .onHdg: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot is On, in heading mode")
        case .onCOG: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot is On, follows Course Over Ground")
        case .onTrack: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot is On, track mode")
        case .unknown: writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Autopilot is On")
        }
    }

    private func handleTackChange(old: Tack, newVal: Tack) {
        guard let trip = instances.currentTrip else { return }
        if old == .none && newVal != .none { return } // defined when hoisting sails
        if newVal == .none { return } // sails down
        if old != .none && old != newVal {
            writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Tacked, new tack on: \(newVal.rawValue)")
        }
    }

    private func handlePointOfSailChange(old: PointOfSail, newVal: PointOfSail) {
        guard let trip = instances.currentTrip else { return }
        if old == .stopped {
            writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: "Boat on \(newVal.rawValue) on tack \(instances.tack.rawValue)")
            return
        }
        // Define an order to compare "above/below"
        let order: [PointOfSail] = [.closeHauled, .closeReach, .beamReach, .broadReach, .running, .deadRun, .stopped]
        let oi = order.firstIndex(of: old) ?? 0
        let ni = order.firstIndex(of: newVal) ?? 0
        let verb = (ni > oi) ? "luffed to" : (ni < oi ? "fell off to" : "held")
        let text = "\(verb) \(newVal.rawValue) on \(instances.tack.rawValue) tack"
        writer.writeNow(trip: trip, instances: instances, stack: logQueue, flushStackFirst: false, header: text)
    }
}

// MARK: - SailStateRow
struct SailStateRow: View {
    @Bindable var sail: Sail

    private var allowedStates: [SailState] {
        var list: [SailState] = [.lowered, .down, .full]
        if sail.reducedWithReefs { list += [.reefed, .reef1, .reef2, .reef3, .lowered] }
        if sail.reducedWithFurling { list += [.lowered, .lightFurled, .halfFurled, .tightFurled] }
        if sail.canBeOutpoled { list += [.outpoled] }
        // Deduplicate while preserving order
        var seen = Set<String>()
        return list.filter { seen.insert($0.rawValue).inserted }
    }

    var body: some View {
        HStack {
            Text(sail.nameOfSail)
            Text(":")
            Spacer()
            Picker("", selection: $sail.currentState) {
                ForEach(allowedStates) { st in
                    Text(st.rawValue).tag(st)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
