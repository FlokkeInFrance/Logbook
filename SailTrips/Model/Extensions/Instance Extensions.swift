//
//  Extensions.swift
//  SailTrips
//
//  Created by jeroen kok on 24/11/2025.
//

extension Instances {
    func activeDangers() -> [EnvironmentDangers] {
        environmentDangers.filter { $0 != .none }
    }

    func setDangers(_ dangers: [EnvironmentDangers]) {
        if dangers.isEmpty {
            environmentDangers = [.none]
        } else {
            environmentDangers = dangers.filter { $0 != .none }
        }
    }

    func clearAllDangers() {
        environmentDangers = [.none]
    }
}
