//
//  LogDetailsView.swift
//  SailTrips
//
//  Created by jeroen kok on 26/07/2025.
//

import SwiftUI
import SwiftData
import CoreLocation

struct LogbookEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var instances: Instances
    var settings: LogbookSettings

    @State private var log = Logs(trip: Trip()) // Temporary init — replaced onAppear
    @State private var logText: String = ""
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var timestamp: Date = Date()
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationDeniedAlert = false
    @StateObject private var positionUpdater: PositionUpdater
        = PositionUpdater(autoReadOnStart: true,
                          autoUpdateEnabled: true,
                          updateInterval: 0)

    @Query private var allLocations: [Location]
    @Query private var settingsArray: [LogbookSettings]

   /* private var settings: LogbookSettings {
        settingsArray.first ?? LogbookSettings()}
    */
    

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button("OK") {
                    saveEntry()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Form {
                Section("Log Time") {
                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Position") {
                    CoordinatesView(latitude: $latitude, longitude: $longitude, isEditable: true)
                }

                Section("Log Entry") {
                    TextField("Enter logbook text", text: $logText, axis: .vertical)
                        .lineLimit(3...10)
                        .textFieldStyle(.roundedBorder)
                }

                LogDetailsForm(
                    log: $log,
                    instances: instances,
                    settings: settings,
                )
            }
        }
        .onAppear {
            positionUpdater.setupAutoloadSettings(autoUpdate: settings.autoUpdatePosition, period: settings.autoUpdatePeriodicity)
            guard let trip = instances.currentTrip else { return }
            log = Logs(trip: trip)
            timestamp = Date()
            latitude = instances.gpsCoordinatesLat
            longitude = instances.gpsCoordinatesLong

            if settings.autoReadposition {
                locationManager.requestLocation()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if let loc = locationManager.lastLocation {
                        latitude = loc.latitude
                        longitude = loc.longitude
                    } else {
                        showLocationDeniedAlert = true
                    }
                }
            }
        }
        .alert("Location Permission Denied", isPresented: $showLocationDeniedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to read current position. Please check location permissions in Settings or enter position manually.")
        }
        .onReceive(positionUpdater.$currentLatitude) { newLat in
            latitude = newLat
        }
        .onReceive(positionUpdater.$currentLongitude) { newLon in
            longitude = newLon
        }
        .alert("Location Permission Denied", isPresented: $positionUpdater.locationDenied) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to access your location. Please check permissions in Settings.")
        }

        
    }

    // MARK: - OK Button Logic
    private func saveEntry() {
        log.dateOfLog = timestamp
        log.logEntry = logText
        log.posLat = latitude
        log.posLong = longitude

        // Insert into model
        context.insert(log)

        // Update instance values
        instances.lastNavigationTimeStamp = timestamp
        instances.gpsCoordinatesLat = latitude
        instances.gpsCoordinatesLong = longitude
        instances.SOG = log.SOG
        instances.COG = log.COG
        instances.STW = log.STW
        instances.TWS = log.TWS
        instances.TWD = log.TWD
        instances.pressure = Float(log.pressure)
        instances.airTemperature = log.airTemp
        instances.waterTemperature = log.waterTemp
        instances.visibility = log.visibility
        instances.seaState = log.seaState
        instances.propulsion = log.propulsion
        instances.steering = log.steering
        instances.AWA = log.AWA
        instances.AWS = log.AWS
        if let pos = PointOfSail(rawValue: log.pointOfSail) {
            instances.pointOfSail = pos
        }
        instances.precipitations = log.precipitation
        instances.severeWeather = log.severeWeather

        // Tack conversion
        instances.tack = log.starboardTack ? .starboard : .port

        // Done
        try? context.save()
    }
}

struct LogDetailsForm: View {
    @Binding var log: Logs
    @Bindable var instances: Instances
    let settings: LogbookSettings

