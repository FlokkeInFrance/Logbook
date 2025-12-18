//
//  LogbookViewer.swift
//  SailTrips
//
//  Created by jeroen kok on 02/12/2025.
//


import SwiftUI
import SwiftData

/// iPhone-first Logbook viewer (no split view).
/// Uses global selection: `active.selectedTripID`
/// - nil => show all logs
/// - UUID => only logs whose `trip?.id` matches
///
struct LogbookViewer: View {
    
    let tripID: UUID?          // nil = all logs
    
    @Query private var logs: [Logs]
    @Query private var settingsArray: [LogbookSettings]
    
    @State private var ascending = false
    @State private var searchText = ""
    
    private var logbookSettings: LogbookSettings? { settingsArray.first }
    
    private var sortedLogs: [Logs] {
        ascending ? logs.sorted { $0.dateOfLog < $1.dateOfLog }
                  : logs.sorted { $0.dateOfLog > $1.dateOfLog }
    }
    
    init(tripID: UUID?) {
        self.tripID = tripID
        
        if let tripID {
            _logs = Query(
                filter: #Predicate<Logs> { log in
                    log.trip.id == tripID
                },
                sort: [SortDescriptor(\Logs.dateOfLog, order: .reverse)]
            )
        } else {
            _logs = Query(sort: [SortDescriptor(\Logs.dateOfLog, order: .reverse)])
        }
    }
    
    
    var body: some View {
        List(sortedLogs) { log in
            NavigationLink {
                LogDetailView(log: log, settings: logbookSettings)
            } label: {
                LogRowView(log: log)
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ascending.toggle() } label: {
                    Image(systemName: ascending ? "arrow.up" : "arrow.down")
                }
            }
        }
        .overlay {
            if logs.isEmpty {
                ContentUnavailableView(
                    "No log entries",
                    systemImage: "note.text",
                    description: Text(emptyMessage)
                )
            }
        }
    }
    
    private var title: String {
        tripID == nil ? "Logbook" : "Trip logbook"
    }

    private var emptyMessage: String {
        tripID == nil
        ? "Once you start logging, entries will appear here."
        : "This trip has no log entries yet."
    }

}

// MARK: - Row

private struct LogRowView: View {
    let log: Logs

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
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
                    .lineLimit(2)
            } else if !log.nextWaypoint.isEmpty {
                Text("→ \(log.nextWaypoint)")
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var shortPosition: String {
        guard log.posLat != 0 || log.posLong != 0 else { return "–" }
        let lat = degMinString(for: log.posLat, isLatitude: true)
        let lon = degMinString(for: log.posLong, isLatitude: false)
        return "\(lat) \(lon)"
    }
}

// MARK: - Detail

private struct LogDetailView: View {
    let log: Logs
    let settings: LogbookSettings?

    private func show(_ field: LogField) -> Bool {
        settings?.isLogFieldVisible(field) ?? true
    }

    var body: some View {
        Form {
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
                        Text("Log text").font(.subheadline)
                        Text(log.logEntry)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Position & route") {
                row("Position", positionString, multiline: true)

                if show(.nextWaypoint), !log.nextWaypoint.isEmpty {
                    row("Next waypoint", log.nextWaypoint)
                }
                if show(.distanceToWP), log.distanceToWP > 0 {
                    row("Distance to WP", String(format: "%.1f nm", log.distanceToWP))
                }
            }

            Section("Navigation") {
                if show(.SOG), log.SOG > 0 { row("SOG", speedString(log.SOG)) }
                if show(.SOW), log.STW > 0 { row("STW", speedString(log.STW)) }
                if show(.COG), log.COG != 0 { row("COG", "\(log.COG)°") }
                if show(.magCourse), log.magHeading != 0 { row("Magnetic course", "\(log.magHeading)°") }
                if show(.distanceSinceLastEntry), log.distanceSinceLastEntry > 0 {
                    row("Distance since last entry", String(format: "%.1f nm", log.distanceSinceLastEntry))
                }
                if show(.averageSpeedSinceLastEntry), log.averageSpeedSinceLastEntry > 0 {
                    row("Average speed", speedString(log.averageSpeedSinceLastEntry))
                }
            }

            Section("Tides & current") {
                if show(.timeHighTide), log.timeHighTide > 0 {
                    row("Time of high tide", String(format: "%.2f h", log.timeHighTide))
                }
                if show(.speedOfCurrent), log.speedOfCurrent > 0 {
                    row("Current speed", String(format: "%.1f kn", log.speedOfCurrent))
                }
                if show(.directionOfCurrent), log.directionOfCurrent > 0 {
                    row("Current direction", String(format: "%.0f°", log.directionOfCurrent))
                }
            }

            Section("Weather & sea") {
                if show(.pressure), log.pressure > 0 { row("Pressure", String(format: "%.0f hPa", log.pressure)) }
                if show(.TWS), log.TWS != 0 { row("True wind speed", "\(log.TWS) kt") }
                if show(.TWD), log.TWD != 0 { row("True wind direction", "\(log.TWD)°") }
                if show(.windGust), log.windGust > 0 { row("Gusts", String(format: "%.0f kt", log.windGust)) }
                if show(.windForce), log.windForce != 0 { row("Wind force", "\(log.windForce) Bft") }
                if show(.airTemp), log.airTemp != 0 { row("Air temperature", "\(log.airTemp)°C") }
                if show(.waterTemp), log.waterTemp != 0 { row("Water temperature", "\(log.waterTemp)°C") }
                if show(.seaState), !log.seaState.isEmpty { row("Sea state", log.seaState) }
                if show(.cloudCover), !log.cloudCover.isEmpty { row("Cloud cover", log.cloudCover) }
                if show(.precipitation), log.precipitation != .none {
                    row("Precipitation", friendlyLabel(from: log.precipitation.rawValue))
                }
                if show(.severeWeather), log.severeWeather != .none {
                    row("Severe weather", friendlyLabel(from: log.severeWeather.rawValue))
                }
                if show(.visibility), !log.visibility.isEmpty { row("Visibility", log.visibility) }
            }

            Section("Sails & propulsion") {
                if show(.propulsion), log.propulsion != .none {
                    row("Propulsion", friendlyLabel(from: log.propulsion.rawValue))
                }
                if show(.pointOfSail), !log.pointOfSail.isEmpty { row("Point of sail", log.pointOfSail) }
                if show(.tack) { row("Tack", friendlyLabel(from: log.tack.rawValue))}
                if show(.AWA), log.AWA != 0 { row("Apparent wind angle", "\(log.AWA)°") }
                if show(.AWS), log.AWS != 0 { row("Apparent wind speed", "\(log.AWS) kt") }
                if show(.steering) { row("Steering", friendlyLabel(from: log.steering.rawValue)) }
            }
        }
        .navigationTitle(log.dateOfLog.formatted(date: .omitted, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var positionString: String {
        guard log.posLat != 0 || log.posLong != 0 else { return "Unknown" }
        let lat = degMinString(for: log.posLat, isLatitude: true)
        let lon = degMinString(for: log.posLong, isLatitude: false)
        return "\(lat)\n\(lon)"
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String, multiline: Bool = false) -> some View {
        HStack(alignment: multiline ? .top : .center) {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func speedString(_ value: Float) -> String {
        String(format: "%.1f kn", value)
    }

    private func friendlyLabel(from raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
