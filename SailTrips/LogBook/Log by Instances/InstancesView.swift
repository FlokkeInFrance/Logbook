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
    @Environment(\.modelContext) private var context

    let settings: LogbookSettings
    @Bindable var instances: Instances

    // GPS + odometer
    @StateObject private var position = PositionUpdater()
    @State private var tracker: OdometerTracker? = nil

    // Log stack + handler
    @StateObject private var logQueue = LogQueue()
    @State private var logHandler: InstanceLogHandler?

    // Locations
    @Query(sort: \Location.Name) private var allLocations: [Location]

    // Sheets
    @State private var showWeatherSheet = false
    @State private var showDangerSheet = false
    @State private var showPilotSheet = false

    var body: some View {
        Form {
            mooringSection
            propulsionPilotSection
            waypointsCourseSection
            sailsSection
            sailingDynamicsSection
            environmentSection

            if !logQueue.items.isEmpty {
                Section {
                    Button {
                        logHandler?.flushStack()
                    } label: {
                        Label("Log modifications (\(logQueue.items.count))",
                              systemImage: "doc.text")
                    }
                }
            }
        }
        .navigationTitle("Instances")
        .onAppear {
            if logHandler == nil {
                logHandler = InstanceLogHandler(
                    instances: instances,
                    stack: logQueue,
                    context: context
                )
            }

            // GPS auto settings
            position.setupAutoloadSettings(
                autoUpdate: settings.autoUpdatePosition,
                period: settings.autoUpdatePeriodicity
            )
            if settings.autoReadposition { position.requestOnce() }
            if settings.autoUpdatePosition { position.startUpdating() }

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
        // Sheets
        .sheet(isPresented: $showWeatherSheet) {
            NavigationStack {
                WeatherView(instances: instances)
            }
        }
        .sheet(isPresented: $showDangerSheet) {
            DangerReporterView(existing: instances.environmentDangers) { newDangers, notes in
                instances.environmentDangers = newDangers
                logHandler?.dangersUpdated(newDangers: newDangers, notes: notes)
            }
        }
        .sheet(isPresented: $showPilotSheet) {
            NavigationStack {
                SteeringAutopilotView(instances: instances,
                                      logHandler: logHandler)
            }
        }
    }

    // MARK: - Sections

    private var mooringSection: some View {
        Section(header: Text("Mooring & Status")) {
            Picker("Mooring", selection: $instances.mooringUsed) {
                ForEach(MooringType.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.mooringUsed) { old, newVal in
                logHandler?.mooringChanged(from: old, to: newVal)
            }

            Picker("Nav Status", selection: $instances.navStatus) {
                ForEach(NavStatus.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.navStatus) { old, newVal in
                logHandler?.navStatusChanged(from: old, to: newVal)
            }

            Picker("Nav Zone", selection: $instances.currentNavZone) {
                ForEach(NavZone.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.currentNavZone) { old, newVal in
                logHandler?.navZoneChanged(from: old, to: newVal)
            }

            Toggle("Day sail", isOn: $instances.daySail)
                .onChange(of: instances.daySail) { _, newVal in
                    logHandler?.dayNightChanged(isDay: newVal)
                }
        }
    }

    private var propulsionPilotSection: some View {
        Section(header: Text("Propulsion & Pilot")) {
            Picker("Propulsion", selection: $instances.propulsion) {
                ForEach(PropulsionTool.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.propulsion) { old, newVal in
                logHandler?.propulsionChanged(from: old, to: newVal)
            }

            Picker("Steering", selection: $instances.steering) {
                ForEach(Steering.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.steering) { old, newVal in
                logHandler?.steeringChanged(from: old, to: newVal)
            }

            Picker("Autopilot", selection: $instances.autopilotMode) {
                ForEach(Autopilot.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.autopilotMode) { old, newVal in
                logHandler?.autopilotChanged(from: old, to: newVal)
            }

            if instances.autopilotMode != .off {
                BearingView(label: "AP Direction",
                            inBearing: $instances.autopilotDirection)
                    .onChange(of: instances.autopilotDirection) { _, newVal in
                        logHandler?.autopilotDirectionChanged(to: newVal)
                    }
            }

            Button {
                showPilotSheet = true
            } label: {
                Label("Pilot & steering details…", systemImage: "steeringwheel")
            }
        }
    }

    private var waypointsCourseSection: some View {
        Section(header: Text("Waypoints & Course")) {
            Picker("Next WPT", selection: Binding(get: {
                instances.nextWPT?.id
            }, set: { id in
                if let id = id,
                   let loc = allLocations.first(where: { $0.id == id }) {
                    instances.nextWPT = loc
                } else {
                    instances.nextWPT = nil
                }
            })) {
                Text("— None —").tag(UUID?.none)
                ForEach(allLocations) { loc in
                    Text(loc.Name).tag(Optional(loc.id))
                }
            }
            .onChange(of: instances.nextWPT) { _, newVal in
                logHandler?.nextWaypointChanged(to: newVal)
            }

            BearingView(label: "COG", inBearing: $instances.COG)
                .onChange(of: instances.COG) { _, newVal in
                    logHandler?.courseOverGroundChanged(to: newVal)
                }

            BearingView(label: "Bearing to WPT",
                        inBearing: $instances.bearingToNextWPT)
                .onChange(of: instances.bearingToNextWPT) { _, newVal in
                    logHandler?.bearingToWPTChanged(to: newVal)
                }

            NumberField(label: "SOG (kn)",
                        inData: Binding(get: { instances.SOG },
                                        set: { instances.SOG = $0 }))
                .onChange(of: instances.SOG) { _, newVal in
                    logHandler?.speedOverGroundChanged(to: newVal)
                }
        }
    }

    private var sailsSection: some View {
        Section(header: Text("Sails")) {
            ForEach(instances.selectedBoat.sails, id: \.id) { sail in
                SailStateRow(sail: sail)
            }
        }
    }

    private var sailingDynamicsSection: some View {
        Section(header: Text("Sailing Dynamics")) {
            Picker("Tack", selection: $instances.tack) {
                ForEach(Tack.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.tack) { old, newVal in
                logHandler?.tackChanged(from: old, to: newVal)
            }

            Picker("Point of Sail", selection: $instances.pointOfSail) {
                ForEach(PointOfSail.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: instances.pointOfSail) { old, newVal in
                logHandler?.pointOfSailChanged(from: old, to: newVal)
            }

            Toggle("Wing-on-wing", isOn: $instances.wingOnWing)
                .onChange(of: instances.wingOnWing) { _, newVal in
                    logHandler?.wingOnWingChanged(isOn: newVal)
                }
        }
    }

    private var environmentSection: some View {
        Section(header: Text("Weather & Environment")) {
            // Quick access to full weather editor
            Button {
                showWeatherSheet = true
            } label: {
                Label("Describe weather…", systemImage: "cloud.sun")
            }

            // Short direct controls that also log
            IntField(label: "TWS", inData: $instances.TWS)
                .onChange(of: instances.TWS) { _, newVal in
                    logHandler?.windSpeedChanged(to: newVal)
                }

            BearingView(label: "TWD", inBearing: $instances.TWD)
                .onChange(of: instances.TWD) { _, newVal in
                    logHandler?.windDirectionChanged(to: newVal)
                }

            IntField(label: "Beaufort", inData: $instances.windDescription)
                .onChange(of: instances.windDescription) { _, newVal in
                    logHandler?.beaufortChanged(to: newVal)
                }

            IntField(label: "Cloudiness (oktas)", inData: $instances.cloudiness)
                .onChange(of: instances.cloudiness) { _, newVal in
                    logHandler?.cloudinessChanged(to: newVal)
                }

            TextField("Visibility", text: $instances.visibility)
                .onSubmit {
                    logHandler?.visibilityChanged(to: instances.visibility)
                }

            Toggle("Cumulonimbus nearby", isOn: $instances.presenceOfCn)
                .onChange(of: instances.presenceOfCn) { _, newVal in
                    logHandler?.cumulonimbusChanged(isOn: newVal)
                }

            // Environment dangers summary & sheet
            let active = instances.environmentDangers.filter { $0 != .none }
            let summary = active.isEmpty
                ? "No specific dangers"
                : active.map { $0.rawValue }.joined(separator: ", ")

            Button {
                showDangerSheet = true
            } label: {
                Label("Dangers: \(summary)", systemImage: "exclamationmark.triangle")
            }

        }
    }
}

// MARK: - SailStateRow (unchanged)
struct SailStateRow: View {
    @Bindable var sail: Sail

    private var allowedStates: [SailState] {
        var list: [SailState] = [.lowered, .down, .full]
        if sail.reducedWithReefs { list += [.reefed, .reef1, .reef2, .reef3, .lowered] }
        if sail.reducedWithFurling { list += [.lowered, .vlightFurled, .lightFurled, .halfFurled, .tightFurled] }
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
struct SteeringAutopilotView: View {
    @Bindable var instances: Instances
    let logHandler: InstanceLogHandler?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Steering") {
                Picker("Mode", selection: $instances.steering) {
                    ForEach(Steering.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.steering) { old, newVal in
                    logHandler?.steeringChanged(from: old, to: newVal)
                }
            }

            Section("Autopilot") {
                Picker("Mode", selection: $instances.autopilotMode) {
                    ForEach(Autopilot.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: instances.autopilotMode) { old, newVal in
                    logHandler?.autopilotChanged(from: old, to: newVal)
                }

                if instances.autopilotMode != .off {
                    BearingView(label: "AP Direction",
                                inBearing: $instances.autopilotDirection)
                        .onChange(of: instances.autopilotDirection) { _, newVal in
                            logHandler?.autopilotDirectionChanged(to: newVal)
                        }
                }
            }

            Section {
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Pilot & Steering")
        .navigationBarTitleDisplayMode(.inline)
    }
}
