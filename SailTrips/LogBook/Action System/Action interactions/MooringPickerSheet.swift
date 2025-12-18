//
//  MooringPickerSheet.swift
//  SailTrips
//
//  Created by jeroen kok on 16/12/2025.
//

import SwiftUI
import SwiftData

struct MooringPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let runtime: ActionRuntime
    @State private var selected: MooringType

    init(runtime: ActionRuntime) {
        self.runtime = runtime
        _selected = State(initialValue: runtime.instances.mooringUsed)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MooringType.allCases.filter { $0 != MooringType.none }) { type in
                    HStack {
                        Text(type.displayString)
                        Spacer()
                        if type == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selected = type
                    }
                }
            }
            .navigationTitle(String(localized: "sheet.mooring.title", defaultValue: "Choose mooring"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.confirm", defaultValue: "Confirm")) {
                        applySelection()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applySelection() {
        let instances = runtime.instances
        let trip = instances.currentTrip

        guard trip != nil else { return }

        instances.mooringUsed = selected

        let zoneT = instances.currentNavZone.displayString
        ActionRegistry.logSimple("Boat moored in \(zoneT), \(selected.displayString).", using: runtime.context)

    }
}
