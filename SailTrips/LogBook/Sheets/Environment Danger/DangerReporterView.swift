//
//  DangerReporterView.swift
//  SailTrips
//
//  Created by jeroen kok on 26/11/2025.
//

import SwiftUI

struct DangerReporterView: View {
    @Environment(\.dismiss) private var dismiss

    /// Initial dangers (from `instances.environmentDangers`)
    private let initialDangers: [EnvironmentDangers]
    /// Callback when user validates
    let onComplete: (_ newDangers: [EnvironmentDangers], _ notes: String) -> Void

    @State private var selected: Set<EnvironmentDangers> = []
    @State private var notes: String = ""

    init(
        existing: [EnvironmentDangers],
        onComplete: @escaping (_ newDangers: [EnvironmentDangers], _ notes: String) -> Void
    ) {
        self.initialDangers = existing
        self.onComplete = onComplete
        // _selected and _notes will be initialized in .onAppear for safety
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dangers in the area") {
                    ForEach(EnvironmentDangers.allCases.filter { $0 != .none }, id: \.self) { danger in
                        Toggle(isOn: Binding(
                            get: { selected.contains(danger) },
                            set: { isOn in
                                if isOn { selected.insert(danger) }
                                else { selected.remove(danger) }
                            }
                        )) {
                            Text(danger.displayName)
                        }
                    }
                }

                Section("Other / notes") {
                    TextField("Describe anything not in the list…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Dangers spotted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Signal") {
                        let newArray: [EnvironmentDangers]
                        if selected.isEmpty {
                            // If user unchecks everything, we treat this as "no specific dangers" → [.none]
                            newArray = [.none]
                        } else {
                            newArray = Array(selected).sorted { $0.displayName < $1.displayName }
                        }
                        onComplete(newArray, notes)
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize selection from existing dangers (ignore .none)
                let active = initialDangers.filter { $0 != .none }
                self.selected = Set(active)
            }
        }
    }
}
