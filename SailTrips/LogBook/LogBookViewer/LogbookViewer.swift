//
//  LogbookViewer.swift
//  SailTrips
//
//  Created by jeroen kok on 02/12/2025.
//


import SwiftUI
import SwiftData

/// Master–detail logbook viewer.
/// If you pass a Trip, only logs for that trip are shown.
/// If you pass nil, all logs are displayed.
struct LogbookViewer: View {
    @Environment(\.modelContext) private var modelContext

    /// Optional trip filter
    let trip: Trip?

    /// Logs for the given trip (or all logs if trip == nil)
    @Query private var logs: [Logs]

    /// Logbook settings (field visibility, units, etc.)
    @Query private var settingsArray: [LogbookSettings]

    @State private var selectedLog: Logs?
    @State private var ascending: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass

    // MARK: - Init with dynamic @Query

    init(trip: Trip? = nil) {
        self.trip = trip

        if let trip {
            let tripID = trip.id   // capture a simple value

            _logs = Query(
                filter: #Predicate<Logs> { log in
                    log.trip.id == tripID
                },
                sort: [SortDescriptor(\Logs.dateOfLog, order: .reverse)]
            )
        } else {
            _logs = Query(
                sort: [SortDescriptor(\Logs.dateOfLog, order: .reverse)]
            )
        }
    }


    // MARK: - Derived

    private var sortedLogs: [Logs] {
        if ascending {
            return logs.sorted { $0.dateOfLog < $1.dateOfLog }
        } else {
            return logs.sorted { $0.dateOfLog > $1.dateOfLog }
        }
    }

    private var logbookSettings: LogbookSettings? {
        settingsArray.first   // may be nil -> default to everything visible
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Header + sort toggle
                HStack {
                    Text(tripTitle)
                        .font(.headline)
                    Spacer()
                    Button {
                        ascending.toggle()
                    } label: {
                        Image(systemName: ascending ? "arrow.up" : "arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.trailing, 4)
                    .help(ascending ? "Oldest first" : "Newest first")
                }
                .padding([.horizontal, .top])

                // List of log rows
                List(sortedLogs, selection: $selectedLog) { log in
                    LogRowView(
                        log: log,
                        isCompact: hSizeClass == .compact
                    )
                }
            }
        } detail: {
            if let log = selectedLog ?? sortedLogs.first {
                LogDetailView(
                    log: log,
                    settings: logbookSettings
                )
            } else {
                ContentUnavailableView(
                    "No log entries",
                    systemImage: "note.text",
                    description: Text("Once you start logging, entries will appear here.")
                )
            }
        }
    }

    private var tripTitle: String {
        if let trip {
            // You can customize this if Trip has a nicer label
            return "Logbook – \(trip.dateOfStart.formatted(date: .abbreviated, time: .omitted))"
        } else {
            return "Logbook"
        }
    }
}

// MARK: - Row view