    var body: some View {
        ScrollView {
            VStack{
                NavigationSection(log: log, instances: instances, settings: settings)
                TidesSection(log: log, settings: settings)
                SeaStateSection(log: log, instances: instances, settings: settings)
                WeatherSection(log: log, instances: instances, settings: settings)
                SailingSection(log: log, instances: instances, settings: settings)
            }
        }
    }
}

struct NavigationSection: View {
    @Environment(\.modelContext) private var context

    @Bindable var log: Logs
    @Bindable var instances: Instances

    let settings: LogbookSettings
    @Query  var allLocations: [Location]

    @State private var previousWaypoint: String = ""
    @State private var showNewLocSheet = false
    @State private var proposedLocation = Location(name: "", latitude: 0, longitude: 0)

    var body: some View {
        Section(header: Text("Navigation"))  {

            if settings.isLogFieldVisible(.nextWaypoint) {
                TextField("Next Waypoint", text: $log.nextWaypoint)
                    .onChange(of: log.nextWaypoint) { _, newValue in
                        handleWaypointChange(newValue)
                    }
            }

            if settings.isLogFieldVisible(.distanceToWP) {
                NumberField(label: "Distance to WP", inData: $log.distanceToWP)
            }

            if settings.isLogFieldVisible(.SOG) {
                NumberField(label: "Speed over Ground", inData: $log.SOG)
            }

            if settings.isLogFieldVisible(.COG) {
                BearingView(label: "COG", inBearing: $log.COG)
            }

            if settings.isLogFieldVisible(.magCourse) {
                BearingView(label: "Magnetic Course", inBearing: $log.magHeading)
            }

            if settings.isLogFieldVisible(.SOW) {
                NumberField(label: "Speed over Water", inData: $log.STW)
            }

            if settings.isLogFieldVisible(.distanceSinceLastEntry) {
                NumberField(label: "Distance since last entry", inData: $log.distanceSinceLastEntry)
            }

            if settings.isLogFieldVisible(.averageSpeedSinceLastEntry) {
                NumberField(label: "Average speed", inData: $log.averageSpeedSinceLastEntry)
            }
        }
        .sheet(isPresented: $showNewLocSheet) {
            QuickAddOnTheFlyView(location: $proposedLocation)
                .onDisappear {
                    // Insert and assign if saved
                    if !proposedLocation.Name.isEmpty {
                        instances.nextWPT = proposedLocation
                    }
                }
        }
        .onAppear {
            previousWaypoint = log.nextWaypoint
        }
    }

    // MARK: - Waypoint Resolution Logic
    private func handleWaypointChange(_ newValue: String) {
        guard newValue != previousWaypoint else { return }

        previousWaypoint = newValue
        log.nextWaypoint = newValue

        let match = allLocations.first {
            $0.Name.localizedCaseInsensitiveCompare(newValue) == .orderedSame
        }

        if let found = match {
            instances.nextWPT = found
        } else {
            instances.nextWPT = nil
            // Prompt to add new location
            proposedLocation = Location(name: newValue, latitude: 0, longitude: 0)
            showNewLocSheet = true
        }
    }
}

struct TidesSection: View {
    
    @Bindable var log: Logs
    let settings: LogbookSettings

    var body: some View {
        Section(header: Text("Tides")) {
            if settings.isLogFieldVisible(.timeHighTide) {
                NumberField(label: "Time to next High Tide (h)", inData: $log.timeHighTide)
            }
        }
    }
}

struct SeaStateSection: View {
    
    @Bindable var log: Logs
    @Bindable var instances: Instances
    let settings: LogbookSettings

    var body: some View {
        Section(header: Text("Sea State")) {
            if settings.isLogFieldVisible(.speedOfCurrent) {
                NumberField(label: "Current Speed (kts)", inData: $log.speedOfCurrent)
            }
            if settings.isLogFieldVisible(.directionOfCurrent) {
                NumberField(label: "Current Direction (°)", inData: $log.directionOfCurrent)
            }
            if settings.isLogFieldVisible(.seaState) {
                TextField("Sea State Description", text: $log.seaState)
            }
        }
    }
}

