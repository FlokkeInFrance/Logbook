//
//  quick add location.swift
//  SailTrips
//
//  Created by jeroen kok on 21/05/2025.
//

import SwiftUI
import SwiftData

struct QuickAddLocationView: View {
    /// Binding to a new Location instance (preset with type .pOI)
    @Binding var location: Location
    @Environment(\.dismiss) private var dismiss
    @State private var showValidationAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Name", text: $location.Name)
                    Picker("Type", selection: $location.typeOfLocation) {
                        ForEach(TypeOfLocation.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section(header: Text("Coordinates")) {
                    CoordinatesView(
                        latitude: $location.Latitude,
                        longitude: $location.Longitude,
                        isEditable: true
                    )
                }
            }
            .navigationTitle("Quick Add Location")
            .navigationBarItems(
                leading: Button("Cancel") {
                    // Signal deletion by clearing name
                    location.Name = ""
                    dismiss()
                },
                trailing: Button("Done") {
                    // Validate: non-empty name and at least one coord != 0
                    if location.Name.trimmingCharacters(in: .whitespaces).isEmpty ||
                       (location.Latitude == 0 && location.Longitude == 0) {
                        showValidationAlert = true
                    } else {
                        dismiss()
                    }
                }
            )
            .alert("Invalid Location", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please begin again and provide a name and at least one non-zero coordinate.")
            }
        }
    }
}
