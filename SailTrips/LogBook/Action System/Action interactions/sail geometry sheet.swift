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

    private var motorOnly: Bool {
        // under motor only OR no propulsion selected
        let p = instances.propulsion
        return !(p == .sail || p == .motorsail)
    }

    init(runtime: ActionRuntime) {
        self.runtime = runtime
        let inst = runtime.instances

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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sailing data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                        title: tack.displayString,
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
                ForEach(PointOfSail.allCases.filter { $0 != .stopped }) { pos in
                    optionRow(
                        title: pos.displayString,
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
            TextField("Heading (0–359)", text: $headingText)
                .keyboardType(.numberPad)

            if let h = parsedHeading(), !(0...359).contains(h) {
                Text("Heading must be between 0 and 359.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.20)
                                     : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .primary : .secondary)
    }

    // MARK: - Apply + log

    private func parsedHeading() -> Int? {
        let trimmed = headingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func sanitizedHeading(_ raw: Int?) -> Int {
        guard let raw else { return 0 }
        guard (0...359).contains(raw) else { return 0 }
        return raw
    }

    private func applyChangesAndLog() {
        let ctx = runtime.context
        let inst = runtime.instances
        let tag = runtime.variant.tag

        let oldHeading = inst.magHeading
        let oldTack = inst.tack
        let oldPos = inst.pointOfSail

        let newHeading = sanitizedHeading(parsedHeading())

        // Apply changes to Instances
        if newHeading != 0 { inst.magHeading = newHeading }

        if !motorOnly {
            inst.tack = selectedTack
            inst.pointOfSail = selectedPointOfSail
        }

        // Build log message
        let underMotorOnly = motorOnly

        let headingPhrase = SailingLogStrings.headingPhrase(old: oldHeading, new: inst.magHeading)
        let posPhrase = SailingLogStrings.pointOfSailPhrase(old: oldPos, new: inst.pointOfSail, underMotorOnly: underMotorOnly)
        let tackPhrase = SailingLogStrings.tackPhrase(old: oldTack, new: inst.tack, underMotorOnly: underMotorOnly)
        let prefix = SailingLogStrings.prefix(for: tag, underMotorOnly: underMotorOnly)

        let message: String
        if underMotorOnly {
            message = (headingPhrase.isEmpty ? "Course updated under power."
                                             : (prefix + headingPhrase + "."))
        } else {
            if headingPhrase.isEmpty && tackPhrase.isEmpty && posPhrase.isEmpty {
                message = "Sailing data updated."
            } else {
                message = prefix + posPhrase + tackPhrase + headingPhrase + "."
            }
        }

        ActionRegistry.logSimple(message, using: ctx)
    }
}
