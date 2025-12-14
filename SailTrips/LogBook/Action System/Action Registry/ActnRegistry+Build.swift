//
//  ActionRegistry+Build.swift
//  SailTrips
//
//  Created by jeroen kok on 29/11/2025.
//



// MARK: - Propulsion helper functions

import SwiftUI

// MARK: - Sail state step helpers

fileprivate func nextReefDown(from state: SailState) -> SailState? {
    switch state {
    case .full:   return .reef1
    case .reef1:  return .reef2
    case .reef2:  return .reef3
    //case .reef3:  return .lowered
    default:      return nil
    }
}

fileprivate func nextReefUp(from state: SailState) -> SailState? {
    switch state {
    case .reef3:  return .reef2
    case .reef2:  return .reef1
   // case .reef1:  return .full
    default:      return nil
    }
}

fileprivate func nextFurlDown(from state: SailState) -> SailState? {
    switch state {
    case .full:         return .vlightFurled
    case .vlightFurled: return .lightFurled
    case .lightFurled:  return .halfFurled
    case .halfFurled:   return .tightFurled
  //  case .tightFurled:  return .lowered
    default:            return nil
    }
}

fileprivate func nextFurlUp(from state: SailState) -> SailState? {
    switch state {
    case .tightFurled:  return .halfFurled
    case .halfFurled:   return .lightFurled
    case .lightFurled:  return .vlightFurled
  //  case .vlightFurled: return .full
    default:            return nil
    }
}

/// Generic "reduce area" for a sail – uses its ReductionMode when possible.
fileprivate func reduceOnce(_ sail: Sail) -> Bool {
    let old = sail.currentState

    let newState: SailState?
    
    if sail.reducedWithReefs {newState = nextReefDown(from: old)} else
    {if sail.reducedWithFurling {newState = nextFurlDown(from: old)}
        else {newState = nextReefDown(from:old)}}

    guard let next = newState else { return false }
    sail.currentState = next
    return true
}

/// Generic "increase area" for a sail – uses its ReductionMode when possible.
fileprivate func increaseOnce(_ sail: Sail) -> Bool {
    let old = sail.currentState

    let newState: SailState?
    if sail.reducedWithReefs {newState = nextReefUp(from: old)} else
    {if sail.reducedWithFurling {newState = nextFurlUp(from: old)}
        else {newState = nextReefUp(from:old)}
    }
 /*   switch sail.reductionMode {
    case .reef:
        newState = nextReefUp(from: old)
    case .furl:
        newState = nextFurlUp(from: old)
    }*/

    guard let next = newState else { return false }
    sail.currentState = next
    return true
}

fileprivate func setFull(_ sail: Sail) -> Bool{
    guard sail.currentState != .full else { return false }
    sail.currentState = .full
    return true
}

/// Drop / stow a sail: make sure it's not a propulsion tool anymore.
fileprivate func fullyDrop(_ sail: Sail) {
    sail.currentState = .lowered
}

/// After any sail change, recompute propulsion + situation.
fileprivate func finishSailChange(_ rt: ActionRuntime, logText: String) {
    recomputePropulsionTool(rt)
    ActionRegistry.logSimple(logText, using: rt.context)
    //rt.rederiveSituation()
}

fileprivate func propulsionMotorIndex(in boat: Boat) -> Int? {
    let motors = boat.motors
    guard !motors.isEmpty else { return nil }

    // 1. single inboard propulsion motor (non generator)
    let inboardIndices = motors.indices.filter { idx in
        let m = motors[idx]
        return m.inboard && m.use != .generator
    }

    if inboardIndices.count == 1 {
        return inboardIndices[0]
    }

    // 2. small-boat cheat: exactly one outboard motor
    if inboardIndices.isEmpty, motors.count == 1 {
        let m = motors[0]
        if m.use == .outboard {
            return 0
        }
    }

    return nil
}

fileprivate func propulsionMotorIndex(_ rt: ActionRuntime) -> Int? {
    let boat = rt.instances.selectedBoat
    return propulsionMotorIndex(in: boat)
}

// MARK: - Helpers for propulsion

/// Returns true if at least one sail is currently a propulsion tool
/// (ie not down / lowered / out of order).
fileprivate func sailsAreDriving(_ boat: Boat) -> Bool {
    boat.sails.contains (where: { (sail: Sail) in
        switch sail.currentState {
        case .full, .reef1, .reef2, .reef3, .vlightFurled, .lightFurled, .halfFurled, .tightFurled:
            return true
        default:
            return false
        }
    })
}
/// Recompute Instances.propulsion based on sails + single propulsion motor.
fileprivate func recomputePropulsionTool(_ rt: ActionRuntime) {
    let boat = rt.instances.selectedBoat

    let motorRunning: Bool = {
        guard let idx = propulsionMotorIndex(rt) else { return false }
        return boat.motors[idx].state != .stopped
    }()

    let sailDriving = sailsAreDriving(boat)

    let newTool: PropulsionTool
    switch (sailDriving, motorRunning) {
    case (false, false): newTool = .none
    case (false, true):  newTool = .motor
    case (true,  false): newTool = .sail
    case (true,  true):  newTool = .motorsail
    }

    rt.instances.propulsion = newTool
}


fileprivate func hasOnlyOnePropulsionMotor(_ rt: ActionRuntime) -> Bool {
    propulsionMotorIndex(rt) != nil
}

/// The single propulsion motor exists and is STOPPED.
fileprivate func hasSingleInboardMotorStopped(_ rt: ActionRuntime) -> Bool {
         let boat = rt.instances.selectedBoat
         guard let idx = propulsionMotorIndex(in: boat) else {
           return false
    }
    return boat.motors[idx].state == .stopped
}

/// The single propulsion motor exists and is RUNNING.
///
/// Here “running” includes *neutral* (engine on, not engaged),
/// because the hour counter ticks in that case.
fileprivate func hasSingleInboardMotorRunning(_ rt: ActionRuntime) -> Bool {
     let boat = rt.instances.selectedBoat
    guard let idx = propulsionMotorIndex(in: boat) else {
        return false
    }
    let state = boat.motors[idx].state
    return state != MotorState.stopped
}

/// Returns true when the boat has *several* motors and we cannot
/// treat exactly one of them as “the” propulsion motor.
///
/// This is the trigger for showing AF21 (motors sheet) instead of AF2/AF2R.
fileprivate func hasSeveralMotors(_ rt: ActionRuntime) -> Bool {
    let boat = rt.instances.selectedBoat

    // Must really have more than one motor
    guard boat.motors.count > 1 else { return false }

    // If we can identify a single propulsion motor (inboard or single outboard),
    // then the single-motor logic (AF2 / AF2R) should be used instead.
    return !hasOnlyOnePropulsionMotor(rt)
}

