//
//  Created by jeroen kok on 07/12/2025.
//

//
//  SailPlanSheet.swift
//  SailTrips
//

//
//  SailTuneSheet.swift
//  SailTrips
//
//  Created by jeroen kok on 07/12/2025.
//

import SwiftUI
import SwiftData

/// Local editing model for one sail in the sheet.
private struct WorkingSail: Identifiable {
    let id: UUID
    let name: String
    let isOptional: Bool
    let isReefed: Bool
    let isFurled: Bool
    let canBeOutpoled: Bool

    // Original values (for diff / logging)
    let originalState: SailState
    let originalPreventer: Bool
    let originalOutpoled: Bool

    // Editable values bound to the UI
    var state: SailState
    var preventer: Bool
    var outpoled: Bool

    /// True if the user actually changed anything for this sail.
    var hasChanges: Bool {
        state != originalState ||
        preventer != originalPreventer ||
        outpoled != originalOutpoled
    }
}

/// Sheet used by A28 “Modify sail plan”.
struct SailPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let runtime: ActionRuntime
    
    @State private var workingSails: [WorkingSail] = []
    
    init(runtime: ActionRuntime) {
        self.runtime = runtime
        
        let boat = runtime.instances.selectedBoat
        
        // NEW: only exclude sails that are out of order.
        let baseSails = boat.sails
            .filter { sail in
                sail.currentState != .outOfOrder
            }
        // First non-optional, then optional, then by name
            .sorted { lhs, rhs in
                if lhs.optional != rhs.optional {
                    return lhs.optional == false && rhs.optional == true
                }
                return lhs.nameOfSail
                    .localizedCaseInsensitiveCompare(rhs.nameOfSail) == .orderedAscending
            }
        
        _workingSails = State(initialValue: baseSails.map { sail in
            WorkingSail(
                id: sail.id,
                name: sail.nameOfSail,
                isOptional: sail.optional,
                isReefed: sail.reducedWithReefs,
                isFurled: sail.reducedWithFurling,
                canBeOutpoled: sail.canBeOutpoled,
                originalState: sail.currentState,
                originalPreventer: sail.preventer,
                originalOutpoled: sail.outpoled,
                state: sail.currentState,
                preventer: sail.preventer,
                outpoled: sail.outpoled
            )
        })
    }
    
    var body: some View {
        Form {
            Section("Sail plan") {
                ForEach($workingSails) { $ws in
                    HStack(alignment: .top, spacing: 12) {
                        // Left column: sail name
                        Text(ws.name)
                            .font(.headline)
                            .frame(maxWidth: .infinity,
                                   alignment: .leading)
                        
                        // Right column: vertical list of options
                        VStack(alignment: .leading, spacing: 6) {
                            // State buttons in a column
                            ForEach(allowedStates(for: ws), id: \.self) { state in
                                Button {
                                    ws.state = state
                                    
                                    // If lowered (or down), clear preventer / outpoled
                                    if state == .lowered || state == .down {
                                        ws.preventer = false
                                        ws.outpoled = false
                                    }
                                } label: {
                                    Text(label(for: state, current: ws.state))
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity,
                                               alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                                .tint(state == ws.state
                                      ? .accentColor
                                      : .secondary)
                            }
                            
                            // Toggles: only when sail is actually driving
                            if isDrivingState(ws.state) {
                                Toggle("Preventer", isOn: $ws.preventer)
                                    .font(.footnote)
                                    .toggleStyle(.button)
                                
                                if ws.canBeOutpoled {
                                    Toggle("Outpoled", isOn: $ws.outpoled)
                                        .font(.footnote)
                                        .toggleStyle(.button)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }
            
        }
            HStack{
                Button("Done") {
                    applyChangesAndDismiss()
                }
                Button("Cancel") {
                    dismiss()
                }
            }

    }
        .navigationTitle("Sail plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    applyChangesAndDismiss()
                }
            }
        }
}
}

// MARK: - Logic / helpers

private extension SailPlanSheet {

    /// Which states we offer for a given sail, based on its current state
    /// and whether it is reefed / furled capable.
    ///
    /// Rules (per your spec):
    /// - When DOWN: only "rig" (-> .rigged)
    /// - When RIGGED: "down" or "full"
    /// - When LOWERED: full + reef/furl positions + down
    /// - When FULL / reefed / furled: change reef/furl / full + lowered (no "down")
    func allowedStates(for sail: WorkingSail) -> [SailState] {
        let current = sail.state

        // The set of "powered" states (full + possible reefs/furls)
        let poweredStates: [SailState] = {
            if sail.isReefed {
                return [.full, .reef1, .reef2, .reef3]
            } else if sail.isFurled {
                return [.full, .vlightFurled, .lightFurled, .halfFurled, .tightFurled]
            } else {
                return [.full]
            }
        }()

        switch current {
        case .down:
            // Only option: rig the sail
            return [.rigged]

        case .rigged:
            // Either put it back down, or hoist to full
            return [.down, .full]

        case .lowered:
            // Sail is on boom / fully furled. Can go to any powered state, or fully down.
            return poweredStates + [.down]

        case .full, .reef1, .reef2, .reef3,
             .vlightFurled, .lightFurled, .halfFurled, .tightFurled:
            // Sail is driving: can change within powered states, or lower it.
            var result = poweredStates
            if !result.contains(.lowered) {
                result.append(.lowered)
            }
            return result

        case .reefed:
            // If you ever use `.reefed` as a “generic” value, treat it like full but reduced.
            var result = poweredStates
            if !result.contains(.lowered) {
                result.append(.lowered)
            }
            return result

        case .outOfOrder:
            // Should not appear in the sheet (filtered out), but keep a safe default.
            return []
        }
    }

    /// Custom label so "rigged" can appear as "Rig" when coming from down.
    func label(for state: SailState, current: SailState) -> String {
        switch (current, state) {
        case (.down, .rigged):
            return "Rig"
        default:
            return state.logName.capitalized
        }
    }

    /// True if this sail state is actually contributing to propulsion.
    /// Used to decide when to show Preventer / Outpoled toggles.
    func isDrivingState(_ state: SailState) -> Bool {
        switch state {
        case .full,
             .reef1, .reef2, .reef3,
             .vlightFurled, .lightFurled, .halfFurled, .tightFurled:
            return true
        default:
            return false
        }
    }

    /// Applies only real changes, logs nicely, updates propulsion & situation, then dismisses.
    func applyChangesAndDismiss() {
        let instances = runtime.instances
        let boat = instances.selectedBoat

        var changeLines: [String] = []

        // 1. Apply only sails that actually changed
        for ws in workingSails where ws.hasChanges {
            guard let sail = boat.sails.first(where: { $0.id == ws.id }) else { continue }

            // Build readable line *before* mutating
            let line = describeChange(for: ws)
            changeLines.append(line)

            // Apply to model
            sail.currentState = ws.state
            sail.preventer = ws.preventer
            sail.outpoled = ws.outpoled
        }

        // 2. If nothing changed: no log, just feedback & dismiss
        if changeLines.isEmpty {
            runtime.showBanner("No changes in sail plan.")
            dismiss()
            return
        }

        // 3. Build final log text
        let header = changeLines.count == 1
            ? "Modified sail:"
            : "Modified sail plan:"

        let logText = ([header] + changeLines.map { "• " + $0 })
            .joined(separator: "\n")

        // 4. Finish: recompute propulsion, re-evaluate situation, write log, banner
        finishSailChange(runtime, logText: logText)

        dismiss()
    }

    /// Human-readable per-sail description.
    func describeChange(for ws: WorkingSail) -> String {
        var parts: [String] = []

        // State change
        if ws.state != ws.originalState {
            switch (ws.originalState, ws.state) {
            case (.down, let new), (.lowered, let new):
                if new == .full {
                    parts.append("hoisted, now full")
                } else {
                    parts.append("hoisted, now \(new.logName)")
                }

            case (let old, .down), (let old, .lowered):
                // From something driving to lowered/down
                switch old {
                case .full, .reefed, .reef1, .reef2, .reef3,
                     .vlightFurled, .lightFurled, .halfFurled, .tightFurled:
                    parts.append(ws.state == .down ? "taken down" : "lowered")
                default:
                    parts.append("now \(ws.state.logName)")
                }

            default:
                parts.append("now \(ws.state.logName)")
            }
        }

        // Preventer
        if ws.preventer != ws.originalPreventer {
            parts.append(ws.preventer ? "preventer rigged" : "preventer removed")
        }

        // Outpoled
        if ws.outpoled != ws.originalOutpoled {
            parts.append(ws.outpoled ? "outpoled" : "brought inboard")
        }

        let detail = parts.isEmpty ? "no effective change" : parts.joined(separator: ", ")
        return "\(ws.name): \(detail)"
    }
}

/// Recompute propulsion + log + banner after sail changes.
fileprivate func finishSailChange(_ runtime: ActionRuntime, logText: String) {
    let instances = runtime.instances

    // Recompute propulsion from current sails + motors
    let newTool = instances.currentPropulsionTool()
    instances.propulsion = newTool

    // Log
    ActionRegistry.logSimple(logText, using: runtime.context)

    // Feedback
    runtime.showBanner("Sail plan updated.")
}
