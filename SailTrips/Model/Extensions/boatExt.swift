//
//  boatExt.swift
//  SailTrips
//
//  Created by jeroen kok on 30/11/2025.
//

extension Boat {
    /// Returns true if the boat is a classical sloop.
    ///
    /// Requirements:
    /// - rigType == .sloop
    /// - Exactly 2 sails are non-optional
    /// - These two must be: "Mainsail" + ("Genoa" or "Jib")
    /// - Other sails are allowed but must be optional
    func isClassicalSloop() -> Bool {
        // 1. Rig must explicitly be a sloop
        guard rigType == .sloop else { return false }

        // 2. Extract the non-optional sails
        let nonOptional = sails.filter { $0.optional == false }

        guard nonOptional.count == 2 else { return false }

        // Normalize their names
        let names = nonOptional.compactMap { sail -> String? in
            let n = sail.nameOfSail.trimmingCharacters(in: .whitespacesAndNewlines)
            return n.isEmpty ? nil : n.lowercased()
        }

        guard names.count == 2 else { return false }

        let hasMain = names.contains("mainsail")
        let hasGenoa = names.contains("genoa")
        let hasJib = names.contains("jib")

        // Required pair:
        return hasMain && (hasGenoa || hasJib)
    }
}
