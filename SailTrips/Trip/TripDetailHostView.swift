//
//  TripDetailHostView.swift
//  SailTrips
//
//  Created by jeroen kok on 13/12/2025.
//


import SwiftUI
import SwiftData

struct TripDetailHostView: View {
    @EnvironmentObject private var active: activations
    @Query private var trips: [Trip]

    init() {
        _trips = Query(sort: \Trip.dateOfStart, order: .reverse)
    }

    var body: some View {
        guard let id = active.selectedTripDetailsID else {
            return AnyView(ContentUnavailableView("No trip selected", systemImage: "questionmark"))
        }
        if let trip = trips.first(where: { $0.id == id }) {
            return AnyView(TripDetailView(trip: trip))
        } else {
            return AnyView(ContentUnavailableView("Trip not found", systemImage: "exclamationmark.triangle"))
        }
    }
}

