//
//  TankLayoutSheet.swift
//  SailTrips
//
//  Created by jeroen kok on 16/12/2025.
//


import SwiftUI
import SwiftData

struct TankLayoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var boat: Boat

    var body: some View {
        NavigationStack {
            List {
                ForEach(TankTypes.allCases) { kind in
                    Section(kind.title) {
                        let tanks = boat.tankItems(of: kind)

                        if tanks.isEmpty {
                            Text("No \(kind.title.lowercased()) defined.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(tanks, id: \.id) { tank in
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Name", text: Binding(
                                        get: { tank.name },
                                        set: { tank.name = $0 }
                                    ))

                                    if !kind.suggestedNames.isEmpty {
                                        Text("Suggestions: \(kind.suggestedNames.joined(separator: ", ")) …")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack {
                                        IntField(label: "Capacity (0 = unknown)", inData: Binding(
                                            get: { tank.capacity },
                                            set: { tank.capacity = max(0, $0) }
                                        ))
                                        .frame(maxWidth: 240)
                                        Spacer()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete { indexSet in
                                // Only delete among this kind’s items
                                let toDelete = indexSet.map { tanks[$0] }
                                for item in toDelete {
                                    if let i = boat.inventory.firstIndex(where: { $0.id == item.id }) {
                                        boat.inventory.remove(at: i)
                                    }
                                    modelContext.delete(item)
                                }
                                try? modelContext.save()
                            }
                        }

                        Button {
                            let item = InventoryItem(
                                boat: boat,
                                name: defaultTankName(for: kind),
                                category: .other,
                                subcategory: kind.rawValue,
                                type: .tank,
                                storageSite: "",
                                tracksUsageInLogbook: false
                            )
                            item.capacity = 0
                            item.quantity = 100 // default full
                            boat.inventory.append(item)
                            modelContext.insert(item)
                            try? modelContext.save()
                        } label: {
                            Label("Add \(kind.title.dropLast())", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Tank layout")
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
    private func defaultTankName(for kind: TankTypes) -> String {
        // Force the generic default for water tanks
        if kind.title.lowercased().contains("water") {
            return "water tank"
        }
        return kind.suggestedNames.first ?? "\(kind.title) 1"
    }

}
