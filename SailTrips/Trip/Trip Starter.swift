//
//  TripStartResult.swift
//  SailTrips
//
//  Created by jeroen kok on 14/12/2025.
//

import SwiftData
import SwiftUI

struct TripStartResult {
    let trip: Trip
    let detectedCruise: Cruise?
}

struct TripStarter {
    let context: ModelContext

    func startTrip(
        instances: Instances,
        now: Date = .now,
        cruises: [Cruise] = []
    ) throws -> TripStartResult {

        // if ongoing -> reuse
        if let cur = instances.currentTrip, cur.tripStatus != .completed {
            return TripStartResult(trip: cur, detectedCruise: nil)
        }

        let trip = Trip()
        trip.dateOfStart = now
        trip.boat = instances.selectedBoat
        trip.tripStatus = .preparing

        // attach early (so downstream code can refer to currentTrip)
        context.insert(trip)
        instances.currentTrip = trip
        instances.dateOfStart = now

        // initialize trip fields from instances
        if let loc = instances.currentLocation {
            trip.startPlace = loc
        }

        // CONSOLIDATED RESETS (lifted from TripCompanion.onAppear)
        applyTripStartResets(instances: instances, trip: trip)

        // cruise candidate
        let detected = cruises.first(where: { cruise in
            guard cruise.Boat?.id == instances.selectedBoat.id else { return false }
            let start = cruise.DateOfStart
            let end = cruise.DateOfArrival ?? Date.distantFuture
            return (start...end).contains(now)
        })

        try context.save()
        return TripStartResult(trip: trip, detectedCruise: detected)
    }

    private func applyTripStartResets(instances: Instances, trip: Trip) {
        // Keep your current logic exactly (copy from TripCompanion.onAppear)

        if !(instances.currentNavZone == .anchorage ||
             instances.currentNavZone == .harbour ||
             instances.currentNavZone == .buoyField) {
            instances.currentNavZone = .harbour
        }

        if instances.mooringUsed == .none || instances.mooringUsed == .other {
            instances.mooringUsed = .mooredOnShore
        }

        instances.navStatus = .none
        instances.propulsion = .none
        instances.onCourse = true
        instances.tack = .none
        instances.pointOfSail = .stopped
        instances.daySail = true
        instances.presenceOfCn = false
        instances.severeWeather = .none
        instances.environmentDangers = [.none]
        instances.currentSpeed = 0
        instances.currentDirection = 0
        instances.emergencyState = false
        instances.emergencyStart = nil
        instances.emergencyEnd = nil
        instances.nextHT = nil
        instances.nextLT = nil
        instances.next2HT = nil
        instances.next2LT = nil
    }

    func setCurrentCruise(_ cruise: Cruise?, instances: Instances) throws {
        instances.currentCruise = cruise
        instances.currentTrip?.cruise = cruise
        try context.save()
    }
}
