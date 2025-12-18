//
//  RelocateBoatSheet.swift
//  SailTrips
//
//  Created by jeroen kok on 18/12/2025.
//


import SwiftUI
import CoreLocation
import SwiftData

struct RelocateBoatSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ctx: ActionContext

    @State private var placeName: String = ""
    @State private var rememberPlace: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("New place") {
                    TextField("Name (e.g. Port Haliguen – pontoon C)", text: $placeName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Toggle("Remember this place in Locations", isOn: $rememberPlace)
                } footer: {
                    Text("If enabled, a new Location is created with type = mooring, coordinates = here, last visit = now.")
                }
            }
            .navigationTitle("Relocate boat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commit()
                        dismiss()
                    }
                    .disabled(placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func commit() {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1) Log
        ActionRegistry.logSimple("Boat relocated at \(trimmed)", using: ctx)

        // 2) Optionally create a Location (TypeOfLocation.mooring exists in your enums) :contentReference[oaicite:2]{index=2}
        guard rememberPlace else { return }

        let lat = ctx.instances.gpsCoordinatesLat
        let lon = ctx.instances.gpsCoordinatesLong

        let loc = Location(name: trimmed, latitude: lat, longitude: lon) // Location model :contentReference[oaicite:3]{index=3}
        loc.typeOfLocation = .mooring
        loc.LastDateVisited = .now

        ctx.modelContext.insert(loc)

        // Optional (but nice for continuity): make it the trip’s destination if you want later.
        // For now, we just “remember” it, as you requested.
    }
}