struct WeatherSection: View {
    
    @Bindable var log: Logs
    @Bindable var instances: Instances
    let settings: LogbookSettings

    var body: some View {
        Section(header: Text("Weather")) {
            if settings.isLogFieldVisible(.pressure) {
                NumberField(label: "Pressure (hPa)", inData: $log.pressure)
            }
            if settings.isLogFieldVisible(.TWS) {
                IntField(label: "True Wind Speed", inData: $log.TWS)
            }
            if settings.isLogFieldVisible(.TWD) {
                IntField(label: "True Wind Direction", inData: $log.TWD)
            }
            if settings.isLogFieldVisible(.windGust) {
                NumberField(label: "Wind Gust", inData: $log.windGust)
            }
            if settings.isLogFieldVisible(.windForce) {
                IntField(label: "Wind Force (Beaufort)", inData: $log.windForce)
            }
            if settings.isLogFieldVisible(.airTemp) {
                IntField(label: "Air Temperature (°C)", inData: $log.airTemp)
            }
            if settings.isLogFieldVisible(.waterTemp) {
                IntField(label: "Water Temperature (°C)", inData: $log.waterTemp)
            }
            if settings.isLogFieldVisible(.cloudCover) {
                VStack(alignment: .leading) {
                    Text("Cloud Cover")
                    CloudOktaSelector(selection: Binding(
                        get: {
                            Int(log.cloudCover) ?? 0
                        },
                        set: {
                            log.cloudCover = "\($0)"
                        }
                    ))
                }
            }
            if settings.isLogFieldVisible(.precipitation) {
                Picker("Precipitation", selection: $log.precipitation) {
                    ForEach(Precipitations.allCases) { precip in
                        Text(precip.rawValue).tag(precip)
                    }
                }
            }
            if settings.isLogFieldVisible(.severeWeather) {
                Picker("Severe Weather", selection: $log.severeWeather) {
                    ForEach(SevereWeather.allCases) { wx in
                        Text(wx.rawValue).tag(wx)
                    }
                }
            }
            if settings.isLogFieldVisible(.visibility) {
                TextField("Visibility", text: $log.visibility)
            }
        }
    }
}

struct SailingSection: View {
    
    @Bindable var log: Logs
    @Bindable var instances: Instances
    let settings: LogbookSettings
    
    var body: some View {
        Section(header: Text("Sailing")) {
            if settings.isLogFieldVisible(.AWA) {
                IntField(label: "Apparent Wind Angle", inData: $log.AWA)
            }
            if settings.isLogFieldVisible(.AWS) {
                IntField(label: "Apparent Wind Speed", inData: $log.AWS)
            }
            if settings.isLogFieldVisible(.pointOfSail) {
                Picker("Point of Sail", selection: $log.pointOfSail) {
                    ForEach(PointOfSail.allCases) { pos in
                        Text(pos.rawValue).tag(pos.rawValue)
                    }
                }
            }
            if settings.isLogFieldVisible(.starboardTack) {
                Picker("Tack", selection: Binding(
                    get: { log.starboardTack ? "Starboard" : "Port" },
                    set: { log.starboardTack = ($0 == "Starboard") }
                )) {
                    Text("Starboard").tag("Starboard")
                    Text("Port").tag("Port")
                }
                .pickerStyle(.segmented)
            }
            if settings.isLogFieldVisible(.propulsion) {
                Picker("Propulsion", selection: $log.propulsion) {
                    ForEach(PropulsionTool.allCases) { prop in
                        Text(prop.rawValue).tag(prop)
                    }
                }
            }
            if settings.isLogFieldVisible(.steering) {
                Picker("Steering Mode", selection: $log.steering) {
                    ForEach(Steering.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                    
                }
            }
        }
    }
}