fileprivate func clearDangersAndEmergency(_ instances: Instances) {
    instances.environmentDangers = [.none]
    instances.trafficDescription = ""
    
    instances.emergencyState = false
    instances.emergencyLevel = .none
    instances.emergencyNature = .none
    instances.emergencyStart = nil
    instances.emergencyEnd = nil
    instances.emergencyDescription = ""
}


extension ActionRegistry {

    static func makeDefault() -> ActionRegistry {
        var reg = ActionRegistry()
        
        func locationTypeDescription(_ instances: Instances) -> String {
            switch instances.currentNavZone {
            case .harbour:   return "harbour"
            case .anchorage: return "anchorage"
            case .buoyField: return "buoy field"
            case .coastal:   return "coastal waters"
            case .openSea:   return "open sea"
            case .protectedWater: return "protected waters"
            case .approach:  return "approach area"
            case .traffic:   return "traffic lane"
            case .intracoastalWaterway: return "intracoastal waterway"
            case .none:      return "unknown location"
            }
        }

       
        // MARK: - Helpers for visibility
        
        func isDangerPresent(_ rt: ActionRuntime) -> Bool {
            rt.instances.environmentDangers != [EnvironmentDangers.none]
            && !rt.instances.environmentDangers.isEmpty
        }
        
        func stormyConditions(_ rt: ActionRuntime) -> Bool {
            rt.instances.severeWeather != SevereWeather.none
        }

        func isTripPreparing(_ rt: ActionRuntime) -> Bool {
            rt.instances.currentTrip?.tripStatus == TripStatus.preparing
            
        }

        func isTripNotCompleted(_ rt: ActionRuntime) -> Bool {
            rt.instances.currentTrip?.tripStatus != TripStatus.completed
        }
        
        func isTripInterrupted(_ rt: ActionRuntime) -> Bool {
            rt.instances.currentTrip?.tripStatus == TripStatus.interrupted
        }

        func isBoatStopped(_ rt: ActionRuntime) -> Bool {
            rt.instances.navStatus == NavStatus.stopped
        }

        func isUnderway(_ rt: ActionRuntime) -> Bool {
            // your definition
            rt.instances.navStatus == .underway
        }
        
        func isMoored(_ rt: ActionRuntime) -> Bool {
            rt.instances.mooringUsed != MooringType.none && rt.instances.mooringUsed != MooringType.atAnchor
        }

        func isEmergency(_ rt: ActionRuntime) -> Bool {
            // TODO: adapt to instances.emergencyState
            rt.instances.emergencyState
        }

        // MARK: - Propulsion helper functions

        func propulsionIsSailOrMotorsail(_ rt: ActionRuntime) -> Bool {
            rt.instances.propulsion == PropulsionTool.sail ||
            rt.instances.propulsion == PropulsionTool.motorsail
        }
        
        func isSailboat(_ rt: ActionRuntime) -> Bool {
            rt.instances.selectedBoat.boatType == PropulsionType.sailboat
            || rt.instances.selectedBoat.boatType == PropulsionType.motorsailer
        }
        
        func isSailing(_ rt: ActionRuntime) -> Bool {
            rt.instances.currentPropulsionTool() == .sail
            || rt.instances.currentPropulsionTool() == .motorsail
        }
        
        func isClassicalSloop(_ rt: ActionRuntime) -> Bool {
            rt.instances.selectedBoat.isClassicalSloop()
        }
        

        // MARK: - Trip lifecycle A1..A2

        reg.add(
            "A1",
            title: "Start trip",
            group: .navigation,
            systemImage: "play.fill",
            isVisible: { rt in isTripPreparing(rt) },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip to start.")
                    return
                }

                let instances = rt.instances

                // Trip state
                trip.tripStatus = .started
                trip.dateOfStart = Date()

                // Instances trip info
                instances.dateOfStart = Date()
                instances.tripDays = 0
                instances.odometerForTrip = 0.0
                instances.odometerForCruise = instances.odometerForCruise // unchanged

                // Position at start (best effort – uses current GPS coords)
                instances.startLocationLat = instances.gpsCoordinatesLat
                instances.startLocationLong = instances.gpsCoordinatesLong

                // Sequence / navigation
                instances.navStatus = .stopped
                instances.propulsion = .none
                instances.tack = .none
                instances.pointOfSail = .stopped
                instances.wingOnWing = false
                instances.onCourse = true
                instances.steering = .byHand

                // Environment & emergency reset per your instance-var-mods
                clearDangersAndEmergency(instances)

                ActionRegistry.logSimple("Trip started.", using: rt.context)
            }
)

        // MARK: - Trip lifecycle A1..A2

        reg.add(
            "A1R",
            title: "Finish trip",
            group: .navigation,
            systemImage: "stop.fill",
            isVisible: { rt in
                // only when trip is interrupted and boat stopped
                isTripInterrupted(rt) && isBoatStopped(rt)
            },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                let instances = rt.instances

                // Mark trip as completed
                trip.tripStatus = .completed

                // Boat is stopped
                instances.navStatus = .stopped

                // Clear dangers and emergency state
                clearDangersAndEmergency(instances)

                // Optionally set an arrival date
                trip.dateOfEnd = Date()
                // (spec didn't demand it, but it's often useful)
                trip.dateOfStart = trip.dateOfStart       // unchanged
                // If you want DateOfArrival in Cruise instead, wire that there.

                // Location type for log
                let locationType = locationTypeDescription(instances)

                ActionRegistry.logSimple(
                    "Trip completed, boat in \(locationType).",
                    using: rt.context
                )
            }
        )

        reg.add(
            "A1A",
            title: "Abort trip",
            group: .navigation,
            systemImage: "xmark.circle",
            isVisible: { rt in isTripPreparing(rt) },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                // Keep handler synchronous; do async UI work in a Task.
                Task { @MainActor in
                    // Ask for reason (one-line, optional)
                    let rawReason = await rt.context.promptSingleLine(
                        title: "Abort trip",
                        message: "You may give a short reason (optional).",
                        placeholder: "Reason (optional)",
                        initialText: ""
                    ) ?? ""

                    let reason = rawReason.trimmingCharacters(in: .whitespacesAndNewlines)
                    let instances = rt.instances
                    // Mark trip as completed / aborted
                    trip.tripStatus = .completed
                    trip.dateOfEnd = Date()
                    // Boat is stopped
                    instances.navStatus = .stopped
                    // Clear dangers & emergency
                    clearDangersAndEmergency(instances)
                    // Log text
                    let logText: String
                    if reason.isEmpty {
                        logText = "Trip aborted."
                    } else {
                        logText = "Trip aborted because \(reason)."
                    }

                    ActionRegistry.logSimple(logText, using: rt.context)
                }
            }
        )

        reg.add(
            "A2",
            title: "Force stop logging",
            group: .otherLog,
            systemImage: "exclamationmark.triangle",
            isVisible: { rt in
                // only when trip not completed
                isTripNotCompleted(rt)
            },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                Task { @MainActor in
                    // Ask for a reason (one-line, optional)
                    let rawReason = await rt.context.promptSingleLine(
                        title: "Force stop logging",
                        message: "You may give a short reason (optional).",
                        placeholder: "Reason (optional)",
                        initialText: ""
                    ) ?? ""

                    let reason = rawReason.trimmingCharacters(in: .whitespacesAndNewlines)

                    let instances = rt.instances

                    // Mark trip as completed
                    trip.tripStatus = .completed
                    instances.navStatus = .stopped

                    // Clear dangers & emergency
                    clearDangersAndEmergency(instances)

                    let logText: String
                    if reason.isEmpty {
                        logText = "The logbook is interrupted here."
                    } else {
                        logText = "The logbook is interrupted here because \(reason)."
                    }

                    ActionRegistry.logSimple(logText, using: rt.context)
                }
            }
        )

        // MARK: - Final log / landmark / steering in storm A49..A51

        // MARK: - Motor regime A3..A6

        reg.add( // Done
            "A3",
            title: "Engine idle",
            group: .motor,
            systemImage: "gauge.low",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                let boat = rt.instances.selectedBoat
                guard let idx = propulsionMotorIndex(in: boat) else {
                    rt.showBanner("No propulsion motor configured.")
                    return
                }
                boat.motors[idx].state = .idle
                rt.instances.propulsion = rt.instances.currentPropulsionTool()
                ActionRegistry.logSimple("Main engine idle.", using: rt.context)
            }
        )

        reg.add( // Done
            "A4",
            title: "Engine cruise",
            group: .motor,
            systemImage: "gauge",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                let boat = rt.instances.selectedBoat
                guard let idx = propulsionMotorIndex(in: boat) else {
                    rt.showBanner("No propulsion motor configured.")
                    return
                }
                boat.motors[idx].state = .cruise
                rt.instances.propulsion = rt.instances.currentPropulsionTool()
                ActionRegistry.logSimple("Main engine cruise regime", using: rt.context)
            }
        )

        reg.add( // Done
            "A5",
            title: "Engine slow",
            group: .motor,
            systemImage: "gauge.medium",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                let boat = rt.instances.selectedBoat
                guard let idx = propulsionMotorIndex(in: boat) else {
                    rt.showBanner("No propulsion motor configured.")
                    return
                }
                boat.motors[idx].state = .slow
                rt.instances.propulsion = rt.instances.currentPropulsionTool()
                ActionRegistry.logSimple("Main engine slow.", using: rt.context)
            }
        )

        reg.add(
            "A6",
            title: "Engine full",
            group: .motor,
            systemImage: "gauge.high",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                let boat = rt.instances.selectedBoat
                guard let idx = propulsionMotorIndex(in: boat) else {
                    rt.showBanner("No propulsion motor configured.")
                    return
                }
                boat.motors[idx].state = .full
                rt.instances.propulsion = rt.instances.currentPropulsionTool()
                ActionRegistry.logSimple("Main engine full revs", using: rt.context)
            }
        )


        // MARK: - Cast off / mooring A7..A10

        reg.add(
            "A7M",
            title: "Cast off (moored)",
            group: .navigation,
            systemImage: "figure.walk",
            isVisible: { rt in
                isBoatStopped(rt) && isTripNotCompleted(rt) && isMoored(rt)
            },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                let instances = rt.instances

                // We are now en route
                trip.tripStatus = .underway
                instances.navStatus = .underway

                // No longer attached to shore/buoy/anchor
                instances.mooringUsed = .none

                // By definition we consider ourselves "on course" again
                instances.onCourse = true

                ActionRegistry.logSimple("Cast off", using: rt.context)
            }
        )


        reg.add(
            "A7A",
            title: "Raise anchor",
            group: .navigation,
            systemImage: "anchor",
            isVisible: { rt in
                // "when boat is in anchorage"
                isBoatStopped(rt)
                && (rt.instances.currentNavZone == NavZone.anchorage)
            },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                let instances = rt.instances

                trip.tripStatus = .underway
                instances.navStatus = .underway

                // Anchor no longer down
                instances.mooringUsed = .none
                instances.onCourse = true

                ActionRegistry.logSimple("Anchor raised.", using: rt.context)
            }
        )


        reg.add(
            "A8M",
            title: "Moor boat",
            group: .navigation,
            systemImage: "dock.rectangle",
            isVisible: { rt in
                // When moving, in harbour or buoy field
                !isBoatStopped(rt) && (rt.instances.currentNavZone == NavZone.harbour || rt.instances.currentNavZone == NavZone.buoyField)

            },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                let instances = rt.instances

                // Trip is "interrupted" while safely moored mid-trip
                trip.tripStatus = .interrupted
                instances.navStatus = .stopped

                // Default mooring type depending on zone
                switch instances.currentNavZone {
                case .harbour:
                    instances.mooringUsed = .mooredOnShore
                case .buoyField:
                    instances.mooringUsed = .mooringBall
                default:
                    instances.mooringUsed = .mooredOnShore
                }

                instances.onCourse = false
                instances.SOG = 0.0
                instances.STW = 0.0

                ActionRegistry.logSimple("Boat moored in \(instances.currentNavZone.rawValue).", using: rt.context)
            }
        )

        reg.add(
            "A8A",
            title: "Drop anchor",
            group: .navigation,
            systemImage: "anchor.circle",
            isVisible: { rt in
                rt.instances.currentNavZone == NavZone.anchorage
            },
            handler: { rt in
                guard let trip = rt.instances.currentTrip else {
                    rt.showBanner("No active trip.")
                    return
                }

                let instances = rt.instances

                trip.tripStatus = .interrupted
                instances.navStatus = .stopped
                instances.mooringUsed = .atAnchor
                instances.onCourse = false
                instances.SOG = 0.0
                instances.STW = 0.0

                ActionRegistry.logSimple("Anchor dropped.", using: rt.context)
            }

        )

        reg.add(
            "A9",
            title: "Tank fuel",
            group: .otherLog,
            systemImage: "fuelpump",
            isVisible: { rt in
                rt.instances.currentNavZone == NavZone.harbour
            },
            handler: { rt in
                // TODO:
                // - ask new fuel level (N)
                // - update instances/boat fuelLevel
                // - log "Tanked [main fuel], fuel level N%"
            }
        )

        reg.add(
            "A10",
            title: "Relocate boat",
            group: .navigation,
            systemImage: "location.viewfinder",
            isVisible: { rt in
                rt.instances.currentNavZone == NavZone.harbour }, // when in harbour
            handler: { rt in
                // TODO:
                // - ask for new position (OP)
                // - set current location to OP
                // - optionally let user define a new position for instance "visitor's dock"
                // - log position text like "now at visitor's dock"
            }
        )

        // MARK: - Zone enter/leave A11*
        /*let A11HR_InHarbourHandler: ActionHandler = { runtime in
            await handleInHarbourAction(runtime: runtime)*/
        
        // MARK: - Harbour / anchorage / buoy field A11x

        reg.add("A11H",  title: "Leave harbour",   group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == .harbour
        }, handler: { rt in
            // Leaving harbour -> coastal zone, keep propulsion/navStatus as-is
            rt.instances.currentNavZone = .coastal
            ActionRegistry.logSimple("Left harbour, now in coastal waters.", using: rt.context)
        })

        reg.add("A11HR", title: "In harbour",      group: .navigation, isVisible: { rt in
            // Used mainly from approach (S6/S6s) to enter harbour
            isUnderway(rt) && rt.instances.currentNavZone == .approach
        }, handler: { rt in
            rt.instances.currentNavZone = .harbour
            rt.instances.onCourse = false   // we’ve reached the destination harbour, no longer “on route”
            ActionRegistry.logSimple("Entered harbour.", using: rt.context)
        })

        reg.add("A11A",  title: "Leave anchorage", group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == .anchorage
        }, handler: { rt in
            rt.instances.currentNavZone = .coastal
            ActionRegistry.logSimple("Left anchorage, now in coastal waters.", using: rt.context)
        })

        reg.add("A11AR", title: "In anchorage",    group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == .approach
        }, handler: { rt in
            rt.instances.currentNavZone = .anchorage
            rt.instances.onCourse = false
            ActionRegistry.logSimple("Arrived in anchorage.", using: rt.context)
        })

        reg.add("A11B",  title: "Leave buoy field", group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == .buoyField
        }, handler: { rt in
            rt.instances.currentNavZone = .coastal
            ActionRegistry.logSimple("Left buoy field, now in coastal waters.", using: rt.context)
        })

        reg.add("A11BR", title: "In buoy field",    group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == .approach
        }, handler: { rt in
            rt.instances.currentNavZone = .buoyField
            rt.instances.onCourse = false
            ActionRegistry.logSimple("Arrived in buoy field.", using: rt.context)
        })

        // MARK: - Zones A12..A15

        reg.add("A12", title: "Coastal zone",    group: .navigation,
                isVisible: { rt in isUnderway(rt) && rt.instances.currentNavZone != .coastal },
                handler: { rt in
                    rt.instances.currentNavZone = .coastal
                    ActionRegistry.logSimple("Changed zone: now in coastal waters.", using: rt.context)
                })

        reg.add("A13", title: "Open sea",        group: .navigation,
                isVisible: { rt in isUnderway(rt) && rt.instances.currentNavZone != .openSea },
                handler: { rt in
                    rt.instances.currentNavZone = .openSea
                    ActionRegistry.logSimple("Changed zone: now in open sea.", using: rt.context)
                })

        reg.add("A14", title: "Intracoastal",    group: .navigation,
                isVisible: { rt in isUnderway(rt) && rt.instances.currentNavZone != .intracoastalWaterway },
                handler: { rt in
                    rt.instances.currentNavZone = .intracoastalWaterway
                    ActionRegistry.logSimple("Changed zone: now in intracoastal waterway.", using: rt.context)
                })

        reg.add("A15", title: "Protected water", group: .navigation,
                isVisible: { rt in isUnderway(rt) && rt.instances.currentNavZone != .protectedWater },
                handler: { rt in
                    rt.instances.currentNavZone = .protectedWater
                    ActionRegistry.logSimple("Changed zone: now in protected waters.", using: rt.context)
                })

        // MARK: - Approach / deviating / clear dangers A16..A21

        reg.add(
            "A16",
            title: "Approach",
            group: .navigation,
            isVisible: { rt in
                isUnderway(rt) && rt.instances.currentNavZone != .openSea
            },
            handler: { rt in
                // Enter generic “approach” mode; actual harbour/anchorage/buoy field
                // will be chosen later via A11HR / A11AR / A11BR.
                rt.instances.currentNavZone = .approach
                rt.instances.onCourse = true   // still going to the intended place, just in approach phase
                ActionRegistry.logSimple("Started approach to destination.", using: rt.context)
            }
        )

        reg.add(
            "A17",
            title: "Heave to",
            group: .navigation,
            isVisible: { rt in
                isUnderway(rt) && isSailing(rt)
            },
            handler: { rt in
                rt.instances.navStatus = .heaveto
                rt.instances.currentSpeed = 0
                rt.instances.onCourse = false
                rt.instances.currentTrip?.tripStatus = .interrupted
                rt.instances.steering = .fixed
                ActionRegistry.logSimple("Boat hove to.", using: rt.context)
            }
        )

        reg.add(
            "A18",
            title: "Bare poles",
            group: .navigation,
            isVisible: { rt in
                isUnderway(rt) && isSailboat(rt)
            },
            handler: { rt in
                rt.instances.navStatus = .barepoles
                rt.instances.propulsion = .none
                rt.instances.onCourse = false
                rt.instances.currentTrip?.tripStatus = .interrupted
                rt.instances.steering = .fixed
                ActionRegistry.logSimple("Boat under bare poles.", using: rt.context)
            }
        )

        reg.add(
            "A19",
            title: "Dangers cleared",
            group: .navigation,
            isVisible: { rt in
                isUnderway(rt) && isDangerPresent(rt)
            },
            handler: { rt in
                rt.instances.environmentDangers = [.none]
                ActionRegistry.logSimple("Dangers cleared.", using: rt.context)
            }
        )

        reg.add(
            "A20",
            title: "Back on track",
            group: .navigation,
            isVisible: { rt in
                isUnderway(rt) && !rt.instances.onCourse
            },
            handler: { rt in
                rt.instances.onCourse = true
                rt.instances.navStatus = .underway
                rt.instances.currentTrip?.tripStatus = .underway
                //ActionRegistry.logSimple("Back on planned track.", using: rt.context)
            }
        )

        reg.add(
            "A21",
            title: "Req deviation",
            group: .navigation,
            isVisible: { rt in isUnderway(rt) },
            handler: { rt in
                rt.instances.onCourse = false
                //ActionRegistry.logSimple("Route deviation required.", using: rt.context)
            }
        )

        // Traffic lane (S45/S55)
        reg.add(
            "A22",
            title: "Traffic Lane",
            group: .navigation,
            isVisible: { rt in isUnderway(rt) },
            handler: { rt in
                rt.instances.currentNavZone = .traffic
                ActionRegistry.logSimple("Entered traffic lane.", using: rt.context)
            }
        )

        reg.add(
            "A23",
            title: "Change course",
            group: .navigation,
            isVisible: { rt in isUnderway(rt) },
            handler: { rt in
                //ActionRegistry.logSimple("Course change ordered.", using: rt.context)
            }
        )

        reg.add("A24", title: "Course to waypoint", group: .navigation, isVisible: {rt in isUnderway(rt) && rt.instances.nextWPT != nil} )
            
            // TODO: A24 only visible if WPT defined, onCourse = true / bearing / CTS.
            
            // MARK: - Autopilot A25 / A25R / A26
        
        // MARK: - Autopilot A25 / A25R / A26

        reg.add(
            "A25",
            title: "Autopilot ON",
            group: .navigation,
            systemImage: "steeringwheel",
            isVisible: { rt in
                // When underway and NOT already on autopilot
                isUnderway(rt) && rt.instances.steering != .autopilot
            },
            handler: { rt in
                let instances = rt.instances

                // Engage autopilot
                instances.steering = .autopilot

                // If mode is still off, pick a sensible default
                if instances.autopilotMode == .off {
                    instances.autopilotMode = Autopilot.defaultEngagedMode
                }

                // If there's no direction yet but this mode wants one, you can leave it at 0.
                // The user can immediately refine with A26.
                ActionRegistry.logSimple("Autopilot engaged.", using: rt.context)
            }
        )

        reg.add(
            "A25R",
            title: "Autopilot OFF",
            group: .navigation,
            systemImage: "steeringwheel.slash",
            isVisible: { rt in
                // Only when autopilot is currently steering
                isUnderway(rt) && rt.instances.steering == .autopilot
            },
            handler: { rt in
                let instances = rt.instances

                // Disengage autopilot and go back to manual steering
                instances.steering = .byHand
                instances.autopilotMode = .off
                instances.autopilotDirection = 0

                ActionRegistry.logSimple("Autopilot disengaged, manual steering.", using: rt.context)
            }
        )

        reg.add(
            "A26",
            title: "Autopilot mode",
            group: .navigation,
            isVisible: { rt in
                // Only meaningful when autopilot is currently engaged
                isUnderway(rt) && rt.instances.steering == .autopilot
            },
            handler: { _ in
                // Real work is done via a sheet captured in LogActionView (like A28).
                // Handler left intentionally empty.
            }
        )


        // MARK: - Sail plan A27–A32

        reg.add("A27",
                title: "sails set",
                group: .sailPlan,
          systemImage: "sail.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    return boat.mainSail != nil || boat.headsail != nil
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    var changed = false

                    if let main = boat.mainSail {
                        main.currentState = .full
                        changed = true
                    }
                    if let head = boat.headsail {
                        head.currentState = .full
                        changed = true
                    }

                    guard changed else { return }
            let nmain = boat.headsail?.nameOfSail
            let nhead = boat.mainSail?.nameOfSail
            
            finishSailChange(rt, logText: "Raised \(nmain ?? "main") and \(nhead ?? "jib")")
                })

        reg.add("A27R",
                title: "sails downed",
                group: .sailPlan,
                systemImage: "sail.slash.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    return boat.sails.contains { $0.currentState.isSet }
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    var changed = false

                    for sail in boat.sails {
                        if sail.currentState.isSet {
                            fullyDrop(sail)
                            changed = true
                        }
                    }

                    guard changed else { return }
                    rt.instances.wingOnWing = false
                    finishSailChange(rt, logText: "All sails lowered")
                })

        reg.add("A27W",
                title: "Wing on wing",
                group: .sailPlan,
                systemImage: "wind",
                isVisible: { rt in
                    !rt.instances.wingOnWing
                },
                handler: { rt in
                    rt.instances.wingOnWing = true
                    ActionRegistry.logSimple("Sailing wing on wing", using: rt.context)
                   // rt.rederiveSituation()
                })

        reg.add("A27WR",
                title: "Sails on tack",
                group: .sailPlan,
                systemImage: "wind.slash",
                isVisible: { rt in
                    rt.instances.wingOnWing
                },
                handler: { rt in
                    rt.instances.wingOnWing = false
                    ActionRegistry.logSimple("Sails back on same tack", using: rt.context)
                    //rt.rederiveSituation()
                })

        // In ActnRegistry+Build.swift, inside makeDefault()
        reg.add(
            "A28",
            title: "sails modified",
            group: .environment,
            isVisible: { rt in
                // your existing visibility predicate
                propulsionIsSailOrMotorsail(rt)
            },
            handler: { rt in
                // Present the sheet from LogActionView; usually via some state
                //rt.showSailPlanSheet()
            }
        )


        
        reg.add("A29",
                title: "jib set",
                group: .sailPlan,
                systemImage: "sail",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return false }
                    return !head.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return }
                    head.currentState = .full
                    let njib = boat.headsail?.nameOfSail
            finishSailChange(rt, logText: "\(njib ?? "jib") is set")
                })

        reg.add("A29R",
                title: "jib full furled",
                group: .sailPlan,
                systemImage: "sail.slash",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return false }
                    return head.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return }
                    fullyDrop(head)
                    var action = "down"
                    if (head.reducedWithFurling) {action = "fully furled"}
                    let nhead = boat.headsail?.nameOfSail
            finishSailChange(rt, logText: "\(nhead ?? "jib") \(action)")
                })

        reg.add("A30",
                title: "main hoisted",
                group: .sailPlan,
                systemImage: "triangle.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return false }
                    return !main.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return }
                    main.currentState = .full
                    let nmain = main.nameOfSail
                    finishSailChange(rt, logText: "\(nmain) hoisted.")
                })

        reg.add("A30R",
                title: "main down",
                group: .sailPlan,
                systemImage: "triangle.slash.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return false }
                    return main.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return }
                    fullyDrop(main)
                    let nmain = main.nameOfSail
                    var action = "lowered"
                    if main.reducedWithFurling { action = "furled" }
                    finishSailChange(rt, logText: "\(nmain) \(action).")
                })

        reg.add("A31",
                title: "Gennaker set",
                group: .sailPlan,
                systemImage: "flag.circle",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let gen = boat.gennakerSail else { return false }
                    return !gen.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let gen = boat.gennakerSail else { return }
                    gen.currentState = .full
                    finishSailChange(rt, logText: "Gennaker deployed.")
                })

        reg.add("A31R",
                title: "gennaker down/furled",
                group: .sailPlan,
                systemImage: "flag.slash.circle",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let gen = boat.gennakerSail else { return false }
                    return gen.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let gen = boat.gennakerSail else { return }
                    fullyDrop(gen)
                    finishSailChange(rt, logText: "Gennaker furled/lowered.")
                })

        reg.add("A32",
                title: "spinnaker set",
                group: .sailPlan,
                systemImage: "flag.square",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let spi = boat.spinnakerSail else { return false }
                    return !spi.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let spi = boat.spinnakerSail else { return }
                    spi.currentState = .full
                    finishSailChange(rt, logText: "Spinnaker set.")
                })

        reg.add("A32R",
                title: "spinnaker down",
                group: .sailPlan,
                systemImage: "flag.square.slash",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let spi = boat.spinnakerSail else { return false }
                    return spi.currentState.isSet
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let spi = boat.spinnakerSail else { return }
                    fullyDrop(spi)
                    finishSailChange(rt, logText: "Spinnaker down.")
                })

        // MARK: - Reef / furl mainsail & headsail A33–A38

        reg.add("A33R",
                title: "mainsail reefed",
                group: .sailPlan,
                systemImage: "triangle.lefthalf.filled",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return false }
                    return main.reducedWithReefs
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return }

                    guard reduceOnce(main) else {
                        rt.context.showBanner("No further reef available on mainsail.")
                        return
                    }
                    let curpos = boat.mainSail?.currentState.rawValue ?? "?"
                    let nmain = main.nameOfSail
                    finishSailChange(rt, logText: "\(nmain) reefed to \(curpos).")
                })

        reg.add("A33F",
                title: "mainsail reduced",
                group: .sailPlan,
                systemImage: "triangle.lefthalf.filled",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return false }
                    return main.reducedWithFurling
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return }

                    guard reduceOnce(main) else {
                        rt.context.showBanner("No further furl available on mainsail.")
                        return
                    }
                    let nmain = main.nameOfSail
                    let curpos = boat.mainSail?.currentState.rawValue ?? "?"
                    finishSailChange(rt, logText: "\(nmain) \(curpos).")
                })

        reg.add("A34",
                title: "mainsail full",
                group: .sailPlan,
                systemImage: "triangle.filled",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return false }
                    return main.isReduced
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return }

                    guard setFull(main) else {
                        rt.context.showBanner("Mainsail is already fully set.")
                        return
                    }
                    let nmain = main.nameOfSail
                    finishSailChange(rt, logText: "\(nmain) full")
                })

        reg.add("A35R", //review text
                title: "jib reefed",
                group: .sailPlan,
                systemImage: "sail.and.arrow.down.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return false }
                    return head.reducedWithReefs
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return }

                    guard reduceOnce(head) else {
                        rt.context.showBanner("No further reduction available on headsail.")
                        return
                    }
                    let nhead = boat.headsail?.nameOfSail
                    let curpos = boat.headsail?.currentState.rawValue ?? "?"
            finishSailChange(rt, logText: "\(nhead ?? "jib") reefed to \(curpos)")
                })

        reg.add("A35F", //review action, rebuild text
                title: "jib reduced",
                group: .sailPlan,
                systemImage: "sail.and.arrow.down.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return false }
            return head.reducedWithFurling && head.canReduce
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return }

                    guard reduceOnce(head) else {
                        rt.context.showBanner("No further furl available on headsail.")
                        return
                    }
            let nhead = boat.headsail?.nameOfSail ?? "jib"
            let curpos = boat.headsail?.currentState.rawValue ?? "?"
            finishSailChange(rt, logText: "\(nhead) \(curpos)")
                })
        
        reg.add("A36", //make again
                title: "jib full",
                group: .sailPlan,
                systemImage: "sail.and.arrow.up.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return false }
                    return head.canIncrease
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let head = boat.headsail else { return }

                    guard setFull(head) else {
                        rt.context.showBanner("Headsail is already fully set.")
                        return
                    }
                    let nhead = boat.headsail?.nameOfSail
            finishSailChange(rt, logText: "\(nhead ?? "jib") full")
                })
        
        reg.add("A37", //adjust text
                title: "main reef dropped",
                group: .sailPlan,
                systemImage: "triangle.righthalf.filled",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return false }
                    return main.canIncrease
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    guard let main = boat.mainSail else { return }

                    guard increaseOnce(main) else {
                        rt.context.showBanner("Mainsail is already fully set.")
                        return
                    }
                    let nmain = main.nameOfSail
                    let curpos = main.currentState
                    finishSailChange(rt, logText: "\(nmain) increased to \(curpos)")
                })

        reg.add("A38", //review action and text
                title: "jib increased",
                group: .sailPlan,
                systemImage: "sailboat.fill",
                isVisible: { rt in
                    let boat = rt.instances.selectedBoat
                    let headCan = boat.headsail?.canIncrease ?? false
                    return headCan
                },
                handler: { rt in
                    let boat = rt.instances.selectedBoat
                    var changed = false
                    if let head = boat.headsail, head.canIncrease {
                        changed = increaseOnce(head) || changed
                    }

                    guard changed else { return }
                    let nmain = boat.mainSail?.nameOfSail ?? "main"
                    let curpos = boat.mainSail?.currentState.rawValue ?? "?"
                    finishSailChange(rt, logText: "\(nmain) increased to \(curpos)")
                })

        // MARK: - AWA / shape / storm tactics A39..A48

        // MARK: - AWA / shape / storm tactics A39..A48

        reg.add(
            "A39",
            title: "Tack",
            group: .environment,
            isVisible: { rt in propulsionIsSailOrMotorsail(rt) },
            handler: { rt in
                let inst = rt.instances

                // Special case: boat is close hauled -> just switch tack, stay close hauled, no sheet.
                guard inst.pointOfSail == .closeHauled else {
                    // For other points of sail the SailingGeometrySheet will handle the details.
                    return
                }

                // Flip tack (or default to starboard if unknown)
                switch inst.tack {
                case .port:
                    inst.tack = .starboard
                case .starboard:
                    inst.tack = .port
                case .none:
                    inst.tack = .starboard
                }

                let tackText = (inst.tack == .port) ? "port" : "starboard"

                ActionRegistry.logSimple(
                    "Tack: still close hauled, now on \(tackText) tack.",
                    using: rt.context
                )
            }
        )

        reg.add(
            "A40",
            title: "Gybe",
            group: .environment,
            isVisible: { rt in propulsionIsSailOrMotorsail(rt) },
            handler: { rt in
                // High-level log; SailingGeometrySheet will add detailed one.
                //ActionRegistry.logSimple("Preparing to gybe.", using: rt.context)
            }
        )

        reg.add(
            "A43",
            title: "Fall off",
            group: .environment,
            isVisible: { rt in propulsionIsSailOrMotorsail(rt) },
            handler: { rt in
                //ActionRegistry.logSimple("Falling off from the wind.", using: rt.context)
            }
        )

        reg.add(
            "A44",
            title: "Luff",
            group: .environment,
            isVisible: { rt in propulsionIsSailOrMotorsail(rt) },
            handler: { rt in
                //ActionRegistry.logSimple("Luffing up towards the wind.", using: rt.context)
            }
        )

        reg.add(
            "A41",
            title: "Flatten sails",
            group: .environment,
            isVisible: {rt in propulsionIsSailOrMotorsail(rt)},
            handler: {rt in
                ActionRegistry.logSimple("Sails flattened", using: rt.context)
            }
        
        )
                
        reg.add(
            "A42",
            title: "Curve sails",
            group: .environment,
            isVisible: {rt in propulsionIsSailOrMotorsail(rt)},
            handler: {rt in
                ActionRegistry.logSimple("Sails curved", using: rt.context)
            }
        )

        reg.add(
            "A45",
            title: "Run off",
            group: .environment,
            isVisible: {rt in stormyConditions(rt)},
            handler: {rt in
                rt.instances.navStatus = .stormTactics
                rt.instances.onCourse = false
                rt.instances.currentTrip?.tripStatus = .interrupted
                    ActionRegistry.logSimple("Trying to handle storm conditions by Running off, not on track anymore", using: rt.context)
            }
        )
        reg.add(
            "A46",
            title: "Forereach",
            group: .environment,
            isVisible: {rt in stormyConditions(rt)},
            handler: {rt in
                rt.instances.navStatus = .stormTactics
                rt.instances.onCourse = false
                rt.instances.currentTrip?.tripStatus = .interrupted
                ActionRegistry.logSimple("Trying to handle storm conditions by Forereaching, not on track anymore", using: rt.context)
            }
        )
        reg.add(
            "A47",
            title: "Drogue",
            group: .environment,
            isVisible: {rt in stormyConditions(rt)},
            handler: {rt in
                rt.instances.navStatus = .stormTactics
                rt.instances.onCourse = false
                rt.instances.currentTrip?.tripStatus = .interrupted
                ActionRegistry.logSimple("Conditions required to deploy a drogue, not on track anymore", using: rt.context)
            }
        )
        reg.add(
            "A48",
            title: "Sea anchor",
            group: .environment,
            isVisible: {rt in stormyConditions(rt)},
            handler: {rt in
                rt.instances.navStatus = .stormTactics
                rt.instances.onCourse = false
                rt.instances.currentTrip?.tripStatus = .interrupted
                ActionRegistry.logSimple("Conditions required to deploy a sea anchor, not on track anymore", using: rt.context)
            }
        )

        // TODO: use AWA, point of sail, storm danger flag

        // MARK: - Final log / landmark / steering in storm A49..A51

        reg.add(
            "A49",
            title: "Final log",
            group: .otherLog,
            isVisible: { rt in
                rt.instances.navStatus == NavStatus.stopped
            },
            handler: { rt in
                // A49 does NOT change trip or instances, it just writes a final line
                // if the user entered something.
                Task { @MainActor in
                    let rawText = await rt.context.promptSingleLine(
                        title: "Final log entry",
                        message: "Add a concluding remark for this trip (optional).",
                        placeholder: "Final remark",
                        initialText: ""
                    ) ?? ""

                    let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
                        // If the user didn't write anything, discard the action.
                        return
                    }

                    let logText = "Trip finished, to conclude: \(text)"
                    ActionRegistry.logSimple(logText, using: rt.context)
                }
            }
        )


        reg.add("A50", title: "Landmark",    group: .otherLog, isVisible: { rt in
            rt.instances.currentNavZone == NavZone.coastal })
        reg.add("A51", title: "Storm steering", group: .navigation, isVisible: {rt in stormyConditions(rt)})

        // TODO: wire these to appropriate sheets / logs

        // MARK: - Emergency triggers E1..E4 (fixed bar)

        reg.add(
            "E1",
            title: "MOB",
            group: .emergency,
            systemImage: "figure.wave.circle",
            isEmphasised: true,
            handler: { rt in
                // TODO:
                // - instances.emergencyState = true
                // - level = .distress
                // - nature = .MOB
                // - start = now
                // - log "Crew member over board at (time, lat, lon)"
            }
        )

        reg.add(
            "E2",
            title: "Fire",
            group: .emergency,
            systemImage: "flame.fill",
            isEmphasised: true,
            handler: { rt in
                // TODO: set emergency state for fire, ask for location, log
            }
        )

        reg.add(
            "E3",
            title: "Medical",
            group: .emergency,
            systemImage: "stethoscope",
            isEmphasised: true,
            handler: { rt in
                // TODO: set emergency state for medical, ask level (distress/urgency)
            }
        )

        reg.add(
            "E4",
            title: "Emergency",
            group: .emergency,
            systemImage: "exclamationmark.octagon.fill",
            isEmphasised: true,
            handler: { rt in
                // TODO: general emergency sheet (distress / PanPan / securite / relay)
            }
        )

        // MARK: - AF (fixed bar tools)

        reg.add(
            "AF1",
            title: "Danger spotted",
            group: .environment,
            systemImage: "exclamationmark.triangle",
            isVisible: { rt in rt.instances.currentTrip?.tripStatus == .underway || rt.instances.currentTrip?.tripStatus == .interrupted },
            handler: { rt in
                // TODO: open danger selector, add to dangers list
            }
        )

        reg.add(
            "AF2",
            title: "Start engine",
            group: .motor,
            systemImage: "engine.combustion",
            isVisible: { rt in hasSingleInboardMotorStopped(rt) && !hasSeveralMotors(rt) },
            handler: { rt in
                let boat = rt.instances.selectedBoat
                guard let idx = propulsionMotorIndex(in: boat) else {
                    rt.showBanner("No propulsion motor configured.")
                    return
                }

                // Engine ON, initially in neutral (unclutched)
                boat.motors[idx].state = .neutral

                // Recompute propulsion (.motor / .motorsail / .sail / .none)
                rt.instances.propulsion = rt.instances.currentPropulsionTool()

                ActionRegistry.logSimple("Main engine started.", using: rt.context)
            }
        )

        reg.add(
            "AF2R",
            title: "Stop motor",
            group: .motor,
            systemImage: "engine.combustion.slash",
            isEmphasised: true,
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                let boat = rt.instances.selectedBoat
                guard let idx = propulsionMotorIndex(in: boat) else {
                    rt.showBanner("No propulsion motor configured.")
                    return
                }

                // Engine OFF
                boat.motors[idx].state = .stopped

                // Recompute propulsion (might become .sail or .none)
                rt.instances.propulsion = rt.instances.currentPropulsionTool()

                ActionRegistry.logSimple("Main engine stopped.", using: rt.context)
            }
        )

        reg.add(
            "AF21",
            title: "Motors",
            group: .motor,
            systemImage: "engine.combustion.circle",
            isVisible: { rt in hasSeveralMotors(rt) },
            handler: { rt in
                // TODO: show motor sheet, set Motor.state according to user
                // log according to what changed
            }
        )
        reg.add(
            "AF2S",
            title: "\u{26F5}", // sailboat character for sail parameter
            group: .motor,
            handler: { rt in
                // Present the sheet from LogActionView; usually via some state
                //rt.showSailPlanSheet()
            }
        )

        reg.add(
            "AF3N",
            title: "Night",
            group: .environment,
            systemImage: "moon.stars",
            handler: { rt in
                rt.instances.daySail = false
            }
        )

        reg.add(
            "AF3D",
            title: "Day",
            group: .environment,
            systemImage: "sun.max",
            handler: { rt in
                rt.instances.daySail = true
            }
        )

        reg.add(
            "AF4",
            title: "Failure report",
            group: .incident,
            systemImage: "exclamationmark.bubble",
            handler: { rt in
                // TODO: open Problem Reporter; that view makes the log
            }
        )

        reg.add(
            "AF5",
            title: "Manual log",
            group: .otherLog,
            systemImage: "book.and.pen",
            handler: { rt in
                // TODO: open manual log view; user makes the log entry
            }
        )

        reg.add(
            "AF6",
            title: "Modify instances",
            group: .otherLog,
            systemImage: "slider.horizontal.3",
            handler: { rt in
                // TODO: open instances manager; manager makes logs as needed
            }
        )

        reg.add(
            "AF7",
            title: "Crew incident",
            group: .incident,
            systemImage: "person.fill.questionmark",
            handler: { rt in
                // TODO: open crew incident sheet; sheet writes log
            }
        )

        reg.add(
            "AF8",
            title: "Run checklist",
            group: .checklist,
            systemImage: "checklist",
            handler: { rt in
                // TODO: open checklist picker
                // - preselect emergency checklists if emergencyState is true
            }
        )

        reg.add(
            "AF9",
            title: "Weather report",
            group: .environment,
            systemImage: "cloud.sun",
            handler: { rt in
                // TODO: open weather reporter; reporter updates Instances weather fields + log
            }
        )

        reg.add(
            "AF10",
            title: "Encounter",
            group: .environment,
            systemImage: "binoculars",
            isVisible: { rt in rt.instances.currentTrip?.tripStatus == .underway || rt.instances.currentTrip?.tripStatus == .interrupted },
            handler: { rt in
                // TODO: open encounter sheet; sheet makes log text
            }
        )

        reg.add(
            "AF11",
            title: "Insert WPT",
            group: .navigation,
            systemImage: "mappin.and.ellipse",
            handler: { rt in
                // TODO: open WPT definition sheet; log "Aim for waypoint: name"
            }
        )

        /*reg.add(
            "AF12",
            title: "Back to trip",
            group: .navigation,
            systemImage: "arrow.uturn.backward",
            handler: { rt in
                // TODO: navigate UI back to trip page (no log)
            }
        )*/

        reg.add(
            "AF14",
            title: "Change destination",
            group: .navigation,
            systemImage: "signpost.right",
            handler: { rt in
                // TODO: open destination sheet, set Trip.destination
                // log "New destination chosen: name, type"
            }
        )
        
        // ActnRegistry+Build.swift

        reg.add(
            "AF15",
            title: "Log position",
            group: .navigation,
            systemImage: "scope",
            handler: { rt in
                ActionRegistry.logSimple("Position report", using: rt.context)
            }
        )


        reg.add(
            "AF15x",
            title: "NMEA test",
            group: .navigation,
            systemImage: "scope",
            handler: { _ in
                // Sheet-driven: the real UI is presented from LogActionView
                // when AF15 is tapped. This handler intentionally left empty.
            }
        )


        reg.add(
            "AF16",
            title: "Goto next WPT",
            group: .navigation,
            systemImage: "arrowshape.turn.up.right",
            handler: { rt in
                // TODO: if WPT list defined:
                // - lastWPT = nextWPT or departure
                // - nextWPT = following WPT from list in the trip's definition or destination (but ask confirmation of that)
                // - if distance > 0.5 nm from supposed wpt: ask confirmation / ask coordinates
                // - maybe create WPT at current location to keep distances consistent
                // log "Navigating to next WPT (name)"
            }
        )

        reg.add(
            "AF17",
            title: "Extra rigging",
            group: .environment,
            isVisible: { rt in !rt.instances.selectedBoat.extraRiggingItems.isEmpty},
            handler: { rt in
                // TODO: if boat.extraRigs not empty, show list of checkboxes, update rigsUsed
                // log "Rig added: [rigUsed]"
            }
        )
        
        // Energy and Water Levels
        
        reg.add(
            "AF18",
            title: "Levels",
            group: .motor,
            systemImage: "",
            isEmphasised: false,
            isVisible: { rt in !rt.instances.selectedBoat.extraRiggingItems.isEmpty},
            handler: { rt in
                // TODO: if boat.extraRigs not empty, show list of checkboxes, update rigsUsed
                // log "Rig added: [rigUsed]"
            })

        // MARK: - EM emergency management (all require emergencyState == true)

        reg.add(
            "EM1",
            title: "Mayday",
            group: .emergency,
            isEmphasised: true,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO: show Mayday call template, then log when user presses OK
                    //Adapt template to conditions MOB, Fire, extreme médical, or other condition if known, otherwise show general template
            }
        )

        reg.add(
            "EM1R",
            title: "Mayday relay",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO: show Mayday relay template, log
            }
        )

        reg.add(
            "EM2",
            title: "PAN PAN",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO: PAN PAN template, log
            }
        )

        reg.add(
            "EM3",
            title: "Securité",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO: securité template, log
            }
        )

        reg.add(
            "EM4",
            title: "Ack call",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO: ask recipient, log acknowledgement
            }
        )

        reg.add(
            "EM5",
            title: "Who (crew)",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO: show crew list, select member; log selected name
            }
        )

        reg.add(
            "EM6",
            title: "Req assist",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: log "require assistance"
            }
        )

        reg.add(
            "EM7",
            title: "SAR in area",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: brief description, log "SAR team arrived in area: description"
            }
        )

        reg.add(
            "EM8",
            title: "Assessment",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: ask description, log "current situation is description"
            }
        )

        reg.add(
            "EM9",
            title: "Get medical advice",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: log "asked for medical advice"
            }
        )

        reg.add(
            "EM10",
            title: "Tow requested",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: mark tow requested, log
            }
        )

        reg.add(
            "EM11",
            title: "In tow",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { rt in
                // TODO:
                // - propulsionTool = .inTow
                // - ask destination D
                // - log "currently under tow (towards D)"
            }
        )

        reg.add(
            "EM11T",
            title: "Take in tow",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: ask destination D, log "took casualty in tow towards D"
            }
        )

        reg.add(
            "EM12",
            title: "Abandon ship",
            group: .emergency,
            isEmphasised: true,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: ask liferaft vs jump, log
            }
        )

        reg.add(
            "EM13",
            title: "Urgency level",
            group: .emergency,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: choose between distress, urgency, securite or no change; log
            }
        )

        reg.add(
            "EM14",
            title: "End emergency",
            group: .emergency,
            isEmphasised: true,
            isVisible: { rt in isEmergency(rt) },
            handler: { _ in
                // TODO: set emergencyEnd = now; emergencyState = false
                // optionally final report sheet, log
            }
        )

        return reg
    }
}
