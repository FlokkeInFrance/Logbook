//
//  SailTrips
//
//  Created by jeroen kok on 11/12/2025.
//

//  SailingGeometrySheet.swift


import SwiftUI
import SwiftData

struct SailingGeometrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let runtime: ActionRuntime

    @State private var selectedTack: Tack
    @State private var selectedPointOfSail: PointOfSail
    @State private var headingText: String

    private var instances: Instances { runtime.instances }

    private var propulsion: PropulsionTool {
        instances.propulsion
    }

    /// Whether we’re under motor only
    private var motorOnly: Bool {
        propulsion == .motor
    }

    init(runtime: ActionRuntime) {
        self.runtime = runtime

        let inst = runtime.instances

        // Default t/Users/jeroen/Desktop/SailTrips/SailTrips/Model/NMEA/NMEA Test.swiftack: if .none, assume starboard as a starting point
        let initialTack: Tack = (inst.tack == .none) ? .starboard : inst.tack
        _selectedTack = State(initialValue: initialTack)
        _selectedPointOfSail = State(initialValue: inst.pointOfSail)

        if inst.magHeading > 0 {
            _headingText = State(initialValue: String(inst.magHeading))
        } else {
            _headingText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !motorOnly {
                    tackSection
                    pointOfSailSection
                }

                headingSection
            }
            .navigationTitle("Sailing data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        applyChangesAndLog()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var tackSection: some View {
        Section("Tack") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Tack.allCases.filter { $0 != .none }) { tack in
                    optionRow(
                        title: tackTitle(tack),
                        isSelected: tack == selectedTack
                    ) {
                        selectedTack = tack
                    }
                }
            }
        }
    }

    private var pointOfSailSection: some View {
        Section("Point of sail") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(PointOfSail.allCases.filter { $0 != .stopped}) { pos in
                    optionRow(
                        title: pointOfSailTitle(pos),
                        isSelected: pos == selectedPointOfSail
                    ) {
                        selectedPointOfSail = pos
                    }
                }
            }
        }
    }

    private var headingSection: some View {
        Section("Magnetic heading") {
            TextField("Heading (° 0–359)", text: $headingText)
                .keyboardType(.numberPad)
        }
    }

    // MARK: - Row helper

    private func optionRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.2)
                          : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .primary : .secondary)
    }

    // MARK: - Titles

    private func tackTitle(_ tack: Tack) -> String {
        switch tack {
        case .port: "Port"
        case .starboard: "Starboard"
        case .none: "None"
        }
    }

    private func pointOfSailTitle(_ pos: PointOfSail) -> String {
        switch pos {
        case .closeHauled: "Close hauled"
        case .closeReach:  "Close reach"
        case .beamReach:   "Beam reach"
        case .broadReach:  "Broad reach"
        case .running:     "Running"
        case .deadRun:     "Dead run"
        case .stopped:     "Stopped"
        }
    }

    // MARK: - Apply + log

    private func applyChangesAndLog() {
        let inst = instances

        // Snapshot old values for logging
        let oldHeading = inst.magHeading
        let oldTack = inst.tack
        let oldPos = inst.pointOfSail

        // 1) Heading
        let newHeading: Int = {
            guard let val = Int(headingText.trimmingCharacters(in: .whitespaces)),
                  (0...359).contains(val)
            else { return oldHeading }
            return val
        }()

        inst.magHeading = newHeading

        // 2) Tack and point of sail – only when sails are part of propulsion
        if !motorOnly {
            inst.tack = selectedTack
            inst.pointOfSail = selectedPointOfSail
        }

        // 3) Log a context-aware line
        logGeometryChange(
            oldHeading: oldHeading,
            newHeading: newHeading,
            oldTack: oldTack,
            newTack: inst.tack,
            oldPos: oldPos,
            newPos: inst.pointOfSail
        )
    }


    private func logGeometryChange(
        oldHeading: Int,
        newHeading: Int,
        oldTack: Tack,
        newTack: Tack,
        oldPos: PointOfSail,
        newPos: PointOfSail
    ) {
        let ctx = runtime.context
        let inst = runtime.instances
        let tag = runtime.variant.tag

        let propulsion = inst.propulsion
        let underMotorOnly = (propulsion == .motor)

        // Localized segments
        let headingPhrase = SailingLogStrings.headingPhrase(old: oldHeading, new: newHeading)
        let posPhrase = SailingLogStrings.pointOfSailPhrase(
            old: oldPos,
            new: newPos,
            underMotorOnly: underMotorOnly
        )
        let tackPhrase = SailingLogStrings.tackPhrase(
            old: oldTack,
            new: newTack,
            underMotorOnly: underMotorOnly
        )

        let prefix = SailingLogStrings.prefix(for: tag, underMotorOnly: underMotorOnly)

        let message: String

        if underMotorOnly {
            // Motor / no sails – we only care about heading
            if headingPhrase.isEmpty {
                message = SailingLogStrings.defaultHeadingUpdatedUnderPower()
            } else {
                // e.g. "Course changed under power, heading changed from 90° to 210°."
                message = prefix + headingPhrase + "."
            }
        } else {
            // Sailing or motorsailing – use full geometry
            if headingPhrase.isEmpty && tackPhrase.isEmpty && posPhrase.isEmpty {
                message = SailingLogStrings.defaultSailingDataUpdated()
            } else {
                // e.g. "Sails set: now close reach on port tack heading 145°."
                message = prefix + posPhrase + tackPhrase + headingPhrase + "."
            }
        }

        ActionRegistry.logSimple(message, using: ctx)
    }


}
