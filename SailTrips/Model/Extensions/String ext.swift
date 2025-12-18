//
//  raw.swift
//  SailTrips
//
//  Created by jeroen kok on 16/12/2025.
//


import SwiftUI

extension String {
    /// "moored_on_buoy" -> "Moored on buoy"
    /// "moored stern on" -> "Moored stern on"
    /// "Orca attack" -> "Orca attack"
    func enumLabel() -> LocalizedStringKey {
        let cleaned = self
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "" }

        let lower = cleaned.lowercased()
        let sentence = lower.prefix(1).uppercased() + lower.dropFirst()
        return LocalizedStringKey(sentence)
    }
}
