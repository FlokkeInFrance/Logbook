//
//  TankInventorySheet.swift
//  SailTrips
//
//  Created by jeroen kok on 16/12/2025.
//


import SwiftUI
import SwiftData

struct TankInventorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var boat: Boat
    var filterKinds: Set<TankTypes>? = nil   // nil = all; e.g. [.fuel] for A9

    private var visibleTanks: [InventoryItem] {
        let tanks = boat.tankItems
        guard let filterKinds else { return tanks }
        return tanks.filter { $0.tankKind.map(filterKinds.contains) ?? false }
    }

    private func tanks(for kind: TankTypes) -> [InventoryItem] {
        visibleTanks.filter { $0.tankKind == kind }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(TankTypes.allCases) { kind in
                    let list = tanks(for: kind)
                    if !list.isEmpty {
                        Section(kind.title) {
                            ForEach(list, id: \.id) { tank in
                                TankLevelRow(tank: tank)
                            }
                        }
                    }
                }

                if visibleTanks.isEmpty {
                    ContentUnavailableView("No tanks defined",
                                           systemImage: "drop",
                                           description: Text("Define your tank layout first in the boat settings."))
                }
            }
            .navigationTitle("Tank levels")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TankLevelRow: View {
    @Bindable var tank: InventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tank.name.isEmpty ? "Unnamed" : tank.name)
                    .font(.headline)
                Spacer()
                Text("\(tank.percentFull)%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            // Top ruler (percent)
            RulerLine(left: "0%", mid: "50%", right: "100%")

            // Slider controls percent (stored in `quantity`)
            Slider(
                value: Binding(
                    get: { Double(tank.percentFull) },
                    set: { tank.percentFull = Int($0.rounded()) }
                ),
                in: 0...100,
                step: 1
            )

            // Bottom ruler (actual quantity if known)
            if tank.capacity > 0 {
                let mid = tank.capacity / 2
                RulerLine(left: "0", mid: "\(mid)", right: "\(tank.capacity)")
                if let amt = tank.amountComputed {
                    Text("≈ \(amt) / \(tank.capacity)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Capacity unknown — tracking in % only")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct RulerLine: View {
    let left: String
    let mid: String
    let right: String

    var body: some View {
        HStack {
            Text(left).frame(maxWidth: .infinity, alignment: .leading)
            Text(mid).frame(maxWidth: .infinity, alignment: .center)
            Text(right).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
}
