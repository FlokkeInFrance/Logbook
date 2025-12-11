//
//  Autopilot.swift
//  SailTrips
//
//  Created by jeroen kok on 09/12/2025.
//

import SwiftUI

struct AutopilotModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let runtime: ActionRuntime

    // Local working copies
    @State private var selectedMode: Autopilot
    @State private var directionText: String

    init(runtime: ActionRuntime) {
        self.runtime = runtime

        let instances = runtime.instances
        let currentMode = instances.autopilotMode

        // If AP is off, start from default engaged mode
        let initialMode = (currentMode == .off) ? Autopilot.defaultEngagedMode : currentMode
        _selectedMode = State(initialValue: initialMode)

        let dir = instances.autopilotDirection
        _directionText = State(initialValue: dir == 0 ? "" : "\(dir)")
    }

    private var selectableModes: [Autopilot] {
        // Don't offer "Off" here; user has A25R for that
        Autopilot.allCases.filter { $0 != .off }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Autopilot mode", selection: $selectedMode) {
                        ForEach(selectableModes, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if selectedMode.needsDirection {
                    Section("Target") {
                        TextField("Target (\u{00B0})", text: $directionText)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Autopilot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyChanges() }
                }
            }
        }
    }

    private func applyChanges() {
        let instances = runtime.instances

        // Parse direction if needed
        var newDirection = instances.autopilotDirection

        if selectedMode.needsDirection {
            if let value = Int(directionText.trimmingCharacters(in: .whitespaces)),
               (0...359).contains(value) {
                newDirection = value
            } else {
                runtime.showBanner(
                    "Please enter a number between 0 and 359°."
                )
                return
            }
        } else {
            newDirection = 0
        }

        instances.autopilotMode = selectedMode
        instances.autopilotDirection = newDirection

        // Make sure steering is actually through autopilot
        instances.steering = .autopilot

        // Log depending on which action invoked us
        let modeName = selectedMode.displayName
        let dirSuffix = selectedMode.needsDirection ? " (\(newDirection)°)" : ""

        if runtime.variant.tag == "A25" {
            // If you ever decide to open the sheet directly from A25
            ActionRegistry.logSimple("Autopilot engaged in \(modeName)\(dirSuffix).",
                                     using: runtime.context)
        } else {
            // A26 (mode change)
            ActionRegistry.logSimple("Autopilot mode set to \(modeName)\(dirSuffix).",
                                     using: runtime.context)
        }

  
        dismiss()
    }
}


struct AutopilotModeSheet2: View {
    @Environment(\.dismiss) private var dismiss

    let runtime: ActionRuntime

    // Local working copies
    @State private var selectedMode: Autopilot
    @State private var directionText: String

    init(runtime: ActionRuntime) {
        self.runtime = runtime

        let instances = runtime.instances
        let currentMode = instances.autopilotMode

        // If AP is off, start from default engaged mode
        let initialMode = (currentMode == .off) ? Autopilot.defaultEngagedMode : currentMode
        _selectedMode = State(initialValue: initialMode)

        let dir = instances.autopilotDirection
        _directionText = State(initialValue: dir == 0 ? "" : "\(dir)")
    }

    private var selectableModes: [Autopilot] {
        // Don't offer "Off" here; user has A25R for that
        Autopilot.allCases.filter { $0 != .off }
    }

    var body: some View {
        HStack{
            Button("Apply") { applyChanges() }
            Spacer()
            Text ("Autopilot")
            Spacer()
            Button("Cancel") { dismiss() }
        }
            Form {
                Section("Mode") {
                    Picker("Autopilot mode", selection: $selectedMode) {
                        ForEach(selectableModes, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if selectedMode.needsDirection {
                    Section("Target") {
                        TextField("Target (\u{00B0})", text: $directionText)
                            .keyboardType(.numberPad)
                    }
                }
            }
           /* .navigationTitle("Autopilot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyChanges() }
                }
            }*/
        
    }

    private func applyChanges() {
        let instances = runtime.instances

        // Parse direction if needed
        var newDirection = instances.autopilotDirection

        if selectedMode.needsDirection {
            if let value = Int(directionText.trimmingCharacters(in: .whitespaces)),
               (0...359).contains(value) {
                newDirection = value
            } else {
                runtime.showBanner(
                    "Invalid target Please enter a number between 0 and 359°."
                )
                return
            }
        } else {
            newDirection = 0
        }

        instances.autopilotMode = selectedMode
        instances.autopilotDirection = newDirection

        // Make sure steering is actually through autopilot
        instances.steering = .autopilot

        // Log depending on which action invoked us
        let modeName = selectedMode.displayName
        let dirSuffix = selectedMode.needsDirection ? " (\(newDirection)°)" : ""

        if runtime.variant.tag == "A25" {
            // If sheet called directly from A25
            ActionRegistry.logSimple("Autopilot engaged in \(modeName)\(dirSuffix).",
                                     using: runtime.context)
        } else {
            // A26 (mode change)
            ActionRegistry.logSimple("Autopilot mode set to \(modeName)\(dirSuffix).",
                                     using: runtime.context)
        }

        dismiss()
    }
}
