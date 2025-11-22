//
//  AutoUpdater.swift
//  SailTrips
//
//  Created by jeroen kok on 27/07/2025.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI
import SwiftData

final class PositionUpdater: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var currentLatitude: Double = 0.0
    @Published var currentLongitude: Double = 0.0
    @Published var locationDenied: Bool = false

    private let manager = CLLocationManager()
    private var timer: Timer?

    var autoReadOnStart: Bool = false
    var autoUpdateEnabled: Bool = false
    var updateInterval: Int = 60

    init(autoReadOnStart: Bool = false,
         autoUpdateEnabled: Bool = false,
         updateInterval: Int = 60) {
        super.init()

        self.autoReadOnStart = autoReadOnStart
        self.autoUpdateEnabled = autoUpdateEnabled
        self.updateInterval = updateInterval

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        if autoReadOnStart {
            requestOnce()
        }

        if autoUpdateEnabled {
            startUpdating()
        }
    }

    func requestOnce() {
        locationDenied = false
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func startUpdating() {
        locationDenied = false
        manager.requestWhenInUseAuthorization()
        stopUpdating()

        if updateInterval == 0 {
            manager.startUpdatingLocation()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(updateInterval), repeats: true) { [weak self] _ in
                self?.manager.requestLocation()
            }
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Delegate methods (nonisolated by default)

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            DispatchQueue.main.async {
                self.locationDenied = true
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.first {
            DispatchQueue.main.async {
                self.currentLatitude = loc.coordinate.latitude
                self.currentLongitude = loc.coordinate.longitude
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationDenied = true
        }
    }
    
    func setupAutoloadSettings(autoUpdate: Bool, period: Int){
        autoUpdateEnabled = autoUpdate
        updateInterval = period
    }
}

// MARK: - DistanceCalculator (orthodromic / Haversine)
struct DistanceCalculator {
/// Returns great-circle distance in nautical miles between two lat/long points (deg).
static func distanceNM(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
let R_km = 6371.0088 // mean earth radius in km
let deg2rad = Double.pi / 180
let φ1 = lat1 * deg2rad
let φ2 = lat2 * deg2rad
let Δφ = (lat2 - lat1) * deg2rad
let Δλ = (lon2 - lon1) * deg2rad
let a = sin(Δφ/2)*sin(Δφ/2) + cos(φ1)*cos(φ2)*sin(Δλ/2)*sin(Δλ/2)
let c = 2 * atan2(sqrt(a), sqrt(1-a))
let km = R_km * c
return km / 1.852 // to nautical miles
}

static func distanceNM(from a: Location, to b: Location) -> Double {
distanceNM(lat1: a.Latitude, lon1: a.Longitude, lat2: b.Latitude, lon2: b.Longitude)
}

static func distanceNM(fromLat: Double, fromLon: Double, to location: Location) -> Double {
distanceNM(lat1: fromLat, lon1: fromLon, lat2: location.Latitude, lon2: location.Longitude)
}
}

// MARK: - Odometer Tracker (consumes PositionUpdater)
final class OdometerTracker: ObservableObject {
@ObservedObject var pos: PositionUpdater
@Bindable var instances: Instances

private var lastLat: Double?
private var lastLon: Double?

init(pos: PositionUpdater, instances: Instances) {
self.pos = pos
self.instances = instances
}

func start() {
// seed last pos with current GPS if valid
if instances.gpsCoordinatesLat != 0 || instances.gpsCoordinatesLong != 0 {
lastLat = instances.gpsCoordinatesLat
lastLon = instances.gpsCoordinatesLong
}
}

/// Call when PositionUpdater publishes a new fix.
func onNewFix(lat: Double, lon: Double) {
instances.gpsCoordinatesLat = lat
instances.gpsCoordinatesLong = lon
instances.lastNavigationTimeStamp = Date()

if let llat = lastLat, let llon = lastLon {
let nm = DistanceCalculator.distanceNM(lat1: llat, lon1: llon, lat2: lat, lon2: lon)
instances.odometerGeneral += Float(nm)
instances.odometerForTrip += Float(nm)
instances.odometerForCruise += Float(nm)
}
lastLat = lat
lastLon = lon
}
}
