//
//  TripList.swift
//  SailTrips
//
//  Created by jeroen kok on 20/05/2025.
//
// Shows the trips made in the past for the current boat, sorted by cruise and date

import SwiftUI
import SwiftData

struct TripListView: View {
    @Bindable var instances: Instances
    @EnvironmentObject var navPath: PathManager
    @Environment(\ .modelContext) private var modelContext

    // Fetch all cruises (for potential cruise matching)
    @Query(sort: \Cruise.DateOfStart, order: .forward)
    private var allCruises: [Cruise]

    // Fetch all trips sorted by start date descending
    @Query(sort: \Trip.dateOfStart, order: .reverse)
    private var allTrips: [Trip]

    @State private var yearFilter: String = ""
    @State private var showCruiseMatchAlert = false
    @State private var potentialCruise: Cruise?
    @State private var newTrip: Trip?
    @State private var selectedTrip: Trip?
    @State private var showTripActions = false

    // Compute filtered trips for current boat and optional year
    private var filteredTrips: [Trip] {
        var trips = allTrips.filter { $0.boat?.id == instances.selectedBoat.id }
        if let year = Int(yearFilter), yearFilter.count == 4 {
            let calendar = Calendar.current
            trips = trips.filter {
                calendar.component(.year, from: $0.dateOfStart) == year
            }
        }
        return trips
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("History of trips made with \(instances.selectedBoat.name)")
                .font(.title2)
                .padding(.top)

            // Current or Begin Trip button
            if instances.currentTrip != nil {
                Button(action: {
                    navPath.path.append(HomePageNavigation.tripdetail)
                }) {
                    Text("Open Current Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke()
                        )
                }
                .padding(.horizontal)
            } else {
                Button(action: beginTrip) {
                    Text("Begin a Trip")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke()
                        )
                }
                .padding(.horizontal)
            }

            // Year filter input
            HStack {
                Text("Year:")
                TextField("YYYY", text: $yearFilter)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
            }
            .padding(.horizontal)

            // Trips list
            List(filteredTrips, id: \ .id, selection: $newTrip) { trip in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trip.dateOfStart, style: .date)
                        Text("- \(trip.tripType.rawValue)")
                    }
                    Text("From \(trip.startPlace?.Name ?? "a place") to \(trip.destination?.Name ?? "another place")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Show") { /* TODO */ }
                    Button("Export") { /* TODO */ }
                    Button("Make PDF") { /* TODO */ }
                    Button("Story") { /* TODO */ }
                }
                .onTapGesture {
                    selectedTrip = trip
                    showTripActions = true
                }

            }
        }
        .alert(isPresented: $showCruiseMatchAlert) {
            Alert(
                title: Text("Cruise Match Found"),
                message: Text("Is this trip part of cruise '\(potentialCruise?.Title ?? "")'?"),
                primaryButton: .default(Text("Yes"), action: confirmCruiseMatch),
                secondaryButton: .cancel { beginTrip() }
            )
        }
        .confirmationDialog(
            "Trip",
            isPresented: $showTripActions,
            titleVisibility: .visible
        ) {
            Button("Show logs") {
                if let id = selectedTrip?.id {
                    navPath.path.append(HomePageNavigation.logView(tripID: id))
                }
            }
            Button("Trip details") {
                if let id = selectedTrip?.id {
                    navPath.path.append(HomePageNavigation.tripDetails)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let t = selectedTrip {
                Text(t.dateOfStart.formatted(date: .abbreviated, time: .omitted))
            }
        }

    }

    // MARK: - Trip creation logic
    private func beginTrip() {
        do {
            let starter = TripStarter(context: modelContext)
            let res = try starter.startTrip(instances: instances, cruises: allCruises)

            potentialCruise = res.detectedCruise
            newTrip = res.trip

            if potentialCruise != nil {
                showCruiseMatchAlert = true
            } else {
                navPath.path.append(HomePageNavigation.tripCompanion)
            }
        } catch {
            print(error)
        }
    }

    private func confirmCruiseMatch() {
        guard let cruise = potentialCruise else { return }
        do {
            try TripStarter(context: modelContext).setCurrentCruise(cruise, instances: instances)
            // If you still want “copy crew + infer destination” for cruise legs, keep that here
            navPath.path.append(HomePageNavigation.tripCompanion)
        } catch {
            print(error)
        }
    }

}

