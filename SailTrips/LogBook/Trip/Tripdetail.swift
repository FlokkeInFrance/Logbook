//
//  Tripdetail.swift
//  SailTrips
//
//  Created by jeroen kok on 20/05/2025.
//

// Shows historical data about trips, a trip companion will show the ongoing trip
import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var showOngoingAlert = false

    var body: some View {
        Form {
            // Group 1: Trip Info
            Section(header: Text("Trip")) {
                LabeledContent("Boat:", value: trip.boat?.name ?? "—")
                if let cruise = trip.cruise {
                    LabeledContent("Part of cruise:", value: cruise.Title)
                }
                LabeledContent("Start date:") {
                                    Text(trip.dateOfStart, style: .date)
                                }
                LabeledContent(
                    "Route:",
                    value: "From \(trip.startPlace?.Name ?? "—") to \(trip.destination?.Name ?? "—")"
                )
                if !trip.plannedStops.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Planned stops:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(trip.plannedStops, id: \.id) { stop in
                            Text(stop.Name)
                        }
                    }
                }
                if !trip.comments.isEmpty {
                    LabeledContent("Comments:", value: trip.comments)
                }
            }

            // Group 2: Crew
            Section(header: Text("Crew")) {
                LabeledContent("Skipper:", value: trip.skipper.map { "\($0.FirstName) \($0.LastName)" } ?? "—")
                if !trip.crew.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Crew:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(trip.crew, id: \.id) { member in
                            Text("\(member.FirstName) \(member.LastName)")
                        }
                    }
                }
            }

            // Group 3: At destination
            if !trip.personAtDestination.isEmpty || !trip.phoneToContact.isEmpty || !trip.vhfChannelDestination.isEmpty {
                Section(header: Text("At destination")) {
                    if !trip.personAtDestination.isEmpty {
                        LabeledContent("Contact person:", value: trip.personAtDestination)
                    }
                    if !trip.phoneToContact.isEmpty || !trip.vhfChannelDestination.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                if !trip.phoneToContact.isEmpty {
                                    Text("Phone:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(trip.phoneToContact)
                                }
                                if !trip.vhfChannelDestination.isEmpty {
                                    Text("VHF:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(trip.vhfChannelDestination)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }

            // Group 4: Conditions
            Section(header: Text("Conditions")) {
                LabeledContent("Weather:", value: trip.weatherAtStart)
                LabeledContent("Forecast:", value: trip.weatherForecast)
                LabeledContent("Warnings:", value: trip.noticesToMariner)
                LabeledContent("Tides:", value: trip.tidalInformation)
            }

            // Group 5: Inventory at start
            Section(header: Text("Inventory at start")) {
                LabeledContent("Water level:", value: "\(Int(trip.waterLevelAtStart)) %")
                // Only show fuel if boat has a combustion engine
                if trip.boat?.hasCombustionEngine == true {
                    LabeledContent("Fuel level:") {
                        Text("\(Int(trip.fuelLevelAtStart)) %")
                    }
                }

                LabeledContent("Charge:", value: "\(Int(trip.batteryLevelAtStart)) %")
            }
        }
        .navigationTitle("Trip Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("View Logbook") { /* TODO */ }
                    Button("Build PDF") { /* TODO */ }
                    Button("Build Story") { /* TODO */ }
                    Button("New Trip") { /* TODO */ }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            // Dismiss if trip is not completed
            if trip.tripStatus != .completed {
                showOngoingAlert = true
            }
        }
        .alert("Trip Ongoing", isPresented: $showOngoingAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Trip is ongoing – returning to live view.")
        }
    }
}

#if DEBUG
/*struct TripDetailView_Previews: PreviewProvider {
    struct DummyBoat { var name = "TestBoat"; var hasCombustionEngine = true }
    struct DummyMember { var id = UUID(); var FirstName = "John"; var LastName = "Doe" }
    static var previews: some View {
        // Create a test trip
        let trip = Trip()
        trip.boat = Boat() // Assume Boat init provides defaults
        trip.boat?.name = "Sea Queen"
        trip.boat?.hasCombustionEngine = true
        trip.dateOfStart = Date()
        trip.tripStatus = .completed
        trip.startPlace = Location(name: "Port A", latitude: 0, longitude: 0)
        trip.destination = Location(name: "Port B", latitude: 0, longitude: 0)
        trip.comments = "Lovely day"
        trip.skipper = CrewMember()
        trip.skipper?.FirstName = "Jane"
        trip.skipper?.LastName = "Smith"
        trip.crew = [CrewMember(), CrewMember()]

        return NavigationView {
            TripDetailView(trip: trip)
        }
    }
}*/
#endif

