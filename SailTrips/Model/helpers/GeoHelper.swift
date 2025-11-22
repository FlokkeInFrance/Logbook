//
//  GeoHelper.swift
//  SailTrips
//
//  Created by jeroen kok on 30/11/2025.
//

import CoreLocation
import MapKit
import SwiftData

// MARK: - Helpers

struct NearbyHarbour {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceNm: Double
    let location: Location?     // if this comes from your DB
}

extension Instances {
    var currentCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: gpsCoordinatesLat,
                               longitude: gpsCoordinatesLong)
    }
}

extension Location {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Latitude,
                               longitude: Longitude)
    }
}

private func distanceNm(from a: CLLocationCoordinate2D,
                        to b: CLLocationCoordinate2D) -> Double {
    let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
    let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
    let meters = locA.distance(from: locB)
    return meters / 1852.0
}

// MARK: - Known harbour / marina in DB

private func nearestKnownHarbour(
    from coordinate: CLLocationCoordinate2D,
    in locations: [Location],
    maxRadiusNm: Double = 1.0
) -> NearbyHarbour? {
    let harbourLocations = locations.filter {
        $0.typeOfLocation == .harbor || $0.typeOfLocation == .marina
    }

    guard !harbourLocations.isEmpty else { return nil }

    var best: NearbyHarbour?
    var bestDistNm = maxRadiusNm

    for loc in harbourLocations {
        let dNm = distanceNm(from: coordinate, to: loc.coordinate)
        guard dNm <= bestDistNm else { continue }

        bestDistNm = dNm
        best = NearbyHarbour(
            name: loc.Name,
            coordinate: loc.coordinate,
            distanceNm: dNm,
            location: loc
        )
    }

    return best
}

// MARK: - MapKit POI search for marinas (no map shown)

@MainActor
private func searchNearbyHarbourOnMapKit(
    around coordinate: CLLocationCoordinate2D,
    radiusNm: Double = 1.0
) async throws -> NearbyHarbour? {
    let radiusMeters = radiusNm * 1852.0

    let request = MKLocalPointsOfInterestRequest(
        center: coordinate,
        radius: radiusMeters
    )
    request.pointOfInterestFilter = MKPointOfInterestFilter(
        including: [.marina]
    )

    let search = MKLocalSearch(request: request)
    let response = try await search.start()

    guard !response.mapItems.isEmpty else { return nil }

    var best: NearbyHarbour?
    var bestDistNm = radiusNm

    for item in response.mapItems {
        let coord = item.placemark.coordinate
        let dNm = distanceNm(from: coordinate, to: coord)
        guard dNm <= bestDistNm else { continue }

        bestDistNm = dNm
        best = NearbyHarbour(
            name: item.name ?? "Unknown harbour",
            coordinate: coord,
            distanceNm: dNm,
            location: nil
        )
    }

    return best
}

// MARK: - Name collision detection

private func existingLocations(
    matching harbour: NearbyHarbour,
    in locations: [Location]
) -> [Location] {
    let target = harbour.name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    guard !target.isEmpty else { return [] }

    return locations.filter { loc in
        loc.Name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == target
    }
}

// MARK: - Overall outcome enum

private enum HarbourSearchOutcome {
    case tripDestination(location: Location, distanceNm: Double)
    case knownLocation(location: Location, distanceNm: Double)
    case mapKitCandidate(candidate: NearbyHarbour, duplicates: [Location])
    case none
}

private func fetchAllLocations(
    in context: ModelContext
) throws -> [Location] {
    let descriptor = FetchDescriptor<Location>()
    return try context.fetch(descriptor)
}

/// Extract the trip’s final destination `Location`, if your `Trip` model has one.
/// Adjust the property name to match your real model.
private func tripFinalDestination(for instances: Instances) -> Location? {
    // Example; change `.finalDestination` to your actual field
    return instances.currentTrip?.destination
}

