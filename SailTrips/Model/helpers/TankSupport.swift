//
//  TankSupport.swift
//  SailTrips
//
//  Created by jeroen kok on 16/12/2025.
//

import SwiftUI

extension InventoryItem {
    /// Tank kind stored in `subcategory` (so we don't need schema changes).
    var tankKind: TankTypes? {
        get { TankTypes(rawValue: subcategory) }
        set { subcategory = newValue?.rawValue ?? "" }
    }

    /// Percent full stored in `quantity` (0...100).
    var percentFull: Int {
        get { min(100, max(0, quantity)) }
        set { quantity = min(100, max(0, newValue)) }
    }

    /// Computed actual amount, only meaningful if capacity > 0.
    var amountComputed: Int? {
        guard capacity > 0 else { return nil }
        return Int((Double(capacity) * Double(percentFull) / 100.0).rounded())
    }
}

extension Boat {
    var tankItems: [InventoryItem] {
        inventory.filter { $0.type == .tank }
    }

    func tankItems(of kind: TankTypes) -> [InventoryItem] {
        tankItems.filter { $0.tankKind == kind }
    }
}

extension TankTypes {
    var title: String {
        switch self {
        case .water: "Water"
        case .fuel: "Fuel"
        case .batteryBank: "Battery banks"
        case .holdingTank: "Holding tanks"
        }
    }

    var suggestedNames: [String] {
        switch self {
        case .water:
            return ["Bow tank", "Stern tank", "Port tank", "Starboard tank"]
        case .fuel:
            return ["Main tank", "Day tank", "Emergency jerrycan"]
        case .batteryBank:
            return ["House bank", "Start battery", "Bow thruster bank", "Electronics bank"]
        case .holdingTank:
            return ["Black water", "Grey water", "Forward holding", "Aft holding"]
        }
    }
}

extension TankTypes {
    func unit(using settings: LogbookSettings) -> String {
        switch self {
        case .water, .fuel, .holdingTank:
            return settings.volumeUnit.shortLabel   // e.g. "L" or "gal"
        case .batteryBank:
            return "Ah"
        }
    }
}
