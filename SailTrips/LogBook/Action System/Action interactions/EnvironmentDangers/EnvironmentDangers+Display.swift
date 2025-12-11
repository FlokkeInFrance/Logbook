//
//  EnvironmentDangers+Display.swift
//  SailTrips
//
//  Created by jeroen kok on 26/11/2025.
//

import Foundation

extension EnvironmentDangers {
    var displayName: String {
        switch self {
        case .none:
            return "No specific danger"
        case .strongCurrents:
            return "Strong currents"
        case .traffic:
            return "Heavy traffic"
        case .floatingDebris:
            return "Floating debris"
        case .icebergs:
            return "Icebergs"
        case .growlers:
            return "Growlers"
        case .weeds:
            return "Dense weeds"
        case .nets:
            return "Fishing nets"
        case .collisionCourse:
            return "Collision course"
        case .uncharted:
            return "Uncharted shoals / highs"
        case .magAnomalies:
            return "Magnetic anomalies"
        case .animals:
            return "Hazardous animals"
        case .orcas:
            return "Orcas"
        case .aggressiveWild:
            return "Aggressive wildlife"
        case .military:
            return "Military presence"
        case .submarine:
            return "Submarines"
        case .observationStation:
            return "Observation station"
        case .floatingStructures:
            return "Floating structures"
        case .windMills:
            return "Windmills / wind farm"
        case .fixedStructures:
            return "Fixed structures"
        case .unPredictable:
            return "Unpredictable vessels"
        case .other:
            return "Other"
        }
    }
}

