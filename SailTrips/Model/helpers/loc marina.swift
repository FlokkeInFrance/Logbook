//
//  marina helpers.swift
//  SailTrips
//
//  Created by jeroen kok on 30/11/2025.
//

import CoreLocation
import MapKit

/*struct NearbyHarbour {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceNm: Double
    /// If this comes from your own DB, keep a reference:
    let location: Location?
}*/

/*extension Instances {
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
}*/

/// Returns the nearest known harbour (Location of type .harbor or .marina)
/// within `maxRadiusNm` nautical miles of the given coordinate.
/*func nearestKnownHarbour(
    from coordinate: CLLocationCoordinate2D,
    in locations: [Location],
    maxRadiusNm: Double = 1.0
) -> NearbyHarbour? {
    let boatLocation = CLLocation(latitude: coordinate.latitude,
                                  longitude: coordinate.longitude)
    let maxRadiusMeters = maxRadiusNm * 1852.0

    // Only keep locations that are harbour-like
    let harbourLocations = locations.filter {
        $0.typeOfLocation == .harbor || $0.typeOfLocation == .marina
    }

    var bestMatch: NearbyHarbour?
    var bestDistanceMeters = maxRadiusMeters

    for harbour in harbourLocations {
        let harbourLoc = CLLocation(latitude: harbour.Latitude,
                                    longitude: harbour.Longitude)
        let distanceMeters = boatLocation.distance(from: harbourLoc)

        guard distanceMeters <= bestDistanceMeters else { continue }

        bestDistanceMeters = distanceMeters
        let distanceNm = distanceMeters / 1852.0

        bestMatch = NearbyHarbour(
            name: harbour.Name,
            coordinate: harbour.coordinate,
            distanceNm: distanceNm,
            location: harbour
        )
    }

    return bestMatch
}

/// Looks for a harbour/marina within `radiusNm` around the given coordinate
/// using MapKit POI search. Returns the nearest one, if any.
@MainActor
func searchNearbyHarbourOnMapKit(
    around coordinate: CLLocationCoordinate2D,
    radiusNm: Double = 1.0
) async throws -> NearbyHarbour? {
    let radiusMeters = radiusNm * 1852.0

    let request = MKLocalPointsOfInterestRequest(
        center: coordinate,
        radius: radiusMeters
    )

    // .marina is the most relevant category for harbours
    request.pointOfInterestFilter = MKPointOfInterestFilter(
        including: [.marina]
    )

    let search = MKLocalSearch(request: request)
    let response = try await search.start()

    guard !response.mapItems.isEmpty else { return nil }

    let boatLocation = CLLocation(latitude: coordinate.latitude,
                                  longitude: coordinate.longitude)

    var bestResult: NearbyHarbour?
    var bestDistanceMeters = radiusMeters

    for item in response.mapItems {
        let coord = item.placemark.coordinate
        let poiLoc = CLLocation(latitude: coord.latitude,
                                longitude: coord.longitude)
        let distanceMeters = boatLocation.distance(from: poiLoc)

        guard distanceMeters <= bestDistanceMeters else { continue }

        bestDistanceMeters = distanceMeters
        let distanceNm = distanceMeters / 1852.0

        let name = item.name ?? "Unknown harbour"

        bestResult = NearbyHarbour(
            name: name,
            coordinate: coord,
            distanceNm: distanceNm,
            location: nil   // Not in your DB (yet)
        )
    }

    return bestResult
}

/// Find existing Location(s) that match this harbour candidate by name.
/// Name is compared in a case-insensitive, trimmed way.
func existingLocations(
    matching harbour: NearbyHarbour,
    in locations: [Location]
) -> [Location] {
    let targetName = harbour.name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    guard !targetName.isEmpty else { return [] }

    return locations.filter { loc in
        loc.Name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == targetName
    }
}

/// High-level helper:
/// 1. Try to find a known harbour/marina in the Location DB within `radiusNm`.
/// 2. If none, optionally fall back to MapKit and:
///    - find a marina within `radiusNm`
///    - check if a Location with same name already exists
/// Returns:
/// - `NearbyHarbour` (name, coordinate, distance)
/// - optional `Location` if a DB entry with same name already exists
@MainActor
func findHarbourInVicinity(
    instances: Instances,
    knownLocations: [Location],
    radiusNm: Double = 1.0,
    useMapKitFallback: Bool = true
) async -> (harbour: NearbyHarbour, existingLocation: Location?)? {

    let coord = instances.currentCoordinate

    // 1. Try the DB first
    if let known = nearestKnownHarbour(
        from: coord,
        in: knownLocations,
        maxRadiusNm: radiusNm
    ) {
        // Already a known Location; no duplicate question needed
        return (harbour: known, existingLocation: known.location)
    }

    // 2. Optional: MapKit fallback
    guard useMapKitFallback else { return nil }

    do {
        guard let mapHarbour = try await searchNearbyHarbourOnMapKit(
            around: coord,
            radiusNm: radiusNm
        ) else {
            return nil
        }

        // 3. Check if that name already exists in your Location DB
        let duplicates = existingLocations(
            matching: mapHarbour,
            in: knownLocations
        )

        // For simplicity, if multiple, just pick the first
        let existing = duplicates.first

        return (harbour: mapHarbour, existingLocation: existing)

    } catch {
        // You may want to log the error
        return nil
    }
}
*/
