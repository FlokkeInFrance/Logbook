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
                    newTrip = trip
                }
            }
        }
        .alert(isPresented: $showCruiseMatchAlert) {
            Alert(
                title: Text("Cruise Match Found"),
                message: Text("Is this trip part of cruise '\(potentialCruise?.Title ?? "")'?"),
                primaryButton: .default(Text("Yes"), action: confirmCruiseMatch),
                secondaryButton: .cancel { finalizeTripCreation() }
            )
        }
    }

    // MARK: - Trip creation logic
    private func beginTrip() {
        let trip = Trip()
        trip.boat = instances.selectedBoat
        trip.dateOfStart = Date()
        trip.tripStatus = .preparing
        if let place = instances.currentLocation{
        trip.startPlace = place}

        // Look for a matching cruise if none is current
        if let currentCruise = instances.currentCruise {
            potentialCruise = currentCruise
            showCruiseMatchAlert = true
            newTrip = trip
        } else if let match = allCruises.first(where: {
            $0.Boat?.id == instances.selectedBoat.id &&
            $0.DateOfStart <= trip.dateOfStart &&
            ($0.DateOfArrival ?? Date.distantFuture) >= trip.dateOfStart
        }) {
            potentialCruise = match
            showCruiseMatchAlert = true
            newTrip = trip
        } else {
            newTrip = trip
            finalizeTripCreation()
        }
    }

    private func confirmCruiseMatch() {
        guard let trip = newTrip, let cruise = potentialCruise else { return }
        // Assign cruise to trip & instances
        trip.cruise = cruise
        instances.currentCruise = cruise
        // Copy crew
        trip.crew = cruise.Crew
        // Determine start/destination
        if let start = trip.startPlace,
           let idx = cruise.legs.firstIndex(where: { $0.id == start.id }),
           idx + 1 < cruise.legs.count {
            trip.destination = cruise.legs[idx + 1]
        } else if cruise.legs.count >= 2 {
            trip.startPlace = cruise.legs[0]
            trip.destination = cruise.legs[1]
        }
        finalizeTripCreation()
    }

    private func finalizeTripCreation() {
        guard let trip = newTrip else { return }
        modelContext.insert(trip)
        instances.currentTrip = trip
        // Navigate to detail
        navPath.path.append(HomePageNavigation.tripdetail)
    }
}