private struct LogRowView: View {
    let log: Logs
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.dateOfLog, format: .dateTime.hour().minute())
                    .font(.subheadline)

                Spacer()

                Text(shortPosition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !log.logEntry.isEmpty {
                Text(log.logEntry)
                    .font(.body)
                    .lineLimit(isCompact ? 2 : 3)
            } else if !log.nextWaypoint.isEmpty {
                Text("→ \(log.nextWaypoint)")
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var shortPosition: String {
        // Adjust this guard if 0,0 is ever a valid position for you
        guard log.posLat != 0 || log.posLong != 0 else { return "–" }
        let lat = degMinString(for: log.posLat, isLatitude: true)
        let lon = degMinString(for: log.posLong, isLatitude: false)
        return "\(lat) \(lon)"
    }
}

// MARK: - Detail view, respecting LogbookSettings / LogField

private struct LogDetailView: View {
    let log: Logs
    let settings: LogbookSettings?

    // Shortcuts into settings
    private func show(_ field: LogField) -> Bool {
        settings?.isLogFieldVisible(field) ?? true
    }

    var body: some View {
        Form {
            // MARK: General
            Section("General") {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(log.dateOfLog, format: .dateTime.day().month().year())
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Time")
                    Spacer()
                    Text(log.dateOfLog, format: .dateTime.hour().minute())
                        .foregroundStyle(.secondary)
                }

                if !log.logEntry.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Log text")
                            .font(.subheadline)
                        TextEditor(text: .constant(log.logEntry))
                            .frame(minHeight: 80)
                            .disabled(true)
                    }
                }
            }

            // MARK: Position & Route
            Section("Position & route") {
                HStack(alignment: .top) {
                    Text("Position")
                    Spacer()
                    Text(positionString)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }

                if show(.nextWaypoint), !log.nextWaypoint.isEmpty {
                    dataRow(label: "Next waypoint", value: log.nextWaypoint)
                }
                if show(.distanceToWP), log.distanceToWP > 0 {
                    dataRow(label: "Distance to WP",
                            value: String(format: "%.1f nm", log.distanceToWP))
                }
            }

            // MARK: Navigation
            Section("Navigation") {
                if show(.SOG), log.SOG > 0 {
                    dataRow(label: "SOG", value: speedString(log.SOG))
                }
                if show(.SOW), log.STW > 0 {
                    dataRow(label: "STW", value: speedString(log.STW))
                }
                if show(.COG), log.COG != 0 {
                    dataRow(label: "COG", value: "\(log.COG)°")
                }
                if show(.magCourse), log.magHeading != 0 {
                    dataRow(label: "Magnetic course", value: "\(log.magHeading)°")
                }
                if show(.distanceSinceLastEntry), log.distanceSinceLastEntry > 0 {
                    dataRow(label: "Distance since last entry",
                            value: String(format: "%.1f nm", log.distanceSinceLastEntry))
                }
                if show(.averageSpeedSinceLastEntry), log.averageSpeedSinceLastEntry > 0 {
                    dataRow(label: "Average speed",
                            value: speedString(log.averageSpeedSinceLastEntry))
                }
            }

            // MARK: Tides & current
            Section("Tides & current") {
                if show(.timeHighTide), log.timeHighTide > 0 {
                    dataRow(label: "Time of high tide",
                            value: String(format: "%.2f h", log.timeHighTide))
                }
                if show(.speedOfCurrent), log.speedOfCurrent > 0 {
                    dataRow(label: "Current speed",
                            value: String(format: "%.1f kn", log.speedOfCurrent))
                }
                if show(.directionOfCurrent), log.directionOfCurrent > 0 {
                    dataRow(label: "Current direction",
                            value: String(format: "%.0f°", log.directionOfCurrent))
                }
            }

            // MARK: Weather & sea
            Section("Weather & sea") {
                if show(.pressure), log.pressure > 0 {
                    dataRow(label: "Pressure",
                            value: String(format: "%.0f hPa", log.pressure))
                }
                if show(.TWS), log.TWS != 0 {
                    dataRow(label: "True wind speed", value: "\(log.TWS) kt")
                }
                if show(.TWD), log.TWD != 0 {
                    dataRow(label: "True wind direction", value: "\(log.TWD)°")
                }
                if show(.windGust), log.windGust > 0 {
                    dataRow(label: "Gusts",
                            value: String(format: "%.0f kt", log.windGust))
                }
                if show(.windForce), log.windForce != 0 {
                    dataRow(label: "Wind force", value: "\(log.windForce) Bft")
                }
                if show(.airTemp), log.airTemp != 0 {
                    dataRow(label: "Air temperature", value: "\(log.airTemp)°C")
                }
                if show(.waterTemp), log.waterTemp != 0 {
                    dataRow(label: "Water temperature", value: "\(log.waterTemp)°C")
                }
                if show(.seaState), !log.seaState.isEmpty {
                    dataRow(label: "Sea state", value: log.seaState)
                }
                if show(.cloudCover), !log.cloudCover.isEmpty {
                    dataRow(label: "Cloud cover", value: log.cloudCover)
                }
                if show(.precipitation), log.precipitation != .none {
                    dataRow(label: "Precipitation",
                            value: friendlyLabel(from: log.precipitation.rawValue))
                }
                if show(.severeWeather), log.severeWeather != .none {
                    dataRow(label: "Severe weather",
                            value: friendlyLabel(from: log.severeWeather.rawValue))
                }
                if show(.visibility), !log.visibility.isEmpty {
                    dataRow(label: "Visibility", value: log.visibility)
                }
            }

            // MARK: Sails & propulsion
            Section("Sails & propulsion") {
                if show(.propulsion), log.propulsion != .none {
                    dataRow(label: "Propulsion",
                            value: friendlyLabel(from: log.propulsion.rawValue))
                }
                if show(.pointOfSail), !log.pointOfSail.isEmpty {
                    dataRow(label: "Point of sail", value: log.pointOfSail)
                }
                if show(.starboardTack) {
                    dataRow(label: "Tack",
                            value: log.starboardTack ? "Starboard" : "Port")
                }

                if show(.AWA), log.AWA != 0 {
                    dataRow(label: "Apparent wind angle", value: "\(log.AWA)°")
                }
                if show(.AWS), log.AWS != 0 {
                    dataRow(label: "Apparent wind speed", value: "\(log.AWS) kt")
                }

                if show(.steering) {
                    dataRow(label: "Steering",
                            value: friendlyLabel(from: log.steering.rawValue))
                }
            }
        }
        .navigationTitle(navTitle)
    }

    // MARK: Helpers

    private var positionString: String {
        guard log.posLat != 0 || log.posLong != 0 else { return "Unknown" }
        let lat = degMinString(for: log.posLat, isLatitude: true)
        let lon = degMinString(for: log.posLong, isLatitude: false)
        return "\(lat)\n\(lon)"
    }

    private var navTitle: String {
        log.dateOfLog.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func speedString(_ value: Float) -> String {
        guard value > 0 else { return "–" }
        return String(format: "%.1f kn", value)
    }

    private func friendlyLabel(from raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Degree-minute formatter