@MainActor
private func searchHarbourForCurrentPosition(
    runtime: ActionRuntime,
    locations: [Location],
    radiusNm: Double = 1.0
) async -> HarbourSearchOutcome {

    let instances = runtime.instances
    let coord = instances.currentCoordinate

    // 1. Trip final destination (if any)
    if let dest = tripFinalDestination(for: instances) {
        let dNm = distanceNm(from: coord, to: dest.coordinate)
        if dNm <= radiusNm {
            return .tripDestination(location: dest, distanceNm: dNm)
        }
    }

    // 2. Any other known harbour/marina in DB
    if let nearby = nearestKnownHarbour(
        from: coord,
        in: locations,
        maxRadiusNm: radiusNm
    ) {
        if let loc = nearby.location {
            return .knownLocation(location: loc, distanceNm: nearby.distanceNm)
        }
    }

    // 3. MapKit fallback
    do {
        guard let candidate = try await searchNearbyHarbourOnMapKit(
            around: coord,
            radiusNm: radiusNm
        ) else {
            return .none
        }

        let duplicates = existingLocations(
            matching: candidate,
            in: locations
        )

        return .mapKitCandidate(candidate: candidate, duplicates: duplicates)

    } catch {
        runtime.showBanner("Error while searching harbour on map.")
        return .none
    }
}

private func createNewLocationFromMapKitCandidate(
    _ candidate: NearbyHarbour,
    type: TypeOfLocation,
    context: ModelContext
) -> Location {
    let loc = Location(
        name: candidate.name,
        latitude: candidate.coordinate.latitude,
        longitude: candidate.coordinate.longitude
    )
    loc.typeOfLocation = type
    context.insert(loc)
    try? context.save()
    return loc
}

/// Simple ad-hoc location creation, e.g. if you later decide
/// to interpret "no harbour" as anchorage/mooring logically.
private func createAdHocLocation(
    name: String,
    coord: CLLocationCoordinate2D,
    type: TypeOfLocation,
    context: ModelContext
) -> Location {
    let loc = Location(
        name: name,
        latitude: coord.latitude,
        longitude: coord.longitude
    )
    loc.typeOfLocation = type
    context.insert(loc)
    try? context.save()
    return loc
}

@MainActor
func handleInHarbourAction(runtime: ActionRuntime) async {
    let instances = runtime.instances
    let context = runtime.modelContext

    // Fetch all Location records once
    let allLocations: [Location]
    do {
        allLocations = try fetchAllLocations(in: context)
    } catch {
        runtime.showBanner("Could not load locations.")
        return
    }

    // 3-step harbour search (trip dest → DB → MapKit)
    let outcome = await searchHarbourForCurrentPosition(
        runtime: runtime,
        locations: allLocations,
        radiusNm: 1.0
    )

    var finalLocation: Location? = nil
    var infoMessage: String = ""

    switch outcome {
    case .tripDestination(let location, let dNm):
        finalLocation = location
        infoMessage = "Arrived at trip destination \(location.Name) (\(String(format: "%.2f", dNm)) nm)."

    case .knownLocation(let location, let dNm):
        finalLocation = location
        infoMessage = "Within \(String(format: "%.2f", dNm)) nm of \(location.Name)."

    case .mapKitCandidate(let candidate, let duplicates):
        if duplicates.isEmpty {
            // No name collision: create a new marina Location
            let loc = createNewLocationFromMapKitCandidate(
                candidate,
                type: .marina,
                context: context
            )
            finalLocation = loc
            infoMessage = "New marina location created for \(candidate.name)."
        } else {
            // Name collision: update first duplicate’s position
            guard let existing = duplicates.first else { break }

            existing.Latitude = candidate.coordinate.latitude
            existing.Longitude = candidate.coordinate.longitude
            existing.typeOfLocation = .marina
            try? context.save()

            finalLocation = existing
            infoMessage = "Updated position for existing marina \(existing.Name)."
        }

    case .none:
        runtime.showBanner("No harbour or marina found within 1 nm – A11HR cancelled.")
        return
    }

    guard let harbourLocation = finalLocation else {
        runtime.showBanner("Unable to resolve harbour location.")
        return
    }

    // Update Instances with the resolved harbour
    instances.currentLocation = harbourLocation
    instances.currentNavZone = .harbour
    instances.navStatus = .stopped
    // You can refine mooringUsed depending on your logic:
    // e.g. .mooredOnShore, .mooredAlongside, etc.
    // For now we'll keep the existing value or set a default:
    // instances.mooringUsed = .mooredOnShore

    // TODO (your future log completer):
    // - create a Logs record with action code "A11HR"
    // - sync with Instances as per your mapping table

    runtime.showBanner(infoMessage)
}
