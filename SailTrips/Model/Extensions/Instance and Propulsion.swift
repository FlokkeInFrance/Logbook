//
//  Instance and Propulsion.swift
//  SailTrips
//
//  Created by jeroen kok on 29/11/2025.
//

//
//  Instances+Propulsion.swift
//  SailTrips
//

import Foundation

extension Instances {

    /// Compute which PropulsionTool is *actually* in use,
    /// based on tow state, sails and motors.
    func currentPropulsionTool() -> PropulsionTool {

        // 1. If we are in tow, this overrides everything else.
        if propulsion == .inTow {
            return .inTow
        }

        // 2. Look at the selected boat's sails and motors.
        let boat = selectedBoat

        // A sail is considered "propulsive" if its state is NOT
        // down, furled, lowered or outOfOrder.
        let nonPropulsiveStates: Set<SailState> = [
            .down,
            .furled,
            .lowered,
            .outOfOrder
        ]

        let sailsAreActive: Bool = boat.sails.contains { sail in
            !nonPropulsiveStates.contains(sail.currentState)
        }

        // 3. Determine whether any non-generator motor is actually running.
        // A motor is considered "on" if its state is not .stopped or .neutral.
        let motorIsOn: Bool = boat.motors.contains { motor in
            guard motor.use != .generator else { return false }
            switch motor.state {
            case .stopped, .neutral:
                return false
            default:
                return true
            }
        }

        // 4. Combine to derive PropulsionTool.
        switch (sailsAreActive, motorIsOn) {
        case (false, false):
            return .none
        case (false, true):
            return .motor
        case (true, false):
            return .sails
        case (true, true):
            return .motorsail
        }
    }
}
