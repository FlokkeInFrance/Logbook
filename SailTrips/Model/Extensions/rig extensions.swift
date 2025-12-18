//
//  rig extensions.swift
//  SailTrips
//
//  Created by jeroen kok on 01/12/2025.
//


import SwiftUI

extension ExtraRigging {
    var label: LocalizedStringKey {
        switch self {
        case .outrigger: "Outrigger"
        case .spinnakerPole: "Spinnaker pole"
        case .whiskerPole: "Whisker pole"
        case .preventer: "Preventer"
        case .walder: "Walder / boom brake"
        case .customPreventer: "Custom preventer"
        case .lifelines: "Additional lifelines / jacklines"
        case .bowsprit: "Bowsprit"
        case .removableForestay: "Removable forestay / inner stay"
        case .other: "Other (custom item)"
        }
    }
}
