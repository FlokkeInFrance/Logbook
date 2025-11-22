//
//  ActionRegistry+Build.swift
//  SailTrips
//
//  Created by jeroen kok on 29/11/2025.
//



// MARK: - Propulsion helper functions

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


extension ActionRegistry {

    static func makeDefault() -> ActionRegistry {
        var reg = ActionRegistry()
       
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
            rt.instances.currentTrip?.tripStatus != TripStatus.preparing
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
                // TODO:
                // - set trip.state = .started
                // - rt.instances.navStatus = .stopped
                // - infer harbour/anchorage/mooringType from location, ask user if unclear
                // - append log "[trip.TypeOfTrip] started"
            }
        )

        reg.add(
            "A1R",
            title: "Finish trip",
            group: .navigation,
            systemImage: "stop.fill",
            isVisible: { rt in
                // "only when trip is interrupted and boat stopped" :contentReference[oaicite:4]{index=4}
                isTripNotCompleted(rt) && isBoatStopped(rt)
            },
            handler: { rt in
                // TODO:
                // - set trip.state = .completed
                // - rt.instances.navStatus = .none
                // - clear dangers and emergency
                // - log "Trip completed, boat in [location type]"
            }
        )

        reg.add(
            "A1A",
            title: "Abort trip",
            group: .navigation,
            systemImage: "xmark.circle",
            isVisible: { rt in isTripPreparing(rt) },
            handler: { rt in
                // TODO:
                // - ask reason R
                // - mark trip aborted
                // - log "Trip aborted because (R)"
            }
        )

        reg.add(
            "A2",
            title: "Force stop logging",
            group: .otherLog,
            systemImage: "exclamationmark.triangle",
            isVisible: { rt in
                // "only visible in menu, when trip not completed" :contentReference[oaicite:5]{index=5}
                isTripNotCompleted(rt)
            },
            handler: { rt in
                // TODO:
                // - set trip.state = .completed
                // - rt.instances.navStatus = .none
                // - ask reason R
                // - log "The logbook is interrupted here because R"
            }
        )

        // MARK: - Motor regime A3..A6

        reg.add(
            "A3",
            title: "Engine idle",
            group: .motor,
            systemImage: "gauge.low",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                // TODO: set main motor state to .idle
                // log "Main motor to idle"
            }
        )

        reg.add(
            "A4",
            title: "Engine cruise",
            group: .motor,
            systemImage: "gauge",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                // TODO: set main motor state to .cruise
                // log "Main motor to cruise"
            }
        )

        reg.add(
            "A5",
            title: "Engine slow",
            group: .motor,
            systemImage: "gauge.medium",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                // TODO: set main motor state to .slow
                // log "Main motor to slow forward"
            }
        )

        reg.add(
            "A6",
            title: "Engine full",
            group: .motor,
            systemImage: "gauge.high",
            isVisible: { rt in hasSingleInboardMotorRunning(rt) },
            handler: { rt in
                // TODO: set main motor state to .full
                // log "Main motor to full forward"
            }
        )

        // MARK: - Cast off / mooring A7..A10

        reg.add(
            "A7M",
            title: "Cast off (moored)",
            group: .navigation,
            systemImage: "figure.walk",
            isVisible: { rt in
                // "when trip started and boat is stopped and boat is moored or anchored" :contentReference[oaicite:6]{index=6}
                isBoatStopped(rt) && isTripNotCompleted(rt) && isMoored(rt)
            },
            handler: { rt in
                // TODO: trip.state = .underway, navStatus = .underway,
                // mooringType = .none, onCourse = true
                // log "Casted off at [HH:MM]"
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
                //  TODO: trip.state = .underway
                // navStatus = .underway
                // mooringType = .none
                // onCourse = true
                // log "Anchor raised"
            }
        )

        reg.add(
            "A8M",
            title: "Moor boat",
            group: .navigation,
            systemImage: "dock.rectangle",
            isVisible: { rt in
                !isBoatStopped(rt) && (rt.instances.currentNavZone == NavZone.harbour || rt.instances.currentNavZone == NavZone.buoyField)
            },
            handler: { rt in
                // TODO:
                // - set mooringType depending on user choice (quay / mooring)
                // - trip.state = .interrupted
                // - navStatus = .stopped
                // - if location unclear, ask for location type
                // log "Boat moored/anchored"
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
                // TODO:
                // - mooringType = .anchor
                // - trip.state = .interrupted
                // - navStatus = .stopped
                // log "Anchor dropped" or re-use "Boat moored/anchored"
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
        let A11HR_InHarbourHandler: ActionHandler = { runtime in
            await handleInHarbourAction(runtime: runtime)
        }
        reg.add("A11H",
                title: "Leave harbour",
                group: .navigation,
                isVisible: { rt in
                    isUnderway(rt) && rt.instances.currentNavZone == NavZone.harbour }
        )
        
        reg.add("A11HR",
                title: "In harbour",
                group: .navigation,
                isVisible: { rt in
                    isUnderway(rt) && rt.instances.currentNavZone == NavZone.coastal }
        )
        reg.add(
            "A11H",
            title: "In harbour",
            group: .navigation,
            isVisible: { rt in
                isUnderway(rt) && rt.instances.currentNavZone == NavZone.coastal
            },
            handler: A11HR_InHarbourHandler
        )
        reg.add("A11A",  title: "Leave anchorage",  group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == NavZone.anchorage })
        reg.add("A11AR", title: "In anchorage",     group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == NavZone.coastal })
        reg.add("A11B",  title: "Leave buoy field", group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == NavZone.buoyField })
        reg.add("A11BR", title: "In buoy field",    group: .navigation, isVisible: { rt in
            isUnderway(rt) && rt.instances.currentNavZone == NavZone.coastal })

        // TODO: fill in visibility & handlers based on navZone + mooringType

        // MARK: - Zones A12..A15

        reg.add("A12", title: "Protected water", group: .navigation, isVisible: { rt in
            isUnderway(rt) && !(rt.instances.currentNavZone == NavZone.protectedWater) })
        reg.add("A13", title: "Coastal zone",    group: .navigation, isVisible: { rt in
            isUnderway(rt) && !(rt.instances.currentNavZone == NavZone.coastal) })
        reg.add("A14", title: "Open sea",        group: .navigation, isVisible: { rt in
            isUnderway(rt) && !(rt.instances.currentNavZone == NavZone.openSea) })
        reg.add("A15", title: "Intracoastal",    group: .navigation, isVisible: { rt in
            isUnderway(rt) && !(rt.instances.currentNavZone == NavZone.intracoastalWaterway) })

        // TODO: toggle navZone / environment, log zone change

        // MARK: - Approach / deviating / clear dangers A16..A21

        reg.add("A16", title: "Approach",          group: .navigation, isVisible: { rt in
            isUnderway(rt) && !(rt.instances.currentNavZone == NavZone.openSea)} )
        reg.add("A17", title: "Heave to",          group: .navigation, isVisible: { rt in
            isUnderway(rt) && isSailing(rt)})
        reg.add("A18", title: "Bare poles",        group: .navigation, isVisible: { rt in
            isUnderway(rt) && isSailboat(rt)})
        reg.add("A19", title: "Dangers cleared",   group: .navigation, isVisible: { rt in
            isUnderway(rt) && isDangerPresent(rt)})
        reg.add("A20", title: "Back on track",    group: .navigation, isVisible: {rt in isUnderway(rt) && !rt.instances.onCourse})
        reg.add("A21", title: "Req deviation", group: .navigation, isVisible: {rt in isUnderway(rt)})

        // TODO for each: set appropriate instances flags (danger state, route deviation…)

        // MARK: - Waypoints / navigation A23..A24

        reg.add("A23", title: "Change course",      group: .navigation, isVisible: {rt in isUnderway(rt)})
        reg.add("A24", title: "Course to waypoint", group: .navigation, isVisible: {rt in isUnderway(rt) && rt.instances.nextWPT != nil} )
            
            // TODO: A24 only visible if WPT defined, onCourse = true / bearing / CTS.
            
            // MARK: - Autopilot A25 / A25R / A26
        
        reg.add(
            "A25",
            title: "Autopilot ON",
            group: .navigation,
            systemImage: "steeringwheel",
            isVisible: {rt in isUnderway(rt) && rt.instances.steering != Steering.autopilot},
            handler: { rt in
                // TODO: set autopilot state ON in instances
            }
        )

        reg.add(
            "A25R",
            title: "Autopilot OFF",
            group: .navigation,
            systemImage: "steeringwheel.slash",
            isVisible: {rt in isUnderway(rt) && rt.instances.steering == Steering.autopilot},
            handler: { rt in
                // TODO: set autopilot state OFF
            }
        )

        reg.add(
            "A26",
            title: "Autopilot mode",
            group: .navigation,
            isVisible: {rt in isUnderway(rt) && rt.instances.steering == Steering.autopilot},
            handler: { rt in
                // TODO: show AP mode selection sheet, log change
            }
        )

        // MARK: - Sail plan (set/drop) A27..A32

        reg.add("A27",
                title: "Set all sails",
                group: .environment,
                isVisible: {rt in isClassicalSloop(rt) && isUnderway(rt) && (rt.instances.propulsion == PropulsionTool.motor || rt.instances.propulsion == PropulsionTool.none)}
        )
        reg.add("A27R",
                title: "Drop all sails",
                group: .environment,
                isVisible: {rt in isClassicalSloop(rt) && propulsionIsSailOrMotorsail(rt)}
        )
        reg.add("A27W",
                title: "Wing On Wing",
                group: .environment,
                isVisible: {rt in
            let boat = rt.instances.selectedBoat
            return isClassicalSloop(rt)
            && boat.isHeadsailSet
            && boat.isMainSailSet
            && rt.instances.pointOfSail == PointOfSail.running
            && !rt.instances.wingOnWing
        }
        )
        
        reg.add("A27WR",
                title: "On Same Tack",
                group: .environment,
                isVisible: {rt in
            let boat = rt.instances.selectedBoat
            return isClassicalSloop(rt)
            && boat.isHeadsailSet
            && boat.isMainSailSet
            && rt.instances.pointOfSail == PointOfSail.running
            && rt.instances.wingOnWing
        }
        )
        reg.add("A28",  title: "Change sail plan",group: .environment)
        reg.add("A29",  title: "Set genoa",       group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            return boat.isClassicalSloop()
                && !boat.isHeadsailSet
        },)
        reg.add("A29R", title: "Drop genoa",      group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            return boat.isClassicalSloop()
                && boat.isHeadsailSet
        },)
        reg.add("A30",  title: "Set mainsail",    group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            return boat.isClassicalSloop()
                && (boat.mainSail?.currentState.isSet == false)
        },)
        reg.add("A30R", title: "Drop mainsail",   group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            return boat.isClassicalSloop()
                && (boat.mainSail?.currentState.isSet == true)
        })
        reg.add("A31",  title: "Set Gennaker/CO",    group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let gen = boat.gennakerSail else {
                return false
            }
            // Only show "Set" when it’s not set
            return !gen.currentState.isSet
        })
        reg.add("A31R", title: "Drop Gennaker/CO",   group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let gen = boat.gennakerSail else {
                return false
            }
            return gen.currentState.isSet
        })
        reg.add("A32",  title: "Set spinnaker",   group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let spi = boat.spinnakerSail else {
                return false
            }
            return !spi.currentState.isSet
        })
        reg.add("A32R", title: "Drop spinnaker",  group: .environment,     isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let spi = boat.spinnakerSail else {
                return false
            }
            return spi.currentState.isSet
        },)

        // TODO: these will look at boat.sails states and instances.propulsionTool

        // MARK: - Reef / furl main & genoa A33..A38

        reg.add("A33R", title: "Reef mainsail",   group: .environment,     isVisible: { rt in
            
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let main = boat.mainSail, main.canReefFurther else {
                return false
            }
            return main.canReduce
        })
        
        reg.add("A33F", title: "Furl mainsail",   group: .environment,     isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let main = boat.mainSail, main.canFurlFurther else {
                return false
            }
            return main.canReduce
        })
        
        reg.add("A34",  title: "Full mainsail",   group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let main = boat.mainSail else {
                return false
            }
            return main.canIncrease
        })
        reg.add("A35R", title: "Reef genoa",      group: .environment,     isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let head = boat.headsail, head.reducedWithReefs else {
                return false
            }
            return head.canReduce
        })
        reg.add("A35F", title: "Furl genoa",      group: .environment,     isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let head = boat.headsail, head.reducedWithFurling else {
                return false
            }
            return head.canReduce
        })
        reg.add("A36",  title: "Full genoa",      group: .environment, isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let head = boat.headsail else {
                return false
            }
            return head.canIncrease
        })
        
        reg.add("A37",  title: "Increase mainsail", group: .environment,isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let main = boat.mainSail else {
                return false
            }
            return main.canIncrease
        })
        
        reg.add("A38",  title: "Increase genoa",    group: .environment,isVisible: { rt in
            let boat = rt.instances.selectedBoat
            guard boat.isClassicalSloop(), let head = boat.headsail else {
                return false
            }
            return head.canIncrease
        })

        // TODO: implement reef/furl logic using Boat.sails and Instances

        // MARK: - AWA / shape / storm tactics A39..A48

        reg.add("A39", title: "Tack",         group: .environment, isVisible: {rt in propulsionIsSailOrMotorsail(rt)})
        reg.add("A40", title: "Gybe",         group: .environment, isVisible: {rt in propulsionIsSailOrMotorsail(rt)})
        reg.add("A41", title: "Flatten sails",group: .environment, isVisible: {rt in propulsionIsSailOrMotorsail(rt)})
        reg.add("A42", title: "Curve sails",  group: .environment, isVisible: {rt in propulsionIsSailOrMotorsail(rt)})
        reg.add("A43", title: "Fall off",     group: .environment, isVisible: {rt in propulsionIsSailOrMotorsail(rt)})
        reg.add("A44", title: "Luff",         group: .environment, isVisible: {rt in propulsionIsSailOrMotorsail(rt)})
        reg.add("A45", title: "Run off",      group: .environment, isVisible: {rt in stormyConditions(rt)})
        reg.add("A46", title: "Forereach",    group: .environment, isVisible: {rt in stormyConditions(rt)})
        reg.add("A47", title: "Drogue",       group: .environment, isVisible: {rt in stormyConditions(rt)})
        reg.add("A48", title: "Sea anchor",   group: .environment, isVisible: {rt in stormyConditions(rt)})

        // TODO: use AWA, point of sail, storm danger flag

        // MARK: - Final log / landmark / steering in storm A49..A51

        reg.add("A49", title: "Final log",   group: .otherLog, isVisible: {rt in rt.instances.navStatus == NavStatus.stopped})
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
            handler: { rt in
                // TODO: open danger selector, add to dangers list
            }
        )

        reg.add(
            "AF2",
            title: "Start motor",
            group: .motor,
            systemImage: "engine.combustion",
            isEmphasised: true,
            isVisible: { rt in hasSingleInboardMotorStopped(rt) },
            handler: { rt in
                // Recommended:
                // - set propulsion motor state = .neutral (engine running, not engaged)
                // - update propulsionTool if you want
                // - log "Main motor started"
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
                // - set propulsion motor state = .stopped
                // - update propulsionTool (.sail or .none)
                // - log "Main motor stopped"
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
            "AF3N",
            title: "Night",
            group: .environment,
            systemImage: "moon.stars",
            handler: { rt in
                // TODO: instances.daySail = false
                // log "Navigating in night conditions"
            }
        )

        reg.add(
            "AF3D",
            title: "Day",
            group: .environment,
            systemImage: "sun.max",
            handler: { rt in
                // TODO: instances.daySail = true
                // log "Navigating in daylight"
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

        reg.add(
            "AF12",
            title: "Back to trip",
            group: .navigation,
            systemImage: "arrow.uturn.backward",
            handler: { rt in
                // TODO: navigate UI back to trip page (no log)
            }
        )

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

        reg.add(
            "AF15",
            title: "Log position",
            group: .navigation,
            systemImage: "scope",
            handler: { rt in
                // TODO: make complete log entry at current position
                // log "Current position is lat lon"
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
            isVisible: { rt in !rt.instances.selectedBoat.extraRigs.isEmpty},
            handler: { rt in
                // TODO: if boat.extraRigs not empty, show list of checkboxes, update rigsUsed
                // log "Rig added: [rigUsed]"
            }
        )

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
